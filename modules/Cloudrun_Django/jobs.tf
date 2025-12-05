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

resource "google_cloud_run_v2_job" "migrate" {
  name     = "${var.application_name}-migrate-${local.random_id}"
  location = var.region
  project  = local.project_id
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.cloudrun_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"
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
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.instance.connection_name]
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job" "createuser" {
  name     = "${var.application_name}-createuser-${local.random_id}"
  location = var.region
  project  = local.project_id
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.cloudrun_sa.email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

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

        command = ["python", "manage.py", "createsuperuser", "--noinput"]

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.instance.connection_name]
        }
      }
    }
  }
}

# Execute jobs
resource "null_resource" "execute_migrate" {
  triggers = {
    job_id = google_cloud_run_v2_job.migrate.id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.migrate.name} --region ${var.region} --project ${local.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.migrate,
      null_resource.build_and_push_application_image,
      google_sql_user.user,
      google_sql_database.database
  ]
}

resource "null_resource" "execute_createuser" {
  triggers = {
    job_id = google_cloud_run_v2_job.createuser.id
  }

  provisioner "local-exec" {
      # Ignore failure if user already exists
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.createuser.name} --region ${var.region} --project ${local.project_id} --wait || true"
  }
  depends_on = [
      null_resource.execute_migrate, # Run after migrate
      google_cloud_run_v2_job.createuser
  ]
}
