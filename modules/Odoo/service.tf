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
  for_each            = (var.configure_environment && local.nfs_server_exists && local.sql_server_exists) ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location            = each.key
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name
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
        timeout_seconds       = 60
        period_seconds        = 120
        failure_threshold     = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      env {
        name  = "DB_HOST"
        value = "${local.db_internal_ip}"
      }

      volume_mounts {
        name      = "nfs-data-volume"
        mount_path = "/mnt"
      }

      volume_mounts {
        name      = "gcs-data-volume"
        mount_path = "/extra-addons"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/${local.subnet_map[each.key]}"
        tags = ["nfsserver"]
      }
      egress = "PRIVATE_RANGES_ONLY"
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
        bucket = "${local.data_bucket_name}"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.nfs_internal_ip}"
        path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.execute_import_db_job,
    null_resource.execute_nfs_setup_job, # Updated to use the new job
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_iam_member.db_password,
    google_cloud_run_v2_job.init_db_job,
  ]
}
resource "google_cloud_run_service_iam_binding" "app" {
  for_each = (var.configure_environment && local.nfs_server_exists && local.sql_server_exists) ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}
