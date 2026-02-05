resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "advanced"
deployment_region    = "us-central1"

application_module       = "medusa"
application_display_name = "medusa Advanced"

# Use prebuilt image
container_image_source = "prebuilt"
container_image        = "medusajs/medusa"
container_port         = 9000

# Resource Customization
container_resources = {
  cpu_limit    = "4000m"
  memory_limit = "8Gi"
  cpu_request  = "2000m"
}

# Scaling Configuration
min_instance_count = 0
max_instance_count = 5

# Database Configuration
database_type            = "POSTGRES_15"
database_password_length = 24
nfs_enabled              = true
