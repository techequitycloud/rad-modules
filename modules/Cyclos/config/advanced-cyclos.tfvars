resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "advanced"
deployment_region    = "us-central1"

application_module       = "cyclos"
application_display_name = "cyclos Advanced"

# Use prebuilt image
container_image_source = "prebuilt"
container_image        = "cyclos:4.16.15"
container_port         = 8069

# Resource Customization
container_resources = {
  cpu_limit    = "2000m"
  memory_limit = "4Gi"
  cpu_request  = "2000m"
}

# Scaling Configuration
min_instance_count = 0
max_instance_count = 3

# Database Configuration
database_type            = "POSTGRES_15"
database_password_length = 24
nfs_enabled              = true

# GCS Volume mapping for Cyclos config
gcs_volumes = [
  {
    name          = "cyclos-config"
    bucket_name   = ""
    mount_path    = "/mnt"
    read_only     = false
    mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
  }
]