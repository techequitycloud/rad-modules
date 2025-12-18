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

resource "google_cloud_run_v2_job" "cron_job_dev" {
  count    = var.configure_development_environment ? 1 : 0
  project  = local.project.project_id
  name     = "cron${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location = local.region

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "bitnami/moodle:latest"

        # Override command to run cron
        command = ["/bin/bash", "-c", "/opt/bitnami/php/bin/php /opt/bitnami/moodle/admin/cli/cron.php"]

        env {
          name  = "MOODLE_DATABASE_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name  = "MOODLE_DATABASE_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }

        env {
          name = "MOODLE_DATABASE_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        env {
          name  = "MOODLE_DATABASE_HOST"
          value = "${local.db_internal_ip}"
        }

        env {
          name  = "MOODLE_DATABASE_PORT_NUMBER"
          value = "5432"
        }

        env {
          name  = "MOODLE_SKIP_BOOTSTRAP"
          value = "yes"
        }

        env {
          name  = "APP_URL"
          value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/bitnami/moodledata"
        }

        volume_mounts {
          name       = "moodle-config"
          mount_path = "/opt/bitnami/moodle/config.php"
          sub_path   = "config.php"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
        }
      }

      volumes {
        name = "moodle-config"
        secret {
          secret = google_secret_manager_secret.moodle_config.secret_id
          items {
            version = "latest"
            path    = "config.php"
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.import_dev_db,
    null_resource.import_dev_nfs,
    google_secret_manager_secret_version.dev_db_password,
    google_secret_manager_secret_version.moodle_config_version,
  ]
}

resource "google_cloud_run_v2_job" "cron_job_qa" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  project  = local.project.project_id
  name     = "cron${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location = local.region

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "bitnami/moodle:latest"

        # Override command to run cron
        command = ["/bin/bash", "-c", "/opt/bitnami/php/bin/php /opt/bitnami/moodle/admin/cli/cron.php"]

        env {
          name  = "MOODLE_DATABASE_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name  = "MOODLE_DATABASE_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }

        env {
          name = "MOODLE_DATABASE_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        env {
          name  = "MOODLE_DATABASE_HOST"
          value = "${local.db_internal_ip}"
        }

        env {
          name  = "MOODLE_DATABASE_PORT_NUMBER"
          value = "5432"
        }

        env {
          name  = "MOODLE_SKIP_BOOTSTRAP"
          value = "yes"
        }

        env {
          name  = "APP_URL"
          value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/bitnami/moodledata"
        }

        volume_mounts {
          name       = "moodle-config"
          mount_path = "/opt/bitnami/moodle/config.php"
          sub_path   = "config.php"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
        }
      }

      volumes {
        name = "moodle-config"
        secret {
          secret = google_secret_manager_secret.moodle_config.secret_id
          items {
            version = "latest"
            path    = "config.php"
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.import_qa_db,
    null_resource.import_qa_nfs,
    google_secret_manager_secret_version.qa_db_password,
    google_secret_manager_secret_version.moodle_config_version,
  ]
}

resource "google_cloud_run_v2_job" "cron_job_prod" {
  count    = var.configure_production_environment ? 1 : 0
  project  = local.project.project_id
  name     = "cron${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location = local.region

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "bitnami/moodle:latest"

        # Override command to run cron
        command = ["/bin/bash", "-c", "/opt/bitnami/php/bin/php /opt/bitnami/moodle/admin/cli/cron.php"]

        env {
          name  = "MOODLE_DATABASE_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name  = "MOODLE_DATABASE_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }

        env {
          name = "MOODLE_DATABASE_PASSWORD"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        env {
          name  = "MOODLE_DATABASE_HOST"
          value = "${local.db_internal_ip}"
        }

        env {
          name  = "MOODLE_DATABASE_PORT_NUMBER"
          value = "5432"
        }

        env {
          name  = "MOODLE_SKIP_BOOTSTRAP"
          value = "yes"
        }

        env {
          name  = "APP_URL"
          value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/bitnami/moodledata"
        }

        volume_mounts {
          name       = "moodle-config"
          mount_path = "/opt/bitnami/moodle/config.php"
          sub_path   = "config.php"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
          tags = ["nfsserver"]
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
        }
      }

      volumes {
        name = "moodle-config"
        secret {
          secret = google_secret_manager_secret.moodle_config.secret_id
          items {
            version = "latest"
            path    = "config.php"
          }
        }
      }
    }
  }

  depends_on = [
    null_resource.import_prod_db,
    null_resource.import_prod_nfs,
    google_secret_manager_secret_version.prod_db_password,
    google_secret_manager_secret_version.moodle_config_version,
  ]
}
