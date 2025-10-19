# Copyright (c) Tech Equity Ltd

#########################################################################
# Configure resources
#########################################################################

# Resource to build the container image locally and push it to the container registry
resource "null_resource" "configure_dev_iap" {
  triggers = {
    project_id = "${local.project.project_id}"
    project_number = "${local.project_number}"
    app_name = "${var.customer_identifier}app${var.application_name}dev"
    app_region = "${var.region}"
    creator_sa = "${var.resource_creator_identity}"
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }
  
  # Provisioner to execute a local script that builds and pushes the container image
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/iap"  # The directory where build scripts are located
    command = "./configure-iap.sh"

    environment = {
      PROJECT_ID      = local.project.project_id
      PROJECT_NUMBER  = local.project_number
      APP_NAME        = "${var.customer_identifier}app${var.application_name}dev"
      APP_REGION      = var.region
      CREATOR_SA      = var.resource_creator_identity
    }
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.build_cloud_deploy_app_pipeline,
    # google_project_service.enabled_services,
    time_sleep.wait_120_seconds
  ]
}

# Resource to build the container image locally and push it to the container registry
resource "null_resource" "configure_qa_iap" {
  triggers = {
    project_id = "${local.project.project_id}"
    project_number = "${local.project_number}"
    app_name = "${var.customer_identifier}app${var.application_name}qa"
    app_region = "${var.region}"
    creator_sa = "${var.resource_creator_identity}"
    # always_run = "${timestamp()}" # Trigger to always run on apply
  }
  
  # Provisioner to execute a local script that builds and pushes the container image
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/iap"  # The directory where build scripts are located
    command = "./configure-iap.sh"

    environment = {
      PROJECT_ID      = local.project.project_id
      PROJECT_NUMBER  = local.project_number
      APP_NAME        = "${var.customer_identifier}app${var.application_name}qa"
      APP_REGION      = var.region
    }
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.build_cloud_deploy_app_pipeline,
    # google_project_service.enabled_services,
    null_resource.configure_dev_iap,
    time_sleep.wait_120_seconds
  ]
}

# Resource to build the container image locally and push it to the container registry
resource "null_resource" "configure_prod_iap" {
  triggers = {
    project_id      = "${local.project.project_id}"
    project_number  = "${local.project_number}"
    app_name        = "${var.customer_identifier}app${var.application_name}prod"
    app_region      = "${var.region}"
    creator_sa      = "${var.resource_creator_identity}"
    # always_run      = "${timestamp()}" # Trigger to always run on apply
  }
  
  # Provisioner to execute a local script that builds and pushes the container image
  provisioner "local-exec" {
    working_dir = "${path.module}/scripts/iap"  # The directory where build scripts are located
    command = "./configure-iap.sh"

    environment = {
      PROJECT_ID      = local.project.project_id
      PROJECT_NUMBER  = local.project_number
      APP_NAME        = "${var.customer_identifier}app${var.application_name}prod"
      APP_REGION      = var.region
      CREATOR_SA      = var.resource_creator_identity
    }
  }

  # Dependencies to ensure resources are created in the correct order
  depends_on = [
    null_resource.build_cloud_deploy_app_pipeline,
    # google_project_service.enabled_services,
    null_resource.configure_qa_iap,
    time_sleep.wait_120_seconds
  ]
}

