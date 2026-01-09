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
# Create new SQL instance only if existing one doesn't exist
#########################################################################

resource "google_sql_database_instance" "postgres_instance" {
  count                   = var.create_postgres ? 1 : 0
  name                    = format("cloud-sql-postgres-%s", local.random_id)
  region                  = local.region                   
  database_version        = var.postgres_database_version 
  project                 = local.project.project_id      
  deletion_protection     = false                         
  root_password           = random_password.root_password.result

  settings {
    activation_policy     = "ALWAYS"                       
    availability_type     = var.postgres_database_availability_type 
    tier                  = var.postgres_tier              
    edition               = "ENTERPRISE"
    disk_autoresize       = true                          
    disk_autoresize_limit = 0                           
    disk_size             = 10
    disk_type             = "PD_SSD"                       

    ip_configuration {
      ipv4_enabled            = false                     
      private_network         = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/global/networks/${var.network_name}"  
      ssl_mode                = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"  
      allocated_ip_range      = null                      
    }

    backup_configuration {
      enabled                        = true                  
      location                       = local.region          
      point_in_time_recovery_enabled = true                 
      backup_retention_settings {
        retained_backups             = 7                     
        retention_unit               = "COUNT"               
      }
      start_time                     = "04:00"               
      transaction_log_retention_days = 7                     
    }

    database_flags {
      name  = "max_connections"
      value = "30000"
    }
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }

  depends_on = [
    null_resource.wait_for_dependencies,
    random_password.root_password,
    google_sql_database_instance.mysql_instance,  # Wait for MySQL to complete first
  ]
}

resource "null_resource" "wait_for_dependencies" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sleep 60"
  }

  depends_on = [
    google_service_networking_connection.psconnect,
    google_compute_instance_group_manager.nfs_server,
  ]
}

#########################################################################
# Secret Manager resources for database
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "pgsql_root_password" {
  count      = var.create_postgres ? 1 : 0
  project    = local.project.project_id  
  secret_id  = "${google_sql_database_instance.postgres_instance[0].name}-root-password"  

  replication {
    auto {} 
  }

  depends_on = [
    google_sql_database_instance.postgres_instance,
  ]
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "pgsql_root_password" {
  count       = var.create_postgres ? 1 : 0
  secret      = google_secret_manager_secret.pgsql_root_password[0].id   
  secret_data = random_password.root_password.result            

  depends_on = [
    google_secret_manager_secret.pgsql_root_password,
  ]
}

# Simple wait for secret propagation (no polling needed)
resource "time_sleep" "wait_for_pgsql_secret" {
  count           = var.create_postgres ? 1 : 0
  create_duration = "10s"
  
  depends_on = [
    google_secret_manager_secret_version.pgsql_root_password
  ]
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "pgsql_root_password" {
  count    = var.create_postgres ? 1 : 0
  provider = google  

  secret   = google_secret_manager_secret.pgsql_root_password[0].id  
  version  = "latest"  

  depends_on = [
    google_secret_manager_secret_version.pgsql_root_password,
    time_sleep.wait_for_pgsql_secret
  ]
}
