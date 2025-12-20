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
  for_each            = var.configure_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

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
      app = var.application_name,
    }

    containers {
# image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}${var.tenant_deployment_id}${local.random_id}/${var.application_name}:${var.application_version}"
      image = "openemr/openemr:7.0.3"
       ports {
        container_port = 80
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
        initial_delay_seconds = 240
        timeout_seconds = 60
        period_seconds = 240
        failure_threshold = 3
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 240
        timeout_seconds = 60
        period_seconds = 180
        failure_threshold = 3
        http_get {
          path = "/interface/login/login.php"
          port = 80
        }
      }

      env {
        name  = "MYSQL_DATABASE"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name  = "MYSQL_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
      }

      env {
        name = "MYSQL_PASS"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      env {
        name  = "MYSQL_HOST"
        value = "${local.db_internal_ip}"
      }

      env {
        name = "MYSQL_ROOT_PASS"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-root-password"
            version = "latest"
          }
        }
      }

      env {
        name  = "MYSQL_PORT"
        value = "3306"
      }

      env {
        name  = "OE_USER"
        value = "admin"
      }

      env {
        name = "OE_PASS"
        value_source {
          secret_key_ref {
            secret = "openemr-admin-password-${var.tenant_deployment_id}-${local.random_id}"
            version = "latest"
          }
        }
      }

      env {
        name = "MANUAL_SETUP"
        value = "no"
      }

      volume_mounts {
        name      = "nfs-data-volume"
        mount_path = "/var/www/localhost/htdocs/openemr/sites"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/gce-vpc-subnet-${each.key}"
        tags = ["nfsserver"]
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
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
    null_resource.import_db,
    null_resource.import_nfs,
    null_resource.execute_init_job,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.openemr_admin_password,
    # null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "app_service_iam" {
  for_each = var.configure_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

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


