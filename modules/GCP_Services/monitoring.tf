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
# Cloud SQL Monitoring
#########################################################################

resource "google_monitoring_alert_policy" "cloud_sql_cpu_high" {
  count        = (var.create_postgres || var.create_mysql) ? 1 : 0
  display_name = "Cloud SQL - High CPU Usage"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "Cloud SQL CPU > ${var.alert_cpu_threshold}%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_cpu_threshold / 100.0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_memory_high" {
  count        = (var.create_postgres || var.create_mysql) ? 1 : 0
  display_name = "Cloud SQL - High Memory Usage"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "Cloud SQL Memory > ${var.alert_memory_threshold}%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/memory/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_memory_threshold / 100.0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_disk_high" {
  count        = (var.create_postgres || var.create_mysql) ? 1 : 0
  display_name = "Cloud SQL - High Disk Usage"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "Cloud SQL Disk > ${var.alert_disk_threshold}%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_disk_threshold / 100.0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

#########################################################################
# NFS Server Monitoring (Custom GCE)
#########################################################################

resource "google_monitoring_alert_policy" "nfs_server_cpu_high" {
  count        = var.create_network_filesystem ? 1 : 0
  display_name = "NFS Server - High CPU Usage"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "NFS Server CPU > ${var.alert_cpu_threshold}%"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\" AND metadata.user_labels.nfsserver = \"true\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_cpu_threshold / 100.0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "nfs_server_memory_high" {
  count        = var.create_network_filesystem ? 1 : 0
  display_name = "NFS Server - High Memory Usage"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "NFS Server Memory > ${var.alert_memory_threshold}%"

    condition_threshold {
      # Requires Ops Agent installed on the NFS GCE instance.
      # Unlike Cloud SQL utilization metrics (0.0-1.0), the Ops Agent
      # percent_used metric reports values as 0-100, so no division needed.
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/memory/percent_used\" AND metadata.user_labels.nfsserver = \"true\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.alert_memory_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "1800s"
  }
}

resource "google_monitoring_alert_policy" "nfs_server_health_check_failed" {
  count        = var.create_network_filesystem ? 1 : 0
  display_name = "NFS Server - Instance Down or Unhealthy"
  combiner     = "OR"
  enabled      = true
  project      = local.project.project_id
  user_labels  = var.resource_labels

  conditions {
    display_name = "NFS Server CPU metrics absent (instance down)"

    condition_absent {
      # If CPU metrics are absent, the instance is down or unreachable
      filter   = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\" AND metadata.user_labels.nfsserver = \"true\""
      duration = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_COUNT"
      }
    }
  }

  notification_channels = var.notification_channels
  alert_strategy {
    auto_close = "3600s"
  }
}
