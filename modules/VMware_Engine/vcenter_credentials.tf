#
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Resets the vCenter solution user password and retrieves the new credentials
# via gcloud after the private cloud is fully provisioned. The credentials are
# printed to Cloud Build logs and are required when registering the Migrate to
# Virtual Machines connector against the vCenter source.
# Triggers re-run only when the private cloud ID changes (i.e. on recreation).
resource "null_resource" "vcenter_credentials_reset" {
  count = var.reset_vcenter_credentials ? 1 : 0

  triggers = {
    private_cloud_id = google_vmwareengine_private_cloud.private_cloud.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking private cloud state before credentials reset..."
      STATE=$(gcloud vmware private-clouds describe '${local.private_cloud_name}' \
        --project='${local.project.project_id}' \
        --location='${var.zone}' \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --format='value(state)' --quiet 2>/dev/null)
      if [ "$STATE" != "ACTIVE" ]; then
        echo "Private cloud state is '$STATE' (not ACTIVE) — skipping credentials reset."
        echo "Run manually once the cloud is ACTIVE:"
        echo "  gcloud vmware private-clouds vcenter credentials reset \\"
        echo "    --private-cloud=${local.private_cloud_name} --username=${var.vcenter_solution_user} \\"
        echo "    --location=${var.zone} --project=${local.project.project_id} \\"
        echo "    --impersonate-service-account='${var.resource_creator_identity}' --no-async"
        exit 0
      fi

      echo "Resetting vCenter solution user credentials..."
      gcloud vmware private-clouds vcenter credentials reset \
        --private-cloud=${local.private_cloud_name} \
        --username=${var.vcenter_solution_user} \
        --location=${var.zone} \
        --project=${local.project.project_id} \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --no-async \
        || echo "WARNING: Reset returned an error — run manually when cloud is fully active."

      echo "Retrieving new vCenter solution user credentials..."
      gcloud vmware private-clouds vcenter credentials describe \
        --private-cloud=${local.private_cloud_name} \
        --username=${var.vcenter_solution_user} \
        --location=${var.zone} \
        --project=${local.project.project_id} \
        --impersonate-service-account='${var.resource_creator_identity}' \
        --format=json \
        || echo "WARNING: Describe failed — run the reset command above first, then describe."
    EOT
  }

  depends_on = [google_vmwareengine_private_cloud.private_cloud]
}
