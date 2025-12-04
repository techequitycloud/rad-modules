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

resource "google_cloud_run_v2_service" "default" {
  name                = "${var.application_name}-${local.random_id}"
  location            = var.region
  project             = local.project_id
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloudrun_sa.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

      env {
        name = "APPLICATION_SETTINGS"
        value_source {
          secret_key_ref {
            secret = google_secret_manager_secret.application_settings.secret_id
            version = "latest"
          }
        }
      }

      # We can also add individual env vars if we want to override or if setting.py supports them directly
      # The provided settings.py reads from APPLICATION_SETTINGS but also env("SECRET_KEY") etc.
      # django-environ will check os.environ first usually if configured that way, but the code does:
      # env.read_env(io.StringIO(os.environ.get("APPLICATION_SETTINGS", None)))
      # So it reads the block.

      ports {
        container_port = 8080
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

  depends_on = [
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.application_settings,
    google_project_iam_member.secret_accessor,
    google_project_iam_member.cloudsql_client,
  ]
}

resource "google_cloud_run_service_iam_binding" "default" {
  location = var.region
  service  = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
  project = local.project_id
}

# Update CSRF settings after deployment (as per tutorial)
# The tutorial says:
# CLOUDRUN_SERVICE_URLS=$(gcloud run services describe ...)
# gcloud run services update ... --update-env-vars "^##^CLOUDRUN_SERVICE_URLS=$CLOUDRUN_SERVICE_URLS"
# In Terraform, we know the URL. We can pass it as an environment variable directly in the resource configuration.
# However, the URL is only known after apply (or during apply).
# But google_cloud_run_v2_service exports `uri`.
# Terraform might complain about cycle if we try to inject the URI into the Env Var of the same service.
# But `uri` is computed.
# A common pattern is to redeploy or use a fixed deterministically generated URL (using run.googleapis.com/urls annotation if possible, but that's output).
# Cloud Run URLs are usually https://<service-name>-<hash>-<region>.run.app
# The hash depends on the project and service name.
# Actually, the tutorial updates the service *after* first deployment.
# In Terraform, we can try to avoid this circular dependency.
# Django 4.0 requires Trusted Origins.
# We can allow all hosts temporarily or use a wildcard?
# `ALLOWED_HOSTS = ["*"]` is set in settings.py if CLOUDRUN_SERVICE_URLS is not set.
# But CSRF_TRUSTED_ORIGINS is needed for admin login.
#
# Workaround: Use a null_resource to update the service after creation, or accept that we might need a second apply?
# Or use `CLOUDRUN_SERVICE_URLS` var.
# The URL is predictable? No, the hash part is random.
#
# Let's use the `post-deploy` null_resource approach to update the env var, similar to the tutorial.

resource "null_resource" "update_csrf_origin" {
  triggers = {
    service_id = google_cloud_run_v2_service.default.id
  }

  provisioner "local-exec" {
    command = <<EOF
      URL=$(gcloud run services describe ${google_cloud_run_v2_service.default.name} --region ${var.region} --project ${local.project_id} --format 'value(uri)')
      gcloud run services update ${google_cloud_run_v2_service.default.name} \
        --region ${var.region} \
        --project ${local.project_id} \
        --set-env-vars CLOUDRUN_SERVICE_URLS=$URL
    EOF
  }
  depends_on = [google_cloud_run_v2_service.default]
}
