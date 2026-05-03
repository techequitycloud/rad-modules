## 2024-05-03 - Avoid timestamp() trigger for downloads in local-exec
**Learning:** Using `always_run = timestamp()` in null_resources used to download artifacts slows down deployments and forces recreation of resources depending on it on every apply, creating drift and making terraform slow.
**Action:** Remove `always_run = timestamp()` and instead rely on checking if the directory/file already exists within the bash script (e.g., `if [ -f "..." ]; then exit 0; fi`) or using the actual artifact version as trigger. Idempotency must be managed inside the bash script.
