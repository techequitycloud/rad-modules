# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

output "deployment_info" {
  description = "Deployment information"
  value = {
    deployment_id = module.wordpress_app.deployment_id
    region        = module.wordpress_app.deployment_summary.deployment_region
    project_id    = module.wordpress_app.project_id
  }
}

output "cloud_sql_info" {
  description = "Cloud SQL information"
  value = {
    cloudsql_instance_ip = module.wordpress_app.database_host
    cloud_sql_studio     = module.wordpress_app.database_instance_name != null ? "https://console.cloud.google.com/sql/instances/${module.wordpress_app.database_instance_name}/studio?project=${module.wordpress_app.project_id}&supportedpurview=project,organizationId,folder" : ""
    database_name        = module.wordpress_app.database_name
    database_user        = module.wordpress_app.database_user
  }
}

output "private_storage_info" {
  description = "Private storage information"
  value = {
    # Assuming the first bucket is the data bucket if any exist
    gcs_private_data_bucket = length(keys(module.wordpress_app.storage_buckets)) > 0 ? values(module.wordpress_app.storage_buckets)[0].name : ""
  }
}

output "application_info" {
  description = "Application information"
  value = {
    application_url      = module.wordpress_app.service_url
    cloud_secret_manager = "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${module.wordpress_app.project_id}&supportedpurview=organizationId"
  }
}

output "service_info" {
  description = "Service information"
  value = {
    # Constructing console URL similar to original
    service_url          = module.wordpress_app.service_name != null ? "https://console.cloud.google.com/run/detail/${module.wordpress_app.service_location}/${module.wordpress_app.service_name}/metrics?orgonly=true&project=${module.wordpress_app.project_id}&supportedpurview=organizationId" : ""
    cloud_secret_manager = "https://console.cloud.google.com/security/secret-manager?inv=1&invt=AbioWw&orgonly=true&project=${module.wordpress_app.project_id}&supportedpurview=organizationId"
  }
}

output "network_info" {
  description = "Network information"
  value = {
    network_exists = module.wordpress_app.network_exists
    network_name   = module.wordpress_app.network_name
    regions        = module.wordpress_app.regions
  }
}

# Forwarding new useful outputs from WebApp
output "deployment_summary" {
  description = "Summary of the deployment"
  value       = module.wordpress_app.deployment_summary
}
