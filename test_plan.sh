cd modules/Bank_GKE
tofu plan -var="existing_project_id=test-project" -var="gcp_region=us-central1" -var="gke_cluster=test-cluster" -var="gcp_zone=us-central1-a" -var="vpc_name=test-vpc"
