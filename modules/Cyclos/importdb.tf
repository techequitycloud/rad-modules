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
resource "local_file" "import_dev_db_script_output" {
  count    = local.sql_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/dev/import-db.sh"
  content = templatefile("${path.module}/scripts/app/import_db.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DB_PASS             = data.google_secret_manager_secret_version.dev_db_password[count.index].secret_data
    PG_PASS             = local.db_root_password
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
  })
}

# Create db import script
resource "local_file" "import_qa_db_script_output" {
  count    = local.sql_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/qa/import-db.sh"
  content = templatefile("${path.module}/scripts/app/import_db.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DB_PASS             = data.google_secret_manager_secret_version.qa_db_password[count.index].secret_data
    PG_PASS             = local.db_root_password
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
  })
}

# Create db import script
resource "local_file" "import_prod_db_script_output" {
  count    = local.sql_server_exists ? 1 : 0  
  filename = "${path.module}/scripts/app/prod/import-db.sh"
  content = templatefile("${path.module}/scripts/app/import_db.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_IP               = local.db_internal_ip
    DB_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DB_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DB_PASS             = data.google_secret_manager_secret_version.prod_db_password[count.index].secret_data
    PG_PASS             = local.db_root_password
    APP_NAME            = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    APP_REGION_1        = length(local.regions) > 0 ? local.regions[0] : ""
    APP_REGION_2        = length(local.regions) > 1 ? local.regions[1] : ""
  })
}

#########################################################################
# Configurations for backup import
#########################################################################

# Resource to import dev db
resource "null_resource" "import_dev_db" {
  count    = local.sql_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
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
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/dev/import-db.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/dev/import-db.sh --impersonate-service-account=${local.project_sa_email}; then
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
    data.google_secret_manager_secret_version.dev_db_password,
    google_secret_manager_secret.dev_db_password,
    local_file.import_dev_db_script_output,
    null_resource.import_dev_nfs,
  ]
}

# Resource to import qa db
resource "null_resource" "import_qa_db" {
  count    = local.sql_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
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
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/qa/import-db.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/qa/import-db.sh --impersonate-service-account=${local.project_sa_email}; then
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
    data.google_secret_manager_secret_version.qa_db_password,
    google_secret_manager_secret.qa_db_password,
    local_file.import_qa_db_script_output,
    null_resource.import_dev_db,
    null_resource.import_qa_nfs,
  ]
}

# Resource to import prod db
resource "null_resource" "import_prod_db" {
  count    = local.sql_server_exists ? 1 : 0  
    
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
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
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/prod/import-db.sh; then
            echo "SSH command succeeded"
            break
          else
            echo "SSH attempt $i failed, retrying in 30 seconds..."
            sleep 30
          fi
        else
          if gcloud compute ssh --project ${local.project.project_id} --quiet $NFS_VM --zone ${data.google_compute_zones.available_zones.names[0]} --command="sudo bash -s" < ${path.module}/scripts/app/prod/import-db.sh --impersonate-service-account=${local.project_sa_email}; then
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
    data.google_secret_manager_secret_version.prod_db_password,
    google_secret_manager_secret.prod_db_password,
    local_file.import_prod_db_script_output,
    null_resource.import_qa_db,
    null_resource.import_prod_nfs,
  ]
}
