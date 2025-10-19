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
# Configurations for nfs import
#########################################################################

# Create db import script
resource "local_file" "import_dev_nfs_script_output" {
  count    = local.nfs_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/dev/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
    NFS_IP              = local.nfs_internal_ip
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
    APP_URL             = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project_number}.${local.region}.run.app"
  })
}

# Create db import script
resource "local_file" "import_qa_nfs_script_output" {
  count    = local.nfs_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/qa/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
    NFS_IP              = local.nfs_internal_ip
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
    APP_URL             = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa-${local.project_number}.${local.region}.run.app"
  })
}

# Create db import script
resource "local_file" "import_prod_nfs_script_output" {
  count    = local.nfs_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/prod/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
    NFS_IP              = local.nfs_internal_ip
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
    APP_URL             = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app"
  })
}

#########################################################################
# Configurations for nfs import
#########################################################################

# Resource to import dev nfs
resource "null_resource" "import_dev_nfs" {
  count    = local.nfs_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOF
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
          sleep 10 # wait before retrying
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
        then
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/dev/import-nfs.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/dev/import-nfs.sh --impersonate-service-account=${local.project_sa_email}; then
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
    local_file.import_dev_nfs_script_output,
    null_resource.build_and_push_application_image,
    null_resource.build_and_push_backup_image,
  ]
}

# Resource to import qa nfs
resource "null_resource" "import_qa_nfs" {
  count    = local.nfs_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOF
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
          sleep 10 # wait before retrying
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
        then
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/qa/import-nfs.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/qa/import-nfs.sh --impersonate-service-account=${local.project_sa_email}; then
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
    local_file.import_qa_nfs_script_output,
    null_resource.import_dev_nfs,
    null_resource.build_and_push_application_image,
    null_resource.build_and_push_backup_image,
  ]
}

# Resource to import prod nfs
resource "null_resource" "import_prod_nfs" {
  count    = local.nfs_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOF
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
          sleep 10 # wait before retrying
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
        then
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/prod/import-nfs.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/prod/import-nfs.sh --impersonate-service-account=${local.project_sa_email}; then
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
    local_file.import_prod_nfs_script_output,
    null_resource.import_qa_nfs,
    null_resource.build_and_push_application_image,
    null_resource.build_and_push_backup_image,
  ]
}


