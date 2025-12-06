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

# --- Dev Jobs ---

resource "google_cloud_run_v2_job" "dev_install" {
  count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-install"
  location = local.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "/usr/local/bin/install_or_upgrade.sh"]

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

        env {
            name = "MOODLE_ADMIN_PASSWORD"
            value = var.moodle_admin_password != null ? var.moodle_admin_password : random_password.moodle_admin_password.result
        }
        env {
            name = "MOODLE_ADMIN_USER"
            value = var.moodle_admin_username
        }
        env {
            name = "MOODLE_ADMIN_EMAIL"
            value = var.moodle_admin_email
        }
        env {
            name = "MOODLE_FULLNAME"
            value = var.application_name
        }
        env {
            name = "MOODLE_SHORTNAME"
            value = var.application_name
        }
        env {
            name = "APP_URL"
            value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
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
        name = "cloudsql"
        cloud_sql_instance {
          instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
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
  }

  depends_on = [
      null_resource.build_and_push_application_image,
      null_resource.import_dev_db,
      null_resource.import_dev_nfs
  ]
}

# Execute jobs
resource "null_resource" "dev_execute_install" {
  count = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.dev_install[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.dev_install[0].name} --region ${local.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.dev_install
  ]
}

# --- QA Jobs ---

resource "google_cloud_run_v2_job" "qa_install" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-install"
  location = local.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "/usr/local/bin/install_or_upgrade.sh"]

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

        env {
            name = "MOODLE_ADMIN_PASSWORD"
            value = var.moodle_admin_password != null ? var.moodle_admin_password : random_password.moodle_admin_password.result
        }
        env {
            name = "MOODLE_ADMIN_USER"
            value = var.moodle_admin_username
        }
        env {
            name = "MOODLE_ADMIN_EMAIL"
            value = var.moodle_admin_email
        }
        env {
            name = "MOODLE_FULLNAME"
            value = var.application_name
        }
        env {
            name = "MOODLE_SHORTNAME"
            value = var.application_name
        }
        env {
            name = "APP_URL"
            value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
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
        name = "cloudsql"
        cloud_sql_instance {
          instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
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
  }

  depends_on = [
      null_resource.build_and_push_application_image,
      null_resource.import_qa_db,
      null_resource.import_qa_nfs
  ]
}

resource "null_resource" "qa_execute_install" {
  count = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.qa_install[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.qa_install[0].name} --region ${local.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.qa_install
  ]
}

# --- Prod Jobs ---

resource "google_cloud_run_v2_job" "prod_install" {
  count    = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-install"
  location = local.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "/usr/local/bin/install_or_upgrade.sh"]

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

        env {
            name = "MOODLE_ADMIN_PASSWORD"
            value = var.moodle_admin_password != null ? var.moodle_admin_password : random_password.moodle_admin_password.result
        }
        env {
            name = "MOODLE_ADMIN_USER"
            value = var.moodle_admin_username
        }
        env {
            name = "MOODLE_ADMIN_EMAIL"
            value = var.moodle_admin_email
        }
        env {
            name = "MOODLE_FULLNAME"
            value = var.application_name
        }
        env {
            name = "MOODLE_SHORTNAME"
            value = var.application_name
        }
        env {
            name = "APP_URL"
            value = "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project_number}.${local.region}.run.app"
        }

        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
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
        name = "cloudsql"
        cloud_sql_instance {
          instances = ["${local.project.project_id}:${local.region}:${local.db_instance_name}"]
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
  }

  depends_on = [
      null_resource.build_and_push_application_image,
      null_resource.import_prod_db,
      null_resource.import_prod_nfs
  ]
}

resource "null_resource" "prod_execute_install" {
  count = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.prod_install[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.prod_install[0].name} --region ${local.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.prod_install
  ]
}
