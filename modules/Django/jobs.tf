# Copyright 2024 Tech Equity Ltd
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

# --- Jobs ---

resource "google_cloud_run_v2_job" "migrate" {
  count    = var.configure_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-migrate"
  location = local.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "python manage.py migrate && python manage.py collectstatic --noinput --clear"]

        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.application_settings.secret_id
              version = "latest"
            }
          }
        }
        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }


      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = ["${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"]
        }
      }
    }
  }

  depends_on = [
      null_resource.build_and_push_application_image
  ]
}

resource "google_cloud_run_v2_job" "createuser" {
  count    = var.configure_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-createuser"
  location = local.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"

        env {
            name = "DJANGO_SUPERUSER_PASSWORD"
            value_source {
                secret_key_ref {
                    secret = google_secret_manager_secret.superuser_password.secret_id
                    version = "latest"
                }
            }
        }
        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.application_settings.secret_id
              version = "latest"
            }
          }
        }
        env {
            name = "DJANGO_SUPERUSER_USERNAME"
            value = var.django_superuser_username
        }
        env {
            name = "DJANGO_SUPERUSER_EMAIL"
            value = var.django_superuser_email
        }
        env {
          name = "GS_BUCKET_NAME"
          value = google_storage_bucket.storage.name
        }

        command = ["python", "manage.py", "createsuperuser", "--noinput"]

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = ["${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}"]
        }
      }
    }
  }

  depends_on = [
      null_resource.build_and_push_application_image
  ]
}

# Execute jobs
resource "null_resource" "execute_migrate" {
  count = var.configure_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.migrate[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.migrate[0].name} --region ${local.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.migrate,
      null_resource.build_and_push_application_image,
      google_sql_user.user,
      google_sql_database.db
  ]
}

resource "null_resource" "execute_createuser" {
  count = var.configure_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.createuser[0].id
  }

  provisioner "local-exec" {
      # Ignore failure if user already exists
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.createuser[0].name} --region ${local.region} --project ${local.project.project_id} --wait || true"
  }
  depends_on = [
      null_resource.execute_migrate, # Run after migrate
      google_cloud_run_v2_job.createuser
  ]
}

# Backup Jobs

resource "google_cloud_run_v2_job" "backup_service" {
  count      = var.configure_backups && var.configure_environment && local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "default"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = google_sql_user.user.name
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.db.name
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.db_password.secret_id
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
          bucket = google_storage_bucket.backup_storage.name
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
  }

  depends_on = [
    null_resource.build_and_push_backup_image,
    google_sql_database.db,
    google_storage_bucket.backup_storage,
    null_resource.import_nfs # Ensures NFS share exists
  ]
}
