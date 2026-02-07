resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "advanced"
deployment_region    = "europe-west1"

application_module       = "odoo"
application_display_name = "Odoo Advanced"

# Use prebuilt image
container_image_source = "prebuilt"
container_image        = "odoo:16.0"
container_port         = 8069

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
enable_nfs              = true

# GCS Volume mapping for Odoo Custom Addons
gcs_volumes = [
  {
    name          = "odoo-addons"
    bucket_name   = ""
    mount_path    = "/mnt/extra-addons"
    read_only     = false
    mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
  }
]

# Environment Variables
environment_variables = {
  LOG_LEVEL = "debug"
  SMTP_HOST = "smtp.sendgrid.net"
  SMTP_PORT = "587"
  SMTP_USER = "apikey"
}

# Secret Environment Variables
secret_environment_variables = {
  SMTP_PASSWORD = "smtp-password-secret"
}
