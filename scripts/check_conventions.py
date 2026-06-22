#!/usr/bin/env python3
"""
Convention checker for the rad-modules repository.

Validates every module under modules/ against the binding rules documented in
CLAUDE.md and .agent/skills/module-conventions/SKILL.md:

  1. The ten standard variables are declared in every module
  2. enable_services is declared (group 0 API toggle)
  3. Every variable description carries a {{UIMeta group=N order=M}} tag
  4. No symlinks inside module directories (modules never share .tf files)
  5. Every .tf file begins with the Apache 2.0 license header
  6. Every google_project_service sets disable_dependent_services = false and
     disable_on_destroy = false, and none use lifecycle { prevent_destroy }
  7. outputs.tf exports at least deployment_id and project_id
  8. project_id is used (not existing_project_id)
  9. Credential variables (client_secret, aws_secret_key, ...) set sensitive = true

Findings have two severities:
  FAIL — hard invariants the repo must always satisfy (UIMeta tags, no symlinks,
         sensitive credentials, the google_project_service API invariant,
         project_id naming). These break the build.
  WARN — completeness rules that legitimately vary by module type (attached-cluster
         modules omit enable_services/outputs.tf; migration modules omit
         trusted_users; some versions.tf lack the license header). Reported but
         non-blocking unless --strict is passed.

Usage:
    python3 scripts/check_conventions.py [--modules-dir modules/] [--fail-fast] [--strict]

Exit codes:
    0  No FAIL findings (WARN findings may be present unless --strict)
    1  One or more FAIL findings (or any finding under --strict)
    2  modules directory not found
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# The ten standard variables every module ships (module-conventions SKILL.md).
STANDARD_VARS = [
    "module_description",
    "module_dependency",
    "module_services",
    "credit_cost",
    "require_credit_purchases",
    "enable_purge",
    "public_access",
    "deployment_id",
    "resource_creator_identity",
    "trusted_users",
]

# API-enablement toggle — lives in group 0 but is not one of the "ten".
ENABLE_SERVICES_VAR = "enable_services"

# Credential variables that must be marked sensitive = true.
CRED_VAR_RE = re.compile(
    r"(?i)(client_secret|aws_secret_key|aws_secret_access_key|"
    r"aws_access_key|service_account_key|private_key)"
)

UIMETA_RE = re.compile(r"\{\{UIMeta\b")
LICENSE_RE = re.compile(r"(?i)licensed under the apache license|apache-2\.0|http://www\.apache\.org/licenses")
PROJECT_SERVICE_RE = re.compile(r'resource\s+"google_project_service"')


# ---------------------------------------------------------------------------
# HCL parsing helpers (lightweight — regex + brace matching, no HCL lib)
# ---------------------------------------------------------------------------


def _block_body(text: str, start: int) -> str:
    """Return the brace-balanced body beginning at the first '{' after `start`."""
    open_idx = text.find("{", start)
    if open_idx == -1:
        return ""
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1 : i]
    return text[open_idx + 1 :]


def extract_variables(variables_tf: Path) -> Dict[str, str]:
    """Return {variable_name: full_block_text} parsed from a variables.tf."""
    text = variables_tf.read_text()
    result: Dict[str, str] = {}
    for m in re.finditer(r'^variable\s+"([^"]+)"', text, re.MULTILINE):
        result[m.group(1)] = _block_body(text, m.end())
    return result


def description_of(block_body: str) -> str:
    m = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', block_body, re.DOTALL)
    return m.group(1) if m else ""


# ---------------------------------------------------------------------------
# Per-module checks
# ---------------------------------------------------------------------------


def check_module(mod_dir: Path) -> List[tuple]:
    """Return a list of (severity, message) tuples where severity is FAIL or WARN."""
    name = mod_dir.name
    findings: List[tuple] = []

    def fail(msg: str) -> None:
        findings.append(("FAIL", f"[{name}] {msg}"))

    def warn(msg: str) -> None:
        findings.append(("WARN", f"[{name}] {msg}"))

    tf_files = sorted(mod_dir.glob("*.tf"))

    # Check 4 (FAIL): no symlinks anywhere in the module tree. Modules never share
    # .tf files — a symlink would silently couple two modules.
    for p in mod_dir.rglob("*"):
        if p.is_symlink():
            fail(f"Symlink found: {p.relative_to(mod_dir)}")

    # Check 5 (WARN): Apache license header on every top-level .tf file. Some
    # provider-only files (versions.tf) omit it in the current repo, so warn.
    for tf in tf_files:
        head = tf.read_text()[:600]
        if not LICENSE_RE.search(head):
            warn(f"{tf.name}: missing Apache 2.0 license header")

    # Variables-based checks.
    variables_tf = mod_dir / "variables.tf"
    if not variables_tf.exists():
        fail("Missing variables.tf")
    else:
        declared = extract_variables(variables_tf)

        # Check 1 + 2 (WARN): standard variables + enable_services. Attached-cluster
        # (AKS/EKS) and migration modules legitimately omit some of these.
        for req in STANDARD_VARS + [ENABLE_SERVICES_VAR]:
            if req not in declared:
                warn(f"Missing standard variable: {req}")

        # Check 3 (FAIL): every description has a UIMeta tag — load-bearing for the UI.
        for var_name, body in declared.items():
            if not UIMETA_RE.search(description_of(body)):
                fail(f"Variable '{var_name}' description missing {{{{UIMeta group=N order=M}}}} tag")

        # Check 9 (FAIL): credential variables marked sensitive = true.
        for var_name, body in declared.items():
            if CRED_VAR_RE.search(var_name) and not re.search(r"sensitive\s*=\s*true", body):
                fail(f"Credential variable '{var_name}' must set sensitive = true")

        # Check 8 (FAIL): project_id, not existing_project_id.
        if "existing_project_id" in declared and "project_id" not in declared:
            fail("Uses existing_project_id; convention is project_id")

    # Check 6 (FAIL): google_project_service API-enablement invariant. Disabling
    # APIs on destroy would break other modules sharing the project.
    for tf in tf_files:
        text = tf.read_text()
        for m in PROJECT_SERVICE_RE.finditer(text):
            body = _block_body(text, m.end())
            if not re.search(r"disable_dependent_services\s*=\s*false", body):
                fail(f"{tf.name}: google_project_service missing 'disable_dependent_services = false'")
            if not re.search(r"disable_on_destroy\s*=\s*false", body):
                fail(f"{tf.name}: google_project_service missing 'disable_on_destroy = false'")
            if re.search(r"prevent_destroy\s*=\s*true", body):
                fail(f"{tf.name}: google_project_service must not use lifecycle prevent_destroy = true")

    # Check 7 (WARN): outputs.tf exports deployment_id and project_id. Attached
    # modules (AKS/EKS) keep outputs in main.tf, so warn rather than fail.
    outputs_tf = mod_dir / "outputs.tf"
    if not outputs_tf.exists():
        warn("Missing outputs.tf (deployment_id + project_id outputs expected)")
    else:
        out_text = outputs_tf.read_text()
        for required_output in ("deployment_id", "project_id"):
            if not re.search(rf'output\s+"{required_output}"', out_text):
                warn(f"outputs.tf missing recommended output: {required_output}")

    return findings


def is_module_dir(p: Path) -> bool:
    """A module dir is PascalCase_WithUnderscores and contains a variables.tf or main.tf."""
    if not p.is_dir():
        return False
    if not re.match(r"^[A-Z][A-Za-z0-9]*(_[A-Z0-9][A-Za-z0-9]*)*$", p.name):
        return False
    return (p / "main.tf").exists() or (p / "variables.tf").exists()


def run_checks(modules_dir: Path, fail_fast: bool, strict: bool) -> int:
    all_findings: List[tuple] = []
    modules = sorted([d for d in modules_dir.iterdir() if is_module_dir(d)], key=lambda p: p.name)

    for mod_dir in modules:
        findings = check_module(mod_dir)
        if findings and fail_fast:
            for sev, msg in findings:
                print(f"{sev}  {msg}")
            sys.exit(1)
        all_findings.extend(findings)

    print(f"\nChecked {len(modules)} module(s): {', '.join(m.name for m in modules)}")

    fails = [m for s, m in all_findings if s == "FAIL"]
    warns = [m for s, m in all_findings if s == "WARN"]

    if all_findings:
        print(f"\n{'=' * 60}\n{len(fails)} ERROR(S), {len(warns)} WARNING(S):\n{'=' * 60}")
        for msg in fails:
            print(f"  FAIL  {msg}")
        for msg in warns:
            print(f"  WARN  {msg}")
        print()
    else:
        print("All convention checks passed.")

    # FAIL findings always break the build; WARN findings break only under --strict.
    return 1 if fails or (strict and warns) else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check rad-modules conventions")
    parser.add_argument("--modules-dir", default="modules", help="Path to modules/ (default: modules)")
    parser.add_argument("--fail-fast", action="store_true", help="Stop at first module with findings")
    parser.add_argument("--strict", action="store_true", help="Treat WARN findings as failures too")
    args = parser.parse_args()

    modules_dir = Path(args.modules_dir)
    if not modules_dir.is_absolute():
        modules_dir = Path(__file__).parent.parent / modules_dir

    if not modules_dir.exists():
        print(f"ERROR: modules directory not found: {modules_dir}", file=sys.stderr)
        sys.exit(2)

    sys.exit(run_checks(modules_dir, args.fail_fast, args.strict))
