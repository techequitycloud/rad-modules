resource_creator_identity = ""
existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "custom"
deployment_region    = "us-central1"

application_module     = "cyclos"
container_image_source = "custom"

# Custom Container Build Configuration
container_build_config = {
  enabled            = true
  dockerfile_path    = "Dockerfile"
  context_path       = "custom-cyclos"
  dockerfile_content = null
  build_args         = {
    cyclos_VERSION = "4.16.15"
  }
  artifact_repo_name = "cyclos-repo"
}

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