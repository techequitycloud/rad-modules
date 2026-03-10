resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "custom"
deployment_region    = "us-east1"

application_module     = "odoo"
container_image_source = "custom"

# Custom Container Build Configuration
container_build_config = {
  enabled            = true
  dockerfile_path    = "Dockerfile"
  context_path       = "custom-odoo"
  dockerfile_content = null
  build_args         = {
    ODOO_VERSION = "19.0"
  }
  artifact_repo_name = "odoo-repo"
}

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
