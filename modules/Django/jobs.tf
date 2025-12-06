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

# --- Dev Jobs ---

resource "google_cloud_run_v2_job" "dev_migrate" {
  count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-migrate"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "python manage.py migrate && python manage.py collectstatic --noinput --clear"]

        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.dev_application_settings[0].secret_id
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

resource "google_cloud_run_v2_job" "dev_createuser" {
  count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-createuser"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

        env {
            name = "DJANGO_SUPERUSER_PASSWORD"
            value_source {
                secret_key_ref {
                    secret = google_secret_manager_secret.dev_superuser_password[0].secret_id
                    version = "latest"
                }
            }
        }
        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.dev_application_settings[0].secret_id
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
          value = google_storage_bucket.dev_storage[0].name
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
resource "null_resource" "dev_execute_migrate" {
  count = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.dev_migrate[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.dev_migrate[0].name} --region ${var.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.dev_migrate,
      null_resource.build_and_push_application_image,
      google_sql_user.dev_user,
      google_sql_database.dev_db
  ]
}

resource "null_resource" "dev_execute_createuser" {
  count = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.dev_createuser[0].id
  }

  provisioner "local-exec" {
      # Ignore failure if user already exists
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.dev_createuser[0].name} --region ${var.region} --project ${local.project.project_id} --wait || true"
  }
  depends_on = [
      null_resource.dev_execute_migrate, # Run after migrate
      google_cloud_run_v2_job.dev_createuser
  ]
}

# --- QA Jobs ---

resource "google_cloud_run_v2_job" "qa_migrate" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-migrate"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "python manage.py migrate && python manage.py collectstatic --noinput --clear"]

        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.qa_application_settings[0].secret_id
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

resource "google_cloud_run_v2_job" "qa_createuser" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-createuser"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

        env {
            name = "DJANGO_SUPERUSER_PASSWORD"
            value_source {
                secret_key_ref {
                    secret = google_secret_manager_secret.qa_superuser_password[0].secret_id
                    version = "latest"
                }
            }
        }
        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.qa_application_settings[0].secret_id
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
          value = google_storage_bucket.qa_storage[0].name
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

resource "null_resource" "qa_execute_migrate" {
  count = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.qa_migrate[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.qa_migrate[0].name} --region ${var.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.qa_migrate,
      null_resource.build_and_push_application_image,
      google_sql_user.qa_user,
      google_sql_database.qa_db
  ]
}

resource "null_resource" "qa_execute_createuser" {
  count = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.qa_createuser[0].id
  }

  provisioner "local-exec" {
      # Ignore failure if user already exists
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.qa_createuser[0].name} --region ${var.region} --project ${local.project.project_id} --wait || true"
  }
  depends_on = [
      null_resource.qa_execute_migrate, # Run after migrate
      google_cloud_run_v2_job.qa_createuser
  ]
}

# --- Prod Jobs ---

resource "google_cloud_run_v2_job" "prod_migrate" {
  count    = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-migrate"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"
        command = ["/bin/bash", "-c", "python manage.py migrate && python manage.py collectstatic --noinput --clear"]

        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.prod_application_settings[0].secret_id
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

resource "google_cloud_run_v2_job" "prod_createuser" {
  count    = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-createuser"
  location = var.region
  project  = local.project.project_id
  deletion_protection = false

  template {
    template {
      service_account = local.cloud_run_sa_email
      containers {
        image = "${var.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

        env {
            name = "DJANGO_SUPERUSER_PASSWORD"
            value_source {
                secret_key_ref {
                    secret = google_secret_manager_secret.prod_superuser_password[0].secret_id
                    version = "latest"
                }
            }
        }
        env {
          name = "APPLICATION_SETTINGS"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.prod_application_settings[0].secret_id
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
          value = google_storage_bucket.prod_storage[0].name
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

resource "null_resource" "prod_execute_migrate" {
  count = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.prod_migrate[0].id
  }

  provisioner "local-exec" {
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.prod_migrate[0].name} --region ${var.region} --project ${local.project.project_id} --wait"
  }
  depends_on = [
      google_cloud_run_v2_job.prod_migrate,
      null_resource.build_and_push_application_image,
      google_sql_user.prod_user,
      google_sql_database.prod_db
  ]
}

resource "null_resource" "prod_execute_createuser" {
  count = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    job_id = google_cloud_run_v2_job.prod_createuser[0].id
  }

  provisioner "local-exec" {
      # Ignore failure if user already exists
      command = "gcloud run jobs execute ${google_cloud_run_v2_job.prod_createuser[0].name} --region ${var.region} --project ${local.project.project_id} --wait || true"
  }
  depends_on = [
      null_resource.prod_execute_migrate, # Run after migrate
      google_cloud_run_v2_job.prod_createuser
  ]
}
# Backup Jobs

resource "google_cloud_run_v2_job" "dev_backup_service" {
  count      = var.configure_backups && var.configure_development_environment ? 1 : 0
  project    = local.project.project_id
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location   = local.region
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
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = google_sql_user.dev_user[0].name
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.dev_db[0].name
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.dev_db_password[0].secret_id
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
          bucket = google_storage_bucket.dev_backup_storage[0].name
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
    null_resource.build_and_push_backup_image,
    google_sql_database.dev_db,
    google_storage_bucket.dev_backup_storage,
    null_resource.import_dev_nfs # Ensures NFS share exists
  ]
}

resource "google_cloud_run_v2_job" "qa_backup_service" {
  count      = var.configure_backups && var.configure_nonproduction_environment ? 1 : 0
  project    = local.project.project_id
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location   = local.region
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
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = google_sql_user.qa_user[0].name
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.qa_db[0].name
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.qa_db_password[0].secret_id
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
          bucket = google_storage_bucket.qa_backup_storage[0].name
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
    null_resource.build_and_push_backup_image,
    google_sql_database.qa_db,
    google_storage_bucket.qa_backup_storage,
    null_resource.import_qa_nfs
  ]
}

resource "google_cloud_run_v2_job" "prod_backup_service" {
  count      = var.configure_backups && var.configure_production_environment ? 1 : 0
  project    = local.project.project_id
  name       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location   = local.region
  deletion_protection = false

  template {
    parallelism = 1
    task_count  = 1

    labels = {
      app : var.application_name,
      env : "prod"
    }

    template {
      service_account       = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries           = 3
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${google_artifact_registry_repository.repo.name}/backup:${var.application_version}"

        env {
          name  = "DB_USER"
          value = google_sql_user.prod_user[0].name
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.prod_db[0].name
        }

        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret = google_secret_manager_secret.prod_db_password[0].secret_id
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
          bucket = google_storage_bucket.prod_backup_storage[0].name
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
    null_resource.build_and_push_backup_image,
    google_sql_database.prod_db,
    google_storage_bucket.prod_backup_storage,
    null_resource.import_prod_nfs
  ]
}
