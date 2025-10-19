# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-a5748c41564f@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-02-a9fda8b68298"

# Network
network_name = "vpc-network"

# Application Features
configure_backups = true
configure_monitoring = true
configure_continuous_integration = true
configure_continuous_deployment = true

# Application Configuration
application_name = "odoo"
application_database_user = "odoo"
application_database_name = "odoo"
application_backup_fileid = "1jolaJFFU8-qMUgI8XOfGNBHDLFYrJQQT"
application_version = "18.0"
application_release = "20250807"
application_sha = "109d077dd280292aa92daf18777cb772e644f972"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false


