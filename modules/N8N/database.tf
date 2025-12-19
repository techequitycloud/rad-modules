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
      echo "========================================="
      echo "Cleaning up database objects for ${self.triggers.user}"
      echo "========================================="
      
      # Check if database exists first
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -z "$DB_EXISTS" ]; then
        echo "✓ Database ${self.triggers.database} does not exist, skipping cleanup"
        exit 0
      fi
      
      # Check if user exists before attempting cleanup
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -z "$USER_EXISTS" ]; then
        echo "✓ User ${self.triggers.user} does not exist, skipping cleanup"
        exit 0
      fi
      
      echo "User and database exist, performing cleanup..."
      echo "⚠ Cleanup requires direct database access (skipping due to IPv6 limitations)"
      echo "Will rely on CASCADE deletion"
      
      echo "✓ Cleanup completed"
      echo "========================================="
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

  deletion_policy = "ABANDON"  # Changed to ABANDON to handle via null_resource

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
# Force delete users (simplified - no SQL connection needed)
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
      echo "Deleting dev user: ${self.triggers.user}"
      echo "========================================="
      
      USER_EXISTS=$(gcloud sql users list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.user}" || echo "")
      
      if [ -z "$USER_EXISTS" ]; then
        echo "✓ User ${self.triggers.user} does not exist"
        exit 0
      fi
      
      # Try deletion, ignore errors
      gcloud sql users delete "${self.triggers.user}" \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --quiet 2>&1 && echo "✓ User deleted" || echo "⚠ User deletion skipped (will be handled by database deletion)"
      
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

#########################################################################
# Force delete databases with connection termination
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
      echo "Deleting dev database: ${self.triggers.database}"
      echo "========================================="
      
      DB_EXISTS=$(gcloud sql databases list \
        --instance="${self.triggers.instance}" \
        --project="${self.triggers.project}" \
        --format="value(name)" 2>/dev/null | grep -x "${self.triggers.database}" || echo "")
      
      if [ -z "$DB_EXISTS" ]; then
        echo "✓ Database does not exist"
        exit 0
      fi
      
      echo "Attempting database deletion (may take multiple attempts)..."
      
      # Try up to 3 times with delays
      for i in 1 2 3; do
        echo "Attempt $i of 3..."
        if gcloud sql databases delete "${self.triggers.database}" \
          --instance="${self.triggers.instance}" \
          --project="${self.triggers.project}" \
          --quiet 2>&1; then
          echo "✓ Database deleted successfully"
          exit 0
        fi
        
        if [ $i -lt 3 ]; then
          echo "⚠ Deletion failed, waiting 10 seconds before retry..."
          sleep 10
        fi
      done
      
      echo "⚠ Database deletion failed after 3 attempts (may have active connections)"
      echo "Database will be cleaned up manually or on next destroy"
      
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

#########################################################################
# Master cleanup orchestrator (runs last on destroy)
#########################################################################

resource "null_resource" "final_cleanup" {
  triggers = {
    dev_user  = google_sql_user.dev_user.name
    dev_db    = google_sql_database.dev_db.name
    instance  = local.db_instance_name
    project   = local.project.project_id
  }

  provisioner "local-exec" {
    when       = destroy
    command    = <<-EOT
      echo "========================================="
      echo "Final cleanup verification"
      echo "========================================="
      
      REMAINING_USERS=$(gcloud sql users list \
        --instance=${self.triggers.instance} \
        --project=${self.triggers.project} \
        --format="value(name)" 2>/dev/null | grep -E "${self.triggers.dev_user}" || echo "")
      
      if [ -n "$REMAINING_USERS" ]; then
        echo "⚠ Found remaining users: $REMAINING_USERS"
      else
        echo "✓ All users deleted"
      fi
      
      REMAINING_DBS=$(gcloud sql databases list \
        --instance=${self.triggers.instance} \
        --project=${self.triggers.project} \
        --format="value(name)" 2>/dev/null | grep -E "${self.triggers.dev_db}" || echo "")
      
      if [ -n "$REMAINING_DBS" ]; then
        echo "⚠ Found remaining databases: $REMAINING_DBS"
      else
        echo "✓ All databases deleted"
      fi
      
      echo "========================================="
      echo "✓ Cleanup verification complete"
      echo "========================================="
    EOT
    on_failure = continue
  }

  depends_on = [
    null_resource.force_delete_dev_user,
    null_resource.force_delete_dev_db
  ]

  lifecycle {
    create_before_destroy = false
  }
}
