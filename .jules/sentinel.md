## 2024-05-24 - Removed hardcoded RDP password in Migration Center
**Vulnerability:** A hardcoded RDP password (`m1grat10nc#nt#r`) was committed in `modules/Migration_Center/windows_vm.tf` (in a PowerShell script), `outputs.tf` and `README.md`.
**Learning:** Hardcoded passwords in sysprep PowerShell scripts must be removed and replaced with a `random_password`. When injecting `random_password.result` into a PowerShell script inside Terraform metadata, the variable must be surrounded by single quotes (`'${...}'`) instead of double quotes to avoid evaluation errors by PowerShell.
**Prevention:** Use `random_password` with `override_special = "!#$%&*()-_=+[]{}<>:?"` for generated passwords, properly injected with single quotes for shell/PS1 scripts, and outputted with `sensitive = true`.
