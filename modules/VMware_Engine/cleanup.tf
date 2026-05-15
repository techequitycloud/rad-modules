/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# On destroy, the VMware Engine private cloud enters a 7-day grace period before
# GCP physically removes it. During this window the VEN deletion is blocked
# ("resource is being used by other resources"). This null_resource runs its
# destroy provisioner BEFORE Terraform deletes the private cloud resource,
# requesting immediate deletion (--delay-hours=0) and polling until the cloud
# is fully gone. Terraform's subsequent native delete sees a 404 and treats it
# as already removed, allowing the VEN to be deleted cleanly.
#
# Values are captured in triggers at apply time so they are available from
# state during destroy even after the source resources are gone.
resource "null_resource" "private_cloud_cleanup" {
  triggers = {
    private_cloud_name = local.private_cloud_name
    project_id         = local.project.project_id
    zone               = var.zone
    service_account    = var.resource_creator_identity
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Requesting immediate private cloud deletion (--delay-hours=0)..."
      gcloud vmware private-clouds delete "${self.triggers.private_cloud_name}" \
        --project="${self.triggers.project_id}" \
        --location="${self.triggers.zone}" \
        --impersonate-service-account="${self.triggers.service_account}" \
        --delay-hours=0 \
        --quiet 2>/dev/null || true

      echo "Polling until private cloud is fully deleted (max 30 min)..."
      for i in $(seq 1 60); do
        STATE=$(gcloud vmware private-clouds describe "${self.triggers.private_cloud_name}" \
          --project="${self.triggers.project_id}" \
          --location="${self.triggers.zone}" \
          --impersonate-service-account="${self.triggers.service_account}" \
          --format="value(state)" \
          --quiet 2>/dev/null || echo "GONE")
        echo "[$i/60] private cloud state: $STATE"
        if [ "$STATE" = "GONE" ] || [ -z "$STATE" ]; then
          echo "Private cloud fully deleted — proceeding."
          exit 0
        fi
        sleep 30
      done
      echo "WARNING: Timed out waiting for private cloud deletion; continuing destroy anyway."
    EOT
  }

  depends_on = [google_vmwareengine_private_cloud.private_cloud]
}
