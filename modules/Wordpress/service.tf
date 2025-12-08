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

resource "google_cloud_run_v2_service" "app_service" {
  # Iterating over the cartesian product of environments and regions
  for_each = {
    for instance in local.service_instances : instance.key => instance
  }

  project             = local.project.project_id
  name                = each.value.name # Use the pre-computed name
  location            = each.value.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = each.value.short_name
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
        initial_delay_seconds = 240
        timeout_seconds       = 60
        period_seconds        = 240
        failure_threshold     = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 300
        timeout_seconds       = 60
        period_seconds        = 60
        failure_threshold     = 3
        http_get {
          path = "/wp-admin/install.php"
          port = 80
        }
      }

      env {
        name  = "WORDPRESS_DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
      }

      env {
        name  = "WORDPRESS_DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
      }

      env {
        name = "WORDPRESS_DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}${each.value.name_suffix}-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      env {
        name  = "WORDPRESS_DB_HOST"
        value = "${local.db_internal_ip}"
      }

      env {
        name  = "WORDPRESS_DEBUG"
        value = "false"
      }

      volume_mounts {
        name      = "gcs-data-volume"
        mount_path = "/var/www/html/wp-content"
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
      name = "gcs-data-volume"
      gcs {
        bucket = "${local.data_bucket_name}"
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_db,  # This will depend on the map of imports. Terraform handles dependency automatically if referenced, but here it's implicit via environment.
    null_resource.import_nfs,
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.db_password,
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service_iam" {
  for_each = {
    for instance in local.service_instances : instance.key => instance
  }

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.app_service[each.key].location
  service  = google_cloud_run_v2_service.app_service[each.key].name
  role     = "roles/run.invoker"
  
  # Condition for public access based on variable
  members = var.public_access ? ["allUsers"] : []

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}

resource "google_cloud_run_v2_job" "backup_service" {
  for_each = var.configure_backups ? local.environments : {}

  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : each.value.short_name
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}${each.value.name_suffix}-password-${var.tenant_deployment_id}-${local.random_id}"
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
          bucket = "${local.backup_bucket_name}"
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}${each.value.name_suffix}"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_db,
    null_resource.import_nfs,
    null_resource.build_and_push_backup_image,
  ]
}
