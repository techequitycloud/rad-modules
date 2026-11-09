#!/usr/bin/env bash
# Tests for apply_retry_policy.sh: a failed apply earns its ONE retry only when
# every `Error:` block is on the transient allowlist. The negative cases matter
# more than the positive ones -- each is a failure that a retry cannot fix and
# that would otherwise bill a second full apply (the Medusa incident).
# Samples are boxed and coloured like real OpenTofu output, because block
# splitting is shared with rollout_timeout_policy.sh and must hold here too.
# Run: ./apply_retry_policy_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# shellcheck source=rollout_timeout_policy.sh
. "$SCRIPT_DIR/rollout_timeout_policy.sh"
# shellcheck source=apply_retry_policy.sh
. "$SCRIPT_DIR/apply_retry_policy.sh"

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

boxed() {
  local summary="$1" address="${2:-google_x.y}"
  printf '%s╷%s\n' "$R" "$N"
  printf '%s│%s %s%sError: %s%s%s\n' "$R" "$N" "$R" "$B" "$N" "$B" "$summary"
  printf '%s│%s %s\n' "$R" "$N" ""
  printf '%s│%s   with %s,\n' "$R" "$N" "$address"
  printf '%s│%s   on main.tf line 12, in resource:\n' "$R" "$N"
  printf '%s╵%s\n' "$R" "$N"
}

verdict() { if apply_failure_is_transient "$1" >/dev/null; then echo retry; else echo fail; fi; }

# case <label> <expected> <preamble lines> <block summary>...
case_() {
  local label="$1" expected="$2" pre="$3"; shift 3
  local f="$TMP_DIR/$(printf '%s' "$label" | tr -c 'a-zA-Z0-9' '_').txt"
  { printf '%s\n' "$pre"; for s in "$@"; do boxed "$s"; done; } > "$f"
  check "$label" "$expected" "$(verdict "$f")"
}

SVC_ENABLED='module.svc.google_project_service.apis["run.googleapis.com"]: Creation complete after 5s [id=p/run.googleapis.com]'
IAM_GRANTED='module.iam.google_project_iam_member.sa_roles["roles/run.admin"]: Creation complete after 9s [id=p/roles/run.admin/serviceAccount:x]'
SA_CREATED='module.iam.google_service_account.app: Creation complete after 2s [id=projects/p/serviceAccounts/app@p.iam.gserviceaccount.com]'

echo "apply_retry_policy — transient (retry):"
case_ "503 from a Google API"            retry "" "Error creating Service: googleapi: Error 503: The service is currently unavailable., backendError"
case_ "500 internalError"                retry "" "Error waiting to create Instance: googleapi: Error 500: Internal error encountered., internalError"
case_ "429 per-minute rate limit"        retry "" "Error creating Topic: googleapi: Error 429: Quota exceeded for quota metric 'Write requests' and limit 'Write requests per minute', rateLimitExceeded"
case_ "409 concurrent IAM policy change" retry "" "Error applying IAM policy for project \"p\": Error setting IAM policy for project \"p\": googleapi: Error 409: There were concurrent policy changes. Please retry the whole read-modify-write with exponential backoff., aborted"
case_ "Saved plan is stale"              retry "" "Saved plan is stale"
case_ "SERVICE_DISABLED after enabling it this apply" retry "$SVC_ENABLED" "Error creating Service: googleapi: Error 403: Cloud Run Admin API has not been used in project 123 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/run.googleapis.com/overview?project=123 then retry. Details: SERVICE_DISABLED"
case_ "actAs denied after granting IAM this apply" retry "$IAM_GRANTED" "Error creating Service: googleapi: Error 403: Permission 'iam.serviceaccounts.actAs' denied on service account app@p.iam.gserviceaccount.com (or it may not exist)."
case_ "new SA reported missing after creating it" retry "$SA_CREATED" "Error setting IAM policy: googleapi: Error 400: Service account app@p.iam.gserviceaccount.com does not exist., badRequest"
case_ "two transient blocks"             retry "" "googleapi: Error 503: unavailable, backendError" "googleapi: Error 502: Bad Gateway"

echo "apply_retry_policy — persistent (fail, single attempt as before):"
case_ "SERVICE_DISABLED, nothing enabled this apply" fail "" "googleapi: Error 403: Cloud Run Admin API has not been used in project 123 before or it is disabled. SERVICE_DISABLED"
case_ "403 denied, no IAM granted this apply" fail "" "Error creating Service: googleapi: Error 403: Permission 'run.services.create' denied on resource"
case_ "setIamPolicy denied even after grants (structural Editor gap)" fail "$IAM_GRANTED" "Error setting IAM policy: googleapi: Error 403: Permission 'secretmanager.secrets.setIamPolicy' denied for resource"
case_ "addPeering denied even after grants" fail "$IAM_GRANTED" "Error creating connection: googleapi: Error 403: Permission 'servicenetworking.services.addPeering' denied on resource"
case_ "409 already exists (self-heal territory)" fail "" "Error creating Bucket: googleapi: Error 409: Your previous request to create the named bucket succeeded and you already own it., conflict"
case_ "409 already exists with 'try again' text" fail "" "googleapi: Error 409: Resource already exists in the project, please try again with another name"
case_ "Medusa: provisioner wrapping a registry 429" fail "" "local-exec provisioner error: Error running command 'build-container.sh': exit status 1. Output: npm ERR! 429 Too Many Requests googleapi: Error 429"
case_ "per-day quota 429"                fail "" "googleapi: Error 429: Quota exceeded for quota metric 'Requests' and limit 'Requests per day', rateLimitExceeded"
case_ "CPU quota exceeded (403)"         fail "" "Error creating Instance: googleapi: Error 403: Quota 'CPUS' exceeded. Limit: 24.0 in region us-central1., quotaExceeded"
case_ "501 not implemented"              fail "" "googleapi: Error 501: Operation is not implemented"
case_ "invalid argument 400"             fail "" "googleapi: Error 400: Invalid value for field 'resource.name', invalid"
case_ "one transient + one real"         fail "" "googleapi: Error 503: unavailable, backendError" "googleapi: Error 400: Invalid value, invalid"
case_ "Error: Cycle"                     fail "" "Cycle: module.a.google_x.y, module.b.google_z.w"

f="$TMP_DIR/no_error_block.txt"; printf 'Killed\n' > "$f"
check "no Error block at all (OOM / killed)" fail "$(verdict "$f")"
check "missing log file" fail "$(verdict "$TMP_DIR/does-not-exist.txt")"

if [ "$failures" -gt 0 ]; then
  echo "apply_retry_policy: $failures failure(s)"
  exit 1
fi
echo "apply_retry_policy: all checks passed"
