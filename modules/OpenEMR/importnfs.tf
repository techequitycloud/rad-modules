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
        NFS_VM=$(gcloud --project ${local.project.project_id} compute instances list \
          --filter="INTERNAL_IP=${local.nfs_internal_ip}" \
          --format="value(NAME)")
        
        status=$(gcloud --project ${local.project.project_id} compute instances list \
          --filter="INTERNAL_IP=${local.nfs_internal_ip}" \
          --format="value(status)")
        
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

      # Get NFS zone
      NFS_ZONE=$(gcloud --project ${local.project.project_id} compute instances list \
        --filter="INTERNAL_IP=${local.nfs_internal_ip}" \
        --format="value(zone)")

      # Create directories on NFS server
      echo "Creating NFS directories on $NFS_VM in zone $NFS_ZONE..."
      
      # FIXED: Removed single quotes to allow variable interpolation
      CREATE_DIRS_SCRIPT=$(cat <<SCRIPT_END
#!/bin/bash
set -e

echo "Creating NFS directory structure..."

# Define the share path
SHARE_PATH="/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"

# Create directories
sudo mkdir -p "\$SHARE_PATH"
sudo mkdir -p "\$SHARE_PATH/default"
sudo mkdir -p "\$SHARE_PATH/default/documents"

# FIXED: Set ownership first (use nobody:nogroup for NFS)
sudo chown -R nobody:nogroup "\$SHARE_PATH"

# FIXED: Set permissions after ownership
sudo chmod -R 777 "\$SHARE_PATH"

echo "✓ Directories created successfully:"
ls -la /share/ | grep app${var.application_database_name}${var.tenant_deployment_id}${local.random_id} || true

# ADDED: Configure NFS export
echo ""
echo "Configuring NFS export..."

EXPORT_LINE="\$SHARE_PATH *(rw,sync,no_subtree_check,no_root_squash,insecure)"

if ! sudo grep -q "^\$SHARE_PATH " /etc/exports; then
  echo "\$EXPORT_LINE" | sudo tee -a /etc/exports
  sudo exportfs -ra
  echo "✓ NFS export added and reloaded"
else
  echo "✓ NFS export already exists, reloading..."
  sudo exportfs -ra
fi

# Verify NFS exports
echo ""
echo "Current NFS exports:"
sudo exportfs -v

echo ""
echo "✓ NFS directory creation and export complete"
SCRIPT_END
)

      # Execute directory creation with retries
      for i in {1..5}; do
        SSH_CMD="gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone $NFS_ZONE"
        
        if [ -n "${local.project_sa_email}" ] && [ -n "${var.resource_creator_identity}" ]; then
          SSH_CMD="$SSH_CMD --impersonate-service-account=${local.project_sa_email}"
        fi
        
        if echo "$CREATE_DIRS_SCRIPT" | $SSH_CMD --command="sudo bash -s"; then
          echo "✓ NFS directories created successfully"
          break
        else
          echo "Attempt $i failed, retrying in 10 seconds..."
          sleep 10
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
    null_resource.create_nfs_directories_on_server,
  ]
}
