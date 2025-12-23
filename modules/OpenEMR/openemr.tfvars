# Deployment
tenant_deployment_id = "demo"
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"
trusted_users = ["student-01-dca557108124@qwiklabs.net"]

# Project
existing_project_id = "qwiklabs-gcp-00-9c58e150e7c1"

# Network
network_name = "vpc-network"

# Application Features
configure_monitoring = true

# Application Configuration
application_name = "openerm"
application_database_user = "openerm"
application_database_name = "openerm"
application_version = "7.0.3"

# environments
configure_environment = true
