# Copyright 2024 Tech Equity Ltd
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

resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "random_password" "dev_superuser_password" {
  length  = 16
  special = false
}

resource "random_password" "qa_superuser_password" {
  length  = 16
  special = false
}

resource "random_password" "prod_superuser_password" {
  length  = 16
  special = false
}

# --- Dev Secrets ---

resource "google_secret_manager_secret" "dev_application_settings" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-application-settings"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_application_settings" {
  secret      = google_secret_manager_secret.dev_application_settings.id
  secret_data = <<EOT
DEBUG=True
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME="${google_storage_bucket.dev_storage.name}"
EOT
}

resource "google_secret_manager_secret" "dev_superuser_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-superuser-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "dev_superuser_password" {
  secret      = google_secret_manager_secret.dev_superuser_password.id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.dev_superuser_password.result
}

# --- QA Secrets ---

resource "google_secret_manager_secret" "qa_application_settings" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-application-settings"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "qa_application_settings" {
  secret      = google_secret_manager_secret.qa_application_settings.id
  secret_data = <<EOT
DEBUG=False
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME="${google_storage_bucket.qa_storage.name}"
EOT
}

resource "google_secret_manager_secret" "qa_superuser_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-superuser-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "qa_superuser_password" {
  secret      = google_secret_manager_secret.qa_superuser_password.id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.qa_superuser_password.result
}

# --- Prod Secrets ---

resource "google_secret_manager_secret" "prod_application_settings" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-application-settings"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "prod_application_settings" {
  secret      = google_secret_manager_secret.prod_application_settings.id
  secret_data = <<EOT
DEBUG=False
SECRET_KEY="${random_password.django_secret_key.result}"
GS_BUCKET_NAME="${google_storage_bucket.prod_storage.name}"
EOT
}

resource "google_secret_manager_secret" "prod_superuser_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-superuser-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

resource "google_secret_manager_secret_version" "prod_superuser_password" {
  secret      = google_secret_manager_secret.prod_superuser_password.id
  secret_data = var.django_superuser_password != null ? var.django_superuser_password : random_password.prod_superuser_password.result
}

# --- Additional Database Password Secrets (Required for Scripts) ---

resource "google_secret_manager_secret" "dev_db_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-dev-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

# Remove password version resource (managed by script)
# Keep data source but depends_on null_resource (script)

data "google_secret_manager_secret_version" "dev_db_password" {
  secret  = google_secret_manager_secret.dev_db_password.id
  version = "latest"
  depends_on = [null_resource.dev_user_setup]
}

resource "google_secret_manager_secret" "qa_db_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-qa-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

data "google_secret_manager_secret_version" "qa_db_password" {
  secret  = google_secret_manager_secret.qa_db_password.id
  version = "latest"
  depends_on = [null_resource.qa_user_setup]
}

resource "google_secret_manager_secret" "prod_db_password" {
  secret_id = "${var.application_name}-${var.tenant_deployment_id}-${local.random_id}-prod-db-password"
  replication {
    user_managed {
      replicas {
        location = local.region
      }
    }
  }
  project = local.project.project_id
}

data "google_secret_manager_secret_version" "prod_db_password" {
  secret  = google_secret_manager_secret.prod_db_password.id
  version = "latest"
  depends_on = [null_resource.prod_user_setup]
}
