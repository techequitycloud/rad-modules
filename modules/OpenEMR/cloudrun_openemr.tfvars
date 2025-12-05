# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-3c4ea1e15062@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-02-ed4cde04b063"

# Network
network_name = "vpc-network"

# Application Features
configure_backups = true
configure_monitoring = true
configure_continuous_integration = true
configure_continuous_deployment = true

# Application Configuration
application_name = "openerm"
application_database_user = "openerm"
application_database_name = "openerm"
application_backup_fileid = "1nitol1S9hdcjf7PpHvsRl3ZDwhKYlzF2"
application_version = "7.0.3"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false

