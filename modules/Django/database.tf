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

#########################################################################
# Cleanup Resources (executed on destroy)
#########################################################################

# Cleanup script for dev database objects
resource "null_resource" "cleanup_dev_db_objects" {
  triggers = {
    user     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-dev"
    database = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "Cleaning up database objects for ${self.triggers.user} in ${self.triggers.database}"
      
      # Check if database exists first
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -z "$DB_EXISTS" ]; then
        echo "Database ${self.triggers.database} does not exist, skipping cleanup"
        exit 0
      fi
      
      # Check if user exists before attempting cleanup
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "User ${self.triggers.user} exists, performing cleanup..."
        gcloud sql connect ${self.triggers.instance} \
          --user=postgres \
          --database=${self.triggers.database} \
          --project=${self.triggers.project} \
          --quiet <<SQL || echo "Cleanup failed, continuing..."
        REASSIGN OWNED BY "${self.triggers.user}" TO postgres;
        DROP OWNED BY "${self.triggers.user}";
SQL
      else
        echo "User ${self.triggers.user} does not exist, skipping cleanup"
      fi
    EOT
    on_failure = continue
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Cleanup script for qa database objects
resource "null_resource" "cleanup_qa_db_objects" {
  triggers = {
    user     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-qa"
    database = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "Cleaning up database objects for ${self.triggers.user} in ${self.triggers.database}"
      
      # Check if database exists first
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -z "$DB_EXISTS" ]; then
        echo "Database ${self.triggers.database} does not exist, skipping cleanup"
        exit 0
      fi
      
      # Check if user exists before attempting cleanup
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "User ${self.triggers.user} exists, performing cleanup..."
        gcloud sql connect ${self.triggers.instance} \
          --user=postgres \
          --database=${self.triggers.database} \
          --project=${self.triggers.project} \
          --quiet <<SQL || echo "Cleanup failed, continuing..."
        REASSIGN OWNED BY "${self.triggers.user}" TO postgres;
        DROP OWNED BY "${self.triggers.user}";
SQL
      else
        echo "User ${self.triggers.user} does not exist, skipping cleanup"
      fi
    EOT
    on_failure = continue
  }

  lifecycle {
    create_before_destroy = false
  }
}

# Cleanup script for prod database objects
resource "null_resource" "cleanup_prod_db_objects" {
  triggers = {
    user     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-prod"
    database = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "Cleaning up database objects for ${self.triggers.user} in ${self.triggers.database}"
      
      # Check if database exists first
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -z "$DB_EXISTS" ]; then
        echo "Database ${self.triggers.database} does not exist, skipping cleanup"
        exit 0
      fi
      
      # Check if user exists before attempting cleanup
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "User ${self.triggers.user} exists, performing cleanup..."
        gcloud sql connect ${self.triggers.instance} \
          --user=postgres \
          --database=${self.triggers.database} \
          --project=${self.triggers.project} \
          --quiet <<SQL || echo "Cleanup failed, continuing..."
        REASSIGN OWNED BY "${self.triggers.user}" TO postgres;
        DROP OWNED BY "${self.triggers.user}";
SQL
      else
        echo "User ${self.triggers.user} does not exist, skipping cleanup"
      fi
    EOT
    on_failure = continue
  }

  lifecycle {
    create_before_destroy = false
  }
}

#########################################################################
# Create Database and User - DEV
#########################################################################

resource "google_sql_database" "dev_db" {
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-dev"
  instance = local.db_instance_name
  project  = local.project.project_id

  deletion_policy = "DELETE"

  lifecycle {
    prevent_destroy = false
  }
}

resource "random_password" "dev_db_password" {
  length  = 30
  special = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_sql_user" "dev_user" {
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-dev"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.dev_db_password.result

  # ABANDON means Terraform won't try to delete the user
  # We handle deletion via null_resource which checks existence first
  deletion_policy = "ABANDON"

  depends_on = [
    google_sql_database.dev_db
  ]

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

#########################################################################
# Create Database and User - QA
#########################################################################

resource "google_sql_database" "qa_db" {
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-qa"
  instance = local.db_instance_name
  project  = local.project.project_id

  deletion_policy = "DELETE"

  lifecycle {
    prevent_destroy = false
  }
}

resource "random_password" "qa_db_password" {
  length  = 30
  special = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_sql_user" "qa_user" {
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-qa"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.qa_db_password.result

  # ABANDON means Terraform won't try to delete the user
  # We handle deletion via null_resource which checks existence first
  deletion_policy = "ABANDON"

  depends_on = [
    google_sql_database.qa_db
  ]

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

#########################################################################
# Create Database and User - PROD
#########################################################################

resource "google_sql_database" "prod_db" {
  name     = "${var.application_database_name}-${var.tenant_deployment_id}-${local.random_id}-prod"
  instance = local.db_instance_name
  project  = local.project.project_id

  deletion_policy = "DELETE"

  lifecycle {
    prevent_destroy = false
  }
}

resource "random_password" "prod_db_password" {
  length  = 30
  special = false

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_sql_user" "prod_user" {
  name     = "${var.application_database_user}-${var.tenant_deployment_id}-${local.random_id}-prod"
  instance = local.db_instance_name
  project  = local.project.project_id
  password = random_password.prod_db_password.result

  # ABANDON means Terraform won't try to delete the user
  # We handle deletion via null_resource which checks existence first
  deletion_policy = "ABANDON"

  depends_on = [
    google_sql_database.prod_db
  ]

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [password]
  }
}

#########################################################################
# Force delete users (handles actual deletion with existence checks)
#########################################################################

resource "null_resource" "force_delete_dev_user" {
  triggers = {
    user     = google_sql_user.dev_user.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting dev user: ${self.triggers.user}"
      echo "========================================="
      
      # Check if user exists
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "✓ User exists, attempting deletion..."
        if gcloud sql users delete "${self.triggers.user}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ User deleted successfully"
        else
          echo "⚠ User deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ User ${self.triggers.user} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.cleanup_dev_db_objects
  ]

  lifecycle {
    create_before_destroy = false
  }
}

resource "null_resource" "force_delete_qa_user" {
  triggers = {
    user     = google_sql_user.qa_user.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting qa user: ${self.triggers.user}"
      echo "========================================="
      
      # Check if user exists
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "✓ User exists, attempting deletion..."
        if gcloud sql users delete "${self.triggers.user}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ User deleted successfully"
        else
          echo "⚠ User deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ User ${self.triggers.user} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.cleanup_qa_db_objects
  ]

  lifecycle {
    create_before_destroy = false
  }
}

resource "null_resource" "force_delete_prod_user" {
  triggers = {
    user     = google_sql_user.prod_user.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting prod user: ${self.triggers.user}"
      echo "========================================="
      
      # Check if user exists
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -n "$USER_EXISTS" ]; then
        echo "✓ User exists, attempting deletion..."
        if gcloud sql users delete "${self.triggers.user}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ User deleted successfully"
        else
          echo "⚠ User deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ User ${self.triggers.user} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.cleanup_prod_db_objects
  ]

  lifecycle {
    create_before_destroy = false
  }
}

#########################################################################
# Force delete databases (backup cleanup method)
#########################################################################

resource "null_resource" "force_delete_dev_db" {
  triggers = {
    database = google_sql_database.dev_db.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting dev database: ${self.triggers.database}"
      echo "========================================="
      
      # Check if database exists
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -n "$DB_EXISTS" ]; then
        echo "✓ Database exists, attempting deletion..."
        if gcloud sql databases delete "${self.triggers.database}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ Database deleted successfully"
        else
          echo "⚠ Database deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ Database ${self.triggers.database} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.force_delete_dev_user
  ]

  lifecycle {
    create_before_destroy = false
  }
}

resource "null_resource" "force_delete_qa_db" {
  triggers = {
    database = google_sql_database.qa_db.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting qa database: ${self.triggers.database}"
      echo "========================================="
      
      # Check if database exists
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -n "$DB_EXISTS" ]; then
        echo "✓ Database exists, attempting deletion..."
        if gcloud sql databases delete "${self.triggers.database}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ Database deleted successfully"
        else
          echo "⚠ Database deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ Database ${self.triggers.database} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.force_delete_qa_user
  ]

  lifecycle {
    create_before_destroy = false
  }
}

resource "null_resource" "force_delete_prod_db" {
  triggers = {
    database = google_sql_database.prod_db.name
    instance = local.db_instance_name
    project  = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Checking and deleting prod database: ${self.triggers.database}"
      echo "========================================="
      
      # Check if database exists
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -n "$DB_EXISTS" ]; then
        echo "✓ Database exists, attempting deletion..."
        if gcloud sql databases delete "${self.triggers.database}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ Database deleted successfully"
        else
          echo "⚠ Database deletion failed (may have been deleted externally)"
        fi
      else
        echo "✓ Database ${self.triggers.database} does not exist, skipping deletion"
      fi
      
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.force_delete_prod_user
  ]

  lifecycle {
    create_before_destroy = false
  }
}

#########################################################################
# Master cleanup orchestrator (runs last on destroy)
#########################################################################

resource "null_resource" "final_cleanup" {
  triggers = {
    dev_user  = google_sql_user.dev_user.name
    qa_user   = google_sql_user.qa_user.name
    prod_user = google_sql_user.prod_user.name
    dev_db    = google_sql_database.dev_db.name
    qa_db     = google_sql_database.qa_db.name
    prod_db   = google_sql_database.prod_db.name
    instance  = local.db_instance_name
    project   = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Final cleanup verification"
      echo "========================================="
      
      # List all remaining users
      echo "Checking for remaining database users..."
      REMAINING_USERS=$(gcloud sql users list \
        --instance=${self.triggers.instance} \
        --project=${self.triggers.project} \
        --format="value(name)" 2>/dev/null | grep -E "${self.triggers.dev_user}|${self.triggers.qa_user}|${self.triggers.prod_user}" || echo "")
      
      if [ -n "$REMAINING_USERS" ]; then
        echo "⚠ WARNING: Found remaining users:"
        echo "$REMAINING_USERS"
        echo "Attempting final cleanup..."
        
        # Force delete any remaining users
        echo "$REMAINING_USERS" | while read user; do
          if [ -n "$user" ]; then
            echo "Deleting user: $user"
            gcloud sql users delete "$user" \
              --instance="${self.triggers.instance}" \
              --project="${self.triggers.project}" \
              --quiet 2>/dev/null || echo "⚠ Failed to delete $user (may not exist)"
          fi
        done
      else
        echo "✓ All users successfully deleted"
      fi
      
      # List all remaining databases
      echo ""
      echo "Checking for remaining databases..."
      REMAINING_DBS=$(gcloud sql databases list \
        --instance=${self.triggers.instance} \
        --project=${self.triggers.project} \
        --format="value(name)" 2>/dev/null | grep -E "${self.triggers.dev_db}|${self.triggers.qa_db}|${self.triggers.prod_db}" || echo "")
      
      if [ -n "$REMAINING_DBS" ]; then
        echo "⚠ WARNING: Found remaining databases:"
        echo "$REMAINING_DBS"
        echo "Attempting final cleanup..."
        
        # Force delete any remaining databases
        echo "$REMAINING_DBS" | while read db; do
          if [ -n "$db" ]; then
            echo "Deleting database: $db"
            gcloud sql databases delete "$db" \
              --instance="${self.triggers.instance}" \
              --project="${self.triggers.project}" \
              --quiet 2>/dev/null || echo "⚠ Failed to delete $db (may not exist)"
          fi
        done
      else
        echo "✓ All databases successfully deleted"
      fi
      
      echo ""
      echo "========================================="
      echo "✓ Cleanup verification complete"
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.force_delete_dev_user,
    null_resource.force_delete_qa_user,
    null_resource.force_delete_prod_user,
    null_resource.force_delete_dev_db,
    null_resource.force_delete_qa_db,
    null_resource.force_delete_prod_db
  ]

  lifecycle {
    create_before_destroy = false
  }
}
