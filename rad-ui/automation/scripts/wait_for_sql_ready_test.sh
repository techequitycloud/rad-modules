#!/usr/bin/env bash
# Tests for wait_for_sql_instance_ready (apply_infrastructure.sh /
# apply_infrastructure_update.sh).
#
# Worth testing despite being ten lines of bash: it is a polling loop with a
# timeout, it parses an attribute out of `tofu state show` by regex, and it
# runs only in the rare self-heal path — so a mistake here would sit unnoticed
# until the next Cloud SQL orphan, and then hang or skip the wait entirely.
# Neither failure is visible in a normal deploy.
#
# The scripts execute a real pipeline at top level and so cannot be sourced;
# the function is extracted and evaluated on its own, with tofu/log/sleep
# stubbed. Run: ./wait_for_sql_ready_test.sh
#
# The stub state is file-backed, NOT a shell variable: the function reads state
# through `tofu state show | awk`, and a pipeline runs its left-hand side in a
# SUBSHELL, so a variable counter never propagates back. The first draft of
# this file used one, saw the same queued state forever, and hung.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STATES_FILE="$TMP_DIR/states"
READS_FILE="$TMP_DIR/reads"

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

# Queue the states `tofu state show` will report, one per call. Once exhausted
# it reports RUNNABLE, so no test can loop forever on a typo.
queue_states() {
  printf '%s\n' "$@" > "$STATES_FILE"
  echo 0 > "$READS_FILE"
}
reads_so_far() { cat "$READS_FILE"; }

log() { :; }
sleep() { :; }   # instant suite; the loop's cadence is not under test

# Mimics the two tofu calls the function makes. `apply -refresh-only` succeeds
# silently; `state show` emits a realistic fragment so the regex has to pick
# the top-level `state` attribute and not `database_version` or a nested block.
tofu() {
  case "${1:-}" in
    apply) return 0 ;;
    state)
      local n s
      n=$(cat "$READS_FILE")
      s=$(awk -v i="$((n + 1))" 'NR == i { print }' "$STATES_FILE")
      [ -z "$s" ] && s=RUNNABLE
      echo $((n + 1)) > "$READS_FILE"
      printf '    database_version = "MYSQL_8_4"\n'
      printf '    state            = "%s"\n' "$s"
      printf '    settings {\n        activation_policy = "ALWAYS"\n    }\n'
      ;;
  esac
}

ADDR='google_sql_database_instance.mysql_instance[0]'

for script in apply_infrastructure.sh apply_infrastructure_update.sh; do
  echo "$script"
  # shellcheck disable=SC2046
  eval "$(sed -n '/^wait_for_sql_instance_ready()/,/^}/p' "$SCRIPT_DIR/$script")"

  SQL_READY_TIMEOUT_SECONDS=600
  SQL_READY_POLL_SECONDS=0

  # Already up: returns immediately, one read.
  queue_states RUNNABLE
  wait_for_sql_instance_ready "$ADDR"
  check "returns 0 when the instance is already RUNNABLE" "0" "$?"
  check "  and reads state exactly once" "1" "$(reads_so_far)"

  # The real case: adopted mid-provision, ready a few polls later. Returning on
  # the first non-RUNNABLE read is the bug this guards.
  queue_states PENDING_CREATE PENDING_CREATE MAINTENANCE RUNNABLE
  wait_for_sql_instance_ready "$ADDR"
  check "keeps polling until RUNNABLE" "0" "$?"
  check "  and stops on the first RUNNABLE, not later" "4" "$(reads_so_far)"

  # A genuinely broken instance must not hang the build forever.
  SQL_READY_TIMEOUT_SECONDS=0
  queue_states PENDING_CREATE
  wait_for_sql_instance_ready "$ADDR"
  check "gives up rather than hanging once the timeout is spent" "1" "$?"
  check "  and does not read state after the deadline" "0" "$(reads_so_far)"
done

echo
if [ "$failures" -eq 0 ]; then
  echo "all wait_for_sql_instance_ready tests passed"
else
  echo "$failures assertion(s) failed"
fi
exit "$failures"
