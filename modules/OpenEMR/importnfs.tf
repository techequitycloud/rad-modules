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
# Create NFS directories on server before any operations
#########################################################################

resource "null_resource" "create_nfs_directories_on_server" {
  count = local.nfs_server_exists ? 1 : 0

  triggers = {
    nfs_ip = local.nfs_internal_ip
    path = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
      set -e
      
      echo "=== Creating NFS directories on server ==="
      
      max_attempts=3
      attempt=0

      # Wait for NFS instance to be running
      while [ $attempt -lt $max_attempts ]; do
        NFS_VM=$(gcloud --project ${local.project.project_id} compute instances list --filter="INTERNAL_IP=${local.nfs_internal_ip}" --format="value(NAME)")
        status=$(gcloud --project ${local.project.project_id} compute instances list --filter="INTERNAL_IP=${local.nfs_internal_ip}" --format="value(status)")
        
        if [ "$status" = "RUNNING" ]; then
          echo "✓ NFS instance $NFS_VM is running"
          break
        else
          echo "Waiting for NFS instance to be running... (Attempt $((attempt + 1)) of $max_attempts)"
          sleep 10
        fi
        
        attempt=$((attempt + 1))
      done

      if [ $attempt -eq $max_attempts ]; then
        echo "ERROR: Max attempts reached. NFS instance is not running."
        exit 1
      fi

      # Create directories on NFS server
      echo "Creating NFS directories on $NFS_VM..."
      
      CREATE_DIRS_SCRIPT=$(cat <<'SCRIPT_END'
#!/bin/bash
set -e

echo "Creating NFS directory structure..."

# Create directories
sudo mkdir -p /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}

# Set permissions - CRITICAL FIX
sudo chmod -R 777 /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}
sudo chown -R www-data:www-data /share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}

echo "✓ Directories created successfully:"
ls -la /share/ | grep app${var.application_database_name}${var.tenant_deployment_id}${local.random_id} || echo "No directories found (this might be normal)"

# Verify NFS exports
echo ""
echo "Current NFS exports:"
sudo exportfs -v || echo "No exports configured yet"

echo ""
echo "✓ NFS directory creation complete"
SCRIPT_END
)

      # Execute directory creation with retries
      for i in {1..5}; do
        if [ -z "${local.project_sa_email}" ] || [ -z "${var.resource_creator_identity}" ]; then
          if echo "$CREATE_DIRS_SCRIPT" | gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s"; then
            echo "✓ NFS directories created successfully"
            break
          else
            echo "Attempt $i failed, retrying in 10 seconds..."
            sleep 10
          fi
        else
          if echo "$CREATE_DIRS_SCRIPT" | gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" --impersonate-service-account=${local.project_sa_email}; then
            echo "✓ NFS directories created successfully"
            break
          else
            echo "Attempt $i failed, retrying in 10 seconds..."
            sleep 10
          fi
        fi

        if [ "$i" -eq 5 ]; then
          echo "ERROR: Failed to create NFS directories after 5 attempts"
          exit 1
        fi
      done
      
      echo "=== NFS directory creation complete ==="
    EOF
  }

  depends_on = [
    data.external.nfs_instance_info
  ]
}

#########################################################################
# Configurations for nfs import
#########################################################################

# Create db import script
resource "local_file" "import_nfs_script_output" {
  count    = local.nfs_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
    DB_PASS             = data.google_secret_manager_secret_version.db_password.secret_data
    ROOT_PASS           = local.db_root_password
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
    NFS_IP              = local.nfs_internal_ip
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
  })
}


#########################################################################
# NFS Import Operations
#########################################################################

# Resource to import nfs
resource "null_resource" "import_nfs" {
  count    = local.nfs_server_exists ? 1 : 0  
    
  triggers = {
    script_hash = filesha256("${path.module}/scripts/app/import_nfs.tpl")
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
      max_attempts=3
      attempt=0

      while [ $attempt -lt $max_attempts ]; do
        NFS_VM=$(gcloud --project ${local.project.project_id} compute instances list --filter="INTERNAL_IP=${local.nfs_internal_ip}" --format="value(NAME)")
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

      for i in {1..5}; do
        if [ -z "${local.project_sa_email}" ] || [ -z "${var.resource_creator_identity}" ]; then
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/import-nfs.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/import-nfs.sh --impersonate-service-account=${local.project_sa_email}; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        fi

        if [ "$i" -eq 5 ]; then
          echo "SSH command failed after 5 attempts. Exiting..."
          exit 1
        fi
      done
    EOF
  }

  depends_on = [
    local_file.import_nfs_script_output,
    null_resource.build_and_push_backup_image,
    null_resource.create_nfs_directories_on_server,
  ]
}
