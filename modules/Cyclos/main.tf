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

# ===========================
# 1. Main Configuration
# ===========================

# Generate random deployment ID if not provided
resource "random_id" "deployment" {
  byte_length = 4
}

locals {
  # Deployment identifiers
  random_id     = random_id.deployment.hex
  deployment_id = var.deployment_id != null ? var.deployment_id : local.random_id
  
  # Script to import DB, create user/DB if not exists, install extensions, and restore backup
  # This combines logic that usually is split in WebApp, but is unified here for Cyclos specific needs
  # and order of operations (Extensions require DB to exist).
  import_db_script = <<-EOT
    set -e

    echo "================================================"
    echo "Starting DB Import Job"
    echo "================================================"
    echo "DB_HOST: $DB_HOST"
    echo "DB_NAME: $DB_NAME"
    echo "DB_USER: $DB_USER"
    echo "BACKUP_FILEID: $BACKUP_FILEID"
    echo "================================================"

    # Install required packages
    echo "Installing packages..."
    apk add --no-cache postgresql-client python3 py3-pip unzip curl netcat-openbsd

    # Install gdown
    echo "Installing gdown..."
    pip3 install gdown --break-system-packages

    # Test network connectivity
    echo "Testing connectivity to $DB_HOST on port 5432..."
    if nc -zv $DB_HOST 5432 2>&1; then
      echo "✓ Port 5432 is reachable"
    else
      echo "✗ Cannot reach $DB_HOST:5432"
      exit 1
    fi

    # Set passwords from injected env vars (ROOT_PASSWORD, DB_PASSWORD)
    export PGPASSWORD=$ROOT_PASSWORD
    export DB_PASS=$DB_PASSWORD

    # Test PostgreSQL connection
    echo "Testing PostgreSQL connection..."
    if psql -h $DB_HOST -U postgres -d postgres -c "SELECT version();" > /dev/null 2>&1; then
      echo "✓ PostgreSQL connection successful"
    else
      echo "✗ PostgreSQL connection failed"
      echo "Attempting to get more details..."
      psql -h $DB_HOST -U postgres -d postgres -c "SELECT version();" || true
      exit 1
    fi

    # Create/Update Role
    echo "Creating/updating database role..."
    psql -h $DB_HOST -U postgres -d postgres <<SQL
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
        RAISE NOTICE 'Role $DB_USER created';
      ELSE
        ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';
        RAISE NOTICE 'Role $DB_USER updated';
      END IF;
    END
    \$\$;
    ALTER ROLE $DB_USER CREATEDB;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO $DB_USER;
    GRANT $DB_USER TO postgres;
SQL

    # Create Database if not exists
    echo "Checking if database exists..."
    if ! psql -h $DB_HOST -U postgres -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
      echo "Creating database $DB_NAME..."
      psql -h $DB_HOST -U postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
      echo "✓ Database created"
    else
      echo "✓ Database $DB_NAME already exists"
    fi

    # Install Extensions
    echo "Installing PostgreSQL extensions..."
    psql -h $DB_HOST -U postgres -d $DB_NAME <<'SQL'
    CREATE EXTENSION IF NOT EXISTS cube;
    CREATE EXTENSION IF NOT EXISTS earthdistance;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS unaccent;
    SQL
    echo "✓ Extensions installed"

    # Download and Restore Backup if provided
    if [ -n "$BACKUP_FILEID" ]; then
      echo "Downloading backup from Google Drive..."
      echo "File ID: $BACKUP_FILEID"

      BACKUP_FILE="$DB_NAME.zip"
      if gdown $BACKUP_FILEID -O "$BACKUP_FILE"; then
        echo "✓ Backup downloaded"

        if [ -f "$BACKUP_FILE" ]; then
          echo "Extracting backup..."
          unzip -q "$BACKUP_FILE" -d restore_dir
          echo "✓ Backup extracted"

          export PGPASSWORD=$DB_PASS

          # Find dump.sql
          DUMP_FILE=$(find restore_dir -name "dump.sql" | head -n 1)

          if [ -n "$DUMP_FILE" ]; then
            echo "Restoring database from $DUMP_FILE..."
            if psql -h $DB_HOST -U $DB_USER -d $DB_NAME < "$DUMP_FILE"; then
              echo "✓ Database restore complete"
            else
              echo "✗ Database restore failed"
              exit 1
            fi
          else
            echo "✗ dump.sql not found in zip archive"
            echo "Contents of restore_dir:"
            find restore_dir -type f
            exit 1
          fi
        else
          echo "✗ Zip file not found after download"
          exit 1
        fi
      else
        echo "✗ Failed to download backup"
        exit 1
      fi
    else
      echo "ℹ No backup file specified, skipping restore"
    fi

    echo "================================================"
    echo "✓ DB Import Job Completed Successfully"
    echo "================================================"
  EOT
}

module "webapp" {
  source = "../../modules/WebApp"

  # Basic Configuration
  existing_project_id      = var.existing_project_id
  deployment_id            = local.deployment_id
  tenant_deployment_id     = var.tenant_deployment_id
  deployment_region        = var.deployment_region

  # Application Module Selection
  application_module       = "cyclos"

  # Resource Naming & Config Overrides (from variables if set)
  application_name          = var.application_name
  application_database_name = var.application_database_name
  application_database_user = var.application_database_user
  application_version       = var.application_version

  # Service Accounts & Security
  agent_service_account     = var.agent_service_account
  resource_creator_identity = var.resource_creator_identity
  trusted_users             = var.trusted_users

  # Network
  network_name              = var.network_name

  # Toggles
  configure_environment     = var.configure_environment
  configure_monitoring      = var.configure_monitoring
  public_access             = var.public_access
  enable_purge              = var.enable_purge

  # Disable built-in extensions and backup because we handle them in the custom job
  # (Custom job handles DB creation which must happen before extensions)
  enable_postgres_extensions = false
  enable_backup_import       = false

  # Custom Initialization Job
  initialization_jobs = [
    {
      name             = "import-db"
      description      = "Creates DB, installs extensions, and imports backup"
      image            = "alpine:3.19"
      command          = ["/bin/sh", "-c"]
      args             = [local.import_db_script]
      timeout_seconds  = 600
      max_retries      = 0
      execute_on_apply = true
      env_vars = {
        BACKUP_FILEID = var.application_backup_fileid
      }
      # DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, ROOT_PASSWORD are injected by WebApp automatically
    }
  ]
}
