resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "advanced"
deployment_region    = "us-central1"

application_module       = "sample"
application_display_name = "sample Advanced"

# Use prebuilt image
container_image_source = "prebuilt"
container_image        = "sample:1.0"
container_port         = 8080

# Resource Customization
container_resources = {
  cpu_limit    = "4000m"
  memory_limit = "8Gi"
  cpu_request  = "2000m"
}

# Scaling Configuration
min_instance_count = 1
max_instance_count = 5

# Database Configuration
database_type            = "POSTGRES_15"
database_password_length = 24
nfs_enabled              = true
