#!/usr/bin/env bash
# Tests the resource-address matching in self_heal_orphaned_creates
# (apply_infrastructure.sh / apply_infrastructure_update.sh).
#
# This is the failure these tests exist for, and it is the quietest kind. The
# self-heal's case arms were anchored at the root -- `google_storage_bucket.*` --
# but nothing in this catalogue is declared at the root. Every real address is
# module-relative:
#
#   module.app_cloudrun.module.app_storage.module.app_storage.google_storage_bucket.buckets["addons"]
#
# so no arm ever matched. The function still logged "checking whether the
# resource actually exists live", iterated every planned create, healed nothing,
# and returned. Confirmed live 2026-08-17 on Odoo_CloudRun a0b84a92: the gate
# opened at 23:23:01 and the apply gave up at 23:23:05 with the orphaned bucket
# sitting there, live and importable, the whole time.
#
# A wrong glob in a case arm produces no error, no warning and no diff in
# behaviour from "there was nothing to heal" -- so nothing short of asserting on
# real addresses catches it.
#
# The scripts execute a real pipeline at top level and so cannot be sourced. The
# case-arm patterns are extracted from the source and evaluated on their own,
# which is the point: the test reads what the script will actually run, not a
# copy of it that can drift.
#
# Run: ./self_heal_address_match_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

failures=0
check() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf '  ok   %s\n' "$label"
    else
        printf '  FAIL %s (expected %s, got %s)\n' "$label" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

# The arm for a given resource type, read out of the script itself.
arm_for() {
    local script="$1" type="$2"
    grep -oE "^[[:space:]]*\*?${type}\.\*\)" "$SCRIPT_DIR/$script" | head -1 \
        | sed -E 's/^[[:space:]]*//; s/\)$//'
}

# Does that arm match this address?
matches() {
    local pattern="$1" addr="$2"
    case "$addr" in
        $pattern) echo yes ;;
        *)        echo no ;;
    esac
}

# Real addresses, taken verbatim from live plans.
NESTED_BUCKET='module.app_cloudrun.module.app_storage.module.app_storage.google_storage_bucket.buckets["addons"]'
NESTED_CLUSTER='module.app_gke.google_container_cluster.primary'
NESTED_SQL='module.services_gcp.google_sql_database_instance.postgres[0]'
ROOT_BUCKET='google_storage_bucket.tfstate'
# Sibling types that must NOT be adopted: importing one under a bucket address
# would write the wrong resource into state.
BUCKET_OBJECT='module.x.google_storage_bucket_object.seed'
BUCKET_IAM='module.x.google_storage_bucket_iam_member.reader'

for script in apply_infrastructure.sh apply_infrastructure_update.sh; do
    echo "$script"

    bucket_arm="$(arm_for "$script" google_storage_bucket)"
    cluster_arm="$(arm_for "$script" google_container_cluster)"
    sql_arm="$(arm_for "$script" google_sql_database_instance)"

    if [ -z "$bucket_arm" ] || [ -z "$cluster_arm" ] || [ -z "$sql_arm" ]; then
        echo "  FAIL could not locate all three case arms (bucket='$bucket_arm' cluster='$cluster_arm' sql='$sql_arm')"
        failures=$((failures + 1))
        continue
    fi

    # The regression: a nested address must match.
    check "bucket arm matches a NESTED address"   yes "$(matches "$bucket_arm"  "$NESTED_BUCKET")"
    check "cluster arm matches a NESTED address"  yes "$(matches "$cluster_arm" "$NESTED_CLUSTER")"
    check "sql arm matches a NESTED address"      yes "$(matches "$sql_arm"     "$NESTED_SQL")"

    # A root-level address must keep working -- widening must not narrow.
    check "bucket arm still matches a ROOT address" yes "$(matches "$bucket_arm" "$ROOT_BUCKET")"

    # And must not swallow neighbouring types.
    check "bucket arm ignores google_storage_bucket_object"     no "$(matches "$bucket_arm" "$BUCKET_OBJECT")"
    check "bucket arm ignores google_storage_bucket_iam_member" no "$(matches "$bucket_arm" "$BUCKET_IAM")"
done

# The two scripts carry the same self-heal. A fix applied to one only would
# leave create-path orphans unhealable while update-path ones healed, which is
# indistinguishable from "it works" until someone hits the other path.
echo "both scripts"
for type in google_storage_bucket google_container_cluster google_sql_database_instance; do
    a="$(arm_for apply_infrastructure.sh "$type")"
    b="$(arm_for apply_infrastructure_update.sh "$type")"
    check "$type arm identical in both scripts" "$a" "$b"
done

# Globbing must be off around the loop: a for_each address carries brackets
# (buckets["addons"]), and an unquoted $(...) expansion is subject to pathname
# expansion where [...] is a character class.
echo "glob safety"
for script in apply_infrastructure.sh apply_infrastructure_update.sh; do
    on=$(grep -cE '^[[:space:]]*set -f$' "$SCRIPT_DIR/$script")
    off=$(grep -cE '^[[:space:]]*set \+f$' "$SCRIPT_DIR/$script")
    check "$script disables globbing for the address loop" 1 "$on"
    # One restore per exit path (healed / not healed).
    check "$script restores globbing on every exit path"   2 "$off"
done

echo
if [ "$failures" -eq 0 ]; then
    echo "All self-heal address-matching tests passed."
    exit 0
fi
echo "$failures test(s) failed."
exit 1
