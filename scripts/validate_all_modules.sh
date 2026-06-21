#!/usr/bin/env bash
#
# Offline static-analysis sweep across every module in rad-modules.
#
# Mirrors what .github/workflows/terraform-ci.yml does per-changed-module, but
# runs the whole catalog locally with no GCP credentials. Use before opening a PR.
#
#   bash scripts/validate_all_modules.sh            # fmt-check + validate + conventions
#   bash scripts/validate_all_modules.sh --tflint   # also run tflint per module
#
# Prefers `tofu`; falls back to `terraform` (interchangeable for init/validate/fmt).
# Exit code is non-zero if any module fails fmt or validate, or if the convention
# checker reports a hard error.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUN_TFLINT=false
[[ "${1:-}" == "--tflint" ]] && RUN_TFLINT=true

if command -v tofu >/dev/null 2>&1; then
  TF=tofu
elif command -v terraform >/dev/null 2>&1; then
  TF=terraform
else
  echo "ERROR: neither tofu nor terraform is installed" >&2
  exit 2
fi
echo "Using: $TF ($("$TF" version | head -1))"

fail=0

# --- Repo-wide format check (fast, single pass) ------------------------------
echo
echo "==> $TF fmt -check -recursive modules/"
if ! "$TF" fmt -check -recursive modules/; then
  echo "FAIL: formatting issues above (run '$TF fmt -recursive modules/' to fix)"
  fail=1
fi

# --- Per-module init + validate (+ optional tflint) --------------------------
for dir in modules/*/; do
  mod="$(basename "$dir")"
  [[ -f "$dir/main.tf" || -f "$dir/variables.tf" ]] || continue
  echo
  echo "==> $mod"
  (
    cd "$dir" || exit 1
    "$TF" init -backend=false -input=false >/dev/null || { echo "  FAIL: init"; exit 1; }
    "$TF" validate || { echo "  FAIL: validate"; exit 1; }
    if $RUN_TFLINT && command -v tflint >/dev/null 2>&1; then
      tflint --init --config ../../.tflint.hcl >/dev/null 2>&1
      tflint --config ../../.tflint.hcl --format compact || echo "  WARN: tflint findings (non-blocking)"
    fi
  ) || fail=1
done

# --- Convention checker (hard errors fail the sweep) -------------------------
echo
echo "==> scripts/check_conventions.py"
python3 scripts/check_conventions.py || fail=1

echo
if [[ $fail -eq 0 ]]; then
  echo "All modules passed static analysis."
else
  echo "One or more modules failed — see output above."
fi
exit $fail
