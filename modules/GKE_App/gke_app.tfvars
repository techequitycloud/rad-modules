# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-168b107614c1@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-01-181c88e68891"

# Network
network_name = "vpc-network"

# Platform Services
create_cloud_storage = false

# Application Features
configure_backups = true
configure_monitoring = true
configure_continuous_integration = true
configure_continuous_deployment = true

# Application Configuration
application_name = "appname"
application_database_user = "dbuser"
application_database_name = "dbname"
application_database_type = "POSTGRES"
application_backup_fileid = ""
application_version = "1.0"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false
