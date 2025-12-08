# Deployment
resource_creator_identity = "" # "REPLACE_WITH_TERRAFORM_SERVICE_ACCOUNT"

# Project
<<<<<<< HEAD
existing_project_id = "qwiklabs-gcp-02-20bdd77062d7"
=======
existing_project_id = "qwiklabs-gcp-03-020528f194e4"
>>>>>>> 0e5e518198d05b98bf1b42773263a91302a2835b

# Network
network_name = "vpc-network"
availability_regions = ["us-west1"]

# Platform Features
create_network_filesystem = true
create_mysql = true
create_postgres = false

# GKE
create_google_kubernetes_engine = false
configure_config_management = false
configure_policy_controller = false
configure_cloud_service_mesh = false
configure_security_posture_service = false
