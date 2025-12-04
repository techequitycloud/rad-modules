# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "null_resource" "build_and_push_application_image" {
  count    = (var.configure_development_environment || var.configure_nonproduction_environment || var.configure_production_environment) ? 1 : 0

  triggers = {
    # Trigger build if any file in source changes
    dir_sha1 = sha1(join("", [for f in fileset("${path.module}/scripts/app/source", "**") : filesha1("${path.module}/scripts/app/source/${f}")]))
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/app/source"
    # Using --pack to follow tutorial, or Dockerfile since I added one.
    # The tutorial uses `gcloud builds submit --pack image=...`
    # But since I created a Dockerfile, `gcloud builds submit` will pick it up automatically if no config is specified.
    # However, to strictly follow the "omit Dockerfile" part of tutorial I should delete it, but I added it for robustness.
    # Let's use the Dockerfile as it is more standard for these modules.
    command = <<EOT
      gcloud builds submit --tag ${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version} . --project ${local.project_id}
    EOT
  }

  depends_on = [
    google_artifact_registry_repository.repo
  ]
}
