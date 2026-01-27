existing_project_id  = "qwiklabs-gcp-03-5421a1d20b10"
tenant_deployment_id = "custom-odoo"
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
    ODOO_VERSION = "17.0"
  }
  artifact_repo_name = "odoo-repo"
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
