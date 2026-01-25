# Terraform Module Development Training
## 1-Day Intensive Program Using RAD Modules Best Practices

**Duration:** 8 hours (9:00 AM - 5:00 PM)
**Target Audience:** DevOps Engineers, Cloud Engineers, Infrastructure Developers
**Prerequisites:** Basic understanding of cloud concepts, some experience with Infrastructure as Code

---

## Training Objectives

By the end of this training, participants will be able to:
1. Understand and apply the RAD modules architectural patterns
2. Build production-ready Terraform modules following enterprise best practices
3. Implement multi-tenant, multi-region, and multi-environment infrastructure
4. Design idempotent and maintainable Terraform modules
5. Integrate security, secrets management, and CI/CD into modules
6. Create well-documented, reusable infrastructure components

---

## Training Schedule

### **Morning Session: Foundations & Architecture (9:00 AM - 12:00 PM)**

#### **9:00 - 9:30 AM: Welcome & Introduction**
- Training overview and objectives
- Introduction to Infrastructure as Code (IaC)
- Why Terraform? Benefits and use cases
- Overview of the RAD modules repository
- **Activity:** Environment setup and repository walkthrough

#### **9:30 - 10:30 AM: Terraform Fundamentals Review**
- **Core Concepts:**
  - Resources, Data Sources, Variables, Outputs, Locals
  - Providers and provider configuration
  - State management and backends
  - Terraform workflow: init, plan, apply, destroy
- **Advanced Concepts:**
  - Meta-arguments: `count`, `for_each`, `depends_on`
  - Dynamic blocks and complex data structures
  - Built-in functions: `try()`, `coalesce()`, `templatefile()`
- **RAD-Specific Patterns:**
  ```hcl
  # Conditional resource creation
  count = var.enable_feature ? 1 : 0

  # Multi-region deployment
  for_each = toset(local.regions)
  ```
- **Hands-on Exercise:** Write a simple Terraform configuration with conditional resources

**10:30 - 10:45 AM: Break**

#### **10:45 AM - 12:00 PM: RAD Modules Architecture & Organization**

##### **Module Structure Patterns (10:45 - 11:15 AM)**
- **Repository Organization:**
  ```
  rad-modules/
  ├── modules/
  │   ├── GCP_Project/         # Foundation modules
  │   ├── GCP_Services/        # Infrastructure modules
  │   └── Application_Name/    # Application modules
  ```
- **File Organization by Concern:**
  - `main.tf` - Core logic and locals (always consistent 41-line pattern)
  - `versions.tf` - Provider declarations
  - `variables.tf` - Input variables with UI metadata
  - `outputs.tf` - Structured outputs
  - `provider-auth.tf` - Service account impersonation
  - `sa.tf` - Service accounts and IAM
  - `network.tf` - VPC and networking
  - `service.tf` - Cloud Run services
  - `jobs.tf` - Cloud Run jobs (migrations, backups)
  - `sql.tf` - Database configuration
  - `secrets.tf` - Secret Manager integration
  - `cicd.tf` - CI/CD pipelines
  - `monitoring.tf` - Observability
  - `security.tf` - Security policies
  - `storage.tf` - Cloud Storage buckets

##### **Naming Conventions & Standards (11:15 - 11:30 AM)**
- **Resource Naming Pattern:**
  ```
  app{application_name}{tenant_deployment_id}{random_id}{environment}
  ```
  Examples:
  - `appodoo123abc456dev` - Development Cloud Run service
  - `cloudsql-instance-odoo-dev-password-123-abc456` - Secret name

- **Variable Naming:**
  - Descriptive, snake_case
  - Prefixed by concern: `application_`, `network_`, `database_`

##### **Variable Organization & UI Metadata (11:30 - 12:00 PM)**
- **UI Metadata Tags for Form Generation:**
  ```hcl
  variable "module_description" {
    description = "The description of the module. {{UIMeta group=0 order=100 }}"
    type        = string
    default     = "Odoo ERP System"
  }

  variable "existing_project_id" {
    description = "The existing GCP project ID. {{UIMeta group=2 order=1 }}"
    type        = string
    sensitive   = false
  }

  variable "database_tier" {
    description = "Database tier. {{UIMeta group=5 order=2 updatesafe }}"
    type        = string
    default     = "db-custom-2-7680"
  }
  ```

- **Standard Variable Groups:**
  - Group 0: Deployment metadata (module_description, credit_cost, enable_purge)
  - Group 1: IAM and authentication
  - Group 2: Project/application configuration
  - Group 3: Network setup
  - Group 5: Storage & database
  - Group 6: CI/CD configuration
  - Group 7: Tenant identifiers
  - Group 8: Feature flags (monitoring, backups, security)

- **Key Concepts:**
  - `updatesafe` tag: Variable can be modified after initial deployment
  - Group ordering: Determines UI presentation sequence
  - Default values: Balance between usability and security

- **Hands-on Exercise:** Define variables for a hypothetical module with proper grouping and metadata

**12:00 - 1:00 PM: Lunch Break**

---

### **Afternoon Session: Implementation & Best Practices (1:00 PM - 5:00 PM)**

#### **1:00 - 2:00 PM: Core Patterns Implementation**

##### **Pattern 1: Idempotent Resource Management (1:00 - 1:20 PM)**
- **The Challenge:** Handling pre-existing resources
- **Solution:** External data sources with shell scripts
  ```hcl
  data "external" "sql_instance_info" {
    program = ["bash", "-c", <<-EOT
      INSTANCE_INFO=$(gcloud sql instances list \
        --filter="name:$INSTANCE_NAME" \
        --project="$PROJECT_ID" \
        --format=json)

      if [ "$INSTANCE_INFO" != "[]" ]; then
        # Extract connection name, IP, instance name
        echo "{ \"sql_server_exists\": \"true\", \"instance_name\": \"...\", \"private_ip\": \"...\" }"
      else
        echo "{ \"sql_server_exists\": \"false\", \"instance_name\": \"\", \"private_ip\": \"\" }"
      fi
    EOT
    ]
  }

  locals {
    sql_server_exists = try(data.external.sql_instance_info.result["sql_server_exists"], "false")
    db_instance_name  = try(data.external.sql_instance_info.result["instance_name"], "")
  }

  resource "google_sql_database_instance" "postgres" {
    count = local.sql_server_exists == "false" ? 1 : 0
    name  = "cloudsql-${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    # ... configuration
  }
  ```

##### **Pattern 2: Multi-Environment Support (1:20 - 1:40 PM)**
- **Boolean flags for environment control:**
  ```hcl
  variable "configure_development_environment" {
    description = "Enable development environment. {{UIMeta group=8 order=1 updatesafe }}"
    type        = bool
    default     = true
  }

  variable "configure_nonproduction_environment" {
    description = "Enable QA/staging environment. {{UIMeta group=8 order=2 updatesafe }}"
    type        = bool
    default     = false
  }

  variable "configure_production_environment" {
    description = "Enable production environment. {{UIMeta group=8 order=3 updatesafe }}"
    type        = bool
    default     = false
  }
  ```

- **Conditional resource creation:**
  ```hcl
  resource "google_cloud_run_v2_service" "dev_app_service" {
    for_each = var.configure_development_environment ?
      toset([local.region]) : toset([])

    name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    location = each.key
    # ... configuration
  }

  resource "google_cloud_run_v2_service" "prod_app_service" {
    for_each = var.configure_production_environment ?
      toset(local.regions) : toset([])  # Multi-region for production

    name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod"
    location = each.key
    # ... configuration with higher resources
  }
  ```

##### **Pattern 3: Multi-Region Deployments (1:40 - 2:00 PM)**
- **Dynamic region handling:**
  ```hcl
  data "external" "check_network" {
    program = ["bash", "-c", <<-EOT
      # Extract subnet regions
      REGIONS=$(gcloud compute networks subnets list \
        --network="$NETWORK_NAME" \
        --project="$PROJECT_ID" \
        --format="value(region)" | jq -R -s -c 'split("\n") | map(select(length > 0))')

      echo "{ \"regions\": $REGIONS }"
    EOT
    ]
  }

  locals {
    regions_list = jsondecode(data.external.check_network.result.regions)
    region       = tolist(local.regions_list)[0]  # Primary region
    regions      = tolist(local.regions_list)     # All regions
  }

  # Deploy to multiple regions based on configuration
  resource "google_cloud_run_v2_service" "app" {
    for_each = length(local.regions) >= 2 ?
      toset(local.regions) : toset([local.regions[0]])

    location = each.key
    # ... configuration
  }
  ```

**2:00 - 2:15 PM: Break**

#### **2:15 - 3:30 PM: Security & Secrets Management**

##### **Service Account Impersonation (2:15 - 2:35 PM)**
- **Why impersonation?**
  - Multi-tenant deployments
  - Separation of concerns
  - Audit trail and security

- **Implementation pattern:**
  ```hcl
  # provider-auth.tf
  provider "google" {
    alias = "impersonated"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/userinfo.email"
    ]
  }

  data "google_service_account_access_token" "default" {
    count                  = length(var.resource_creator_identity) != 0 ? 1 : 0
    provider               = google.impersonated
    target_service_account = var.resource_creator_identity
    lifetime               = "3600s"
    scopes                 = ["cloud-platform", "userinfo-email"]
  }

  provider "google" {
    access_token = length(var.resource_creator_identity) != 0 ?
      data.google_service_account_access_token.default[0].access_token : null
    project      = data.google_project.existing_project.project_id
    region       = local.region
  }
  ```

##### **Secrets Management Best Practices (2:35 - 3:00 PM)**
- **Pattern: Generate, Store, Reference**
  ```hcl
  # 1. Generate random password
  resource "random_password" "db_password" {
    length           = 16
    special          = true
    override_special = "_%@"
  }

  # 2. Create Secret Manager secret
  resource "google_secret_manager_secret" "db_password" {
    project   = local.project.project_id
    secret_id = "cloudsql-${var.application_database_name}dev-password-${var.tenant_deployment_id}-${local.random_id}"

    replication {
      auto {}
    }
  }

  # 3. Store secret value
  resource "google_secret_manager_secret_version" "db_password" {
    secret      = google_secret_manager_secret.db_password.id
    secret_data = random_password.db_password.result
  }

  # 4. Wait for propagation
  resource "time_sleep" "wait_for_secret" {
    depends_on      = [google_secret_manager_secret_version.db_password]
    create_duration = "30s"
  }

  # 5. Reference in Cloud Run service
  resource "google_cloud_run_v2_service" "app" {
    template {
      containers {
        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.db_password.secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  # 6. Grant IAM access to service account
  resource "google_secret_manager_secret_iam_member" "cloudrun_access" {
    secret_id = google_secret_manager_secret.db_password.id
    role      = "roles/secretmanager.secretAccessor"
    member    = "serviceAccount:${local.cloud_run_sa_email}"
  }
  ```

- **Key Principles:**
  - Never hardcode credentials
  - Use Secret Manager for all sensitive data
  - Reference secrets via environment variables
  - Implement proper IAM permissions
  - Use `time_sleep` for propagation delays

##### **IAM and Service Account Management (3:00 - 3:30 PM)**
- **Service Account Pattern:**
  ```hcl
  # sa.tf

  # Check if service account exists
  data "external" "check_cloudrun_sa" {
    program = ["bash", "-c", <<-EOT
      if gcloud iam service-accounts describe cloudrun-sa@${var.existing_project_id}.iam.gserviceaccount.com --project=${var.existing_project_id}; then
        echo '{"exists":"true"}'
      else
        echo '{"exists":"false"}'
      fi
    EOT
    ]
  }

  locals {
    cloudrun_sa_exists = try(data.external.check_cloudrun_sa.result["exists"], "false")
    cloud_run_sa_email = "cloudrun-sa@${local.project.project_id}.iam.gserviceaccount.com"
  }

  # Create service account if it doesn't exist
  resource "google_service_account" "cloud_run_sa" {
    count        = local.cloudrun_sa_exists == "false" ? 1 : 0
    account_id   = "cloudrun-sa"
    display_name = "Cloud Run Service Account"
    project      = local.project.project_id
  }

  # Grant necessary roles
  resource "google_project_iam_member" "cloudrun_sql_client" {
    project = local.project.project_id
    role    = "roles/cloudsql.client"
    member  = "serviceAccount:${local.cloud_run_sa_email}"
  }

  resource "google_project_iam_member" "cloudrun_secret_accessor" {
    project = local.project.project_id
    role    = "roles/secretmanager.secretAccessor"
    member  = "serviceAccount:${local.cloud_run_sa_email}"
  }
  ```

- **Principle of Least Privilege:**
  - Grant only necessary permissions
  - Use specific service accounts for different concerns
  - Separate project-level, Cloud Run, and Cloud SQL service accounts

- **Hands-on Exercise:** Create a secure module with service accounts, secrets, and proper IAM bindings

**3:30 - 3:45 PM: Break**

#### **3:45 - 4:45 PM: Advanced Patterns & Integration**

##### **Cloud Run Services and Jobs (3:45 - 4:05 PM)**
- **Service Pattern with Health Probes:**
  ```hcl
  resource "google_cloud_run_v2_service" "app" {
    name     = "app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev"
    location = local.region

    template {
      service_account = local.cloud_run_sa_email

      containers {
        image = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}/app:${var.application_version}"

        # Startup probe
        startup_probe {
          initial_delay_seconds = 10
          timeout_seconds       = 3
          period_seconds        = 10
          failure_threshold     = 3
          tcp_socket {
            port = 8080
          }
        }

        # Liveness probe
        liveness_probe {
          initial_delay_seconds = 120
          timeout_seconds       = 5
          period_seconds        = 30
          failure_threshold     = 3
          http_get {
            path = "/health"
            port = 8080
          }
        }

        # Resource limits
        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }
      }

      # Auto-scaling
      scaling {
        min_instance_count = 0
        max_instance_count = 10
      }

      # VPC access
      vpc_access {
        network_interfaces {
          network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
          subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${var.subnet_name}"
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }
  }
  ```

- **Jobs Pattern for One-off Tasks:**
  ```hcl
  # Database migration job
  resource "google_cloud_run_v2_job" "migrate" {
    count    = var.configure_development_environment && local.sql_server_exists ? 1 : 0
    name     = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-migrate"
    location = local.region

    template {
      template {
        service_account = local.cloud_run_sa_email

        containers {
          image   = "${local.region}-docker.pkg.dev/${local.project.project_id}/${var.application_name}/app:${var.application_version}"
          command = ["/bin/bash", "-c"]
          args    = ["python manage.py migrate && python manage.py collectstatic --noinput"]

          env {
            name = "DATABASE_URL"
            value_source {
              secret_key_ref {
                secret  = google_secret_manager_secret.database_url.secret_id
                version = "latest"
              }
            }
          }
        }

        vpc_access {
          network_interfaces {
            network    = "projects/${local.project.project_id}/global/networks/${var.network_name}"
            subnetwork = "projects/${local.project.project_id}/regions/${local.region}/subnetworks/${var.subnet_name}"
          }
        }
      }
    }
  }

  # Backup job scheduled via Cloud Scheduler
  resource "google_cloud_scheduler_job" "backup" {
    count    = var.configure_development_environment ? 1 : 0
    name     = "${var.application_name}-backup-${var.tenant_deployment_id}-${local.random_id}-dev"
    schedule = "0 2 * * *"  # Daily at 2 AM

    http_target {
      uri         = "https://${local.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project.project_id}/jobs/${google_cloud_run_v2_job.backup[0].name}:run"
      http_method = "POST"

      oauth_token {
        service_account_email = local.cloud_run_sa_email
      }
    }
  }
  ```

##### **Container Build Automation (4:05 - 4:25 PM)**
- **Pattern: Template + Local-Exec + Cloud Build**
  ```hcl
  # 1. Generate Dockerfile from template
  resource "local_file" "dockerfile" {
    count    = var.configure_development_environment ? 1 : 0
    filename = "${path.module}/scripts/app/Dockerfile"
    content  = templatefile("${path.module}/scripts/app/dockerfile.tpl", {
      APP_VERSION = var.application_version
      APP_RELEASE = var.application_release
      BASE_IMAGE  = var.base_image
    })
  }

  # 2. Generate Cloud Build config
  resource "local_file" "cloudbuild" {
    count    = var.configure_development_environment ? 1 : 0
    filename = "${path.module}/scripts/app/cloudbuild.yaml"
    content  = templatefile("${path.module}/scripts/app/cloudbuild.tpl", {
      PROJECT_ID = local.project.project_id
      REGION     = local.region
      APP_NAME   = var.application_name
    })
  }

  # 3. Create Artifact Registry repository
  resource "google_artifact_registry_repository" "app" {
    count         = var.configure_development_environment ? 1 : 0
    project       = local.project.project_id
    location      = local.region
    repository_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}"
    format        = "DOCKER"
  }

  # 4. Build and push container
  resource "null_resource" "build_container" {
    count = var.configure_development_environment ? 1 : 0

    triggers = {
      script_hash    = filesha256("${path.module}/scripts/app/build-container.sh")
      dockerfile     = filesha256("${path.module}/scripts/app/Dockerfile")
      app_version    = var.application_version
    }

    provisioner "local-exec" {
      interpreter = ["/bin/bash", "-c"]
      working_dir = "${path.module}/scripts/app"
      command     = <<-EOT
        bash build-container.sh "${local.project.project_id}" "${var.resource_creator_identity}"
      EOT
    }

    depends_on = [
      local_file.dockerfile,
      local_file.cloudbuild,
      google_artifact_registry_repository.app
    ]
  }
  ```

##### **Structured Outputs (4:25 - 4:45 PM)**
- **Group outputs by concern:**
  ```hcl
  output "deployment_info" {
    description = "Deployment identification and configuration"
    value = {
      deployment_id = local.random_id
      region        = local.region
      regions       = local.regions
      project_id    = local.project.project_id
      project_number = local.project.number
    }
  }

  output "service_urls" {
    description = "Application service URLs"
    value = {
      dev_url = var.configure_development_environment ?
        "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}dev-${local.project.number}.${local.region}.run.app" : ""

      qa_url = var.configure_nonproduction_environment ?
        "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}qa-${local.project.number}.${local.region}.run.app" : ""

      prod_url = var.configure_production_environment ?
        "https://app${var.application_name}${var.tenant_deployment_id}${local.random_id}prod-${local.project.number}.${local.region}.run.app" : ""
    }
  }

  output "database_info" {
    description = "Cloud SQL database connection information"
    value = {
      instance_name        = local.sql_server_exists ? local.db_instance_name : ""
      instance_ip          = local.sql_server_exists ? local.db_internal_ip : ""
      dev_database_name    = var.configure_development_environment ?
        "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}dev" : ""
      qa_database_name     = var.configure_nonproduction_environment ?
        "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}qa" : ""
      prod_database_name   = var.configure_production_environment ?
        "app${var.application_database_name}${var.tenant_deployment_id}${local.random_id}prod" : ""
    }
    sensitive = false
  }

  output "management_urls" {
    description = "GCP Console management URLs"
    value = {
      cloud_run       = "https://console.cloud.google.com/run?project=${local.project.project_id}"
      cloud_sql       = "https://console.cloud.google.com/sql/instances?project=${local.project.project_id}"
      secret_manager  = "https://console.cloud.google.com/security/secret-manager?project=${local.project.project_id}"
      artifact_registry = "https://console.cloud.google.com/artifacts?project=${local.project.project_id}"
    }
  }
  ```

- **Benefits:**
  - Easy consumption by UI/automation
  - Conditional based on configuration
  - Grouped by logical concern
  - Include management URLs for convenience

#### **4:45 - 5:00 PM: Best Practices Summary & Q&A**

##### **Module Development Best Practices Checklist**
- [ ] **Idempotency:** Check resource existence before creation
- [ ] **Consistent Naming:** Follow `app{name}{tenant}{id}{env}` pattern
- [ ] **File Organization:** Separate concerns into dedicated files
- [ ] **Variable Grouping:** Use UI metadata tags for organization
- [ ] **Environment Separation:** Boolean flags for dev/qa/prod
- [ ] **Multi-Region Support:** Dynamic region handling with `for_each`
- [ ] **Secrets Management:** Always use Secret Manager, never hardcode
- [ ] **Service Accounts:** Implement least privilege with specific SAs
- [ ] **Impersonation:** Use provider impersonation for multi-tenant
- [ ] **Health Probes:** Add startup and liveness probes to services
- [ ] **Resource Limits:** Define CPU/memory limits and auto-scaling
- [ ] **VPC Access:** Configure private networking
- [ ] **Structured Outputs:** Group outputs by concern
- [ ] **Documentation:** Add clear descriptions and examples
- [ ] **Testing:** Validate with `terraform validate` and review plans

##### **Common Pitfalls to Avoid**
1. **Hardcoding values** instead of using variables
2. **Not checking resource existence** leading to creation failures
3. **Mixing concerns** in a single file
4. **Ignoring timing issues** (always use `time_sleep` for Secret Manager)
5. **Over-privileged service accounts**
6. **Not supporting multiple environments**
7. **Hardcoding regions** instead of dynamic discovery
8. **Missing health probes** on Cloud Run services
9. **Not implementing idempotency**
10. **Poor variable organization** without UI metadata

##### **Additional Resources**
- **Terraform Documentation:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Cloud Run:** https://cloud.google.com/run/docs
- **Secret Manager:** https://cloud.google.com/secret-manager/docs
- **Service Accounts Best Practices:** https://cloud.google.com/iam/docs/best-practices-service-accounts
- **RAD Modules Repository:** /home/user/rad-modules/
- **AGENTS.md:** Architectural documentation in repository

##### **Open Q&A Session**
- Questions about patterns
- Troubleshooting common issues
- Discussion of specific use cases
- Next steps and continued learning

---

## Hands-On Exercises Summary

### **Exercise 1: Simple Module (Morning)**
**Objective:** Create a basic Terraform module with variables and conditional resources
**Time:** 30 minutes
**Task:** Build a module that creates a Cloud Storage bucket with optional versioning

### **Exercise 2: Variable Organization (Late Morning)**
**Objective:** Define properly organized variables with UI metadata
**Time:** 30 minutes
**Task:** Create variables.tf for a hypothetical module with proper grouping

### **Exercise 3: Secure Module (Early Afternoon)**
**Objective:** Implement security best practices
**Time:** 45 minutes
**Task:** Build a module with service accounts, secrets management, and IAM bindings

### **Exercise 4: Idempotent Resources (Afternoon)**
**Objective:** Implement resource existence checking
**Time:** 30 minutes
**Task:** Create external data source to check for existing resources

### **Exercise 5: Multi-Environment Service (Afternoon)**
**Objective:** Deploy Cloud Run service with environment separation
**Time:** 45 minutes
**Task:** Create a complete Cloud Run module with dev/qa/prod environments

---

## Required Materials

### **For Participants:**
- Laptop with internet access
- GCP account with project creation permissions
- Terraform installed (v1.0+)
- gcloud CLI installed and authenticated
- Code editor (VS Code recommended with Terraform extension)
- Access to rad-modules repository

### **For Instructor:**
- Presentation slides
- Live demo environment
- Sample code repository with exercises
- Exercise solutions
- GCP project for demonstrations

---

## Post-Training Follow-Up

### **Week 1:**
- Review exercise solutions
- Answer questions via email/Slack
- Share additional resources

### **Week 2:**
- 1-hour follow-up session for troubleshooting
- Review of participants' first module implementations

### **Ongoing:**
- Monthly office hours for module development questions
- Slack channel for continued discussion
- Code review support for new modules

---

## Assessment & Certification

### **Knowledge Check Quiz (Optional)**
- 20 multiple choice questions
- Covering core concepts and best practices
- Pass score: 80%

### **Practical Assessment (Optional)**
**Task:** Build a complete Terraform module that:
- Creates a Cloud Run service
- Implements proper secrets management
- Supports multiple environments
- Uses service account impersonation
- Follows RAD modules patterns
- Includes proper documentation

**Evaluation Criteria:**
- Code organization and structure (25%)
- Security and IAM implementation (25%)
- Idempotency and reliability (20%)
- Documentation and usability (15%)
- Best practices adherence (15%)

---

## Training Materials Repository Structure

```
training-materials/
├── slides/
│   ├── 01-introduction.pdf
│   ├── 02-terraform-fundamentals.pdf
│   ├── 03-rad-architecture.pdf
│   ├── 04-security-patterns.pdf
│   └── 05-advanced-patterns.pdf
├── exercises/
│   ├── exercise-1-simple-module/
│   ├── exercise-2-variables/
│   ├── exercise-3-security/
│   ├── exercise-4-idempotency/
│   └── exercise-5-multi-environment/
├── solutions/
│   └── [corresponding solution directories]
├── reference/
│   ├── rad-modules-quick-reference.pdf
│   ├── terraform-cheat-sheet.pdf
│   └── gcp-resources-guide.pdf
└── README.md
```

---

## Instructor Notes

### **Key Teaching Points:**
1. Emphasize **idempotency** as critical for production reliability
2. Demonstrate **real failures** and recovery patterns
3. Show **diff between modules** to highlight consistency
4. Use **live coding** for complex patterns
5. Encourage **questions throughout** - not just at end
6. Connect patterns to **real-world scenarios**

### **Common Student Questions:**
- "Why not use Terraform workspaces?" → Explain boolean flag approach
- "Can we use modules from Terraform Registry?" → Discuss customization needs
- "How do we test these modules?" → Cover validation strategies
- "What about state management?" → Discuss backend configuration
- "How do we version modules?" → Explain git tags and release strategy

### **Timing Flexibility:**
- If running ahead: Deep dive into CI/CD integration patterns
- If running behind: Shorten Q&A, provide exercise solutions as homework
- Break times are flexible based on energy levels

### **Success Metrics:**
- Participants complete at least 3 out of 5 exercises
- Post-training survey shows 80%+ satisfaction
- At least 70% can explain core RAD patterns
- Participants feel confident to start building their own modules

---

**Version:** 1.0
**Last Updated:** 2025-12-11
**Prepared by:** RAD Modules Team
