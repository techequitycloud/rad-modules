## 2024-05-09 - null_resource timestamp() anti-pattern
**Learning:** Using `always_run = timestamp()` inside `null_resource` triggers for local-exec scripts (like downloading bank-of-anthos) forces the resource to be marked as replaced on every apply. This slows down terraform apply runs unnecessarily.
**Action:** Instead of `timestamp()`, use static triggers like version numbers or `always_run = "true"` and handle idempotency inside the bash script (e.g., checking if the required file or directory already exists and exiting early, or skipping the expensive operations like curl/tar).
