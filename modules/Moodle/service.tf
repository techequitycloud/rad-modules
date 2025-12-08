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

locals {
  # Define environments based on variables
  env_config = {
    dev  = var.configure_development_environment
    qa   = var.configure_nonproduction_environment
    prod = var.configure_production_environment
  }

  # Create a set of enabled environments
  enabled_envs = toset([for env, enabled in local.env_config : env if enabled])

  # Calculate locations for each environment
  # If we have 2 regions, split them. If only 1, use it.
  # This logic follows the original code:
  # dev: regions[0], qa: regions[0] (but in for_each context it's tricky if they overlap)
  # The original code used:
  # dev: for_each = (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]]))
  # But that created services in ALL regions for EACH environment?
  # Original code:
  # resource "google_cloud_run_v2_service" "dev_app_service" {
  #   for_each = var.configure_development_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  # ...
  # }
  # So "dev" is deployed to multiple regions if available? Yes.
  # And "qa" also deployed to multiple regions? Yes.
  # And "prod" also? Yes.

  # So we need a Cartesian product of [enabled_envs] x [regions]
  service_instances = {
    for pair in setproduct(local.enabled_envs, (length(local.regions) >= 2 ? local.regions : [local.regions[0]])) :
    "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      region = pair[1]
    }
  }
}

resource "google_cloud_run_v2_service" "app_service" {
  for_each            = local.service_instances

  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}"
  location            = each.value.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.cloud_run_sa_email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = each.value.env
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
      ports {
        container_port = 80
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 120
        timeout_seconds       = 60
        period_seconds        = 120
        failure_threshold     = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 120
        timeout_seconds       = 5
        period_seconds        = 120
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            # Reference the correct secret for the environment
            secret = google_secret_manager_secret.db_password[each.value.env].secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "DB_HOST"
        value = "${local.db_internal_ip}"
      }

      env {
        name  = "APP_URL"
        value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}-${local.project_number}.${each.value.region}.run.app"
      }

      volume_mounts {
        name      = "nfs-data-volume"
        mount_path = "/mnt"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.value.region}/subnetworks/gce-vpc-subnet-${each.value.region}"
        tags = ["nfsserver"]
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.nfs_internal_ip}"
        path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.env}"
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_nfs, # Renamed dependency
    google_cloud_run_v2_job.db_import_job, # Wait for DB import
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.db_password,
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service_public" {
  for_each = { for k, v in local.service_instances : k => v if var.public_access == true }

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.app_service[each.key].location
  service  = google_cloud_run_v2_service.app_service[each.key].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

# Backup Jobs
resource "google_cloud_run_v2_job" "backup_service" {
  for_each = var.configure_backups ? local.enabled_envs : toset([])
  
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app = var.application_name,
      env = each.key
    }

    template {
      service_account       = local.cloud_run_sa_email
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.db_password[each.key].secret_id
              version = "latest"
            }
          }
        }

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }

        volume_mounts {
          name      = "gcs-backup-volume"
          mount_path = "/data"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
        }
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = "${local.backup_bucket_name}"  # Replace with your GCS bucket name
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.key}"
        }
      }
    }
  }

  depends_on = [
    google_cloud_run_v2_job.db_import_job, # Wait for DB import
    null_resource.import_nfs, # Renamed
    null_resource.build_and_push_backup_image,
  ]
}
