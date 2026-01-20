output "service_name" {
  description = "Passed through from core module"
  value       = module.core.service_name
}

output "service_url" {
  description = "Passed through from core module"
  value       = module.core.service_url
}

output "service_location" {
  description = "Passed through from core module"
  value       = module.core.service_location
}

output "database_instance_name" {
  description = "Passed through from core module"
  value       = module.core.database_instance_name
}

output "database_name" {
  description = "Passed through from core module"
  value       = module.core.database_name
}

output "database_user" {
  description = "Passed through from core module"
  value       = module.core.database_user
}

output "database_password_secret" {
  description = "Passed through from core module"
  value       = module.core.database_password_secret
}

output "database_host" {
  description = "Passed through from core module"
  value       = module.core.database_host
}

output "database_port" {
  description = "Passed through from core module"
  value       = module.core.database_port
}

output "storage_buckets" {
  description = "Passed through from core module"
  value       = module.core.storage_buckets
}

output "network_name" {
  description = "Passed through from core module"
  value       = module.core.network_name
}

output "network_exists" {
  description = "Passed through from core module"
  value       = module.core.network_exists
}

output "regions" {
  description = "Passed through from core module"
  value       = module.core.regions
}

output "nfs_server_ip" {
  description = "Passed through from core module"
  value       = module.core.nfs_server_ip
}

output "nfs_mount_path" {
  description = "Passed through from core module"
  value       = module.core.nfs_mount_path
}

output "nfs_share_path" {
  description = "Passed through from core module"
  value       = module.core.nfs_share_path
}

output "container_image" {
  description = "Passed through from core module"
  value       = module.core.container_image
}

output "container_registry" {
  description = "Passed through from core module"
  value       = module.core.container_registry
}

output "monitoring_enabled" {
  description = "Passed through from core module"
  value       = module.core.monitoring_enabled
}

output "monitoring_notification_channels" {
  description = "Passed through from core module"
  value       = module.core.monitoring_notification_channels
}

output "uptime_check_names" {
  description = "Passed through from core module"
  value       = module.core.uptime_check_names
}

output "deployment_id" {
  description = "Passed through from core module"
  value       = module.core.deployment_id
}

output "tenant_id" {
  description = "Passed through from core module"
  value       = module.core.tenant_id
}

output "resource_prefix" {
  description = "Passed through from core module"
  value       = module.core.resource_prefix
}

output "project_id" {
  description = "Passed through from core module"
  value       = module.core.project_id
}

output "project_number" {
  description = "Passed through from core module"
  value       = module.core.project_number
}

output "initialization_jobs" {
  description = "Passed through from core module"
  value       = module.core.initialization_jobs
}

output "nfs_setup_job" {
  description = "Passed through from core module"
  value       = module.core.nfs_setup_job
}

output "deployment_summary" {
  description = "Passed through from core module"
  value       = module.core.deployment_summary
}

output "cicd_enabled" {
  description = "Passed through from core module"
  value       = module.core.cicd_enabled
}

output "github_repository_url" {
  description = "Passed through from core module"
  value       = module.core.github_repository_url
}

output "github_repository_owner" {
  description = "Passed through from core module"
  value       = module.core.github_repository_owner
}

output "github_repository_name" {
  description = "Passed through from core module"
  value       = module.core.github_repository_name
}

output "artifact_registry_repository" {
  description = "Passed through from core module"
  value       = module.core.artifact_registry_repository
}

output "cloudbuild_trigger_name" {
  description = "Passed through from core module"
  value       = module.core.cloudbuild_trigger_name
}

output "cloudbuild_trigger_id" {
  description = "Passed through from core module"
  value       = module.core.cloudbuild_trigger_id
}

output "cicd_configuration" {
  description = "Passed through from core module"
  value       = module.core.cicd_configuration
}
