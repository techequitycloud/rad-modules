# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

# WordPress Wrapper Module

module "wordpress_app" {
  source = "../WebApp"

  # Module Metadata
  module_description = var.module_description
  module_dependency  = var.module_dependency
  module_services    = var.module_services
  credit_cost        = var.credit_cost
  require_credit_purchases = var.require_credit_purchases
  enable_purge       = var.enable_purge
  public_access      = var.public_access

  # Deployment Configuration
  deployment_id             = var.deployment_id
  agent_service_account     = var.agent_service_account
  resource_creator_identity = var.resource_creator_identity
  trusted_users             = var.trusted_users
  existing_project_id       = var.existing_project_id
  deployment_region         = var.deployment_region

  # Network
  network_name = var.network_name

  # Storage
  create_cloud_storage = var.create_cloud_storage

  # Application Configuration
  application_module        = "wordpress"
  application_name          = var.application_name
  application_display_name  = "WordPress"
  application_version       = var.application_version
  # application_sha is unused by WebApp currently, but we keep it in variables for compatibility

  # Database
  application_database_user = var.application_database_user
  application_database_name = var.application_database_name

  # Tenant
  tenant_deployment_id = var.tenant_deployment_id

  # Environment & Monitoring
  configure_environment = var.configure_environment
  configure_monitoring  = var.configure_monitoring

  # Initialization Jobs
  # Add a job to create the database and user if they don't exist
  initialization_jobs = [
    {
      name        = "init-db"
      description = "Initialize WordPress Database and User"
      image       = "alpine:3.19"
      timeout_seconds = 600
      execution_mode  = "TASK"
      execute_on_apply = true

      command = ["/bin/sh", "-c"]
      args = [<<-EOT
          set -e

          echo "================================================"
          echo "Starting DB Init Job"
          echo "================================================"
          # DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, ROOT_PASSWORD are injected by WebApp
          echo "DB_HOST: $DB_HOST"
          echo "DB_NAME: $DB_NAME"
          echo "DB_USER: $DB_USER"
          echo "================================================"

          # Install required packages
          echo "Installing packages..."
          apk add --no-cache mysql-client netcat-openbsd

          # Test network connectivity
          echo "Testing connectivity to $DB_HOST..."
          # Extract host and port if needed, but DB_HOST usually includes IP (WebApp logic)
          # WebApp injects DB_HOST as IP. DB_PORT is also injected.
          if nc -zv $DB_HOST $DB_PORT 2>&1; then
            echo "✓ Port $DB_PORT is reachable"
          else
            echo "✗ Cannot reach $DB_HOST:$DB_PORT"
            exit 1
          fi

          # Create MySQL configuration file
          echo "Configuring MySQL client..."
          rm -rf ~/.my.cnf
          cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASSWORD
host=$DB_HOST
port=$DB_PORT
EOF
          chmod 600 ~/.my.cnf

          # Verify connection
          echo "Verifying MySQL connection..."
          if mysql --defaults-file=~/.my.cnf -e "SELECT VERSION();" > /dev/null 2>&1; then
             echo "✓ MySQL connection successful"
          else
             echo "✗ MySQL connection failed"
             exit 1
          fi

          # Create User if not exists
          # Note: DB_PASSWORD is the application user password injected by WebApp
          echo "Checking/Creating user $DB_USER..."
          mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF
          echo "✓ User processed"

          # Create Database if not exists
          echo "Checking/Creating database $DB_NAME..."
          mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          echo "✓ Database processed"

          # Grant Privileges
          echo "Granting privileges..."
          mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
GRANT GRANT OPTION ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
          echo "✓ Privileges granted"

          # Clean up
          rm -f ~/.my.cnf

          echo "================================================"
          echo "✓ DB Init Job Completed Successfully"
          echo "================================================"
      EOT
      ]
    }
  ]
}
