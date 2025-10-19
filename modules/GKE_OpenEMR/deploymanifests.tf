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
# Configurations for Dev environment
#########################################################################

# Resource for creating the local files
resource "local_file" "dev_backend_config_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/backend_config.yaml"

  content = templatefile("${path.module}/templates/backend_config.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_frontend_config_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/frontend_config.yaml"

  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME    = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_horizontal_pod_autoscaler_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/horizontal_pod_autoscaler.yaml"

  content = templatefile("${path.module}/templates/horizontal_pod_autoscaler.yaml.tpl", {
    APPLICATION_NAME    = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_ingress_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/ingress.yaml"

  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    APPLICATION_IP        = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_managed_certificate_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/managed_certificate.yaml"

  content = templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev.${google_compute_global_address.dev[count.index].address}.sslip.io"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_namespace_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/namespace.yaml"

  content = templatefile("${path.module}/templates/namespace.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_service_account_yaml_output" {
  filename = "${path.module}/manifests/dev/service_account.yaml"

  content = templatefile("${path.module}/templates/service_account.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    GCP_SERVICE_ACCOUNT   = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_storage_pv_yaml_output" {
    filename                  = "${path.module}/manifests/dev/persistentvolume.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolume.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    ADDON_BUCKET_NAME         = "${local.project.project_id}-addons"
    DATABASE_NAME             = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NFS_IP        = local.nfs_internal_ip
  })
}

resource "local_file" "dev_storage_pvc_yaml_output" {
    filename                  = "${path.module}/manifests/dev/persistentvolumeclaim.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolumeclaim.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NAMESPACE     = "${var.application_name}${var.tenant_deployment_id}dev"
  })
}

resource "local_file" "dev_service_nodeport_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/service_nodeport.yaml"

  content = templatefile("${path.module}/templates/service_nodeport.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

resource "local_file" "dev_deployment_yaml_output" {
  count    = var.configure_development_environment ? 1 : 0
  filename = "${path.module}/manifests/dev/deployment.yaml"

  content = templatefile("${path.module}/templates/deployment.yaml.tpl", {
    GCP_PROJECT           = local.project.project_id
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}dev"
    APPLICATION_REGION    = local.region
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}dev"
    APPLICATION_NFS_IP    = local.nfs_internal_ip
    DATABASE_USER         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_NAME         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    DATABASE_HOST         = local.db_internal_ip
    IMAGE_NAME            = var.application_name
    IMAGE_VERSION         = "${var.application_version}"
    REPO_NAME             = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    NFS_PVC               = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    GCS_DATA_PVC          = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}dev"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}dev"
  })
}

#########################################################################
# Configurations for QA environment
#########################################################################

# Resource for creating the local files
resource "local_file" "qa_backend_config_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/backend_config.yaml"

  content = templatefile("${path.module}/templates/backend_config.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_frontend_config_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/frontend_config.yaml"

  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_horizontal_pod_autoscaler_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/horizontal_pod_autoscaler.yaml"

  content = templatefile("${path.module}/templates/horizontal_pod_autoscaler.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_ingress_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/ingress.yaml"

  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
    APPLICATION_IP        = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_managed_certificate_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/managed_certificate.yaml"

  content = templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa.${google_compute_global_address.qa[count.index].address}.sslip.io"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_namespace_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/namespace.yaml"

  content = templatefile("${path.module}/templates/namespace.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_service_account_yaml_output" {
  filename = "${path.module}/manifests/qa/service_account.yaml"

  content = templatefile("${path.module}/templates/service_account.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    GCP_SERVICE_ACCOUNT   = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_storage_pv_yaml_output" {
    filename                  = "${path.module}/manifests/qa/persistentvolume.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolume.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    ADDON_BUCKET_NAME         = "${local.project.project_id}-addons"
    DATABASE_NAME             = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NFS_IP        = local.nfs_internal_ip
  })
}

resource "local_file" "qa_storage_pvc_yaml_output" {
    filename                  = "${path.module}/manifests/qa/persistentvolumeclaim.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolumeclaim.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DB_PV                 = "gcs-csi-backup-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DB_PVC                = "gcs-csi-backup-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    APP_NAME                  = var.application_name
    APP_NAMESPACE             = "${var.tenant_deployment_id}${var.application_name}qa"
    DATABASE_NAME             = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NAMESPACE     = "${var.application_name}${var.tenant_deployment_id}qa"
  })
}

resource "local_file" "qa_service_nodeport_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/service_nodeport.yaml"

  content = templatefile("${path.module}/templates/service_nodeport.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

resource "local_file" "qa_deployment_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/qa/deployment.yaml"

  content = templatefile("${path.module}/templates/deployment.yaml.tpl", {
    GCP_PROJECT           = local.project.project_id
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}qa"
    APPLICATION_REGION    = local.region
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}qa"
    APPLICATION_NFS_IP    = local.nfs_internal_ip
    DATABASE_USER         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_NAME         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa"
    DATABASE_HOST         = local.db_internal_ip
    IMAGE_NAME            = var.application_name
    IMAGE_VERSION         = "${var.application_version}"
    REPO_NAME             = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    NFS_PVC               = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    GCS_DATA_PVC          = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}qa"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}qa"
  })
}

#########################################################################
# Configurations for Prod environment
#########################################################################

# Resource for creating the local files
resource "local_file" "prod_backend_config_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/backend_config.yaml"

  content = templatefile("${path.module}/templates/backend_config.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_frontend_config_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/frontend_config.yaml"

  content = templatefile("${path.module}/templates/frontend_config.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_horizontal_pod_autoscaler_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/horizontal_pod_autoscaler.yaml"

  content = templatefile("${path.module}/templates/horizontal_pod_autoscaler.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_ingress_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/ingress.yaml"

  content = templatefile("${path.module}/templates/ingress.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
    APPLICATION_IP        = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_managed_certificate_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/managed_certificate.yaml"

  content = templatefile("${path.module}/templates/managed_certificate.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    APPLICATION_DOMAIN    = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod.${google_compute_global_address.prod[count.index].address}.sslip.io"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_namespace_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/namespace.yaml"

  content = templatefile("${path.module}/templates/namespace.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_service_account_yaml_output" {
  filename = "${path.module}/manifests/prod/service_account.yaml"

  content = templatefile("${path.module}/templates/service_account.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    GCP_SERVICE_ACCOUNT   = "gke-sa@${local.project.project_id}.iam.gserviceaccount.com"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_storage_pv_yaml_output" {
    filename                  = "${path.module}/manifests/prod/persistentvolume.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolume.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    ADDON_BUCKET_NAME         = "${local.project.project_id}-addons"
    DATABASE_NAME             = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NFS_IP        = local.nfs_internal_ip
  })
}

resource "local_file" "prod_storage_pvc_yaml_output" {
    filename                  = "${path.module}/manifests/prod/persistentvolumeclaim.yaml"
    content                   = templatefile("${path.module}/templates/persistentvolumeclaim.yaml.tpl", {
    NFS_PV                    = "nfs-csi-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DB_PV                 = "gcs-csi-backup-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DATA_PV               = "gcs-csi-addon-pv-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    NFS_PVC                   = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DB_PVC                = "gcs-csi-backup-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DATA_PVC              = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    APP_NAME                  = var.application_name
    APP_NAMESPACE             = "${var.tenant_deployment_id}${var.application_name}prod"
    DATABASE_NAME             = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    NFS_STORAGE_CLASS         = "nfs-volume"
    GCS_STORAGE_CLASS         = "gcs-volume"
    APPLICATION_NAMESPACE     = "${var.application_name}${var.tenant_deployment_id}prod"
  })
}

resource "local_file" "prod_service_nodeport_yaml_output" {
  count    = var.configure_production_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/service_nodeport.yaml"

  content = templatefile("${path.module}/templates/service_nodeport.yaml.tpl", {
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}

resource "local_file" "prod_deployment_yaml_output" {
  count    = var.configure_nonproduction_environment ? 1 : 0
  filename = "${path.module}/manifests/prod/deployment.yaml"

  content = templatefile("${path.module}/templates/deployment.yaml.tpl", {
    GCP_PROJECT           = local.project.project_id
    APPLICATION_NAME      = "app${var.application_name}${local.random_id}prod"
    APPLICATION_REGION    = local.region
    APPLICATION_NAMESPACE = "${var.application_name}${var.tenant_deployment_id}prod"
    APPLICATION_NFS_IP    = local.nfs_internal_ip
    DATABASE_USER         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_NAME         = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    DATABASE_HOST         = local.db_internal_ip
    IMAGE_NAME            = var.application_name
    IMAGE_VERSION         = "${var.application_version}"
    REPO_NAME             = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    NFS_PVC               = "nfs-csi-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    GCS_DATA_PVC          = "gcs-csi-addon-pvc-${var.tenant_deployment_id}-${var.application_name}${local.random_id}prod"
    SERVICE_ACCOUNT_NAME  = "app${var.application_name}${local.random_id}prod"
  })
}