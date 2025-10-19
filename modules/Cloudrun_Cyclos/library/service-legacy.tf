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
  count               = var.configure_dev_environment ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.customer_identifier}${local.random_id}dev"
  location            = local.region  # Replace with your desired region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  
  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app : var.application_name,
      env : "dev"
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/${var.application_name}:${var.application_version}"
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
        initial_delay_seconds = 0
        timeout_seconds = 120
        period_seconds = 240
        failure_threshold = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 180
        timeout_seconds = 1
        period_seconds = 10
        failure_threshold = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}dev"
      }

      env {
        name  = "DB_USER"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}dev"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_name}dev-password-${var.customer_identifier}-${local.random_id}"
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
        network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
        subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
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
        bucket = "${local.project.project_id}-data"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.gce_instance_internalIP}"
        path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}dev"
      }
    }
  }

  traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_dev_dump,
    null_resource.build_and_push_container_image,
    google_secret_manager_secret_version.dev_db_password
  ]
}

resource "google_cloud_run_service_iam_binding" "dev_app_service" {
  count    = var.configure_dev_environment ? 1 : 0
  project  = local.project.project_id  
  location = google_cloud_run_v2_service.dev_app_service[count.index].location
  service  = google_cloud_run_v2_service.dev_app_service[count.index].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.dev_app_service
  ]
}

resource "google_cloud_run_v2_job" "dev_backup_service" {
  count      = var.configure_dev_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.customer_identifier}${local.random_id}dev"
  location   = "${local.region}"  # Replace with your desired region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "dev"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}dev"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}dev"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_name}dev-password-${var.customer_identifier}-${local.random_id}"
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
          network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
          subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = "${local.project.project_id}-backups"  # Replace with your GCS bucket name
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.gce_instance_internalIP}"
          path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}dev"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_dev_dump,
    null_resource.build_and_push_backup_image
  ]
}

resource "google_cloud_run_v2_service" "qa_app_service" {
  count               = var.configure_qa_environment ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.customer_identifier}${local.random_id}qa"
  location            = local.region  # Replace with your desired region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  
  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app : var.application_name,
      env : "qa"
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/${var.application_name}:${var.application_version}"
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
        initial_delay_seconds = 0
        timeout_seconds = 120
        period_seconds = 240
        failure_threshold = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 180
        timeout_seconds = 1
        period_seconds = 10
        failure_threshold = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}qa"
      }

      env {
        name  = "DB_USER"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}qa"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_name}qa-password-${var.customer_identifier}-${local.random_id}"
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
        network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
        subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
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
        bucket = "${local.project.project_id}-data"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.gce_instance_internalIP}"
        path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}qa"
      }
    }
  }

  traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_qa_dump,
    null_resource.build_and_push_container_image,
    google_secret_manager_secret_version.qa_db_password
  ]
}

resource "google_cloud_run_service_iam_binding" "qa_app_service" {
  count    = var.configure_qa_environment ? 1 : 0
  project  = local.project.project_id  
  location = google_cloud_run_v2_service.qa_app_service[count.index].location
  service  = google_cloud_run_v2_service.qa_app_service[count.index].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.qa_app_service
  ]
}

resource "google_cloud_run_v2_job" "qa_backup_service" {
  count      = var.configure_qa_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.customer_identifier}${local.random_id}qa"
  location   = "${local.region}"  # Replace with your desired region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "qa"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}qa"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}qa"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_name}qa-password-${var.customer_identifier}-${local.random_id}"
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
          network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
          subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = "${local.project.project_id}-backups"  # Replace with your GCS bucket name
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.gce_instance_internalIP}"
          path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}qa"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_qa_dump,
    null_resource.build_and_push_backup_image
  ]
}


resource "google_cloud_run_v2_service" "prod_app_service" {
  count               = var.configure_prod_environment ? 1 : 0
  project             = local.project.project_id
  name                = "app${var.application_name}${var.customer_identifier}${local.random_id}prod"
  location            = local.region  # Replace with your desired region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  
  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app : var.application_name,
      env : "prod"
    }

    containers {
      image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/${var.application_name}:${var.application_version}"
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
        initial_delay_seconds = 0
        timeout_seconds = 120
        period_seconds = 240
        failure_threshold = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 180
        timeout_seconds = 1
        period_seconds = 10
        failure_threshold = 3
        http_get {
          path = "/web/health"
          port = 80
        }
      }

      env {
        name  = "DB_NAME"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}prod"
      }

      env {
        name  = "DB_USER"
        value = "app${var.database_name}${var.customer_identifier}${local.random_id}prod"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret = "${local.db_instance_name}-${var.application_name}prod-password-${var.customer_identifier}-${local.random_id}"
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
        network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
        subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
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
        bucket = "${local.project.project_id}-data"  # Replace with your GCS bucket name
      }
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server = "${local.gce_instance_internalIP}"
        path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}prod"
      }
    }
  }

  traffic {
    type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.import_prod_dump,
    null_resource.build_and_push_container_image,
    google_secret_manager_secret_version.prod_db_password
  ]
}

resource "google_cloud_run_service_iam_binding" "prod_app_service" {
  count    = var.configure_prod_environment ? 1 : 0
  project  = local.project.project_id  
  location = google_cloud_run_v2_service.prod_app_service[count.index].location
  service  = google_cloud_run_v2_service.prod_app_service[count.index].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.prod_app_service
  ]
}

resource "google_cloud_run_v2_job" "prod_backup_service" {
  count      = var.configure_prod_environment ? 1 : 0
  project    = local.project.project_id  
  name       = "bkup${var.application_name}${var.customer_identifier}${local.random_id}prod"
  location   = "${local.region}"  # Replace with your desired region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name
      env : "prod"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.customer_identifier}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}prod"
        }

        env {
          name  = "DB_NAME"
          value = "app${var.database_name}${var.customer_identifier}${local.random_id}prod"
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_name}prod-password-${var.customer_identifier}-${local.random_id}"
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
          network = "projects/${local.configuration[var.application_project].app_host_project}/global/networks/${var.host_project_network}"
          subnetwork = "projects/${local.configuration[var.application_project].app_host_project}/regions/${local.region}/subnetworks/gce-vpc-subnet"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "gcs-backup-volume"
        gcs {
          bucket = "${local.project.project_id}-backups"  # Replace with your GCS bucket name
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.gce_instance_internalIP}"
          path   = "/share/app${var.database_name}${var.customer_identifier}${local.random_id}prod"
        }
      }
    }
  }

  depends_on = [
    null_resource.import_prod_dump,
    null_resource.build_and_push_backup_image
  ]
}
