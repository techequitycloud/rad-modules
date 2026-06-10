## 2024-06-10 - Missing set -e in helper scripts
 **Learning:** Helper scripts in `scripts/` directory lack the standard `set -e` fail-fast bash mechanism, which can cause them to silently proceed after intermediate command failures. This breaks the expected operator experience and debuggability.
 **Action:** Add `set -e` and `set -o pipefail` to all standalone shell scripts immediately following the shebang/license block to ensure robust failure handling.
