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

resource "google_cloud_run_v2_service" "dev_app_service" {
  for_each            = var.configure_development_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location            = each.key
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.odoo_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "dev"
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
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
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
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/gce-vpc-subnet-${each.key}"
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
        bucket = "${local.data_bucket_name}"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.nfs_internal_ip}"
        path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
      }
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_dev_db,
    null_resource.import_dev_nfs,
    null_resource.build_and_push_backup_image,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.dev_db_password,
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "dev" {
  for_each = var.configure_development_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.dev_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.dev_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.dev_app_service
  ]
}

resource "google_cloud_run_v2_service" "qa_app_service" {
  for_each            = var.configure_nonproduction_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location            = "${each.key}"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  
  template {
    service_account = google_service_account.odoo_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app : var.application_name,
      env : "qa"
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
          "cpu" = "1"
          "memory" = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 120
        timeout_seconds = 60
        period_seconds = 120
        failure_threshold = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 120
        timeout_seconds = 60
        period_seconds = 120
        failure_threshold = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"
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
        network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/gce-vpc-subnet-${each.key}"
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
        bucket = "${local.data_bucket_name}"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.nfs_internal_ip}"
        path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
      }
    }
  }

  traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_qa_db,
    null_resource.import_qa_nfs,
    null_resource.build_and_push_backup_image,
    google_cloud_run_v2_service.dev_app_service,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.qa_db_password,
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "qa" {
  for_each = var.configure_nonproduction_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.qa_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.qa_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.qa_app_service
  ]
}

resource "google_cloud_run_v2_service" "prod_app_service" {
  for_each            = var.configure_production_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location            = "${each.key}"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  
  template {
    service_account = google_service_account.odoo_sa.email
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app : var.application_name,
      env : "prod"
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
          "cpu" = "1"
          "memory" = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 120
        timeout_seconds = 60
        period_seconds = 120
        failure_threshold = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 120
        timeout_seconds = 60
        period_seconds = 120
        failure_threshold = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
      }

      env {
        name  = "DB_USER"
        value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
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
        network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${each.key}/subnetworks/gce-vpc-subnet-${each.key}"
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
        bucket = "${local.data_bucket_name}"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.nfs_internal_ip}"
        path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
      }
    }
  }

  traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_prod_db,
    null_resource.import_prod_nfs,
    null_resource.build_and_push_backup_image,
    google_cloud_run_v2_service.qa_app_service,
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.prod_db_password,
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "prod" {
  for_each = var.configure_production_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.prod_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.prod_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.prod_app_service
  ]
}
