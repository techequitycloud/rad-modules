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

module "webapp" {
  source = "../WebApp"

  # Module Selection
  application_module = "n8n"

  # Project & Deployment
  deployment_id        = var.deployment_id
  tenant_deployment_id = var.tenant_deployment_id
  existing_project_id  = var.existing_project_id
  agent_service_account = var.agent_service_account
  resource_creator_identity = var.resource_creator_identity
  deployment_region    = var.deployment_region

  # Metadata
  module_description = var.module_description
  module_dependency  = var.module_dependency
  module_services    = var.module_services
  credit_cost        = var.credit_cost
  require_credit_purchases = var.require_credit_purchases
  enable_purge       = var.enable_purge
  public_access      = var.public_access
  trusted_users      = var.trusted_users

  # Application Config
  application_name          = var.application_name
  application_version       = var.application_version
  application_database_name = var.application_database_name
  application_database_user = var.application_database_user

  # Network
  network_name = var.network_name

  # Environment
  configure_environment = var.configure_environment

  # Monitoring
  # If configure_monitoring is false, disable uptime check (enabled by default in WebApp)
  uptime_check_config = {
    enabled = var.configure_monitoring
    path    = "/"
  }

  # Initialization Job for Database Creation
  initialization_jobs = [
    {
      name             = "db-init"
      image            = "alpine:3.19"
      execute_on_apply = true
      command          = ["/bin/sh", "-c"]
      args             = [<<-EOT
        set -e
        echo "================================================"
        echo "Starting DB Import Job"
        echo "================================================"

        # Verify environment variables (injected by WebApp)
        if [ -z "$DB_HOST" ]; then echo "DB_HOST is missing"; exit 1; fi
        if [ -z "$DB_NAME" ]; then echo "DB_NAME is missing"; exit 1; fi
        if [ -z "$DB_USER" ]; then echo "DB_USER is missing"; exit 1; fi
        if [ -z "$ROOT_PASSWORD" ]; then echo "ROOT_PASSWORD is missing"; exit 1; fi
        if [ -z "$DB_PASSWORD" ]; then echo "DB_PASSWORD is missing"; exit 1; fi

        echo "DB_HOST: $DB_HOST"
        echo "DB_NAME: $DB_NAME"
        echo "DB_USER: $DB_USER"
        echo "================================================"

        # Install required packages
        echo "Installing packages..."
        apk add --no-cache postgresql-client netcat-openbsd

        # Test network connectivity
        echo "Testing connectivity to $DB_HOST on port 5432..."
        # DB_HOST might include port? WebApp injects IP. Port is 5432.
        if nc -zv $DB_HOST 5432 2>&1; then
          echo "✓ Port 5432 is reachable"
        else
          echo "✗ Cannot reach $DB_HOST:5432"
          exit 1
        fi

        # Set passwords for psql
        export PGPASSWORD=$ROOT_PASSWORD

        # Test PostgreSQL connection
        echo "Testing PostgreSQL connection..."
        if psql -h $DB_HOST -U postgres -d postgres -c "SELECT version();" > /dev/null 2>&1; then
          echo "✓ PostgreSQL connection successful"
        else
          echo "✗ PostgreSQL connection failed"
          # Try to get error details
          psql -h $DB_HOST -U postgres -d postgres -c "SELECT version();" || true
          exit 1
        fi

        # Create/Update Role
        echo "Creating/updating database role..."
        psql -h $DB_HOST -U postgres -d postgres <<SQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
            CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';
            RAISE NOTICE 'Role $DB_USER created';
          ELSE
            ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASSWORD';
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

        echo "================================================"
        echo "✓ DB Import Job Completed Successfully"
        echo "================================================"
      EOT
      ]
    }
  ]
}
