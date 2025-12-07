# N8N Terraform Module

This Terraform module deploys the N8N workflow automation tool on Google Cloud Run, backed by a managed Google Cloud SQL (PostgreSQL) database. It simplifies the process of setting up a production-ready N8N instance by provisioning and configuring all the necessary infrastructure.

## Features

*   **Multi-Environment Deployment:** Supports deploying separate development, non-production, and production environments.
*   **CI/CD Pipeline:** Integrates with GitHub to create a continuous integration and deployment pipeline using Cloud Build and Cloud Deploy, automating the build and release process.
*   **Database Management:** Provisions a dedicated Cloud SQL for PostgreSQL instance, database, and user. It can also import an existing database from a backup file.
*   **Automated Backups:** Configures scheduled daily backups of the N8N database using Cloud Scheduler and Cloud Run jobs.
*   **Monitoring:** Sets up application monitoring, including uptime checks, SLOs, and SLIs.
*   **Web Application Security:** Can deploy a global load balancer with Google Cloud Armor to protect the application from web-based attacks and control access.

## Usage

```hcl
module "n8n" {
  source = "./modules/N8N"

  existing_project_id = "your-gcp-project-id"
  tenant_deployment_id = "unique-deployment-id"

  configure_production_environment = true
  configure_backups = true
  configure_monitoring = true
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_external"></a> [external](#requirement\_external) | 2.3.3 |
| <a name="requirement_github"></a> [github](#requirement\_github) | 6.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | 5.29.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | 5.29.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.5.1 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.2 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.11.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.3 |
| <a name="provider_github"></a> [github](#provider\_github) | 6.0.0 |
| <a name="provider_google"></a> [google](#provider\_google) | 5.29.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 5.29.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.2 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_actions_secret.github_secret_token](https://registry.terraform.io/providers/hashicorp/github/latest/docs/resources/actions_secret) | resource |
| [github_collaborator.git_collaborators](https://registry.terraform.io/providers/hashicorp/github/latest/docs/resources/collaborator) | resource |
| [github_repository.application_repository](https://registry.terraform.io/providers/hashicorp/github/latest/docs/resources/repository) | resource |
| [google-beta_google_cloud_run_v2_job.cloud_run_job_backup](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_cloud_run_v2_job) | resource |
| [google-beta_google_cloud_run_v2_job.cloud_run_job_db](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_cloud_run_v2_job) | resource |
| [google-beta_google_cloud_run_v2_job.cloud_run_job_importnfs](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_cloud_run_v2_job) | resource |
| [google-beta_google_cloud_run_v2_service.app_service](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_cloud_run_v2_service) | resource |
| [google_cloud_run_service_iam_member.allow_public_access](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service_iam_member) | resource |
| [google_cloud_scheduler_job.backup_scheduler](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_scheduler_job) | resource |
| [google_cloudbuild_trigger.build-trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_clouddeploy_delivery_pipeline.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_delivery_pipeline) | resource |
| [google_clouddeploy_target.dev](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_target) | resource |
| [google_clouddeploy_target.nonprod](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_target) | resource |
| [google_clouddeploy_target.prod](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/clouddeploy_target) | resource |
| [google_compute_address.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_backend_service.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_global_forwarding_rule.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_instance.nfs_server](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network_peering.peering1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.peering2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_security_policy.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy) | resource |
| [google_compute_ssl_certificate.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_certificate) | resource |
| [google_compute_target_https_proxy.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_filestore_instance.nfs_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance) | resource |
| [google_kms_crypto_key_iam_member.crypto_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_logging_metric.custom_metric](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_metric) | resource |
| [google_monitoring_alert_policy.alert_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_notification_channel.email](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_monitoring_uptime_check_config.https](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_uptime_check_config) | resource |
| [google_project_iam_member.cloud_build_service_account_is_cloud_sql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloud_run_service_account_is_cloud_sql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudbuild_custom_worker_service_account_is_cloud_sql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudbuild_service_account_is_clouddeploy_releaser](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudbuild_service_account_is_cloudrun_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudbuild_service_account_is_iam_service_account_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudrun_sa_is_artifactregistry_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudrun_sa_is_secretmanager_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cloudrun_sa_is_storage_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.rad_module_creator_is_cloudrun_invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service_identity.cloudrun_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service_identity) | resource |
| [google_project_service_identity.gcp_sa_cloudbuild](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service_identity) | resource |
| [google_project_service_identity.gcp_sa_clouddeploy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service_identity) | resource |
| [google_secret_manager_secret.application_secrets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_member.rad_module_creator_is_secretmanager_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_version.application_secrets_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.cloudbuild_custom_worker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.cloudrun_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_sql_database.database](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_binding.binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_binding) | resource |
| [google_vpc_access_connector.connector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector) | resource |
| [local_file.cicd_manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.clouddeploy_manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.application_import_db](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.application_install_database](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.build_and_push_backup_container](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_filestore_mount](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.db_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.n8n_webhook_tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [time_sleep.wait_30_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [external_script.get_rad_launcher_config](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/script) | data source |
| [github_repository.application_repository](https://registry.terraform.io/providers/hashicorp/github/latest/docs/data-sources/repository) | data source |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_zones.available_zones](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_project.existing_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_secret_manager_secret_version.db_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_service_account_access_token.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account_access_token) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application_authorized_network"></a> [application\_authorized\_network](#input\_application\_authorized\_network) | Enter the application authorized network. Cloud Armour is configured to allow traffic from this network. {{UIMeta group=0 order=811 updatesafe}} | `set(string)` | `[]` | no |
| <a name="input_application_backup_fileid"></a> [application\_backup\_fileid](#input\_application\_backup\_fileid) | Enter application backup file ID. When enabled, terraform attempts to download the file from Google Drive, and if found, imports the backup file during deployment. {{UIMeta group=0 order=808 updatesafe}} | `string` | `""` | no |
| <a name="input_application_backup_schedule"></a> [application\_backup\_schedule](#input\_application\_backup\_schedule) | Enter the application backup schedule in cron format. This is used to configure the Cloud Scheduler cron job. {{UIMeta group=0 order=807 updatesafe }} | `string` | `"0 0 * * *"` | no |
| <a name="input_application_database_name"></a> [application\_database\_name](#input\_application\_database\_name) | Specify application database name. {{UIMeta group=0 order=503 updatesafe }} | `string` | `"n8n"` | no |
| <a name="input_application_database_user"></a> [application\_database\_user](#input\_application\_database\_user) | Specify application database user name. {{UIMeta group=0 order=502 updatesafe}} | `string` | `"n8n-user"` | no |
| <a name="input_application_git_installation_id"></a> [application\_git\_installation\_id](#input\_application\_git\_installation\_id) | Specify the application installation ID. {{UIMeta group=0 order=603 updatesafe}} | `string` | `"38735316"` | no |
| <a name="input_application_git_organization"></a> [application\_git\_organization](#input\_application\_git\_organization) | Specify the github organization. {{UIMeta group=0 order=604 updatesafe}} | `string` | `"techequitycloud"` | no |
| <a name="input_application_git_token"></a> [application\_git\_token](#input\_application\_git\_token) | Specify a github classic token with following privileges needed to configure the code repository: delete\_repo, read:org, repo. {{UIMeta group=0 order=602 updatesafe}} | `string` | `""` | no |
| <a name="input_application_git_usernames"></a> [application\_git\_usernames](#input\_application\_git\_usernames) | Specify the usernames to add as collaborators to the git repo. {{UIMeta group=0 order=602 updatesafe}} | `set(string)` | `[]` | no |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | Specify application name. The application name is used to identify configured resources alongside other attributes that ensures uniqueness. {{UIMeta group=0 order=501 updatesafe}} | `string` | `"n8n"` | no |
| <a name="input_application_secure_path"></a> [application\_secure\_path](#input\_application\_secure\_path) | Enter the application secure path. Cloud Armour is configured to restrict traffic to this path. {{UIMeta group=0 order=810 updatesafe}} | `string` | `""` | no |
| <a name="input_application_version"></a> [application\_version](#input\_application\_version) | Enter application version (image tag). {{UIMeta group=0 order=504 updatesafe}} | `string` | `"latest"` | no |
| <a name="input_configure_application_security"></a> [configure\_application\_security](#input\_configure\_application\_security) | Select this checkbox to configure web application security.  Configures a global load balancer with Cloud Armor web application security. {{UIMeta group=0 order=809 updatesafe }} | `bool` | `false` | no |
| <a name="input_configure_backups"></a> [configure\_backups](#input\_configure\_backups) | Select this checkbox to schedule daily application backups. Configures a Cloud Scheduler trigger to execute a Cloud Run backup job. {{UIMeta group=0 order=806 updatesafe }} | `bool` | `false` | no |
| <a name="input_configure_continuous_deployment"></a> [configure\_continuous\_deployment](#input\_configure\_continuous\_deployment) | Select the checkbox to configure continous deployment pipeline. Implements a continuous delivery pipeline on the primary deployment region using Cloud Deploy. {{UIMeta group=0 order=600 updatesafe}} | `bool` | `false` | no |
| <a name="input_configure_continuous_integration"></a> [configure\_continuous\_integration](#input\_configure\_continuous\_integration) | Select the checkbox to configure GitHub continuous integration and continous delivery pipeline that supports single and multi-region deployment. {{UIMeta group=0 order=601 updatesafe}} | `bool` | `false` | no |
| <a name="input_configure_development_environment"></a> [configure\_development\_environment](#input\_configure\_development\_environment) | Select to configure development environment. {{UIMeta group=3 order=703 updatesafe }} | `bool` | `false` | no |
| <a name="input_configure_monitoring"></a> [configure\_monitoring](#input\_configure\_monitoring) | Select this option to configure monitoring. Configures uptime checks, SLOs and SLIs for application, and CPU utilization monitoring for NFS virtual machine. {{UIMeta group=0 order=805 updatesafe}} | `bool` | `true` | no |
| <a name="input_configure_nonproduction_environment"></a> [configure\_nonproduction\_environment](#input\_configure\_nonproduction\_environment) | Select to configure staging environment. {{UIMeta group=3 order=704 updatesafe }} | `bool` | `false` | no |
| <a name="input_configure_production_environment"></a> [configure\_production\_environment](#input\_configure\_production\_environment) | Select to configure production environment. {{UIMeta group=3 order=705 updatesafe }} | `bool` | `false` | no |
| <a name="input_credit_cost"></a> [credit\_cost](#input\_credit\_cost) | Specify the module cost {{UIMeta group=0 order=103 }} | `number` | `100` | no |
| <a name="input_deployment_id"></a> [deployment\_id](#input\_deployment\_id) | Unique ID suffix for resources.  Leave blank to generate random ID. | `string` | `null` | no |
| <a name="input_enable_purge"></a> [enable\_purge](#input\_enable\_purge) | Set to true to enable the ability to purge this module. {{UIMeta group=0 order=105 }} | `bool` | `true` | no |
| <a name="input_existing_project_id"></a> [existing\_project\_id](#input\_existing\_project\_id) | Enter the project ID of the destination project. {{UIMeta group=2 order=200 updatesafe }} | `string` | n/a | yes |
| <a name="input_module_dependency"></a> [module\_dependency](#input\_module\_dependency) | Specify the names of the modules this module depends on in the order in which they should be deployed. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP Project",<br>  "GCP Services"<br>]</pre> | no |
| <a name="input_module_description"></a> [module\_description](#input\_module\_description) | The description of the module. {{UIMeta group=0 order=100 }} | `string` | `"This module deploys n8n on Google Cloud Run, providing a workflow automation tool with a PostgreSQL database."` | no |
| <a name="input_module_services"></a> [module\_services](#input\_module\_services) | Specify the module services. {{UIMeta group=0 order=102 }} | `list(string)` | <pre>[<br>  "GCP",<br>  "Cloud Run",<br>  "Cloud SQL",<br>  "Secret Manager",<br>  "Cloud IAM"<br>]</pre> | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | The name of the VPC network. {{UIMeta group=0 order=201 updatesafe }} | `string` | `"vpc-network"` | no |
| <a name="input_public_access"></a> [public\_access](#input\_public\_access) | Set to true to enable the module to be available to all platform users. {{UIMeta group=0 order=106 }} | `bool` | `false` | no |
| <a name="input_require_credit_purchases"></a> [require\_credit\_purchases](#input\_require\_credit\_purchases) | Set to true to require credit purchases to deploy this module. {{UIMeta group=0 order=104 }} | `bool` | `false` | no |
| <a name="input_resource_creator_identity"></a> [resource\_creator\_identity](#input\_resource\_creator\_identity) | The terraform Service Account used to create resources in the destination project. This Service Account must be assigned roles/owner IAM role in the destination project. {{UIMeta group=1 order=102 updatesafe }} | `string` | `"rad-module-creator@tec-rad-ui-2b65.iam.gserviceaccount.com"` | no |
| <a name="input_tenant_deployment_id"></a> [tenant\_deployment\_id](#input\_tenant\_deployment\_id) | Specify a client or application deployment id. This uniquely identifies the client or application deployment. {{UIMeta group=3 order=701 updatesafe}} | `string` | n/a | yes |
| <a name="input_trusted_users"></a> [trusted\_users](#input\_trusted\_users) | List of trusted users with limited Google Cloud project admin privileges. (e.g. `username@abc.com`). {{UIMeta group=0 order=103 updatesafe }} | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_info"></a> [application\_info](#output\_application\_info) | n/a |
| <a name="output_cloud_sql_info"></a> [cloud\_sql\_info](#output\_cloud\_sql\_info) | n/a |
| <a name="output_deployment_info"></a> [deployment\_info](#output\_deployment\_info) | n/a |
| <a name="output_network_info"></a> [network\_info](#output\_network\_info) | n/a |
| <a name="output_nfs_instance_info"></a> [nfs\_instance\_info](#output\_nfs\_instance\_info) | n/a |
| <a name="output_service_info"></a> [service\_info](#output\_service\_info) | n/a |
| <a name="output_sql_instance_info"></a> [sql\_instance\_info](#output\_sql\_instance\_info) | n/a |
<!-- END_TF_DOCS -->
