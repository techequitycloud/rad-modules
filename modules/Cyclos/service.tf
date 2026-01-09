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
  count               = var.configure_environment ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
      ports {
        container_port = 8080
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 30
        period_seconds        = 60
        failure_threshold     = 3
        tcp_socket {
          port = 8080
        }
      }

      liveness_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 5
        period_seconds        = 60
        failure_threshold     = 3
        http_get {
          path = "/api"
          port = 8080
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_user}${var.tenant_deployment_id}${local.random_id}"
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

      # Mount Cloud Storage bucket (replaces NFS for file storage)
      volume_mounts {
        name       = "gcs-data"
        mount_path = "/data"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        tags = ["nfsserver"]
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    # Mount Cloud Storage bucket for file storage (replaces NFS)
    volumes {
      name = "gcs-data"
      gcs {
        bucket    = var.create_cloud_storage ? local.data_bucket_name : ""
        read_only = false
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_db,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.db_password,
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service_iam" {
  count  = var.configure_environment ? 1 : 0

  project  = local.project.project_id  
  location = local.region  # Access location using local.region
  service  = google_cloud_run_v2_service.app_service[count.index].name      # Access service name using local.region
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.app_service
  ]
}
