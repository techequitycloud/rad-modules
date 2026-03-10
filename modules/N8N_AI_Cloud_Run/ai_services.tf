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

#########################################################################
# Qdrant Vector Database Service
#########################################################################

resource "google_cloud_run_v2_service" "qdrant_service" {
  count               = local.configure_environment && var.enable_ai_components && var.enable_qdrant ? 1 : 0
  project             = local.project.project_id
  name                = "qdrant-${local.application_name}${local.tenant_id}${local.random_id}"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account       = local.cloud_run_sa_email
    session_affinity      = true
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = merge(
      local.common_labels,
      {
        app = local.application_name,
        env = "qdrant"
      }
    )

    containers {
      image   = "qdrant/qdrant:${var.qdrant_version}"

      ports {
        container_port = 6333
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
        cpu_idle = true # Can be throttled
      }

      # Startup probe
      startup_probe {
        http_get {
          path = "/readyz"
          port = 6333
        }
        initial_delay_seconds = 15
        period_seconds        = 10
        failure_threshold     = 10
      }

      # Storage Configuration
      # Qdrant stores data in /qdrant/storage
      # We mount GCS bucket to /mnt/gcs and configure Qdrant to use subdirectory
      env {
        name  = "QDRANT__STORAGE__STORAGE_PATH"
        value = "/mnt/gcs/qdrant"
      }

      volume_mounts {
        name       = "gcs-data"
        mount_path = "/mnt/gcs"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "gcs-data"
      gcs {
        bucket    = google_storage_bucket.buckets["n8n-data"].name
        read_only = false
        mount_options = [
          "implicit-dirs",
          "metadata-cache-ttl-secs=60",
          "uid=1000",
          "gid=1000"
        ]
      }
    }
  }

  depends_on = [
    google_storage_bucket.buckets,
    google_storage_bucket_iam_member.n8n_cloudrun_access
  ]
}

resource "google_cloud_run_v2_service_iam_binding" "qdrant_service" {
  count = local.configure_environment && var.enable_ai_components && var.enable_qdrant ? 1 : 0

  project  = local.project.project_id
  location = local.region
  name     = google_cloud_run_v2_service.qdrant_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

#########################################################################
# Ollama LLM Service
#########################################################################

resource "google_cloud_run_v2_service" "ollama_service" {
  count               = local.configure_environment && var.enable_ai_components && var.enable_ollama ? 1 : 0
  project             = local.project.project_id
  name                = "ollama-${local.application_name}${local.tenant_id}${local.random_id}"
  location            = local.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account       = local.cloud_run_sa_email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    timeout               = "300s"

    labels = merge(
      local.common_labels,
      {
        app = local.application_name,
        env = "ollama"
      }
    )

    containers {
      image   = "ollama/ollama:${var.ollama_version}"

      ports {
        container_port = 11434
      }

      resources {
        cpu_idle = false # Ollama needs CPU for inference
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }

      # Startup probe
      startup_probe {
        http_get {
          path = "/"
          port = 11434
        }
        initial_delay_seconds = 20
        period_seconds        = 10
        failure_threshold     = 10
      }

      # Storage Configuration
      # Ollama stores models in /root/.ollama
      env {
        name  = "OLLAMA_MODELS"
        value = "/mnt/gcs/ollama/models"
      }

      # Since we are running in a container, HOME is usually /root
      # But we want to persist models.

      volume_mounts {
        name       = "gcs-data"
        mount_path = "/mnt/gcs"
      }
    }

    vpc_access {
      network_interfaces {
        network    = "projects/${local.project.project_id}/global/networks/${local.network_name}"
        subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${local.subnet_map[local.region]}"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    volumes {
      name = "gcs-data"
      gcs {
        bucket    = google_storage_bucket.buckets["n8n-data"].name
        read_only = false
        mount_options = [
          "implicit-dirs",
          "metadata-cache-ttl-secs=60",
          "uid=1000",
          "gid=1000"
        ]
      }
    }
  }

  depends_on = [
    google_storage_bucket.buckets,
    google_storage_bucket_iam_member.n8n_cloudrun_access
  ]
}

resource "google_cloud_run_v2_service_iam_binding" "ollama_service" {
  count = local.configure_environment && var.enable_ai_components && var.enable_ollama ? 1 : 0

  project  = local.project.project_id
  location = local.region
  name     = google_cloud_run_v2_service.ollama_service[0].name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}
