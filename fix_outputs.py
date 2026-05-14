import re

with open("modules/Bank_GKE/outputs.tf", "r") as f:
    content = f.read()

new_content = content.replace(
    'value       = fileexists("${path.module}/scripts/app/external_ip.txt") ? file("${path.module}/scripts/app/external_ip.txt") : "IP not available"',
    'value       = google_compute_global_address.glb.address'
)

with open("modules/Bank_GKE/outputs.tf", "w") as f:
    f.write(new_content)
