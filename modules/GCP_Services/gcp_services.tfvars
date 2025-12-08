# Deployment
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"

# Project
existing_project_id = "qwiklabs-gcp-00-a40917b3f9e5"

# Network
network_name = "vpc-network"
availability_regions = ["us-central1"]

# Platform Features
create_network_filesystem = true
create_mysql = false
create_postgres = true

# GKE
create_google_kubernetes_engine = false
configure_config_management = false
configure_policy_controller = false
configure_cloud_service_mesh = false
configure_security_posture_service = false
