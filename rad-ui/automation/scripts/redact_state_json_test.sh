#!/usr/bin/env bash
# Tests for redact_state_json.sh: the document uploaded to build-logs/ must
# name every resource and carry NO value. The fixture is shaped like real
# `tofu show -json` output, with the cases that matter most: a sensitive
# attribute in the root module, one in a NESTED child module (the pipeline's
# own root-only listings never reach those), a sensitive output, and a
# NON-sensitive output -- which is dropped too, because "not marked sensitive"
# is the module author's opinion, not a guarantee.
# Run: ./redact_state_json_test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

cat > "$TMP_DIR/state.json" <<'EOF'
{
  "format_version": "1.0",
  "terraform_version": "1.8.2",
  "values": {
    "outputs": {
      "db_password": { "sensitive": true, "type": "string", "value": "SECRET-OUTPUT-1" },
      "service_url": { "sensitive": false, "type": "string", "value": "https://PLAIN-OUTPUT-2.example" }
    },
    "root_module": {
      "resources": [
        {
          "address": "google_secret_manager_secret_version.token",
          "mode": "managed",
          "type": "google_secret_manager_secret_version",
          "name": "token",
          "provider_name": "registry.opentofu.org/hashicorp/google",
          "schema_version": 0,
          "values": { "secret_data": "SECRET-ROOT-3", "enabled": true },
          "sensitive_values": { "secret_data": true }
        },
        {
          "address": "data.google_project.current",
          "mode": "data",
          "type": "google_project",
          "name": "current",
          "provider_name": "registry.opentofu.org/hashicorp/google",
          "values": { "number": "PLAIN-DATA-4" },
          "sensitive_values": {}
        }
      ],
      "child_modules": [
        {
          "address": "module.app",
          "resources": [
            {
              "address": "module.app.google_cloud_run_v2_service.main",
              "mode": "managed",
              "type": "google_cloud_run_v2_service",
              "name": "main",
              "provider_name": "registry.opentofu.org/hashicorp/google",
              "values": { "template": [{ "containers": [{ "env": [{ "name": "API_KEY", "value": "SECRET-ENV-5" }] }] }] },
              "sensitive_values": { "template": [{}] }
            }
          ],
          "child_modules": [
            {
              "address": "module.app.module.db",
              "resources": [
                {
                  "address": "module.app.module.db.random_password.root[0]",
                  "mode": "managed",
                  "type": "random_password",
                  "name": "root",
                  "index": 0,
                  "provider_name": "registry.opentofu.org/hashicorp/random",
                  "values": { "result": "SECRET-NESTED-6", "length": 32 },
                  "sensitive_values": { "result": true }
                }
              ]
            }
          ]
        }
      ]
    }
  }
}
EOF

OUT="$TMP_DIR/inventory.json"

echo "Redacting a state with root, child and nested-child resources"
bash "$SCRIPT_DIR/redact_state_json.sh" "$TMP_DIR/state.json" "$OUT"
check "exits 0" "0" "$?"
check "output is valid JSON" "0" "$(jq -e . "$OUT" >/dev/null 2>&1; echo $?)"

echo "No value survives"
for marker in SECRET-OUTPUT-1 PLAIN-OUTPUT-2 SECRET-ROOT-3 PLAIN-DATA-4 SECRET-ENV-5 SECRET-NESTED-6; do
  check "no '$marker'" "0" "$(grep -c -- "$marker" "$OUT")"
done
check "no key named values / sensitive_values / value anywhere" "0" \
  "$(jq '[paths | .[-1] | select(. == "values" or . == "sensitive_values" or . == "value")] | length' "$OUT")"
check "resource keys are exactly the allowlist" "address,mode,module,name,provider_name,type" \
  "$(jq -r '[.resources[] | keys[]] | unique | join(",")' "$OUT")"
check "output keys are exactly name + sensitive" "name,sensitive" \
  "$(jq -r '[.outputs[] | keys[]] | unique | join(",")' "$OUT")"

echo "Every resource is still named"
check "four resources, nested ones included" "4" "$(jq '.resources | length' "$OUT")"
check "resource_count agrees" "4" "$(jq '.resource_count' "$OUT")"
check "nested child module resource is listed" "module.app.module.db" \
  "$(jq -r '.resources[] | select(.address == "module.app.module.db.random_password.root[0]") | .module' "$OUT")"
check "its type is kept" "random_password" \
  "$(jq -r '.resources[] | select(.name == "root") | .type' "$OUT")"
check "root resource has an empty module path" "" \
  "$(jq -r '.resources[] | select(.address == "google_secret_manager_secret_version.token") | .module' "$OUT")"
check "data sources keep their mode" "data" \
  "$(jq -r '.resources[] | select(.name == "current") | .mode' "$OUT")"
check "provider is kept" "registry.opentofu.org/hashicorp/random" \
  "$(jq -r '.resources[] | select(.name == "root") | .provider_name' "$OUT")"
check "output names are kept" "db_password,service_url" "$(jq -r '[.outputs[].name] | join(",")' "$OUT")"
check "sensitive flag is kept" "true" "$(jq -r '.outputs[] | select(.name == "db_password") | .sensitive' "$OUT")"
check "marked redacted" "true" "$(jq -r '.redacted' "$OUT")"
check "versions are kept" "1.8.2" "$(jq -r '.terraform_version' "$OUT")"

echo "An empty state is an empty inventory, not an error"
echo '{"format_version":"1.0"}' > "$TMP_DIR/empty.json"
bash "$SCRIPT_DIR/redact_state_json.sh" "$TMP_DIR/empty.json" "$TMP_DIR/empty.out"
check "exits 0" "0" "$?"
check "zero resources" "0" "$(jq '.resource_count' "$TMP_DIR/empty.out")"

echo "Fails closed"
printf '{"values": {"root_module": {"resources": [{"values": {"p": "SECRET-TRUNCATED-7"' > "$TMP_DIR/bad.json"
echo "stale" > "$TMP_DIR/bad.out"
bash "$SCRIPT_DIR/redact_state_json.sh" "$TMP_DIR/bad.json" "$TMP_DIR/bad.out" 2>/dev/null
check "unparseable input exits non-zero" "1" "$?"
check "and leaves NO output file, not even a stale one" "absent" "$([ -e "$TMP_DIR/bad.out" ] && echo present || echo absent)"
bash "$SCRIPT_DIR/redact_state_json.sh" "$TMP_DIR/does-not-exist.json" "$TMP_DIR/missing.out" 2>/dev/null
check "missing input exits non-zero" "1" "$?"
check "and leaves no output file" "absent" "$([ -e "$TMP_DIR/missing.out" ] && echo present || echo absent)"
bash "$SCRIPT_DIR/redact_state_json.sh" 2>/dev/null
check "missing arguments exit 2" "2" "$?"
check "no temp file is left behind" "0" "$(find "$TMP_DIR" -name '*.tmp.*' | wc -l | tr -d ' ')"

echo
if [ "$failures" -eq 0 ]; then
  echo "All redact_state_json tests passed."
else
  echo "$failures test(s) failed."
  exit 1
fi
