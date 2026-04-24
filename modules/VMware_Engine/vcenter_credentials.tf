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
      echo "Resetting vCenter solution user credentials..."
      gcloud vmware private-clouds vcenter credentials reset \
        --private-cloud=${var.private_cloud_name} \
        --username=${var.vcenter_solution_user} \
        --location=${var.zone} \
        --project=${local.project.project_id} \
        --no-async

      echo "Retrieving new vCenter solution user credentials..."
      gcloud vmware private-clouds vcenter credentials describe \
        --private-cloud=${var.private_cloud_name} \
        --username=${var.vcenter_solution_user} \
        --location=${var.zone} \
        --project=${local.project.project_id} \
        --format=json
    EOT
  }

  depends_on = [google_vmwareengine_private_cloud.private_cloud]
}
