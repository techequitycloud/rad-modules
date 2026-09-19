#!/usr/bin/env bash
# Tests for rollout_timeout_policy.sh (audit P-30, decision D-9): a failed
# apply counts as success ONLY when every `Error:` block is a workload rollout
# timeout. The samples below are shaped like real OpenTofu output -- boxed,
# with ANSI colour, resource addresses and source excerpts -- because the
# block splitting is the part most likely to be wrong, and a flat one-line
# sample would never exercise it. Run: ./rollout_timeout_policy_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=rollout_timeout_policy.sh
. "$SCRIPT_DIR/rollout_timeout_policy.sh"

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

ESC=$(printf '\033')
R="${ESC}[31m"; B="${ESC}[1m"; N="${ESC}[0m"

# Emits one boxed error block the way OpenTofu prints it with colour on.
boxed() {
  local summary="$1" address="$2" file="$3"
  printf '%s╷%s\n' "$R" "$N"
  printf '%s│%s %s%sError: %s%s%s\n' "$R" "$N" "$R" "$B" "$N" "$B" "$summary"
  printf '%s│%s %s\n' "$R" "$N" "$N"
  printf '%s│%s %s\n' "$R" "$N" ""
  printf '%s│%s   with %s,\n' "$R" "$N" "$address"
  printf '%s│%s   on %s line 12, in resource:\n' "$R" "$N" "$file"
  printf '%s│%s   12: resource "x" "y" {\n' "$R" "$N"
  printf '%s│%s\n' "$R" "$N"
  printf '%s╵%s\n' "$R" "$N"
}

preamble() {
  cat <<'EOF'
kubernetes_deployment_v1.app["base"]: Still creating... [9m50s elapsed]
kubernetes_deployment_v1.app["base"]: Still creating... [10m0s elapsed]
EOF
}

verdict() { if only_rollout_timeouts "$1" >/dev/null; then echo tolerated; else echo failed; fi; }

echo "rollout_timeout_policy:"

KUBECTL_DEPLOY="local-exec provisioner error: Error running command 'kubectl rollout status deployment/app -n app --timeout=10m': exit status 1. Output: Waiting for deployment \"app\" rollout to finish: 0 of 1 updated replicas are available... error: timed out waiting for the condition"
KUBECTL_STS="local-exec provisioner error: Error running command 'kubectl wait --for=jsonpath={.status.readyReplicas}=1 statefulset/redis -n app --timeout=10m': exit status 1. Output: error: timed out waiting for the condition on statefulsets/redis"

f="$TMP_DIR/deploy_only.txt"
{ preamble; boxed "$KUBECTL_DEPLOY" 'null_resource.wait_for_app' main.tf; } > "$f"
check "a lone kubectl Deployment rollout timeout is tolerated" tolerated "$(verdict "$f")"

f="$TMP_DIR/two_rollouts.txt"
{ boxed "$KUBECTL_DEPLOY" 'null_resource.wait_for_app' main.tf
  boxed "$KUBECTL_STS" 'null_resource.wait_for_redis' main.tf; } > "$f"
check "two rollout timeouts, nothing else, are tolerated" tolerated "$(verdict "$f")"

# The provider taints a workload whose create fails this way, so the next
# apply replaces it: never reported as success (and the old grep never was).
f="$TMP_DIR/provider_deploy.txt"
boxed "Waiting for rollout to finish: 0 of 1 updated replicas are available..." 'kubernetes_deployment_v1.app["base"]' deployment.tf > "$f"
check "the provider's own Deployment rollout error still FAILS (tainted)" failed "$(verdict "$f")"

f="$TMP_DIR/provider_sts.txt"
boxed 'StatefulSet app-dev/app is not finished rolling out' 'kubernetes_stateful_set_v1.app[0]' statefulset.tf > "$f"
check "the provider's own StatefulSet rollout error still FAILS (tainted)" failed "$(verdict "$f")"

f="$TMP_DIR/kubectl.txt"
boxed "local-exec provisioner error: Error running command 'kubectl rollout status deployment/app -n app --timeout=10m': exit status 1. Output: error: timed out waiting for the condition" 'null_resource.wait_for_app' main.tf > "$f"
check "a kubectl rollout-status timeout on a Deployment is tolerated" tolerated "$(verdict "$f")"

# THE BUG: the old grep matched the rollout line and returned success, even
# though Cloud SQL had failed in the same apply.
f="$TMP_DIR/sql_plus_rollout.txt"
{ preamble
  boxed 'Error, failed to create instance app-db: googleapi: Error 409: The Cloud SQL instance already exists., instanceAlreadyExists' 'google_sql_database_instance.db' sql.tf
  boxed "$KUBECTL_DEPLOY" 'null_resource.wait_for_app' main.tf; } > "$f"
check "a Cloud SQL error beside a rollout timeout FAILS" failed "$(verdict "$f")"

f="$TMP_DIR/unrelated_timed_out.txt"
{ boxed 'Error waiting for Creating Service: timed out waiting for the condition' 'google_cloud_run_v2_service.app' service.tf
  boxed "$KUBECTL_DEPLOY" 'null_resource.wait_for_app' main.tf; } > "$f"
check "a Cloud Run 'timed out waiting for the condition' beside a rollout FAILS" failed "$(verdict "$f")"

f="$TMP_DIR/job.txt"
boxed "local-exec provisioner error: Error running command 'kubectl wait job/app-db-init --for=condition=complete --timeout=10m': exit status 1. Output: error: timed out waiting for the condition on jobs/app-db-init" 'null_resource.db_init' jobs.tf > "$f"
check "a Job wait timeout is NOT a rollout, and fails" failed "$(verdict "$f")"

f="$TMP_DIR/no_blocks.txt"
{ preamble; echo "Killed"; } > "$f"
check "a failed apply with no Error block at all fails" failed "$(verdict "$f")"

f="$TMP_DIR/warning_only.txt"
{ printf '╷\n│ Warning: Deprecated attribute\n│ \n│ Waiting for rollout to finish is mentioned in a warning\n╵\n'
  boxed 'Error creating Network: googleapi: Error 403: Permission denied' 'google_compute_network.vpc' network.tf; } > "$f"
check "rollout text inside a WARNING does not count" failed "$(verdict "$f")"

f="$TMP_DIR/unboxed.txt"
printf 'Error: local-exec provisioner error: kubectl rollout status deployment/app: error: timed out waiting for the condition\n\n  with null_resource.wait_for_app,\n' > "$f"
check "an unboxed (no-colour) rollout block is recognised" tolerated "$(verdict "$f")"

f="$TMP_DIR/deploy_only.txt"
check "block count is reported" "rollout policy: 1 of 1 error block(s) are workload rollout timeouts" "$(only_rollout_timeouts "$f" | tail -1)"

# The marker reaches $BUILDER_OUTPUT/output, where Cloud Build publishes it as
# results.buildStepOutputs for notification_status to read.
export BUILDER_OUTPUT="$TMP_DIR/builder"
record_rollout_timeout_tolerated >/dev/null
check "the tolerance is recorded in \$BUILDER_OUTPUT/output" "rolloutTimeoutTolerated" "$(cat "$BUILDER_OUTPUT/output" 2>/dev/null)"
unset BUILDER_OUTPUT
check "recording without \$BUILDER_OUTPUT still succeeds" 0 "$(record_rollout_timeout_tolerated >/dev/null; echo $?)"

# Both apply scripts must use the policy, not a whole-log grep of their own.
for s in apply_infrastructure.sh apply_infrastructure_update.sh; do
  check "$s gates the tolerance on only_rollout_timeouts" 1 "$(grep -c 'if only_rollout_timeouts /tmp/apply_output.txt' "$SCRIPT_DIR/$s")"
  check "$s records the tolerance" 1 "$(grep -c '^ *record_rollout_timeout_tolerated$' "$SCRIPT_DIR/$s")"
done

if [ "$failures" -gt 0 ]; then
  echo "❌ $failures failure(s)"
  exit 1
fi
echo "✅ all passed"
