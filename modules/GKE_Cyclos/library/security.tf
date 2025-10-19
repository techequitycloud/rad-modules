/**
 * Copyright 2024 Tech Equity Ltd
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
 
#########################################################################
# Configure Dev resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "dev_policy" {
  name    = "app${var.application_name}${local.random_id}dev-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

/**
resource "google_security_scanner_scan_config" "dev_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.application_name}-${local.random_id}dev-gke-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}dev.${google_compute_global_address.gke_dev.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on  = [
    time_sleep.wait_for_dev_ip,
    module.app_dev_deploy,
    local_file.dev_persistentvolume_yaml_output,
    google_monitoring_uptime_check_config.dev_https,
  ]
}

resource "time_sleep" "wait_for_dev_ip" {
  depends_on = [
    google_compute_global_address.gke_dev
  ]

  create_duration = "2m"
}
**/

# Cloud Armor configuration
/** resource "google_compute_security_policy" "dev_app_policy" {
  name    = "app${var.application_name}-${local.random_id}dev-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

resource "google_security_scanner_scan_config" "app_dev_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "app${var.application_name}-${local.random_id}dev-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}dev.${google_compute_global_address.gke_app_dev.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on  = [
    time_sleep.wait_for_app_dev_ip,
    module.app_dev_deploy,
    local_file.dev_persistentvolume_yaml_output,
  ]
}

resource "time_sleep" "wait_for_app_dev_ip" {
  depends_on = [
    google_compute_global_address.gke_app_dev
  ]

  create_duration = "2m"
}

**/

#########################################################################
# Configure QA resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "qa_policy" {
  name    = "app${var.application_name}${local.random_id}qa-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 900
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

/**
resource "google_security_scanner_scan_config" "qa_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.application_name}-${local.random_id}qa-gke-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}qa.${google_compute_global_address.gke_qa.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on  = [
    time_sleep.wait_for_qa_ip,
    local_file.qa_persistentvolume_yaml_output,
    google_monitoring_uptime_check_config.dev_https,
  ]
}

resource "time_sleep" "wait_for_qa_ip" {
  depends_on = [
    google_compute_global_address.gke_qa
  ]

  create_duration = "2m"
}
**/

/**
# Cloud Armor configuration
resource "google_compute_security_policy" "app_qa_policy" {
  name    = "app${var.application_name}-${local.random_id}qa-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 900
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

resource "google_security_scanner_scan_config" "app_qa_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "app${var.application_name}-${local.random_id}qa-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}qa.${google_compute_global_address.gke_app_qa.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on  = [
    time_sleep.wait_for_app_qa_ip,
    local_file.qa_persistentvolume_yaml_output,
    # module.app_qa_deploy
  ]
}

resource "time_sleep" "wait_for_app_qa_ip" {
  depends_on = [
    google_compute_global_address.gke_app_qa
  ]

  create_duration = "2m"
}
**/

#########################################################################
# Configure Prod resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "prod_policy" {
  name    = "app${var.application_name}${local.random_id}prod-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 900
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

/**
resource "google_security_scanner_scan_config" "prod_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.application_name}-${local.random_id}prod-gke-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}prod.${google_compute_global_address.gke_prod.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on = [
    time_sleep.wait_for_prod_ip,
    local_file.prod_persistentvolume_yaml_output,
    google_monitoring_uptime_check_config.dev_https,
  ]
}

resource "time_sleep" "wait_for_prod_ip" {
  depends_on = [
    google_compute_global_address.gke_prod
  ]

  create_duration = "2m"
}
**/

/**
# Cloud Armor configuration
resource "google_compute_security_policy" "app_prod_policy" {
  name    = "app${var.application_name}-${local.random_id}prod-gke"
  project = local.project.project_id
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.ip_blacklist
      }
    }
    description = "Deny access to list of IPs"
  }
  rule {
    action   = "deny(403)"
    priority = 900
    match {
      expr {
        expression = "request.path.matches(\"${var.path_blocked}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule"
  }

  depends_on  = [
    null_resource.init_git_repo,
  ]
}

resource "google_security_scanner_scan_config" "app_prod_scanner_config" {
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "app${var.application_name}-${local.random_id}prod-scan-config"
  starting_urls    = ["https://app${var.application_name}${local.random_id}prod.${google_compute_global_address.gke_app_prod.address}.sslip.io"]
  target_platforms = ["COMPUTE"]

  depends_on = [
    time_sleep.wait_for_app_prod_ip,
    local_file.prod_persistentvolume_yaml_output,
    # module.app_prod_deploy
  ]
}

resource "time_sleep" "wait_for_app_prod_ip" {
  depends_on = [
    google_compute_global_address.gke_app_prod
  ]

  create_duration = "2m"
}
**/