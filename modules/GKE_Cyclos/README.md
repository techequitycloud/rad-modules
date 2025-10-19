# GKE Cyclos

This directory contains Terraform code to provision a standalone GKE environment for the Cyclos Banking System (CBS).

## Overview

The Terraform configuration provisions the following resources:

*   **Google Kubernetes Engine (GKE):** A GKE cluster to host the Cyclos application.
*   **Cloud SQL:** A PostgreSQL database for the Cyclos application.
*   **Cloud Storage:** Buckets for application data and backups.
*   **Filestore:** A Filestore instance for shared storage.
*   **VPC Network:** A VPC network and subnets for the GKE cluster and other resources.
*   **IAM:** Service accounts and IAM bindings for the various components.
*   **Cloud Load Balancing:** A global load balancer to expose the Cyclos application to the internet.
*   **Cloud Armor:** A Cloud Armor policy to protect the application from DDoS attacks.
*   **Cloud Build:** Cloud Build triggers to build and deploy the Cyclos application.
*   **Cloud Deploy:** A Cloud Deploy pipeline to manage deployments to the GKE cluster.
*   **Artifact Registry:** An Artifact Registry repository to store container images.
*   **Cloud Scheduler:** A Cloud Scheduler job to trigger daily backups.
*   **Secret Manager:** Secrets to store sensitive data like database credentials and API keys.

## File Descriptions

*   `main.tf`: The main entrypoint for the Terraform configuration. It defines the providers, locals, and data sources.
*   `variables.tf`: Defines the input variables for the Terraform configuration.
*   `outputs.tf`: Defines the outputs of the Terraform configuration.
*   `gke.tf`: Provisions the GKE cluster.
*   `sql.tf`: Provisions the Cloud SQL for PostgreSQL instance.
*   `storage.tf`: Provisions the Cloud Storage buckets.
*   `nfs.tf`: Provisions the Filestore instance.
*   `network.tf`: Provisions the VPC network and subnets.
*   `iam.tf`: Provisions the IAM service accounts and bindings.
*   `sa.tf`: Provisions additional service accounts.
*   `glb.tf`: Provisions the global load balancer.
*   `security.tf`: Provisions the Cloud Armor policy.
*   `cicd.tf`: Provisions the Cloud Build triggers.
*   `clouddeploy.tf`: Provisions the Cloud Deploy pipeline.
*   `registry.tf`: Provisions the Artifact Registry repository.
*   `scheduler.tf`: Provisions the Cloud Scheduler job.
*   `secrets.tf`: Provisions the secrets in Secret Manager.
*   `buildappcontainer.tf`: Defines the Cloud Build configuration for the application container.
*   `buildbackupcontainer.tf`: Defines the Cloud Build configuration for the backup container.
*   `cicdmanifest.tf`: Defines the CI/CD manifest.
*   `clouddeploymanifest.tf`: Defines the Cloud Deploy manifest.
*   `debug.tf`: Contains debugging resources.
*   `deploy.tf`: Defines the deployment configuration.
*   `deploymanifests.tf`: Defines the deployment manifests.
*   `importdb.tf`: Defines the database import configuration.
*   `importnfs.tf`: Defines the NFS import configuration.
*   `kubernetes_cbs.tfvars`: A sample tfvars file.
*   `provider-auth.tf`: Defines the provider authentication.
*   `versions.tf`: Defines the required provider versions.

## Usage

1.  **Initialize Terraform:**

    ```bash
    terraform init
    ```

2.  **Create a `terraform.tfvars` file:**

    Create a `terraform.tfvars` file and populate it with the required variables. See `variables.tf` for the full list of variables.

3.  **Plan the deployment:**

    ```bash
    terraform plan
    ```

4.  **Apply the changes:**

    ```bash
    terraform apply
    ```

## Inputs

Refer to the `variables.tf` file for the full list of input variables.

## Outputs

Refer to the `outputs.tf` file for the full list of outputs.
