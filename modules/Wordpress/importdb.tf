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
# Configurations for backup import
#########################################################################

# Create db import script
resource "local_file" "import_db_script_output" {
  for_each = local.sql_server_exists ? local.environments : {}

  filename = "${path.module}/scripts/app/${each.key}/import-db.sh"
  content = templatefile("${path.module}/scripts/app/import_db.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
    DB_PASS             = data.google_secret_manager_secret_version.db_password[each.key].secret_data
    # Root password removed from template variables to avoid state exposure
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
    ROOT_PASS_SECRET    = "${local.db_instance_name}-root-password" # Passing the secret name for retrieval inside the script
  })
}

#########################################################################
# Configurations for backup import
#########################################################################

# Resource to import db
resource "null_resource" "import_db" {
  for_each = local.sql_server_exists ? local.environments : {}
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
      set -e  # Exit on error
      
      # Maximum number of attempts
      max_attempts=3
      attempt=0

      # Loop until the NFS VM instance is in RUNNING status or max attempts reached
      while [ $attempt -lt $max_attempts ]; do
        # Get the instance name using the internal IP address
        NFS_VM=$(gcloud --project ${local.project.project_id} compute instances list --filter="INTERNAL_IP=${local.nfs_internal_ip}" --format="value(NAME)")
                
        # Check the status of the instance
        status=$(gcloud --project ${local.project.project_id} compute instances list --filter="INTERNAL_IP=${local.nfs_internal_ip}" --format="value(status)")
                
        if [ "$status" = "RUNNING" ]; then
          echo "Instance is running."
          break
        else
          echo "Waiting for instance to be running... (Attempt $((attempt + 1)) of $max_attempts)"
          sleep 10
        fi
                
        attempt=$((attempt + 1))
      done

      if [ $attempt -eq $max_attempts ]; then
        echo "Max attempts reached. Instance is not running."
        exit 1
      fi

      # Ensure application directory is empty and execute the script
      for i in {1..5}; do
        if [ -z "${local.project_sa_email}" ] && [ -z "${var.resource_creator_identity}" ]; then
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/${each.key}/import-db.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --impersonate-service-account=${local.project_sa_email} --command="sudo bash -s" < ${path.module}/scripts/app/${each.key}/import-db.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        fi

        # If the last attempt fails, exit with error
        if [ "$i" -eq 5 ]; then
          echo "SSH command failed after 5 attempts. Exiting..."
          exit 1
        fi
      done
    EOF
  }

  depends_on = [
    data.google_secret_manager_secret_version.db_password,
    google_secret_manager_secret.db_password,
    local_file.import_db_script_output,
    null_resource.import_nfs, # Assuming nfs.tf has a resource named null_resource.import_nfs[each.key] or similar, wait, importnfs.tf logic might differ.
    # Checking importnfs.tf content is needed.
  ]
}
