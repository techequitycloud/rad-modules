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
configure_monitoring = false
configure_continuous_integration = false
configure_continuous_deployment = true

# Application Configuration
application_name = "cyclos"
application_database_user = "cyclos"
application_database_name = "cyclos"
application_backup_fileid = "1NWsxy_PHGKn9LJnXaQh5FFqp_WKjYEsJ"
application_version = "4.16.15"
application_download_fileid = "1-rHTal1upD8u57WuMieuKz51uVN1erBr"
application_git_installation_id = "38735316"
application_git_organization = "techequitycloud"
application_git_usernames = ["snavti"]

# environments
configure_development_environment = true
configure_nonproduction_environment = true
configure_production_environment = false
