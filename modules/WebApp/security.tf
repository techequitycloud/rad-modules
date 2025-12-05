# Copyright (c) Tech Equity Ltd

#########################################################################
# Configure Dev resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "dev_policy" {
  count = (var.configure_development_environment && var.configure_application_security && length(var.application_authorized_network) > 0 && length(var.application_secure_path) > 0) ? 1 : 0
  name    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
  project = local.project.project_id

  # Rule to allow access from authorized IP ranges
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.application_authorized_network
      }
    }
    description = "Allow access from authorized IP ranges"
  }

  # Rule to deny access to specific URL paths
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      expr {
        expression = "request.path.matches(\"${var.application_secure_path}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }

  # Default rule to deny all other traffic
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Deny access to all other IPs"
  }
}

/**
resource "google_security_scanner_scan_config" "dev_scanner_config" {
  count            = (var.configure_development_environment && var.configure_application_security && var.configure_high_availability) ? 1 : 0
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.tenant_deployment_id}-${var.application_name}dev-cr-scan-config"
  starting_urls    = ["https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[0].address}.nip.io"]
  target_platforms = ["COMPUTE"]

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    google_compute_global_address.dev,
    time_sleep.wait_for_dev_ip,
    google_monitoring_uptime_check_config.dev_https,
  ]
}

resource "time_sleep" "wait_for_dev_ip" {
  count = var.configure_development_environment ? 1 : 0

  depends_on = [
    google_compute_global_address.dev
  ]

  create_duration = "2m"
}
**/

#########################################################################
# Configure QA resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "qa_policy" {
  count = (var.configure_nonproduction_environment && var.configure_application_security && length(var.application_authorized_network) > 0 && length(var.application_secure_path) > 0) ? 1 : 0
  name    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
  project = local.project.project_id

  # Rule to allow access from authorized IP ranges
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.application_authorized_network
      }
    }
    description = "Allow access from authorized IP ranges"
  }

  # Rule to deny access to specific URL paths
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      expr {
        expression = "request.path.matches(\"${var.application_secure_path}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }

  # Default rule to deny all other traffic
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Deny access to all other IPs"
  }
}

/**
resource "google_security_scanner_scan_config" "qa_scanner_config" {
  count            = (var.configure_nonproduction_environment && var.configure_application_security && var.configure_high_availability) ? 1 : 0
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.tenant_deployment_id}-${var.application_name}qa-cr-scan-config"
  starting_urls    = ["https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[0].address}.nip.io"]
  target_platforms = ["COMPUTE"]

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    google_compute_global_address.qa,
    time_sleep.wait_for_qa_ip,
    google_monitoring_uptime_check_config.dev_https,
    // google_project_iam_member.web_security_scanner_iap_accessor
  ]
}

resource "time_sleep" "wait_for_qa_ip" {
  count = var.configure_nonproduction_environment ? 1 : 0

  depends_on = [
    google_compute_global_address.qa
  ]

  create_duration = "2m"
}
**/

#########################################################################
# Configure Prod resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "prod_policy" {
  count = (var.configure_production_environment && var.configure_application_security && length(var.application_authorized_network) > 0 && length(var.application_secure_path) > 0) ? 1 : 0
  name    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
  project = local.project.project_id

  # Rule to allow access from authorized IP ranges
  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.application_authorized_network
      }
    }
    description = "Allow access from authorized IP ranges"
  }

  # Rule to deny access to specific URL paths
  rule {
    action   = "deny(403)"
    priority = 1100
    match {
      expr {
        expression = "request.path.matches(\"${var.application_secure_path}\")"
      }
    }
    description = "Deny access to specific URL paths"
  }

  # Default rule to deny all other traffic
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Deny access to all other IPs"
  }
}

/**
resource "google_security_scanner_scan_config" "prod_scanner_config" {
  count            = (var.configure_production_environment && var.configure_application_security && var.configure_high_availability) ? 1 : 0
  project          = local.project.project_id
  provider         = google-beta
  display_name     = "${var.tenant_deployment_id}-${var.application_name}prod-cr-scan-config"
  starting_urls    = ["https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[0].address}.nip.io"]
  target_platforms = ["COMPUTE"]

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    google_compute_global_address.prod,
    time_sleep.wait_for_prod_ip,
    google_monitoring_uptime_check_config.dev_https,
  ]
}

resource "time_sleep" "wait_for_prod_ip" {
  count = var.configure_production_environment ? 1 : 0

  depends_on = [
    google_compute_global_address.prod
  ]

  create_duration = "2m"
}
**/