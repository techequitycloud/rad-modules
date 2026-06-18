## 2024-06-12 - Remove always_run from null_resource
**Learning:** Setting `always_run = timestamp()` in a `null_resource` breaks idempotency, forces recreation on every apply, and triggers downstream resource replacements (like deployment jobs) if they depend on its ID.
**Action:** Remove `always_run` to prevent unnecessary execution and break downstream dynamic trigger chains (e.g., removing `download_id`), relying on `depends_on` for sequence where appropriate.
