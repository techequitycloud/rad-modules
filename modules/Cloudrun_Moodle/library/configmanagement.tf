/**
 * Copyright 2025 Tech Equity Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "time_sleep" "allow_10_minutes_for_config_management_api_activation" {
  count       = (var.create_google_kubernetes_engine && var.configure_config_management) ? 1 : 0

  depends_on = [
    google_project_service.enabled_services,
  ]

  create_duration = "10m"
}

resource "google_gke_hub_feature" "config_management_feature" {
  count       = (var.create_google_kubernetes_engine && var.configure_config_management) ? 1 : 0
  project     = local.project.project_id
  name        = "configmanagement"
  location    = "global"

  depends_on = [
    time_sleep.allow_10_minutes_for_config_management_api_activation
  ]
}

resource "google_gke_hub_feature_membership" "gke_cluster_config_management_feature_member" {
  count       = (var.create_google_kubernetes_engine && var.configure_config_management) ? 1 : 0
  project     = local.project.project_id
  location    = "global"
  feature     = google_gke_hub_feature.config_management_feature[count.index].name
  membership  = google_gke_hub_membership.gke_cluster[count.index].membership_id 

  configmanagement {
    version = "1.20.0"
    config_sync {
      enabled = true
      source_format = "unstructured"
      git {
        sync_repo   = "https://github.com/GoogleCloudPlatform/anthos-config-management-samples"
        policy_dir  = "config-sync-quickstart/multirepo/root"
        sync_branch = "main"
        secret_type = "none" 
        sync_rev    = "HEAD"
      }
    }
  }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_project_iam_binding.config_management_trace_agent,
    google_project_iam_binding.config_management_metric_writer,
  ]
}

resource "google_gke_hub_feature" "policy_controller_feature" {
  count   = (var.create_google_kubernetes_engine && var.configure_policy_controller) ? 1 : 0
  project     = local.project.project_id
  name        = "policycontroller"
  location    = "global"

  depends_on = [
    google_project_service.enabled_services,
  ]
}

resource "google_gke_hub_feature_membership" "gke_cluster_policy_controller_feature_member" {
  count       = (var.create_google_kubernetes_engine && var.configure_policy_controller) ? 1 : 0
  project     = local.project.project_id
  location    = "global"
  feature     = google_gke_hub_feature.policy_controller_feature[count.index].name
  membership  = google_gke_hub_membership.gke_cluster[count.index].membership_id 

    policycontroller {
        policy_controller_hub_config {
            install_spec = "INSTALL_SPEC_ENABLED"
        }
    }

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
    google_project_iam_binding.config_management_trace_agent,
    google_project_iam_binding.config_management_metric_writer,
  ]
}

# Allow Services Accounts to create trace
resource "google_project_iam_binding" "config_management_trace_agent" {
  count   = (var.create_google_kubernetes_engine && var.configure_config_management) ? 1 : 0
  project = local.project.project_id

  role = "roles/cloudtrace.agent"
  members = [
    "serviceAccount:${local.project.project_id}.svc.id.goog[config-management-monitoring/default]",
    "serviceAccount:${local.project.project_id}.svc.id.goog[gatekeeper-system/gatekeeper-admin]",
  ]

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]
}

# Allow Services Accounts to send metrics
resource "google_project_iam_binding" "config_management_metric_writer" {
  count   = (var.create_google_kubernetes_engine && var.configure_config_management) ? 1 : 0
  project = local.project.project_id

  role = "roles/monitoring.metricWriter"
  members = [
    "serviceAccount:${local.project.project_id}.svc.id.goog[config-management-monitoring/default]",
    "serviceAccount:${local.project.project_id}.svc.id.goog[gatekeeper-system/gatekeeper-admin]",
  ]

  depends_on = [
    google_container_cluster.gke_autopilot_cluster,
  ]
}
