# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-168b107614c1@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-01-181c88e68891"

# Network
network_name = "vpc-network"

# Application Features
configure_backups = true
configure_monitoring = true
configure_continuous_integration = true
configure_continuous_deployment = true

# Application Configuration
application_name = "moodle"
application_database_user = "moodle"
application_database_name = "moodle"
application_backup_fileid = "1qvhNXanv6KVWkY2pGyaY1KDSDbq-vRXV"
application_version = "5.0.0"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = false
configure_production_environment = false

