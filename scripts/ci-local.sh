#!/usr/bin/env bash
# ci-local.sh - run every check from .github/workflows/ locally.
#
# The GitHub Actions workflows are manual-only (owner decision 2026-10-13,
# Actions spending limit). This script is the local-first replacement: it runs
# the same commands the workflows ran, on this machine, for free.
#
#   bash scripts/ci-local.sh                 run every deterministic section
#   bash scripts/ci-local.sh --list          list sections and what they mirror
#   bash scripts/ci-local.sh --only <name>   run one section (repeatable)
#   bash scripts/ci-local.sh --ai            also run the Claude review + audit
#                                            through the LOCAL Claude Code CLI
#
# Safety: never deploys, applies or plans against a cloud; never calls GCP
# (gcloud is pointed at an empty config dir and ADC is unset); never reads or
# prints secrets. A missing tool is reported as SKIP, not FAIL. Every selected
# section runs; the exit code is non-zero if any section FAILED.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ci-local.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Belt and braces: nothing below should reach GCP, and nothing can if gcloud
# has no credentials and ADC is unset.
export CLOUDSDK_CONFIG="$WORK/gcloud-empty"
unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_OAUTH_ACCESS_TOKEN GOOGLE_CREDENTIALS

# Section name | workflow + step it mirrors
SECTIONS=(
  "conventions|convention-check.yml: scripts/check_conventions.py"
  "cloudbuild-args|cloudbuild-lint.yml: Cloud Build step-arg limits + volume usage"
  "pipeline-scripts|cloudbuild-lint.yml: bash -n + *_test.sh for rad-ui/automation/scripts"
  "tf-fmt|terraform-ci.yml format: fmt -check -recursive modules/"
  "tf-validate|terraform-ci.yml validate: init -backend=false + validate, every module"
  "tflint|terraform-ci.yml tflint: .tflint.hcl, fail on error severity"
  "tf-test|terraform-ci.yml test: terraform test (mock providers), CI exclusions kept"
  "trivy|terraform-ci.yml security: Trivy config scan HIGH/CRITICAL (non-blocking)"
  "docs-published|docs-published.yml: scripts/check_docs_published.py"
  "ai-review|claude-pr-review.yml: Claude review of git diff origin/main...HEAD (--ai)"
  "ai-audit|claude-weekly-audit.yml: Claude convention + doc audit (--ai)"
)

# Modules terraform-ci.yml excludes from `terraform test` (mock_provider
# cannot override computed nested blocks there - see that workflow).
TEST_EXCLUDE=" AKS_GKE Bank_GKE EKS_GKE MC_Bank_GKE "

ONLY=()
AI=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list)
      printf '%-18s %s\n' SECTION MIRRORS
      for s in "${SECTIONS[@]}"; do printf '%-18s %s\n' "${s%%|*}" "${s#*|}"; done
      exit 0 ;;
    --only)
      [ $# -ge 2 ] || { echo "--only needs a section name" >&2; exit 2; }
      ONLY+=("$2"); shift ;;
    --ai) AI=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1 (try --list)" >&2; exit 2 ;;
  esac
  shift
done

for o in ${ONLY[@]+"${ONLY[@]}"}; do
  found=0
  for s in "${SECTIONS[@]}"; do [ "${s%%|*}" = "$o" ] && found=1; done
  [ "$found" = 1 ] || { echo "unknown section: $o (try --list)" >&2; exit 2; }
done

RESULTS=()
record() { RESULTS+=("$1|$2|$3"); }   # section|PASS/FAIL/SKIP/WARN|note
have() { command -v "$1" >/dev/null 2>&1; }
banner() { printf '\n=== %s ===\n' "$1"; }

# terraform-ci.yml uses Terraform ~1.9; OpenTofu is interchangeable for
# fmt/init/validate/test (see CLAUDE.md "CI Pipeline").
TF=""
if have terraform; then TF=terraform; elif have tofu; then TF=tofu; fi

modules() { for d in modules/*/; do d="${d%/}"; echo "${d#modules/}"; done; }

# --- sections ------------------------------------------------------------

sec_conventions() {
  have python3 || { record conventions SKIP "python3 not found"; return; }
  python3 scripts/check_conventions.py --modules-dir modules/ \
    && record conventions PASS "" || record conventions FAIL "FAIL findings (see output)"
}

sec_cloudbuild_args() {
  have python3 || { record cloudbuild-args SKIP "python3 not found"; return; }
  python3 -c 'import yaml' 2>/dev/null \
    || { record cloudbuild-args SKIP "PyYAML missing (pip install pyyaml)"; return; }
  python3 rad-ui/automation/check_step_arg_limits.py \
    && record cloudbuild-args PASS "" || record cloudbuild-args FAIL "step arg / volume limit crossed"
}

sec_pipeline_scripts() {
  local bad=0 f t
  for f in rad-ui/automation/scripts/*.sh; do
    bash -n "$f" || { echo "syntax error: $f"; bad=1; }
  done
  for t in rad-ui/automation/scripts/*_test.sh; do
    echo "--- $t"
    bash "$t" || { echo "test failed: $t"; bad=1; }
  done
  [ "$bad" = 0 ] && record pipeline-scripts PASS "" || record pipeline-scripts FAIL "syntax error or test failure"
}

sec_tf_fmt() {
  [ -n "$TF" ] || { record tf-fmt SKIP "terraform/tofu not found"; return; }
  "$TF" fmt -check -recursive modules/ \
    && record tf-fmt PASS "($TF)" || record tf-fmt FAIL "files need $TF fmt (listed above)"
}

# Each module gets its own TF_DATA_DIR under $WORK so the working tree is not
# touched; providers are shared through a plugin cache.
tf_init() {
  local m="$1"
  export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.cache/ci-local-tf-plugins}"
  mkdir -p "$TF_PLUGIN_CACHE_DIR"
  (cd "modules/$m" && TF_DATA_DIR="$WORK/tfdata/$m" "$TF" init -backend=false -input=false -no-color >"$WORK/init-$m.log" 2>&1) \
    || { echo "init failed for $m:"; tail -20 "$WORK/init-$m.log"; return 1; }
}

sec_tf_validate() {
  [ -n "$TF" ] || { record tf-validate SKIP "terraform/tofu not found"; return; }
  local m failed=()
  for m in $(modules); do
    echo "--- $m"
    if tf_init "$m" && (cd "modules/$m" && TF_DATA_DIR="$WORK/tfdata/$m" "$TF" validate -no-color); then :; else failed+=("$m"); fi
  done
  [ ${#failed[@]} -eq 0 ] && record tf-validate PASS "all modules ($TF)" \
    || record tf-validate FAIL "${failed[*]}"
}

sec_tflint() {
  have tflint || { record tflint SKIP "tflint not found (brew install tflint)"; return; }
  local m failed=()
  for m in $(modules); do
    echo "--- $m"
    (cd "modules/$m" && tflint --init --config ../../.tflint.hcl >/dev/null \
      && tflint --config ../../.tflint.hcl --format compact --minimum-failure-severity=error) \
      || failed+=("$m")
  done
  [ ${#failed[@]} -eq 0 ] && record tflint PASS "" || record tflint FAIL "${failed[*]}"
}

sec_tf_test() {
  [ -n "$TF" ] || { record tf-test SKIP "terraform/tofu not found"; return; }
  local m failed=() ran=()
  for m in $(modules); do
    case "$TEST_EXCLUDE" in *" $m "*) echo "--- $m (excluded, as in terraform-ci.yml)"; continue ;; esac
    compgen -G "modules/$m/tests/*.tftest.hcl" >/dev/null || compgen -G "modules/$m/*.tftest.hcl" >/dev/null \
      || { echo "--- $m (no tests)"; continue; }
    echo "--- $m"
    ran+=("$m")
    if [ -d "$WORK/tfdata/$m" ] || tf_init "$m"; then
      (cd "modules/$m" && TF_DATA_DIR="$WORK/tfdata/$m" "$TF" test -no-color) || failed+=("$m")
    else
      failed+=("$m")
    fi
  done
  [ ${#failed[@]} -eq 0 ] && record tf-test PASS "${ran[*]:-none}" || record tf-test FAIL "${failed[*]}"
}

sec_trivy() {
  have trivy || { record trivy SKIP "trivy not found (brew install trivy)"; return; }
  local m
  for m in $(modules); do
    echo "--- $m"
    trivy config --severity HIGH,CRITICAL --exit-code 0 --quiet "modules/$m"
  done
  record trivy PASS "non-blocking, as in CI (exit-code 0)"
}

sec_docs_published() {
  have python3 || { record docs-published SKIP "python3 not found"; return; }
  local args=() note=""
  # Optional rad.github.io checkout for the body-drift comparison.
  local site="${RAD_SITE_DIR:-$ROOT/../rad.github.io}"
  [ -d "$site/docs" ] && args+=(--site-dir "$site") && note="with site dir"
  if have curl && curl -fsS -o /dev/null --max-time 10 https://docs.radmodules.dev/; then
    note="live site checked ${note}"
  else
    args+=(--offline); note="OFFLINE: docs.radmodules.dev unreachable, live checks skipped ${note}"
  fi
  python3 scripts/check_docs_published.py ${args[@]+"${args[@]}"} \
    && record docs-published PASS "$note" || record docs-published FAIL "$note"
}

# --- AI sections: local Claude Code CLI, the owner's login, never an API key --

run_claude() {   # $1 = section, $2 = prompt file
  have claude || { record "$1" SKIP "claude CLI not found"; return; }
  (
    unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
    claude -p "$(cat "$2")" --allowedTools "Read,Grep,Glob"
  ) && record "$1" PASS "review printed above" || record "$1" FAIL "claude exited non-zero"
}

# The prompts read the convention checker output from /tmp/conventions.txt;
# point them at this run's copy instead.
prompt_with_conventions() {   # $1 = prompt file, $2 = output
  python3 scripts/check_conventions.py --modules-dir modules/ >"$WORK/conventions.txt" 2>&1 || true
  sed "s#/tmp/conventions.txt#$WORK/conventions.txt#g" "$1" >"$2"
}

sec_ai_review() {
  git fetch -q origin main 2>/dev/null || echo "(git fetch failed - using the local origin/main)"
  local p="$WORK/review-prompt.txt"
  prompt_with_conventions .github/claude-prompts/pr-review.md "$p"
  {
    echo
    echo "Changed files in this PR:"
    git diff --name-only origin/main...HEAD
    echo
    echo "Diff (git diff origin/main...HEAD; Bash is not available - review from this):"
    git diff origin/main...HEAD | head -c 200000
  } >>"$p"
  run_claude ai-review "$p"
}

sec_ai_audit() {
  local p="$WORK/audit-prompt.txt"
  prompt_with_conventions .github/claude-prompts/weekly-audit.md "$p"
  run_claude ai-audit "$p"
}

# --- run -------------------------------------------------------------------

selected() {
  local name="$1"
  if [ ${#ONLY[@]} -gt 0 ]; then
    local o; for o in "${ONLY[@]}"; do [ "$o" = "$name" ] && return 0; done; return 1
  fi
  case "$name" in ai-*) [ "$AI" = 1 ] ;; *) return 0 ;; esac
}

for s in "${SECTIONS[@]}"; do
  name="${s%%|*}"
  if ! selected "$name"; then
    [ ${#ONLY[@]} -eq 0 ] && case "$name" in ai-*) record "$name" SKIP "needs --ai" ;; esac
    continue
  fi
  banner "$name"
  "sec_${name//-/_}"
done

printf '\n%-18s %-6s %s\n' SECTION RESULT NOTE
printf '%-18s %-6s %s\n' ------- ------ ----
rc=0
for r in "${RESULTS[@]}"; do
  IFS='|' read -r n st note <<<"$r"
  printf '%-18s %-6s %s\n' "$n" "$st" "$note"
  [ "$st" = FAIL ] && rc=1
done
exit "$rc"
