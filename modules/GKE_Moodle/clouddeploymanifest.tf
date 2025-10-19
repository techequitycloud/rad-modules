# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 
#########################################################################
# Customize backup files to repo
#########################################################################

resource "local_file" "clouddeploy_backup_skaffold" {
  count = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/backup/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/cd/backup/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION                = local.region
  })
}

# Resource to create a local file for development deployment, with variables substituted
resource "local_file" "clouddeploy_backup_deploy_dev" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/backup/deploy-dev.yaml"
  content  = templatefile("${path.module}/scripts/cd/backup/deploy-dev.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev" # 
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev" # module.sql_db_postgresql.additional_users[0].name
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev" # google_sql_database.sql_dev_database.name
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}" 
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    BACKUP_BUCKET     = "${local.backup_bucket_name}"
    DATA_BUCKET       = "${local.data_bucket_name}"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })
}

resource "local_file" "clouddeploy_backup_deploy_qa" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/backup/deploy-qa.yaml"
  content  = templatefile("${path.module}/scripts/cd/backup/deploy-qa.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa" # 
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa" # module.sql_db_postgresql.additional_users[0].name
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa" # google_sql_database.sql_qa_database.name
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}qa-password-${var.tenant_deployment_id}-${local.random_id}" 
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    BACKUP_BUCKET     = "${local.backup_bucket_name}"
    DATA_BUCKET       = "${local.data_bucket_name}"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })
}

resource "local_file" "clouddeploy_backup_deploy_prod" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/backup/deploy-prod.yaml"
  content  = templatefile("${path.module}/scripts/cd/backup/deploy-prod.yaml.tpl", {
    # Variables are passed to the template file for dynamic content generation
    PROJECT_ID        = local.project.project_id
    PROJECT_NUMBER    = local.project_number
    APP_REGION        = local.region
    APP_NAME          = var.application_name
    APP_SERVICE       = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    APP_DATA_DIR      = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod" # 
    APP_NFS_IP        = local.nfs_internal_ip
    DATABASE_USER     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod" # module.sql_db_postgresql.additional_users[0].name
    DATABASE_NAME     = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod" # google_sql_database.sql_prod_database.name
    DATABASE_PASSWORD = "${local.db_instance_name}-${var.application_database_name}prod-password-${var.tenant_deployment_id}-${local.random_id}" 
    DATABASE_HOST     = local.db_internal_ip
    DATABASE_INSTANCE = local.db_instance_name
    BACKUP_BUCKET     = "${local.backup_bucket_name}"
    DATA_BUCKET       = "${local.data_bucket_name}"
    NETWORK_NAME      = "${var.network_name}"
    HOST_PROJECT_ID   = "${local.project.project_id}"
  })
}

resource "local_file" "clouddeploy_backup_cloudbuild" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/backup/cloudbuild.yaml"
  content  = templatefile("${path.module}/scripts/cd/backup/cloudbuild.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION    = local.region
    IMAGE_NAME    = "backup"
    IMAGE_VERSION = "${var.application_version}"
    REPO_NAME     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    PIPELINE_NAME = "bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}

# Resource to create a local clouddeploy file from a template, with variables substituted
resource "local_file" "backup_clouddeploy" {
  count = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/backup/clouddeploy.yaml"
  content  = templatefile("${path.module}/scripts/cd/backup/clouddeploy.yaml.tpl", {
    PROJECT_ID    = local.project.project_id
    APP_NAME      = "bkup${var.application_name}${var.tenant_deployment_id}${local.random_id}"
    APP_REGION    = local.region
    CREATOR_SA    = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
    PIPELINE_NAME = "bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    TARGET_NAME   = "bkup${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}

#########################################################################
# Customize app dev files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "clouddeploy_dev_autoscale_horizontal" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_dev/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_dev/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "clouddeploy_dev_backend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_dev/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_dev/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "clouddeploy_dev_frontend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_dev/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_dev/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "clouddeploy_dev_base_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/base_dev/kustomization.yaml"
  content  = file("${path.module}/scripts/cd/app/base_dev/kustomization.yaml.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "clouddeploy_dev_service_cluster" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_dev/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_dev/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local storage Persistent Volume Claim (PVC) configuration file from a template
resource "local_file" "clouddeploy_dev_storage_pvc" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_dev/storage-pvc.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_dev/storage-pvc.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "clouddeploy_dev_ingress_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_dev/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_dev/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.dev,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "clouddeploy_dev_overlay_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_dev/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_dev/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}dev"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    APP_ENV                   = "dev"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "clouddeploy_dev_managedcert_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_dev/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_dev/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.dev,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "clouddeploy_dev_deployment_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    # Various variables are passed to the template to customize the deployment.
    filename                  = "${path.module}/scripts/cd/app/overlay_dev/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_dev/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}dev"
    APP_ENV                   = "dev"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_HOST             = local.db_internal_ip
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}dev-password"
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    APP_NFS_IP                = local.nfs_internal_ip
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
  })

  # Specifies that this resource depends on the PostgreSQL database module being available.
  depends_on      = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize qa files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "clouddeploy_qa_autoscale_horizontal" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_qa/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_qa/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "clouddeploy_qa_backend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_qa/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_qa/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "clouddeploy_qa_frontend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_qa/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_qa/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "clouddeploy_qa_base_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/base_qa/kustomization.yaml"
  content  = file("${path.module}/scripts/cd/app/base_qa/kustomization.yaml.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "clouddeploy_qa_service_cluster" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_qa/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_qa/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local storage Persistent Volume Claim (PVC) configuration file from a template
resource "local_file" "clouddeploy_qa_storage_pvc" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_qa/storage-pvc.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_qa/storage-pvc.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "clouddeploy_qa_ingress_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_qa/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_qa/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.qa,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "clouddeploy_qa_overlay_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_qa/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_qa/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}qa"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    APP_ENV                   = "qa"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "clouddeploy_qa_managedcert_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_qa/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_qa/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.qa,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "clouddeploy_qa_deployment_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    # Various variables are passed to the template to customize the deployment.
    filename                  = "${path.module}/scripts/cd/app/overlay_qa/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_qa/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}qa"
    APP_ENV                   = "qa"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.dev[count.index].address}.sslip.io"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_HOST             = local.db_internal_ip
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}qa-password"
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    APP_NFS_IP                = local.nfs_internal_ip
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
  })

  # Specifies that this resource depends on the PostgreSQL database module being available.
  depends_on      = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize prod files to repo
#########################################################################

# Resource for creating a local autoscale horizontal configuration file from a template
resource "local_file" "clouddeploy_prod_autoscale_horizontal" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_prod/autoscale-horizontal.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_prod/autoscale-horizontal.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local backend configuration file from a template
resource "local_file" "clouddeploy_prod_backend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_prod/backend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_prod/backend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local frontend configuration file from a template
resource "local_file" "clouddeploy_prod_frontend_config" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_prod/frontend-config.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_prod/frontend-config.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}prod"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local base kustomization file directly from an existing file
resource "local_file" "clouddeploy_prod_base_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
  filename = "${path.module}/scripts/cd/app/base_prod/kustomization.yaml"
  content  = file("${path.module}/scripts/cd/app/base_prod/kustomization.yaml.tpl")

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local service cluster configuration file from a template
resource "local_file" "clouddeploy_prod_service_cluster" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_prod/service-cluster.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_prod/service-cluster.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local storage Persistent Volume Claim (PVC) configuration file from a template
resource "local_file" "clouddeploy_prod_storage_pvc" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/base_prod/storage-pvc.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/base_prod/storage-pvc.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local ingress application configuration file from a template
resource "local_file" "clouddeploy_prod_ingress_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_prod/ingress-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_prod/ingress-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
    APP_IP                    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}"
  })

  depends_on      = [
    google_compute_global_address.prod,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local overlay kustomization file from a template.
# This will configure kustomization for a specific environment or 'overlay' like staging or production.
resource "local_file" "clouddeploy_prod_overlay_kustomization" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_prod/kustomization.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_prod/kustomization.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}prod"
    APP_REGION                = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    APP_ENV                   = "prod"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local managed certificate for the app from a template.
# It sets up the necessary information to create a managed certificate for an application's domain.
resource "local_file" "clouddeploy_prod_managedcert_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/overlay_prod/managedcert-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_prod/managedcert-app.yaml.tpl", {
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
  })

  depends_on      = [
    google_compute_global_address.prod,
    null_resource.init_git_repo,
  ]
}

# Resource for creating a deployment configuration for the stateful app from a template.
# This includes all necessary information for the deployment of the application to Kubernetes.
resource "local_file" "clouddeploy_prod_deployment_app" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    # Various variables are passed to the template to customize the deployment.
    filename                  = "${path.module}/scripts/cd/app/overlay_prod/deployment-app.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/overlay_prod/deployment-app.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    GCP_SERVICE_ACCOUNT       = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    APP_REGION                = local.region
    APP_NAME                  = "app${var.application_name}${local.random_id}"
    APP_NAMESPACE             = "${var.application_name}${var.tenant_deployment_id}prod"
    APP_ENV                   = "prod"
    APP_DOMAIN                = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.dev[count.index].address}.sslip.io"
    DATABASE_USER             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_NAME             = "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_HOST             = local.db_internal_ip
    DATABASE_SECRET           = "app${var.application_database_name}${local.random_id}prod-password"
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    APP_NFS_IP                = local.nfs_internal_ip
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
  })

  # Specifies that this resource depends on the PostgreSQL database module being available.
  depends_on      = [
    null_resource.init_git_repo,
  ]
}

#########################################################################
# Customize root folder files to repo
#########################################################################

# Resource for creating a local Cloud Build configuration file from a template.
resource "local_file" "clouddeploy_cloudbuild" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/cloudbuild.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/cloudbuild.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    IMAGE_REGION              = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    PIPELINE_NAME             = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Cloud Deploy configuration file from a template.
resource "local_file" "clouddeploy_clouddeploy" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/clouddeploy.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/clouddeploy.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = var.application_name
    APP_REGION                = local.region
    GKE_CLUSTER               = local.gke_cluster_name
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    CREATOR_SA                = "clouddeploy-sa@${local.project.project_id}.iam.gserviceaccount.com"
    PIPELINE_NAME             = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    TARGET_NAME               = "app${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Skaffold configuration file from a template.
# Skaffold is a tool that facilitates continuous development for Kubernetes applications.
resource "local_file" "clouddeploy_skaffold" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/cd/app/skaffold.yaml"
    content                   = templatefile("${path.module}/scripts/cd/app/skaffold.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    APP_NAME                  = var.application_name
    APP_REGION                = local.region
    GKE_CLUSTER               = local.gke_cluster_name
  })

  depends_on = [
    null_resource.init_git_repo,
  ]
}

# Resource for creating a local Cloud Build configuration file from a template.
resource "local_file" "cicd_cloudbuild" {
    count                     = var.configure_continuous_deployment ? 1 : 0
    filename                  = "${path.module}/scripts/app/cloudbuild.yaml"
    content                   = templatefile("${path.module}/scripts/app/cloudbuild.yaml.tpl", {
    PROJECT_ID                = local.project.project_id
    IMAGE_REGION              = local.region
    IMAGE_NAME                = var.application_name
    IMAGE_VERSION             = "${var.application_version}"
    REPO_NAME                 = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
  })
}
