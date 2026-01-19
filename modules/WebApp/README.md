# WebApp Module

This module deploys a generic Web Application on Google Cloud Run, providing a flexible platform with configurable infrastructure services.

## Features

*   **Cloud Run Application**: Deploys a containerized application to Cloud Run (Gen2).
*   **Database Integration**: Supports connecting to existing Cloud SQL instances (MySQL or PostgreSQL). Automatically creates database users and databases.
*   **NFS Storage**: Supports mounting an existing NFS share.
*   **Cloud Storage**: Supports mounting a GCS bucket.
*   **Configuration**: Allows specifying environment variables, ports, and resource limits (via code modification if needed, currently defaults).

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application_name | Name of the application. | string | "webapp" | no |
| application_image | Container image URL. | string | - | yes |
| application_port | Port the application listens on. | number | 8080 | no |
| application_env_vars | Map of environment variables. | map(string) | {} | no |
| database_type | Type of database ("MYSQL", "POSTGRES", "NONE"). | string | "NONE" | no |
| enable_nfs | Enable NFS mounting. | bool | false | no |
| nfs_mount_path | Path to mount NFS. | string | "/mnt/nfs" | no |
| create_cloud_storage | Enable GCS bucket creation and mounting. | bool | false | no |
| existing_project_id | GCP Project ID. | string | - | yes |
| tenant_deployment_id | Unique deployment ID. | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| service_name | Name of the Cloud Run service. |
| service_url | URL of the deployed service. |
| db_internal_ip | Internal IP of the database. |
| nfs_internal_ip | Internal IP of the NFS server. |
