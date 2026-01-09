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

resource "google_sql_database_instance" "mysql_instance" {
  count                   = var.create_mysql ? 1 : 0
  name                    = format("cloud-sql-mysql-%s", local.random_id)
  region                  = local.region
  database_version        = var.mysql_database_version
  project                 = local.project.project_id
  deletion_protection     = false

  settings {
    activation_policy     = "ALWAYS"
    availability_type     = var.mysql_database_availability_type
    tier                  = var.mysql_tier
    edition               = "ENTERPRISE"
    disk_autoresize       = true
    disk_autoresize_limit = 0
    disk_size             = 10
    disk_type             = "PD_SSD"

    ip_configuration {
      ipv4_enabled            = false
      private_network         = "https://www.googleapis.com/compute/v1/projects/${var.existing_project_id}/global/networks/${var.network_name}"
      allocated_ip_range      = null
    }

    backup_configuration {
      enabled                        = true
      location                       = local.region
      binary_log_enabled             = true
      backup_retention_settings {
        retained_backups             = 7
        retention_unit               = "COUNT"
      }
      start_time                     = "04:00"
    }

    # Database flags for performance and security
    dynamic "database_flags" {
      for_each = [
        { name = "max_connections", value = "30000" },
        { name = "local_infile", value = "off" }
      ]
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
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
  ]
}

resource "google_sql_user" "mysql_root_user" {
  count    = var.create_mysql ? 1 : 0
  name     = "root"
  instance = google_sql_database_instance.mysql_instance[0].name
  host     = "%"  # Allow connections from any host within the private network
  password = random_password.root_password.result
  project  = local.project.project_id

  depends_on = [
    google_sql_database_instance.mysql_instance,
    random_password.root_password,
  ]
}

#########################################################################
# Secret Manager resources for database
#########################################################################

# Resource for creating a secret in Google Secret Manager to store the database password
resource "google_secret_manager_secret" "mysql_root_password" {
  count      = var.create_mysql ? 1 : 0
  project    = local.project.project_id  
  secret_id  = "${google_sql_database_instance.mysql_instance[0].name}-root-password"  

  replication {
    auto {} 
  }

  depends_on = [
    google_sql_database_instance.mysql_instance,
  ]
}

# Resource for adding a version of the secret with the actual database password
resource "google_secret_manager_secret_version" "mysql_root_password" {
  count       = var.create_mysql ? 1 : 0
  secret      = google_secret_manager_secret.mysql_root_password[0].id   
  secret_data = random_password.root_password.result            

  depends_on = [
    google_secret_manager_secret.mysql_root_password,
  ]
}

# Simple wait for secret propagation
resource "time_sleep" "wait_for_mysql_secret" {
  count           = var.create_mysql ? 1 : 0
  create_duration = "10s"
  
  depends_on = [
    google_secret_manager_secret_version.mysql_root_password
  ]
}

# Data source for accessing the latest version of the secret when it's ready
data "google_secret_manager_secret_version" "mysql_root_password" {
  count    = var.create_mysql ? 1 : 0
  provider = google  

  secret   = google_secret_manager_secret.mysql_root_password[0].id  
  version  = "latest"  

  depends_on = [
    google_secret_manager_secret_version.mysql_root_password,
    time_sleep.wait_for_mysql_secret
  ]
}
