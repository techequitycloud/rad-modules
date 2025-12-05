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
  for_each            = var.configure_development_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  location            = each.key
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "dev"
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 80
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 30
        period_seconds        = 60
        failure_threshold     = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 5
        period_seconds        = 60
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 80
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "dev" {
  for_each = var.configure_development_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.dev_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.dev_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.dev_app_service
  ]
}

resource "google_cloud_run_v2_service" "qa_app_service" {
  for_each            = var.configure_nonproduction_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  location            = "${each.key}"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "qa"
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 80
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 30
        period_seconds        = 60
        failure_threshold     = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 5
        period_seconds        = 60
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 80
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    google_cloud_run_v2_service.dev_app_service,
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "qa" {
  for_each = var.configure_nonproduction_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.qa_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.qa_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.qa_app_service
  ]
}

resource "google_cloud_run_v2_service" "prod_app_service" {
  for_each            = var.configure_production_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])
  project             = local.project.project_id
  name                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  location            = "${each.key}"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
    session_affinity = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout = "300s"

    labels = {
      app = var.application_name,
      env = "prod"
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 80
      }

      resources {
        startup_cpu_boost = true
        cpu_idle = true
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }

      startup_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 30
        period_seconds        = 60
        failure_threshold     = 1
        tcp_socket {
          port = 80
        }
      }

      liveness_probe {
        initial_delay_seconds = 60
        timeout_seconds       = 5
        period_seconds        = 60
        failure_threshold     = 3
        http_get {
          path = "/"
          port = 80
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  traffic {
    type   = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    tag    = "latest"
    percent = 100
  }

  depends_on = [
    google_cloud_run_v2_service.qa_app_service,
    null_resource.build_and_push_application_image,
  ]
}

resource "google_cloud_run_service_iam_binding" "prod" {
  for_each = var.configure_production_environment ? (length(local.regions) >= 2 ? toset(local.regions) : toset([local.regions[0]])) : toset([])

  project  = local.project.project_id  
  location = google_cloud_run_v2_service.prod_app_service[each.key].location  # Access location using each.key
  service  = google_cloud_run_v2_service.prod_app_service[each.key].name      # Access service name using each.key
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]

  depends_on = [
    google_cloud_run_v2_service.prod_app_service
  ]
}