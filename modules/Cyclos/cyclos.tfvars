# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-dca557108124@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-00-9c58e150e7c1"

# Network
network_name = "vpc-network"

# Application Features
configure_backups = true
configure_monitoring = false
configure_continuous_integration = false
configure_continuous_deployment = false

# Application Configuration
application_name = "cyclos"
application_database_user = "cyclos"
application_database_name = "cyclos"
application_backup_fileid = ""
application_version = "4.16.15"
application_download_fileid = ""
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false
