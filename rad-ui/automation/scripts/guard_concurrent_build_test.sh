#!/usr/bin/env bash
# Tests for guard_concurrent_build.sh (audit P-24): refuse a second build on
# one deployment's Terraform state, FAIL CLOSED when Cloud Build cannot be
# asked, let the OLDEST build win, and clear a leftover lock only after the
# check has passed. gcloud and gsutil are stubs driven by files, so nothing
# here reaches GCP. Run: ./guard_concurrent_build_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/guard_concurrent_build.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

failures=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $label"
  else
    echo "  ❌ $label — expected '$expected', got '$actual'"
    failures=$((failures + 1))
  fi
}

# gcloud stub: prints $TMP_DIR/listing (tab-separated, as `value()` does) and
# exits with $TMP_DIR/gcloud_rc; counts calls.
cat > "$TMP_DIR/gcloud" <<'EOF'
#!/usr/bin/env bash
echo x >> "$STUB_DIR/gcloud_calls"
rc=$(cat "$STUB_DIR/gcloud_rc" 2>/dev/null || echo 0)
if [ "$rc" != 0 ]; then echo "ERROR: (gcloud.builds.list) PERMISSION_DENIED" >&2; exit "$rc"; fi
cat "$STUB_DIR/listing" 2>/dev/null
EOF
# gsutil stub: `stat` succeeds while $TMP_DIR/lock exists; `rm` removes it.
cat > "$TMP_DIR/gsutil" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do case "$a" in stat) [ -f "$STUB_DIR/lock" ]; exit $? ;; rm) rm -f "$STUB_DIR/lock"; echo rm >> "$STUB_DIR/gsutil_rm"; exit 0 ;; esac; done
exit 0
EOF
chmod +x "$TMP_DIR/gcloud" "$TMP_DIR/gsutil"

reset() {
  rm -f "$TMP_DIR/listing" "$TMP_DIR/gcloud_calls" "$TMP_DIR/gsutil_rm" "$TMP_DIR/lock"
  echo 0 > "$TMP_DIR/gcloud_rc"
  : > "$TMP_DIR/listing"
}
row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TMP_DIR/listing"; }
run_guard() {
  STUB_DIR="$TMP_DIR" GCLOUD="$TMP_DIR/gcloud" GSUTIL="$TMP_DIR/gsutil" \
    GUARD_RETRY_SLEEP=0 GUARD_LIST_LIMIT="${LIMIT:-500}" \
    PROJECT_ID=p DEPLOYMENT_ID=dep1 BUILD_ID="${SELF:-self}" \
    LOCK_PATH=gs://b/deployments/M/dep1/state/default.tflock \
    bash "$GUARD" > "$TMP_DIR/out" 2>&1
  echo $?
}
lock_present() { [ -f "$TMP_DIR/lock" ] && echo yes || echo no; }

echo "guard_concurrent_build:"

reset; row self dep1 2026-09-19T10:00:00.5Z; row other dep2 2026-09-19T09:00:00Z; touch "$TMP_DIR/lock"
check "no other build for this deployment: passes" 0 "$(run_guard)"
check "…and clears the leftover lock" no "$(lock_present)"

reset; row older dep1 2026-09-19T09:59:00Z; row self dep1 2026-09-19T10:00:00Z; touch "$TMP_DIR/lock"
check "an OLDER live build for this deployment: refuses (1)" 1 "$(run_guard)"
check "…and leaves its lock alone" yes "$(lock_present)"
check "…naming the other build" 1 "$(grep -c 'older (created' "$TMP_DIR/out")"

reset; row self dep1 2026-09-19T10:00:00Z; row newer dep1 2026-09-19T10:00:07Z
check "only a NEWER build is live: the oldest proceeds (0)" 0 "$(run_guard)"

# Two builds created in the same second: exactly one must win.
reset; row aaa dep1 2026-09-19T10:00:00Z; row bbb dep1 2026-09-19T10:00:00Z
a=$(SELF=aaa run_guard); b=$(SELF=bbb run_guard)
check "same-second twins: exactly one proceeds (aaa=0, bbb=1)" "0 1" "$a $b"

# Variable-length fractions: a whole second is EARLIER than the same second
# plus a fraction, which plain text ordering gets backwards.
reset; row whole dep1 2026-09-19T10:00:05Z; row self dep1 2026-09-19T10:00:05.4Z
check "…:05Z is older than …:05.4Z, so self refuses" 1 "$(run_guard)"

# THE FAIL-OPEN: gcloud errors. The old inline check swallowed this with
# `2>/dev/null || true`, saw an empty list, and deleted the lock anyway.
reset; echo 1 > "$TMP_DIR/gcloud_rc"; touch "$TMP_DIR/lock"
check "gcloud errors: FAILS CLOSED (2)" 2 "$(run_guard)"
check "…after retrying" 3 "$(wc -l < "$TMP_DIR/gcloud_calls" | tr -d ' ')"
check "…and never touches the lock" yes "$(lock_present)"
check "…and says so" 1 "$(grep -c 'Could not confirm' "$TMP_DIR/out")"

# A full page may hide the build that matters.
reset; row self dep1 2026-09-19T10:00:00Z; row a dep9 2026-09-19T10:00:00Z; row b dep9 2026-09-19T10:00:00Z
check "a full page of ongoing builds: fails closed (2)" 2 "$(LIMIT=3 run_guard)"

# Our own entry not in the listing: cannot order ourselves, so any other
# live build for this deployment refuses.
reset; row other dep1 2026-09-19T10:05:00Z
check "own entry missing + another build live: refuses (1)" 1 "$(run_guard)"

reset
check "BUILD_ID unset: fails closed (2)" 2 "$(STUB_DIR="$TMP_DIR" GCLOUD="$TMP_DIR/gcloud" PROJECT_ID=p DEPLOYMENT_ID=d BUILD_ID= bash "$GUARD" >/dev/null 2>&1; echo $?)"

# Every pipeline that touches a deployment's state must call the guard, and
# none may keep the fail-open inline list.
AUT="$SCRIPT_DIR/.."
for y in cloudbuild_deployment_create.yaml cloudbuild_deployment_update.yaml cloudbuild_deployment_destroy.yaml cloudbuild_deployment_purge.yaml; do
  check "$y runs guard_concurrent_build.sh" 1 "$([ "$(grep -c 'guard_concurrent_build.sh' "$AUT/$y")" -ge 1 ] && echo 1 || echo 0)"
  check "$y has no fail-open 'builds list' of its own" 0 "$(grep -c 'gcloud builds list' "$AUT/$y")"
  check "$y deletes no lock outside the guard" 0 "$(grep -c 'gsutil rm "\$\$LOCK_PATH"' "$AUT/$y")"
done

if [ "$failures" -gt 0 ]; then
  echo "❌ $failures failure(s)"
  exit 1
fi
echo "✅ all passed"
