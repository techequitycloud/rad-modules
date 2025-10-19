
#########################################################################
# Debug Outputs for GKE
#########################################################################

/**
output "debug_gke_exists" {
  value       = local.gke_exists
  description = "Debug: Does GKE cluster already exist?"
}

output "debug_create_new_gke" {
  value       = local.create_new_gke
  description = "Debug: Should we create a new GKE cluster?"
}

output "debug_gke_cluster_info" {
  value       = var.create_google_kubernetes_engine ? try(data.external.gke_cluster_info[0].result, {}) : {}
  description = "Debug: Raw GKE cluster info from external data source"
}

output "debug_gke_cluster_name" {
  value       = local.gke_cluster_name
  description = "Debug: GKE cluster name (if exists)"
}

output "debug_gke_subnet_exists" {
  value       = local.gke_subnet_exists
  description = "Debug: Does the GKE subnet exist?"
}

output "debug_cluster_endpoint" {
  value       = local.cluster_endpoint
  description = "Debug: GKE cluster endpoint"
}

output "debug_has_valid_cluster" {
  value       = local.has_valid_cluster
  description = "Debug: Do we have valid cluster credentials?"
}

output "debug_gke_subnet_id" {
  value       = try(local.gke_subnet_id, "Not available")
  description = "Debug: GKE subnet ID structure"
}

output "debug_gke_secondary_ranges" {
  value       = try(local.gke_subnet_id[local.region].secondary_ip_range, "Not available")
  description = "Debug: GKE subnet secondary IP ranges"
  sensitive   = false
}

output "debug_k8s_credentials_cmd" {
  value       = local.k8s_credentials_cmd
  description = "Debug: Command to get GKE credentials"
}

#########################################################################
# Debug Outputs for Networking
#########################################################################

# Output validation errors if any
output "validation_errors" {
  value = local.validation_errors
}


# Enhanced debug outputs
output "firewall_configuration_summary" {
  description = "Summary of firewall configuration"
  value = {
    total_rules_count    = length(local.custom_rules)
    nfs_rules_enabled   = var.enable_nfs_rules
    http_rules_enabled  = var.enable_http_rules
    regions_configured  = length(var.availability_regions)
    gce_subnets_count   = length(local.gce_subnet_cidrs)
    gke_subnets_count   = length(local.gke_subnet_cidrs)
  }
}

output "gce_subnet_cidrs" {
  description = "GCE subnet CIDR ranges mapped to regions"
  value = zipmap(var.availability_regions, local.gce_subnet_cidrs)
}

output "gke_subnet_cidrs" {
  description = "GKE subnet CIDR ranges mapped to regions"
  value = zipmap(var.availability_regions, local.gke_subnet_cidrs)
}

output "all_internal_cidrs" {
  description = "All internal CIDR ranges (GCE + GKE)"
  value = local.all_internal_cidrs
}

output "firewall_rules_created" {
  description = "Names of firewall rules that will be created"
  value = [for rule in local.custom_rules : rule.name]
}

# Optional: Output for debugging CIDR calculations
output "cidr_mapping_debug" {
  description = "Debug information for CIDR mapping"
  value = {
    availability_regions_count     = length(var.availability_regions)
    gce_subnet_cidr_range_count   = length(var.gce_subnet_cidr_range)
    gke_subnet_cidr_range_count   = length(var.gke_subnet_cidr_range)
    regions                       = var.availability_regions
    gce_cidrs_original           = var.gce_subnet_cidr_range
    gke_cidrs_original           = var.gke_subnet_cidr_range
    gce_cidrs_mapped             = local.gce_subnet_cidrs
    gke_cidrs_mapped             = local.gke_subnet_cidrs
  }
}


#########################################################################
# SQL Debug outputs
#########################################################################

output "debug_create_cloud_sql" {
  value = "var.create_cloud_sql = ${var.create_cloud_sql}"
  description = "Debug: Whether Cloud SQL creation is enabled"
}

output "debug_project_id" {
  value = "Project ID: ${local.project.project_id}"
  description = "Debug: Project ID being used"
}

output "debug_region" {
  value = "Region: ${local.region}"
  description = "Debug: Region being used"
}

output "debug_resource_creator" {
  value = "Resource Creator: ${var.resource_creator_identity}"
  description = "Debug: Resource creator identity"
}

output "debug_external_script_path" {
  value = "${path.module}/scripts/app/get-sqlserver-info.sh"
  description = "Debug: Path to the external script"
}

output "debug_external_script_result" {
  value = var.create_cloud_sql ? jsonencode(try(data.external.sql_instance_info[0].result, {})) : "External script not run (create_cloud_sql = false)"
  description = "Debug: Result from external script"
  sensitive = true
}

output "debug_existing_instance_name" {
  value = "Existing instance name: ${local.existing_instance_name != "" ? local.existing_instance_name : "None found"}"
  description = "Debug: Name of existing SQL instance if found"
}

output "debug_create_new_sql" {
  value = "Using existing instance: ${local.create_new_sql}"
  description = "Debug: Whether using existing instance"
}

output "debug_db_instance_name" {
  value = "Final DB instance name: ${local.db_instance_name != null ? local.db_instance_name : "None determined yet"}"
  description = "Debug: Final DB instance name being used"
}

output "debug_db_internal_ip" {
  value = "DB internal IP: ${local.db_internal_ip != null ? local.db_internal_ip : "None determined yet"}"
  description = "Debug: Internal IP of the database"
}

output "debug_password_source" {
  value = var.create_cloud_sql ? (
    local.create_new_sql ? 
      "Using existing instance password" : 
      (length(google_secret_manager_secret_version.root_password) > 0 ? 
        "Using password from Secret Manager" : 
        "Using generated random password"
      )
  ) : "No password needed (create_cloud_sql = false)"
  description = "Debug: Source of the database password"
}

output "debug_existing_instance_lookup" {
  value = var.create_cloud_sql && local.create_new_sql ? "Looking up existing instance: ${local.existing_instance_name}" : "Not looking up existing instance"
  description = "Debug: Whether looking up existing instance details"
}

output "debug_existing_instance_details" {
  value = var.create_cloud_sql && local.create_new_sql && length(data.google_sql_database_instance.existing_instance) > 0 ? "Found existing instance details" : "No existing instance details"
  description = "Debug: Whether existing instance details were found"
}

output "debug_creating_new_instance" {
  value = var.create_cloud_sql && !local.create_new_sql ? "Creating new SQL instance: cloud-sql-postgres-${local.random_id}" : "Not creating new SQL instance"
  description = "Debug: Whether creating a new SQL instance"
}

output "debug_network_info" {
  value = "Private network: projects/${var.existing_project_id}/global/networks/${var.network_name}"
  description = "Debug: Network information for SQL instance"
}

output "debug_secret_creation" {
  value = var.create_cloud_sql && !local.create_new_sql ? "Creating secret in Secret Manager" : "Not creating secret"
  description = "Debug: Whether creating a secret in Secret Manager"
}

output "debug_secret_id" {
  value = var.create_cloud_sql && !local.create_new_sql && length(google_secret_manager_secret.root_password) > 0 ? "Secret ID: ${google_secret_manager_secret.root_password[0].secret_id}" : "No secret created"
  description = "Debug: Secret ID being created"
}

output "debug_secret_version_access" {
  value = var.create_cloud_sql && !local.create_new_sql ? "Accessing latest version of secret" : "Not accessing secret"
  description = "Debug: Whether accessing the latest version of the secret"
}

output "debug_time_sleep" {
  value = "Waiting 90 seconds after creating secret version"
  description = "Debug: Time sleep after creating secret version"
}

*/