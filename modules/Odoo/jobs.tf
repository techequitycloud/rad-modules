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

# ============================================================================
# NFS Setup Job
# ============================================================================

resource "google_cloud_run_v2_job" "nfs_setup_job" {
  count      = local.nfs_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "nfs-setup-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DIR_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }

        command = ["/bin/sh"]
        args    = ["-c", file("${path.module}/scripts/app/nfs_setup_job.sh")]

        volume_mounts {
          name       = "nfs-root-volume"
          mount_path = "/mnt/nfs"
        }
      }

      volumes {
        name = "nfs-root-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share"
        }
      }

      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }
}

resource "null_resource" "execute_nfs_setup_job" {
  count = local.nfs_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.nfs_setup_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing NFS setup job..."

      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      # Execute the Cloud Run job
      gcloud run jobs execute ${google_cloud_run_v2_job.nfs_setup_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ NFS setup job completed successfully"
      else
        echo "✗ NFS setup job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.nfs_setup_job
  ]
}

# ============================================================================
# Import DB Job
# ============================================================================

resource "google_cloud_run_v2_job" "import_db_job" {
  count      = local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "import-db-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "alpine:3.19"

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }
        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }

        env {
          name = "ROOT_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-root-password"
              version = "latest"
            }
          }
        }

        env {
          name = "DB_PASS"
          value_source {
            secret_key_ref {
              secret = "${local.db_instance_name}-${var.application_database_name}-password-${var.tenant_deployment_id}-${local.random_id}"
              version = "latest"
            }
          }
        }

        command = ["/bin/sh"]
        args = ["-c", file("${path.module}/scripts/app/import_db_job.sh")]
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }
  
  depends_on = [
    data.google_secret_manager_secret_version.db_password,
  ]
}

resource "null_resource" "execute_import_db_job" {
  count = local.sql_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.import_db_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing DB import job..."

      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      gcloud run jobs execute ${google_cloud_run_v2_job.import_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB import/init job completed successfully"
      else
        echo "✗ DB import/init job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.import_db_job,
    google_secret_manager_secret_version.db_password
  ]
}

# ============================================================================
# Init Odoo DB Job (Installs base modules)
# ============================================================================

resource "google_cloud_run_v2_job" "init_db_job" {
  count      = local.sql_server_exists ? 1 : 0
  project    = local.project.project_id
  name       = "init-db-${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  location   = local.region
  deletion_protection = false

  template {
    template {
      service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
      max_retries     = 0
      timeout         = "600s"
      execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}-${var.tenant_deployment_id}-${local.random_id}/${var.application_name}:${var.application_version}"

        env {
          name  = "DB_HOST"
          value = "${local.db_internal_ip}"
        }
        env {
          name  = "DB_NAME"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
        env {
          name  = "DB_USER"
          value = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
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
        
        args = ["/entrypoint.sh", "odoo", "-i", "base", "--stop-after-init"]
        
        volume_mounts {
          name      = "nfs-data-volume"
          mount_path = "/mnt"
        }

        volume_mounts {
          name      = "gcs-data-volume"
          mount_path = "/extra-addons"
        }
      }

      volumes {
        name = "gcs-data-volume"
        gcs {
          bucket = "${local.data_bucket_name}"
        }
      }

      volumes {
        name = "nfs-data-volume"
        nfs {
          server = "${local.nfs_internal_ip}"
          path   = "/share/app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}"
        }
      }

      vpc_access {
        network_interfaces {
          network = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/gce-vpc-subnet-${local.region}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_iam_member.db_password,
    null_resource.execute_import_db_job, # Ensure DB is created first
    null_resource.execute_nfs_setup_job  # Ensure NFS is ready
  ]
}

resource "null_resource" "execute_init_db_job" {
  count = local.sql_server_exists ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.init_db_job[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      echo "Executing DB Initialization job..."

      # Set impersonation flag if service account is provided
      IMPERSONATE_FLAG=""
      if [ -n "${local.impersonation_service_account}" ]; then
        IMPERSONATE_FLAG="--impersonate-service-account=${local.impersonation_service_account}"
        echo "Using impersonation: ${local.impersonation_service_account}"
      fi

      gcloud run jobs execute ${google_cloud_run_v2_job.init_db_job[0].name} \
        --region ${local.region} \
        --project ${local.project.project_id} \
        $IMPERSONATE_FLAG \
        --wait

      if [ $? -eq 0 ]; then
        echo "✓ DB Initialization job completed successfully"
      else
        echo "✗ DB Initialization job failed"
        exit 1
      fi
    EOT
  }

  depends_on = [
    google_cloud_run_v2_job.init_db_job,
    null_resource.execute_import_db_job,
    null_resource.execute_nfs_setup_job
  ]
}
