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

    # Storage volumes (Addons)
    gcs_volumes = [{
      name       = "odoo-addons-volume"
      mount_path = "/extra-addons"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "uid=101",
        "gid=101",
        "file-mode=644",
        "dir-mode=755",
        "metadata-cache-ttl-secs=60"
      ]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 1
    max_instance_count = 1

    # ✅ PRODUCTION-READY: Direct command-line arguments (no file I/O)
    container_command = ["/bin/bash", "-c"]
    container_args = [
      "echo 'Starting Odoo with DB: $DB_HOST' && exec odoo --db_host=\"$DB_HOST\" --db_port=5432 --db_user=\"$DB_USER\" --db_password=\"$DB_PASSWORD\" --data-dir=/mnt/filestore --addons-path=/usr/lib/python3/dist-packages/odoo/addons,/extra-addons --http-port=8069 --logfile=False --log-level=info"
    ]

    # Environment variables (DB credentials will be injected)
    environment_variables = {}

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "nfs-init"
        description     = "Initialize NFS directories for Odoo"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          "mkdir -p /mnt/filestore /mnt/sessions /mnt/addons /mnt/backups && chmod 777 /mnt/filestore /mnt/sessions /mnt/addons /mnt/backups"
        ]
        mount_nfs       = true
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
        name            = "odoo-init"
        description     = "Initialize Odoo database"
        image           = null # Uses default container image (odoo)
        command         = ["/bin/bash", "-c"]
        args            = [
          "odoo -d $DB_NAME --db_host=$DB_HOST --db_port=5432 --db_user=$DB_USER --db_password=$DB_PASSWORD --data-dir=/mnt/filestore --addons-path=/usr/lib/python3/dist-packages/odoo/addons,/extra-addons -i base --stop-after-init --log-level=info"
        ]
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons-volume"]
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
