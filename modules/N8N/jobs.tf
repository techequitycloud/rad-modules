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
