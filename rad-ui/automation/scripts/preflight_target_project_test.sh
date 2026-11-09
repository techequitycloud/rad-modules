#!/usr/bin/env bash
# Tests for preflight_target_project.sh. gcloud and curl are replaced by stubs
# on PATH, so nothing here reaches Google. The cases that matter most are the
# FAIL-OPEN ones: every response the preflight cannot read as a definitive
# answer must exit 0, because a false block stops a deployment that would have
# worked. Run: ./preflight_target_project_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="$SCRIPT_DIR/preflight_target_project.sh"
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

# ── stubs ────────────────────────────────────────────────────────────────────
BIN="$TMP_DIR/bin"; mkdir -p "$BIN"
cat > "$BIN/gcloud" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG.gcloud"
case "$*" in
  *print-access-token*) [ "${STUB_TOKEN_FAIL:-0}" = 1 ] && exit 1; echo "stub-token" ;;
  *get-value\ account*) echo "builder@platform.iam.gserviceaccount.com" ;;
esac
EOF
cat > "$BIN/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift ;; -X|-w|-H|--max-time|--data) shift ;; -*) ;; *) url="$1" ;; esac
  shift
done
hdr=$(cat)
case "$hdr" in *"Bearer stub-token"*) ;; *) echo "no bearer header on stdin" >&2; exit 2 ;; esac
echo "$url" >> "$STUB_LOG.curl"
case "$url" in
  *:testIamPermissions) code="$TIP_CODE"; body="$TIP_BODY" ;;
  *billingInfo)         code="$BILL_CODE"; body="$BILL_BODY" ;;
  */v1/projects/*)      code="$CRM_CODE"; body="$CRM_BODY" ;;
esac
[ "$code" = "000" ] && exit 28
printf '%s' "$body" > "$out"
printf '%s' "$code"
EOF
chmod +x "$BIN/gcloud" "$BIN/curl"
export PATH="$BIN:$PATH"

ALL_PERMS='{"permissions":["serviceusage.services.enable","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","iam.serviceAccounts.create"]}'
DENIED='{"error":{"code":403,"status":"PERMISSION_DENIED","message":"The caller does not have permission"}}'
SVC_DISABLED='{"error":{"code":403,"status":"PERMISSION_DENIED","message":"API disabled","details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"SERVICE_DISABLED"}]}}'

healthy() {
  export CRM_CODE=200 CRM_BODY='{"projectId":"p-1","lifecycleState":"ACTIVE"}'
  export BILL_CODE=200 BILL_BODY='{"billingEnabled":true}'
  export TIP_CODE=200 TIP_BODY="$ALL_PERMS"
  export STUB_TOKEN_FAIL=0
  unset RAD_PREFLIGHT
}

# run <tfvars-json> [variables.tf content] -> sets RC and OUT
run() {
  local mod="$TMP_DIR/mod.$RANDOM"; mkdir -p "$mod"
  printf '%s' "$1" > "$mod/terraform.tfvars.json"
  printf '%s\n' "${2:-variable \"project_id\" { type = string }}" > "$mod/variables.tf"
  export STUB_LOG="$mod/stub"
  OUT=$(cd "$mod" && bash "$PREFLIGHT" 2>&1); RC=$?
  CURL_CALLS=$(cat "$STUB_LOG.curl" 2>/dev/null | wc -l | tr -d ' ')
  GCLOUD_ARGS=$(cat "$STUB_LOG.gcloud" 2>/dev/null)
}
line() { printf '%s\n' "$OUT" | grep -E '^RAD_PREFLIGHT_[A-Z]+:' | head -1 | cut -d: -f1-2 | tr -d ' '; }

BASIC='{"project_id":"p-1","resource_creator_identity":"creator@host.iam.gserviceaccount.com"}'

echo "preflight — passes:"
healthy; run "$BASIC"
check "healthy project passes" "0 RAD_PREFLIGHT_OK:p-1" "$RC $(line)"
check "token minted for the IMPERSONATED identity" "yes" "$(printf '%s' "$GCLOUD_ARGS" | grep -q 'impersonate-service-account=creator@host' && echo yes || echo no)"

echo "preflight — definitive failures (exit 1, one marked line):"
healthy; CRM_CODE=403 CRM_BODY="$DENIED"; run "$BASIC"
check "no access / no such project" "1 RAD_PREFLIGHT_FAILED:PROJECT_NOT_ACCESSIBLE" "$RC $(line)"
check "  ... message carries the grant command" "yes" "$(printf '%s' "$OUT" | grep -q 'gcloud projects add-iam-policy-binding p-1 --member=serviceAccount:creator@host.iam.gserviceaccount.com --role=roles/owner' && echo yes || echo no)"
healthy; CRM_BODY='{"projectId":"p-1","lifecycleState":"DELETE_REQUESTED"}'; run "$BASIC"
check "project pending deletion" "1 RAD_PREFLIGHT_FAILED:PROJECT_NOT_ACTIVE" "$RC $(line)"
healthy; BILL_BODY='{"projectId":"p-1"}'; run "$BASIC"
check "billing disabled (field absent)" "1 RAD_PREFLIGHT_FAILED:BILLING_DISABLED" "$RC $(line)"
check "  ... exactly one FAILED line" "1" "$(printf '%s\n' "$OUT" | grep -c '^RAD_PREFLIGHT_FAILED:')"
healthy; TIP_BODY='{"permissions":["resourcemanager.projects.getIamPolicy"]}'; run "$BASIC"
check "cannot enable APIs" "1 RAD_PREFLIGHT_FAILED:IAM_PERMISSION_MISSING" "$RC $(line)"
healthy; TIP_BODY='{}'; run "$BASIC"
check "holds none of the permissions" "1 RAD_PREFLIGHT_FAILED:IAM_PERMISSION_MISSING" "$RC $(line)"

echo "preflight — fails OPEN (exit 0):"
healthy; TIP_BODY='{"permissions":["serviceusage.services.enable"]}'; run "$BASIC"
check "partial permissions only warn" "0 RAD_PREFLIGHT_WARNING" "$RC $(line | cut -d: -f1)"
healthy; STUB_TOKEN_FAIL=1; run "$BASIC"
check "token cannot be minted" "0 0" "$RC $CURL_CALLS"
healthy; CRM_CODE=403 CRM_BODY="$SVC_DISABLED"; run "$BASIC"
check "403 SERVICE_DISABLED on the quota project is not a denial" "0" "$RC"
healthy; CRM_CODE=503 CRM_BODY='{}'; run "$BASIC"
check "CRM 5xx" "0" "$RC"
healthy; CRM_CODE=000; run "$BASIC"
check "network failure" "0" "$RC"
healthy; BILL_CODE=403 BILL_BODY="$DENIED"; run "$BASIC"
check "billing unreadable continues to the IAM check" "0 3" "$RC $CURL_CALLS"
healthy; TIP_CODE=500 TIP_BODY='garbage'; run "$BASIC"
check "testIamPermissions 500" "0" "$RC"
healthy; RAD_PREFLIGHT=off; export RAD_PREFLIGHT; CRM_CODE=403 CRM_BODY="$DENIED"; run "$BASIC"
check "RAD_PREFLIGHT=off skips even a doomed project" "0 0" "$RC $CURL_CALLS"

echo "preflight — skips when this build creates the project:"
healthy; CRM_CODE=403 CRM_BODY="$DENIED"
run '{"project_id":"p-new","create_project":true}'
check "create_project=true" "0 0" "$RC $CURL_CALLS"
run '{"project_id":"p-new"}' 'variable "create_project" {
  type    = bool
  default = true
}'
check "Project_GCP shape: create_project declared, unset in tfvars" "0 0" "$RC $CURL_CALLS"
run '{"project_id":"p-new","create_project":false,"resource_creator_identity":""}' 'variable "create_project" {
  default = true
}'
check "create_project=false (bring-your-own) IS checked" "1 RAD_PREFLIGHT_FAILED:PROJECT_NOT_ACCESSIBLE" "$RC $(line)"
check "  ... on ambient credentials when identity is empty" "no" "$(printf '%s' "$GCLOUD_ARGS" | grep -q impersonate && echo yes || echo no)"

echo "preflight — skips on a shape it does not understand:"
healthy; run '{"region":"us-central1"}'
check "no project_id" "0 0" "$RC $CURL_CALLS"
healthy; run 'not json'
check "unparseable tfvars" "0 0" "$RC $CURL_CALLS"
healthy; run '{"project_id":"p-1"}' 'variable "resource_creator_identity" {
  type = string
}'
check "declared identity with no parseable default" "0 0" "$RC $CURL_CALLS"
healthy; run '{"project_id":"p-1"}' 'variable "resource_creator_identity" {
  type    = string
  default = "rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"
}'
check "identity taken from the module default" "yes" "$(printf '%s' "$GCLOUD_ARGS" | grep -q 'impersonate-service-account=rad-module-creator@tec-rad-ui-2b65' && echo yes || echo no)"

if [ "$failures" -gt 0 ]; then
  echo "preflight_target_project: $failures failure(s)"
  exit 1
fi
echo "preflight_target_project: all checks passed"
