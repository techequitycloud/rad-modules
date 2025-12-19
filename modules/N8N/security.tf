# Copyright (c) Tech Equity Ltd

#########################################################################
# Configure resources
#########################################################################

# Cloud Armor configuration
resource "google_compute_security_policy" "policy" {
  count = (var.configure_environment && var.configure_application_security && length(var.application_authorized_network) > 0 && length(var.application_secure_path) > 0) ? 1 : 0
  name    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
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
