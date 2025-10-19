# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"

# Project
existing_project_id = "qwiklabs-gcp-01-661f19cef479"

# Application Features
configure_monitoring = true
configure_continuous_integration = true
configure_continuous_deployment = true

# Application Configuration
application_name = "appname"
application_version = "1.0"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]
application_git_token=""

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false
