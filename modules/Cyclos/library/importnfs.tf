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
resource "local_file" "import_dev_nfs_script_output" {
  count    = var.create_network_filesystem ? 1 : 0  
  filename = "${path.module}/scripts/app/dev/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev"
    DB_USER             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev"
    APP_NAME            = "app${var.application_name}${var.client_deployment_id}${local.random_id}dev"
    APP_REGION_1        = "${local.regions[0]}"
    APP_REGION_2        = "${local.regions[1]}"
    NFS_IP              = local.gce_instance_internalIP
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
  })
}

# Create db import script
resource "local_file" "import_qa_nfs_script_output" {
  count    = var.create_network_filesystem ? 1 : 0  
  filename = "${path.module}/scripts/app/qa/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa"
    DB_USER             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa"
    APP_NAME            = "app${var.application_name}${var.client_deployment_id}${local.random_id}qa"
    APP_REGION_1        = "${local.regions[0]}"
    APP_REGION_2        = "${local.regions[1]}"
    NFS_IP              = local.gce_instance_internalIP
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
  })
}

# Create db import script
resource "local_file" "import_prod_nfs_script_output" {
  count    = var.create_network_filesystem ? 1 : 0  
  filename = "${path.module}/scripts/app/prod/import-nfs.sh"
  content = templatefile("${path.module}/scripts/app/import_nfs.tpl", {
    PROJECT_ID          = local.project.project_id
    BACKUP_FILEID       = "${var.application_backup_fileid}"
    DB_NAME             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod"
    DB_USER             = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod"
    APP_NAME            = "app${var.application_name}${var.client_deployment_id}${local.random_id}prod"
    APP_REGION_1        = "${local.regions[0]}"
    APP_REGION_2        = "${local.regions[1]}"
    NFS_IP              = local.gce_instance_internalIP
    NFS_ZONE            = data.google_compute_zones.available_zones.names[0]
  })
}

#########################################################################
# Configurations for backup import
#########################################################################

# Resource to import db
resource "null_resource" "import_dev_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  

  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    timeout 600 bash -c '
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances create setup-dev-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_dev_nfs_script_output[count.index].filename}
    else
        gcloud compute instances create setup-dev-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_dev_nfs_script_output[count.index].filename} --impersonate-service-account=${var.resource_creator_identity}
    fi
    '
    EOT
  }

  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    local_file.import_dev_nfs_script_output,
  ]
}

# Resource to import db 
resource "null_resource" "import_qa_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  

  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    timeout 600 bash -c '
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances create setup-qa-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_qa_nfs_script_output[count.index].filename}
    else
        gcloud compute instances create setup-qa-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_qa_nfs_script_output[count.index].filename} --impersonate-service-account=${var.resource_creator_identity}
    fi
    '
    EOT
  }

  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    local_file.import_qa_nfs_script_output,
    # null_resource.import_dev_nfs,
  ]
}

# Resource to import db 
resource "null_resource" "import_prod_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  

  # Triggers that cause the resource to be updated/recreated
  triggers = {
    # always_run    = "${timestamp()}" # Trigger to always run on apply
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    timeout 600 bash -c '
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances create setup-prod-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_prod_nfs_script_output[count.index].filename}
    else
        gcloud compute instances create setup-prod-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --machine-type=f1-micro --image-family=debian-11 --image-project=debian-cloud --network=${google_compute_network.vpc_network.id} --subnet=${google_compute_subnetwork.gce_subnetwork[local.region].id} --service-account=${google_service_account.setup_server_sa_admin.email} --scopes=cloud-platform --no-address --metadata=enable-oslogin=true --metadata-from-file=${local_file.import_prod_nfs_script_output[count.index].filename} --impersonate-service-account=${var.resource_creator_identity}
    fi
    '
    EOT
  }

  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    local_file.import_prod_nfs_script_output,
    # null_resource.import_qa_nfs,
  ]
}

#########################################################################
# Configurations for deleting VM
#########################################################################

resource "time_sleep" "import_dev_nfs" {

  create_duration = "600s"
  depends_on = [
    null_resource.import_dev_nfs,
  ]
}

resource "null_resource" "delete_dev_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances delete setup-dev-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --quiet || true
    else
        gcloud compute instances delete setup-dev-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --impersonate-service-account=${var.resource_creator_identity} --quiet || true
    fi
    EOT
  }

  depends_on = [
    time_sleep.import_dev_nfs,
    null_resource.import_dev_nfs,
  ]
}

resource "time_sleep" "import_qa_nfs" {

  create_duration = "600s"
  depends_on = [
    null_resource.import_qa_nfs,
  ]
}

resource "null_resource" "delete_qa_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances delete setup-qa-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --quiet || true
    else
        gcloud compute instances delete setup-qa-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --impersonate-service-account=${var.resource_creator_identity} --quiet || true
    fi
    EOT
  }

  depends_on = [
    time_sleep.import_qa_nfs,
    null_resource.import_qa_nfs,
  ]
}

resource "time_sleep" "import_prod_nfs" {

  create_duration = "600s"
  depends_on = [
    null_resource.import_prod_nfs,
  ]
}

resource "null_resource" "delete_prod_nfs" {
  count    = var.create_network_filesystem ? 1 : 0  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
    if [ "${var.resource_creator_identity}" = "" ];
    then
        gcloud compute instances delete setup-prod-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --quiet || true
    else
        gcloud compute instances delete setup-prod-nfs-vm --zone=${data.google_compute_zones.available_zones.names[0]} --project=${local.project.project_id} --impersonate-service-account=${var.resource_creator_identity} --quiet || true
    fi
    EOT
  }

  depends_on = [
    time_sleep.import_prod_nfs,
    null_resource.import_prod_nfs,
  ]
}
