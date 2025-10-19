# Copyright (c) Tech Equity Ltd

#########################################################################
# Configure Dev resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "cr_dev" {
  project = local.project.project_id
  name = "${var.customer_identifier}${var.application_name}dev-cr"
}

#########################################################################
# Configure QA resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "cr_qa" {
  project = local.project.project_id
  name = "${var.customer_identifier}${var.application_name}qa-cr"
}

#########################################################################
# Configure Prod resources
#########################################################################

# Reserve a global IP address for the load balancer
resource "google_compute_global_address" "cr_prod" {
  project = local.project.project_id
  name = "${var.customer_identifier}${var.application_name}prod-cr"
}
