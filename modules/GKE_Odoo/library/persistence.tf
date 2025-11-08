
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

# Resource to import dev dump
resource "null_resource" "import_dev_dump" {
  triggers = {
    project_id        = local.project.project_id
    nfs_server        = local.nfs_internal_ip
    zone              = data.google_compute_zones.available_zones.names[0]
    bucket            = "${local.project.project_id}-backups"
    backup_id         = "${var.application_backup_fileid}"
    backup_dump       = "dev_${var.application_backup_file}"
    db_ip             = google_sql_database_instance.postgresql_instance[0].private_ip_address
    db_name           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev"
    db_user           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev"
    db_pass           = data.google_secret_manager_secret_version.dev_db_password.secret_data
    pg_pass           = "${google_secret_manager_secret_version.postgres_password[0].secret_data}"
    app_name          = "app${var.application_name}${local.random_id}dev"
    app_region        = local.region
    app_namespace     = "${var.application_name}${var.client_deployment_id}dev"
    app_cluster       = "${var.google_kubernetes_engine_server}"
    app_restore_bucket  = "${local.project.project_id}-restore"
    creator_sa        = "${var.resource_creator_identity}"
    import_hash       = filesha256("${path.module}/scripts/app/import-db-nfs.sh")
    delete_hash       = filesha256("${path.module}/scripts/app/delete-db-nfs.sh")
    # always_run        = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/app" 
    command = "bash import-db-nfs.sh \"${local.project.project_id}\" \"${local.nfs_internal_ip}\" \"${data.google_compute_zones.available_zones.names[0]}\" \"${local.project.project_id}-backups\" \"${var.application_backup_fileid}\" \"dev_${var.application_backup_file}\" \"${google_sql_database_instance.postgresql_instance[0].private_ip_address}\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}dev\" \"${data.google_secret_manager_secret_version.dev_db_password.secret_data}\" \"${"${google_secret_manager_secret_version.postgres_password[0].secret_data}"}\" \"app${var.application_name}${local.random_id}dev\" \"${local.region}\" \"${var.application_name}${var.client_deployment_id}dev\" \"${var.google_kubernetes_engine_server}\" \"${local.project.project_id}-restore\" \"${var.resource_creator_identity}\""
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    working_dir = "${path.module}/scripts/app" 
    command = "bash delete-db-nfs.sh \"${self.triggers.project_id}\" \"${self.triggers.nfs_server}\" \"${self.triggers.zone}\" \"${self.triggers.bucket}\" \"${self.triggers.backup_dump}\" \"${self.triggers.db_ip}\" \"${self.triggers.db_name}\" \"${self.triggers.db_user}\" \"${self.triggers.db_pass}\" \"${self.triggers.pg_pass}\" \"${self.triggers.app_name}\" \"${self.triggers.app_region}\" \"${self.triggers.app_namespace}\" \"${self.triggers.app_cluster}\" \"${self.triggers.creator_sa}\""
  }

  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    google_secret_manager_secret_version.postgres_password,
    data.google_secret_manager_secret_version.dev_db_password,
    google_secret_manager_secret.dev_db_password,
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
  ]
}

#########################################################################
# Configurations for QA Database Creation
#########################################################################

# Resource to import qa dump
resource "null_resource" "import_qa_dump" {
  triggers = {
    project_id        = local.project.project_id
    nfs_server        = local.nfs_internal_ip
    zone              = data.google_compute_zones.available_zones.names[0]
    bucket            = "${local.project.project_id}-backups"
    backup_id         = "${var.application_backup_fileid}"
    backup_dump       = "dev_${var.application_backup_file}"
    db_ip             = google_sql_database_instance.postgresql_instance[0].private_ip_address
    db_name           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa"
    db_user           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa"
    db_pass           = data.google_secret_manager_secret_version.qa_db_password.secret_data
    pg_pass           = "${google_secret_manager_secret_version.postgres_password[0].secret_data}"
    app_name          = "app${var.application_name}${local.random_id}qa"
    app_region        = local.region
    app_namespace     = "${var.application_name}${var.client_deployment_id}qa"
    app_cluster       = "${var.google_kubernetes_engine_server}"
    app_restore_bucket  = "${local.project.project_id}-restore"
    creator_sa        = "${var.resource_creator_identity}"
    import_hash       = filesha256("${path.module}/scripts/app/import-db-nfs.sh")
    delete_hash       = filesha256("${path.module}/scripts/app/delete-db-nfs.sh")
    # always_run        = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/app"  
    command = "bash import-db-nfs.sh \"${local.project.project_id}\" \"${local.nfs_internal_ip}\" \"${data.google_compute_zones.available_zones.names[0]}\" \"${local.project.project_id}-backups\" \"${var.application_backup_fileid}\" \"qa_${var.application_backup_file}\" \"${google_sql_database_instance.postgresql_instance[0].private_ip_address}\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}qa\" \"${data.google_secret_manager_secret_version.qa_db_password.secret_data}\" \"${"${google_secret_manager_secret_version.postgres_password[0].secret_data}"}\" \"app${var.application_name}${local.random_id}qa\" \"${local.region}\" \"${var.application_name}${var.client_deployment_id}qa\" \"${var.google_kubernetes_engine_server}\" \"${local.project.project_id}-restore\" \"${var.resource_creator_identity}\""
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    working_dir = "${path.module}/scripts/app" 
    command = "bash delete-db-nfs.sh \"${self.triggers.project_id}\" \"${self.triggers.nfs_server}\" \"${self.triggers.zone}\" \"${self.triggers.bucket}\" \"${self.triggers.backup_dump}\" \"${self.triggers.db_ip}\" \"${self.triggers.db_name}\" \"${self.triggers.db_user}\" \"${self.triggers.db_pass}\" \"${self.triggers.pg_pass}\" \"${self.triggers.app_name}\" \"${self.triggers.app_region}\" \"${self.triggers.app_namespace}\" \"${self.triggers.app_cluster}\" \"${self.triggers.creator_sa}\""
  }

  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    google_secret_manager_secret_version.postgres_password,
    data.google_secret_manager_secret_version.qa_db_password,
    google_secret_manager_secret.qa_db_password,
    null_resource.import_dev_dump,
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
  ]
}

#########################################################################
# Configurations for Prod Database Creation
#########################################################################

# Resource to import prod dump
resource "null_resource" "import_prod_dump" {
  # Triggers that cause the resource to be updated/recreated
  triggers = {
    project_id        = local.project.project_id
    nfs_server        = local.nfs_internal_ip
    zone              = data.google_compute_zones.available_zones.names[0]
    bucket            = "${local.project.project_id}-backups"
    backup_id         = "${var.application_backup_fileid}"
    backup_dump       = "dev_${var.application_backup_file}"
    db_ip             = google_sql_database_instance.postgresql_instance[0].private_ip_address
    db_name           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod"
    db_user           = "app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod"
    db_pass           = data.google_secret_manager_secret_version.prod_db_password.secret_data
    pg_pass           = "${google_secret_manager_secret_version.postgres_password[0].secret_data}"
    app_name          = "app${var.application_name}${local.random_id}prod"
    app_region        = local.region
    app_namespace     = "${var.application_name}${var.client_deployment_id}prod"
    app_cluster       = "${var.google_kubernetes_engine_server}"
    app_restore_bucket  = "${local.project.project_id}-restore"
    creator_sa        = "${var.resource_creator_identity}"
    import_hash       = filesha256("${path.module}/scripts/app/import-db-nfs.sh")
    delete_hash       = filesha256("${path.module}/scripts/app/delete-db-nfs.sh")
    # always_run        = "${timestamp()}" # Trigger to always run on apply
  }
  
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/scripts/app"  
    command = "bash import-db-nfs.sh \"${local.project.project_id}\" \"${local.nfs_internal_ip}\" \"${data.google_compute_zones.available_zones.names[0]}\" \"${local.project.project_id}-backups\" \"${var.application_backup_fileid}\" \"prod_${var.application_backup_file}\" \"${google_sql_database_instance.postgresql_instance[0].private_ip_address}\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod\" \"app${var.application_database_name}${var.client_deployment_id}${local.random_id}prod\" \"${data.google_secret_manager_secret_version.prod_db_password.secret_data}\" \"${"${google_secret_manager_secret_version.postgres_password[0].secret_data}"}\" \"app${var.application_name}${local.random_id}prod\" \"${local.region}\" \"${var.application_name}${var.client_deployment_id}prod\" \"${var.google_kubernetes_engine_server}\" \"${local.project.project_id}-restore\" \"${var.resource_creator_identity}\""
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when    = destroy
    working_dir = "${path.module}/scripts/app" 
    command = "bash delete-db-nfs.sh \"${self.triggers.project_id}\" \"${self.triggers.nfs_server}\" \"${self.triggers.zone}\" \"${self.triggers.bucket}\" \"${self.triggers.backup_dump}\" \"${self.triggers.db_ip}\" \"${self.triggers.db_name}\" \"${self.triggers.db_user}\" \"${self.triggers.db_pass}\" \"${self.triggers.pg_pass}\" \"${self.triggers.app_name}\" \"${self.triggers.app_region}\" \"${self.triggers.app_namespace}\" \"${self.triggers.app_cluster}\" \"${self.triggers.creator_sa}\""
  }
  
  depends_on = [
    google_compute_instance_group_manager.nfs_server,
    google_secret_manager_secret_version.postgres_password,
    data.google_secret_manager_secret_version.prod_db_password,
    google_secret_manager_secret.prod_db_password,
    null_resource.import_qa_dump,
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
  ]
}
