#!/usr/bin/env python3
"""
PreToolUse hook: block writes of .tf files that contain hardcoded credentials.

Receives the Claude Code hook payload as JSON on stdin. If a suspicious hardcoded
credential is detected in the content being written, outputs a JSON denial
response — Claude Code shows the reason to the model and cancels the write.

rad-modules is a multi-cloud repo (GCP + Azure AKS + AWS EKS). Its conventions
state cloud credentials "must never be hardcoded as defaults" and that credential
variables must be `sensitive = true`. This hook enforces the first rule (the hard
gate); `sensitive = true` completeness is covered by /audit-module and
/check-conventions.

Two detections:
  1. FIELD ASSIGNMENT — a credential field set to a literal string, e.g.
        aws_secret_key = "AKIA...."         client_secret = "p@ssw0rd...."
  2. VARIABLE DEFAULT — a `variable "<credential>"` block whose `default` is a
     non-empty literal, e.g.
        variable "aws_secret_key" { ... default = "AKIA...." }

Patterns NOT flagged (safe Terraform expressions / empty):
  client_secret = var.client_secret      aws_secret_key = local.creds.secret
  default       = ""                      password = random_password.x.result
"""
import json
import re
import sys

# Field / variable names that suggest a secret value.
SECRET_NAMES = (
    r"password|passwd|api_key|access_token|secret_key|private_key|"
    r"client_secret|service_account_key|"
    r"aws_secret_key|aws_secret_access_key|aws_access_key|aws_access_key_id"
)

# `field = "value"` assignment of a credential field.
FIELD_ASSIGN_RE = re.compile(rf"(?i)\b({SECRET_NAMES})\s*=\s*")

# Start of a credential variable block: variable "aws_secret_key" {
VAR_BLOCK_RE = re.compile(rf'(?i)^variable\s+"([^"]*(?:{SECRET_NAMES})[^"]*)"\s*{{')

# A default assignment inside a variable block.
DEFAULT_RE = re.compile(r'^\s*default\s*=\s*')

# Quoted values that are safe Terraform expressions (not hardcoded literals).
SAFE_EXPR_RE = re.compile(
    r'"(?:'
    r"var\.|local\.|module\.|data\."
    r"|random_password\.|random_string\."
    r"|google_|self\.|each\.|count\.|path\."
    r"|tofile\b|templatefile\b"
    r"|\$\{"     # interpolation block
    r'|"'        # empty string: the closing quote follows immediately
    r")"
)

# Minimum literal length (chars, excluding quotes) before we consider it a secret.
MIN_LEN = 8


def _flag_literal(remainder: str) -> bool:
    """True if `remainder` begins with a hardcoded literal long enough to matter."""
    if not remainder.startswith('"'):
        return False
    end_quote = remainder.find('"', 1)
    if end_quote < MIN_LEN:  # too short, or unterminated
        return False
    value = remainder[: end_quote + 1]
    return not SAFE_EXPR_RE.match(value)


def check_content(content: str) -> list:
    findings = []
    in_secret_var = False
    var_depth = 0

    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("//"):
            # Track brace depth even inside comments would be wrong; comments
            # don't carry braces in practice for these blocks, so skip.
            continue

        # Detection 1: direct field assignment.
        m = FIELD_ASSIGN_RE.search(stripped)
        if m and _flag_literal(stripped[m.end():]):
            findings.append(f"  Line {i}: {stripped[:120]}")

        # Detection 2: credential variable block default.
        vm = VAR_BLOCK_RE.match(stripped)
        if vm:
            in_secret_var = True
            var_depth = stripped.count("{") - stripped.count("}")
            continue
        if in_secret_var:
            var_depth += stripped.count("{") - stripped.count("}")
            dm = DEFAULT_RE.match(stripped)
            if dm and _flag_literal(stripped[dm.end():]):
                findings.append(f"  Line {i}: {stripped[:120]} (hardcoded credential default)")
            if var_depth <= 0:
                in_secret_var = False

    return findings


def deny(path: str, findings: list) -> None:
    reason = (
        f"Potential hardcoded credential detected in {path}:\n"
        + "\n".join(findings)
        + "\n\nrad-modules forbids hardcoded cloud credentials. Use var.<name> "
        "(with sensitive = true and no default), local.<name>, or supply the "
        "value at apply time via ARM_*/AWS_* env vars or a tfvars file."
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    ti = data.get("tool_input", {})
    path = ti.get("file_path", "")
    if not path.endswith(".tf"):
        sys.exit(0)

    # Edit tool uses new_string; Write tool uses content.
    content = ti.get("new_string") or ti.get("content") or ""
    if not content:
        sys.exit(0)

    findings = check_content(content)
    if findings:
        deny(path, findings)

    sys.exit(0)


if __name__ == "__main__":
    main()
