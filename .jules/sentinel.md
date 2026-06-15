## 2024-06-15 - Hardcoded RDP Password in Migration Center
**Vulnerability:** Hardcoded Windows RDP password in Migration_Center modules/Migration_Center/windows_vm.tf and outputs.tf.
**Learning:** Initialization scripts often require passwords for local users. Hardcoding these in the script metadata makes them plaintext in source control. They should be dynamically generated via random_password and injected into the script, then exposed as sensitive outputs.
**Prevention:** Always use random_password or secret manager for OS user passwords and pass them to the script dynamically. Ensure any generated password injected into scripts is wrapped in single quotes.
