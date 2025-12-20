# Copyright 2024 (c) Tech Equity Ltd
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

#########################################################################
# Database Import Operations
#########################################################################

# Resource to execute import db job
resource "null_resource" "import_db" {
  count    = local.sql_server_exists ? 1 : 0  
    
  triggers = {
    job_id = google_cloud_run_v2_job.import_db_job[0].id
    script_hash = filesha256("${path.module}/scripts/app/import_db_job.sh")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
      echo "Executing DB import/setup job..."
      gcloud run jobs execute ${google_cloud_run_v2_job.import_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB import/setup completed successfully"
      else
        echo "✗ DB import/setup failed"
        exit 1
      fi
    EOF
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret.db_password,
    null_resource.import_nfs,
    null_resource.create_nfs_directories_on_server,
    google_cloud_run_v2_job.import_db_job
  ]
}
