# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Odoo ERP Preset Configuration
#########################################################################

locals {
  odoo_module = {
    app_name        = "odoo"
    description     = "Odoo ERP System - CRM, e-commerce, billing, accounting, manufacturing, warehouse, project management"
    container_image = "odoo:18.0"
    image_source    = "prebuilt"
    container_port  = 8069
    database_type   = "POSTGRES_15"
    db_name         = "odoo"
    db_user         = "odoo"

    # Performance optimization
    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = ""

    # NFS Configuration
    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    # ✅ UPDATED: GCS volumes for addons only
    gcs_volumes = [
      {
        name       = "odoo-addons-volume"
        mount_path = "/mnt/extra-addons"
        read_only  = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
      }
    ]

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    # ✅ UPDATED: Container command includes /mnt/extra-addons
    container_command = ["/bin/bash", "-c"]
    container_args = [
      "echo 'Starting Odoo...' && echo 'Config file: /mnt/odoo.conf' && if [ ! -f /mnt/odoo.conf ]; then echo 'Error: /mnt/odoo.conf not found. Ensure generate-config job ran.'; exit 1; fi && exec odoo -c /mnt/odoo.conf"
    ]

    # Environment variables
    environment_variables = {
      SMTP_HOST     = ""
      SMTP_PORT     = "25"
      SMTP_USER     = ""
      SMTP_PASSWORD = ""
      SMTP_SSL      = "false"
      EMAIL_FROM    = "odoo@example.com"
    }

    # ✅ UPDATED: Initialization Jobs (restored nfs-init, removed gcs checks for filestore)
    initialization_jobs = [
      {
        name            = "nfs-init"
        description     = "Initialize NFS directories for Odoo"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          "mkdir -p /mnt/filestore /mnt/sessions /mnt/backups && chown -R 101:101 /mnt/filestore /mnt/sessions /mnt/backups && echo 'NFS directories initialized successfully with UID 101' && ls -la /mnt/"
        ]
        mount_nfs        = true
        execute_on_apply = true
      },
      {
        name            = "db-init"
        description     = "Create Odoo Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache postgresql-client

            echo "Waiting for database..."
            export PGPASSWORD=$ROOT_PASSWORD
            until psql -h $DB_HOST -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database connection..."
              sleep 2
            done

            echo "Creating Role $DB_USER if not exists..."
            psql -h $DB_HOST -p 5432 -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
                CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
              ELSE
                ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
              END IF;
            END
            \$\$;
            ALTER ROLE "$DB_USER" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
            EOF

            echo "Creating Database $DB_NAME if not exists..."
            if ! psql -h $DB_HOST -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
              echo "Database does not exist. Creating as $DB_USER..."
              export PGPASSWORD=$DB_PASSWORD
              psql -h $DB_HOST -p 5432 -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
            else
              echo "Database $DB_NAME already exists."
            fi

            echo "Granting privileges..."
            export PGPASSWORD=$ROOT_PASSWORD
            psql -h $DB_HOST -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      },
      {
        name            = "generate-config"
        description     = "Generate Odoo configuration file"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        script_path     = "${path.module}/../../scripts/odoo/odoo-gen-config.sh"
        mount_nfs       = true
        execute_on_apply = true
      },
      {
        name            = "odoo-init"
        description     = "Initialize Odoo database"
        image           = null # Uses default container image (odoo)
        command         = ["/bin/bash", "-c"]
        args            = [
          "echo 'Verifying mount points...' && echo 'NFS (/mnt):' && ls -la /mnt/ && echo 'GCS Addons:' && ls -la /mnt/extra-addons && echo 'Starting Odoo initialization...' && odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info"
        ]
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons-volume"]
        depends_on_jobs   = ["generate-config"]
        execute_on_apply  = true
      }
    ]

    # PostgreSQL extensions
    enable_postgres_extensions = false
    postgres_extensions         = []

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 180
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/web/health"
      initial_delay_seconds = 120
      timeout_seconds       = 60
      period_seconds        = 120
      failure_threshold     = 3
    }
  }
}

output "odoo_module" {
  description = "odoo application module configuration"
  value       = local.odoo_module
}
