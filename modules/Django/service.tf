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

resource "google_cloud_run_v2_service" "dev_app_service" {
  count               = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  location            = var.region
  project             = local.project_id
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.cloud_run_sa_email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    labels = {
      app = var.application_name,
      env = "dev"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

      env {
        name = "GS_BUCKET_NAME"
        value = google_storage_bucket.dev_storage[0].name
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

      ports {
        container_port = 8080
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

  depends_on = [
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.dev_application_settings,
    google_project_iam_member.secret_accessor,
    google_project_iam_member.cloudsql_client,
  ]
}

resource "google_cloud_run_service_iam_binding" "dev" {
  count    = var.configure_development_environment && local.sql_server_exists && var.public_access ? 1 : 0
  location = var.region
  service  = google_cloud_run_v2_service.dev_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
  project = local.project_id
}

resource "null_resource" "dev_update_csrf_origin" {
  count = var.configure_development_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    service_id = google_cloud_run_v2_service.dev_app_service[0].id
  }

  provisioner "local-exec" {
    command = <<EOF
      URL=$(gcloud run services describe ${google_cloud_run_v2_service.dev_app_service[0].name} --region ${var.region} --project ${local.project_id} --format 'value(uri)')
      gcloud run services update ${google_cloud_run_v2_service.dev_app_service[0].name} \
        --region ${var.region} \
        --project ${local.project_id} \
        --set-env-vars CLOUDRUN_SERVICE_URLS=$URL
    EOF
  }
  depends_on = [google_cloud_run_v2_service.dev_app_service]
}


resource "google_cloud_run_v2_service" "qa_app_service" {
  count               = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
  location            = var.region
  project             = local.project_id
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.cloud_run_sa_email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    labels = {
      app = var.application_name,
      env = "qa"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

      env {
        name = "GS_BUCKET_NAME"
        value = google_storage_bucket.dev_storage[0].name
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

      ports {
        container_port = 8080
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

  depends_on = [
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.qa_application_settings,
    google_project_iam_member.secret_accessor,
    google_project_iam_member.cloudsql_client,
  ]
}

resource "google_cloud_run_service_iam_binding" "qa" {
  count    = var.configure_nonproduction_environment && local.sql_server_exists && var.public_access ? 1 : 0
  location = var.region
  service  = google_cloud_run_v2_service.qa_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
  project = local.project_id
}

resource "null_resource" "qa_update_csrf_origin" {
  count = var.configure_nonproduction_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    service_id = google_cloud_run_v2_service.qa_app_service[0].id
  }

  provisioner "local-exec" {
    command = <<EOF
      URL=$(gcloud run services describe ${google_cloud_run_v2_service.qa_app_service[0].name} --region ${var.region} --project ${local.project_id} --format 'value(uri)')
      gcloud run services update ${google_cloud_run_v2_service.qa_app_service[0].name} \
        --region ${var.region} \
        --project ${local.project_id} \
        --set-env-vars CLOUDRUN_SERVICE_URLS=$URL
    EOF
  }
  depends_on = [google_cloud_run_v2_service.qa_app_service]
}


resource "google_cloud_run_v2_service" "prod_app_service" {
  count               = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  name                = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
  location            = var.region
  project             = local.project_id
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = local.cloud_run_sa_email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    labels = {
      app = var.application_name,
      env = "prod"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${local.project_id}/${google_artifact_registry_repository.repo.name}/${var.application_name}:${var.application_version}"

      env {
        name = "GS_BUCKET_NAME"
        value = google_storage_bucket.dev_storage[0].name
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

      ports {
        container_port = 8080
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

  depends_on = [
    null_resource.build_and_push_application_image,
    google_secret_manager_secret_version.prod_application_settings,
    google_project_iam_member.secret_accessor,
    google_project_iam_member.cloudsql_client,
  ]
}

resource "google_cloud_run_service_iam_binding" "prod" {
  count    = var.configure_production_environment && local.sql_server_exists && var.public_access ? 1 : 0
  location = var.region
  service  = google_cloud_run_v2_service.prod_app_service[0].name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
  project = local.project_id
}

resource "null_resource" "prod_update_csrf_origin" {
  count = var.configure_production_environment && local.sql_server_exists ? 1 : 0
  triggers = {
    service_id = google_cloud_run_v2_service.prod_app_service[0].id
  }

  provisioner "local-exec" {
    command = <<EOF
      URL=$(gcloud run services describe ${google_cloud_run_v2_service.prod_app_service[0].name} --region ${var.region} --project ${local.project_id} --format 'value(uri)')
      gcloud run services update ${google_cloud_run_v2_service.prod_app_service[0].name} \
        --region ${var.region} \
        --project ${local.project_id} \
        --update-env-vars CLOUDRUN_SERVICE_URLS=$URL
    EOF
  }
  depends_on = [google_cloud_run_v2_service.prod_app_service]
}
