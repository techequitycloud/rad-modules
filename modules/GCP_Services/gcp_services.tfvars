# Deployment
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"

# Project
existing_project_id  = "qwiklabs-gcp-02-30b30b50c2a4"

# Network
network_name = "vpc-network"
availability_regions = ["us-east1"]

# Platform Features
create_network_filesystem = true
create_mysql = true
create_postgres = true
