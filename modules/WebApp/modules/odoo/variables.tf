# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

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

    enable_cloudsql_volume     = false
    cloudsql_volume_mount_path = ""

    nfs_enabled    = true
    nfs_mount_path = "/mnt"

    gcs_volumes = [
      {
        name          = "odoo-addons-volume"
        mount_path    = "/mnt/extra-addons"
        read_only     = false
        mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
      }
    ]

    container_resources = {
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
    min_instance_count = 0
    max_instance_count = 3

    container_command = ["/bin/bash", "-c"]
    container_args = [
      <<-EOT
        set -e
        echo "=========================================="
        echo "Starting Odoo Server"
        echo "=========================================="
        
        # Verify configuration
        if [ ! -f /mnt/odoo.conf ]; then
            echo "ERROR: /mnt/odoo.conf not found"
            exit 1
        fi
        
        # Verify filestore directory exists and is writable
        if [ ! -d /mnt/filestore ]; then
            echo "ERROR: /mnt/filestore not found"
            exit 1
        fi
        
        # Test write permissions
        if ! touch /mnt/filestore/.test 2>/dev/null; then
            echo "ERROR: Cannot write to /mnt/filestore"
            ls -la /mnt/filestore/
            exit 1
        fi
        rm -f /mnt/filestore/.test
        
        echo "✅ All checks passed"
        echo "Starting Odoo server..."
        exec odoo -c /mnt/odoo.conf
      EOT
    ]

    environment_variables = {
      SMTP_HOST     = ""
      SMTP_PORT     = "25"
      SMTP_USER     = ""
      SMTP_PASSWORD = ""
      SMTP_SSL      = "false"
      EMAIL_FROM    = "odoo@example.com"
    }

    initialization_jobs = [
      # Job 1: NFS Initialization
      {
        name            = "nfs-init"
        description     = "Initialize NFS directories for Odoo"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=========================================="
            echo "NFS Initialization"
            echo "=========================================="
            
            # Show current state
            echo "Current /mnt contents:"
            ls -la /mnt/ 2>/dev/null || echo "Empty or not accessible"
            
            # Create directories
            echo "Creating directories..."
            mkdir -p /mnt/filestore /mnt/sessions /mnt/backups
            
            # Try to set ownership, fall back to 777 if it fails
            echo "Setting ownership to UID 101 (Odoo user)..."
            if chown -R 101:101 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null; then
              echo "✅ Ownership set successfully"
              chmod -R 755 /mnt/filestore /mnt/sessions /mnt/backups
            else
              echo "⚠️  chown failed (NFS limitation), using 777 permissions..."
              chmod -R 777 /mnt/filestore /mnt/sessions /mnt/backups
            fi
            
            # Verify
            echo "✅ Directories created"
            echo "Directory listing:"
            ls -la /mnt/
            
            echo "Filestore contents:"
            ls -la /mnt/filestore/ 2>/dev/null || echo "Empty"
            
            echo "✅ NFS initialization complete"
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 2: Database Initialization (runs in parallel with nfs-init)
      {
        name            = "db-init"
        description     = "Create Odoo Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=========================================="
            echo "Database Initialization"
            echo "=========================================="
            
            echo "Installing PostgreSQL client..."
            apk update && apk add --no-cache postgresql-client

            echo "Connecting to database..."
            export PGPASSWORD=$$ROOT_PASSWORD
            until psql -h $$DB_HOST -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
              echo "Waiting for database..."
              sleep 2
            done
            echo "✅ Database is accessible"

            # Create role
            echo "Creating/updating database role..."
            psql -h $$DB_HOST -p 5432 -U postgres -d postgres <<EOF
            DO \$$\$$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$$DB_USER') THEN
                CREATE ROLE "$$DB_USER" WITH LOGIN PASSWORD '$$DB_PASSWORD';
                RAISE NOTICE 'Role created: $$DB_USER';
              ELSE
                ALTER ROLE "$$DB_USER" WITH PASSWORD '$$DB_PASSWORD';
                RAISE NOTICE 'Role updated: $$DB_USER';
              END IF;
            END
            \$$\$$;
            ALTER ROLE "$$DB_USER" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$$DB_USER";
            EOF

            # Create database
            echo "Creating database if not exists..."
            if ! psql -h $$DB_HOST -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$$DB_NAME'" | grep -q 1; then
              export PGPASSWORD=$$DB_PASSWORD
              psql -h $$DB_HOST -p 5432 -U $$DB_USER -d postgres -c "CREATE DATABASE \"$$DB_NAME\" OWNER \"$$DB_USER\";"
              echo "✅ Database created"
            else
              echo "✅ Database already exists"
            fi

            # Grant privileges
            export PGPASSWORD=$$ROOT_PASSWORD
            psql -h $$DB_HOST -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$$DB_NAME\" TO \"$$DB_USER\";"

            echo "✅ Database initialization complete"
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 3: Configuration Generation (waits for nfs-init)
      {
        name            = "odoo-config"
        description     = "Generate Odoo configuration file"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        script_path     = "${path.module}/../../scripts/odoo/odoo-gen-config.sh"
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = ["nfs-init"]  # ✅ Wait for NFS directories
        execute_on_apply  = true
      },
      
      # Job 4: Odoo Initialization (waits for ALL prerequisites)
      {
        name            = "odoo-init"
        description     = "Initialize Odoo database"
        image           = null
        command         = ["/bin/bash", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=========================================="
            echo "Odoo Database Initialization"
            echo "=========================================="
            
            # Debug: Show all mount points
            echo "Mounted filesystems:"
            df -h | grep -E '(Filesystem|/mnt)'
            echo ""
            
            # Verify NFS mount
            echo "Checking NFS mount (/mnt)..."
            if [ ! -d /mnt ]; then
                echo "❌ ERROR: /mnt directory does not exist"
                exit 1
            fi
            
            echo "NFS mount contents:"
            ls -la /mnt/ || { echo "❌ Cannot list /mnt"; exit 1; }
            echo ""
            
            # Verify GCS mount
            echo "Checking GCS mount (/mnt/extra-addons)..."
            if [ ! -d /mnt/extra-addons ]; then
                echo "❌ ERROR: /mnt/extra-addons not found"
                exit 1
            fi
            ls -la /mnt/extra-addons || { echo "❌ Cannot list /mnt/extra-addons"; exit 1; }
            echo "✅ GCS mount verified"
            echo ""
            
            # Verify config file
            echo "Checking configuration file..."
            if [ ! -f /mnt/odoo.conf ]; then
                echo "❌ ERROR: /mnt/odoo.conf not found"
                echo "This means odoo-config job failed or NFS mount is not working"
                echo "NFS mount contents:"
                ls -la /mnt/
                exit 1
            fi
            echo "✅ Configuration file found"
            echo ""
            
            # Verify filestore directory
            echo "Checking filestore directory..."
            if [ ! -d /mnt/filestore ]; then
                echo "❌ ERROR: /mnt/filestore not found"
                echo "This means nfs-init job failed"
                echo "NFS mount contents:"
                ls -la /mnt/
                exit 1
            fi
            echo "✅ Filestore directory found"
            echo ""
            
            # Test filestore write access
            echo "Testing filestore write access..."
            if ! touch /mnt/filestore/.test 2>/dev/null; then
                echo "❌ ERROR: Cannot write to /mnt/filestore"
                echo "Filestore permissions:"
                ls -la /mnt/filestore/
                exit 1
            fi
            rm -f /mnt/filestore/.test
            echo "✅ Filestore is writable"
            echo ""
            
            # Check if database is already initialized
            echo "Checking if database is already initialized..."
            if psql "postgresql://$${DB_USER}:$${DB_PASSWORD}@$${DB_HOST}:5432/$${DB_NAME}" \
                 -c "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module';" 2>/dev/null | grep -q 1; then
                echo "⚠️  Database already initialized, skipping initialization..."
                exit 0
            fi
            echo "Database not initialized, proceeding..."
            echo ""
            
            # Start Odoo initialization
            echo "=========================================="
            echo "Starting Odoo initialization..."
            echo "=========================================="
            odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info
            
            echo ""
            echo "=========================================="
            echo "✅ Odoo initialization complete"
            echo "=========================================="
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons-volume"]
        depends_on_jobs   = ["nfs-init", "db-init", "odoo-config"]  # ✅ FIXED: Wait for all prerequisites
        execute_on_apply  = true
      }
    ]

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
