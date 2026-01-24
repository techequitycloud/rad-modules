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

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

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
            
            # Set ownership and permissions
            echo "Setting ownership and permissions..."
            
            # Try method 1: Set ownership to Odoo user (101:101) with group write
            if chown -R 101:101 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null; then
              echo "✅ Ownership set to 101:101"
              # Use 775 to allow group writes
              chmod -R 775 /mnt/filestore /mnt/sessions /mnt/backups
              echo "✅ Permissions set to 775 (rwxrwxr-x)"
            else
              echo "⚠️  chown failed (NFS limitation)"
              # Fallback: Use 777 for maximum compatibility
              chmod -R 777 /mnt/filestore /mnt/sessions /mnt/backups
              echo "✅ Permissions set to 777 (rwxrwxrwx)"
            fi
            
            # Verify final state
            echo ""
            echo "✅ Directories created and configured"
            echo "Final directory listing:"
            ls -la /mnt/
            echo ""
            echo "Filestore permissions:"
            ls -la /mnt/filestore/
            echo ""
            echo "Sessions permissions:"
            ls -la /mnt/sessions/
            echo ""
            
            # Test write access
            echo "Testing write access..."
            if touch /mnt/filestore/.test 2>/dev/null; then
              echo "✅ Write test successful"
              rm -f /mnt/filestore/.test
            else
              echo "⚠️  Write test failed - this may cause issues"
              echo "Current user: $$(id)"
            fi
            
            echo "✅ NFS initialization complete"
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 2: Database Initialization with Enhanced Debugging
      {
        name            = "db-init"
        description     = "Create Odoo Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=========================================="
            echo "Database Initialization - Enhanced Debug"
            echo "=========================================="
            
            # Show environment variables (mask passwords)
            echo "Environment Check:"
            echo "  DB_HOST: $${DB_HOST:-NOT_SET}"
            echo "  DB_PORT: 5432"
            echo "  DB_USER: $${DB_USER:-NOT_SET}"
            echo "  DB_NAME: $${DB_NAME:-NOT_SET}"
            echo "  ROOT_PASSWORD: $${ROOT_PASSWORD:+***SET***}"
            echo "  DB_PASSWORD: $${DB_PASSWORD:+***SET***}"
            echo ""
            
            # Check if variables are actually set
            if [ -z "$${DB_HOST}" ]; then
              echo "❌ ERROR: DB_HOST is not set!"
              exit 1
            fi
            
            if [ -z "$${ROOT_PASSWORD}" ]; then
              echo "❌ ERROR: ROOT_PASSWORD is not set!"
              exit 1
            fi
            
            # Install tools
            echo "Installing tools..."
            apk update && apk add --no-cache postgresql-client bind-tools netcat-openbsd curl
            echo ""
            
            # Test DNS resolution
            echo "Testing DNS resolution for $${DB_HOST}..."
            if nslookup $${DB_HOST} 2>&1; then
              echo "✅ DNS resolution successful"
            else
              echo "❌ DNS resolution failed for $${DB_HOST}"
              echo "Trying to resolve google.com as a test..."
              nslookup google.com || echo "DNS is completely broken"
              exit 1
            fi
            echo ""
            
            # Get resolved IP
            RESOLVED_IP=$(nslookup $${DB_HOST} | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
            echo "Resolved IP: $${RESOLVED_IP:-FAILED}"
            echo ""
            
            # Test network connectivity
            echo "Testing network connectivity to $${DB_HOST}:5432..."
            if timeout 5 nc -zv $${DB_HOST} 5432 2>&1; then
              echo "✅ Port 5432 is reachable"
            else
              echo "❌ Cannot reach $${DB_HOST}:5432"
              echo ""
              echo "Checking if this is a Cloud SQL instance..."
              echo "If using Cloud SQL, ensure:"
              echo "  1. Instance has public IP enabled"
              echo "  2. Authorized networks include 0.0.0.0/0 (for testing)"
              echo "  3. Cloud SQL Admin API is enabled"
              echo "  4. Service account has cloudsql.client role"
              echo ""
              echo "Trying to ping the host..."
              ping -c 3 $${DB_HOST} 2>&1 || echo "Ping failed"
              exit 1
            fi
            echo ""
            
            # Try connection with detailed error
            echo "Attempting PostgreSQL connection..."
            export PGPASSWORD=$${ROOT_PASSWORD}
            export PGCONNECT_TIMEOUT=5
            
            echo "First connection attempt (will show detailed error)..."
            if psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' 2>&1; then
              echo "✅ Connection successful on first try!"
            else
              echo "First attempt failed, will retry..."
              echo ""
            fi
            
            # Retry loop with progress
            echo "Starting retry loop (max 60 attempts, 2 minutes)..."
            MAX_RETRIES=60
            RETRY_COUNT=0
            
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; then
                echo "✅ Database connection successful after $RETRY_COUNT attempts!"
                break
              fi
              
              RETRY_COUNT=$((RETRY_COUNT + 1))
              
              # Show detailed error every 10 attempts
              if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
                echo "Attempt $RETRY_COUNT/$MAX_RETRIES - Detailed error:"
                psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' 2>&1 || true
                echo ""
              else
                echo "Waiting for database... ($RETRY_COUNT/$MAX_RETRIES)"
              fi
              
              sleep 2
            done
            
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
              echo ""
              echo "❌ Failed to connect after $MAX_RETRIES attempts"
              echo ""
              echo "Final connection attempt with full error details:"
              psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' 2>&1 || true
              echo ""
              echo "Troubleshooting tips:"
              echo "1. Check Cloud SQL instance is RUNNABLE:"
              echo "   gcloud sql instances describe <instance-name>"
              echo ""
              echo "2. Check authorized networks:"
              echo "   gcloud sql instances describe <instance-name> --format='value(settings.ipConfiguration.authorizedNetworks)'"
              echo ""
              echo "3. Verify password is correct in Secret Manager"
              echo ""
              echo "4. Check Cloud SQL logs:"
              echo "   gcloud logging read 'resource.type=cloudsql_database' --limit=20"
              exit 1
            fi
            
            echo ""
            echo "Database is accessible, proceeding with initialization..."
            echo ""
            
            # Create role
            echo "Creating/updating database role..."
            psql -h $${DB_HOST} -p 5432 -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$${DB_USER}') THEN
                CREATE ROLE "$${DB_USER}" WITH LOGIN PASSWORD '$${DB_PASSWORD}';
                RAISE NOTICE 'Role created: $${DB_USER}';
              ELSE
                ALTER ROLE "$${DB_USER}" WITH PASSWORD '$${DB_PASSWORD}';
                RAISE NOTICE 'Role updated: $${DB_USER}';
              END IF;
            END
            \$\$;
            ALTER ROLE "$${DB_USER}" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$${DB_USER}";
            EOF
            echo "✅ Role configured"
            echo ""
      
            # Create database
            echo "Creating database if not exists..."
            if ! psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$${DB_NAME}'" | grep -q 1; then
              export PGPASSWORD=$${DB_PASSWORD}
              psql -h $${DB_HOST} -p 5432 -U $${DB_USER} -d postgres -c "CREATE DATABASE \"$${DB_NAME}\" OWNER \"$${DB_USER}\";"
              echo "✅ Database created"
            else
              echo "✅ Database already exists"
            fi
            echo ""
      
            # Grant privileges
            export PGPASSWORD=$${ROOT_PASSWORD}
            psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$${DB_NAME}\" TO \"$${DB_USER}\";"
            echo "✅ Privileges granted"
            echo ""
      
            echo "=========================================="
            echo "✅ Database initialization complete"
            echo "=========================================="
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 4: Odoo Initialization
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
            
            echo "Mounted filesystems:"
            df -h | grep -E '(Filesystem|/mnt)'
            echo ""
            
            echo "Checking NFS mount (/mnt)..."
            if [ ! -d /mnt ]; then
                echo "ERROR: /mnt directory does not exist"
                exit 1
            fi
            
            echo "NFS mount contents:"
            ls -la /mnt/ || { echo "Cannot list /mnt"; exit 1; }
            echo ""
            
            echo "Checking GCS mount (/mnt/extra-addons)..."
            if [ ! -d /mnt/extra-addons ]; then
                echo "ERROR: /mnt/extra-addons not found"
                exit 1
            fi
            ls -la /mnt/extra-addons || { echo "Cannot list /mnt/extra-addons"; exit 1; }
            echo "GCS mount verified"
            echo ""
            
            echo "Waiting for configuration file..."
            MAX_RETRIES=30
            RETRY_COUNT=0
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if [ -f /mnt/odoo.conf ]; then
                echo "Configuration file found"
                break
              fi
              RETRY_COUNT=$(expr $RETRY_COUNT + 1)
              echo "Waiting for /mnt/odoo.conf... ($RETRY_COUNT/$MAX_RETRIES)"
              sleep 2
            done
            
            if [ ! -f /mnt/odoo.conf ]; then
              echo "ERROR: /mnt/odoo.conf not found after waiting"
              echo "NFS mount contents:"
              ls -la /mnt/
              exit 1
            fi
            echo ""
            
            echo "Verifying config file permissions..."
            if ! cat /mnt/odoo.conf > /dev/null 2>&1; then
              echo "ERROR: Cannot read /mnt/odoo.conf"
              ls -la /mnt/odoo.conf
              exit 1
            fi
            echo "Config file is readable"
            echo ""
            
            echo "Checking filestore directory..."
            if [ ! -d /mnt/filestore ]; then
                echo "ERROR: /mnt/filestore not found"
                ls -la /mnt/
                exit 1
            fi
            echo "Filestore directory found"
            echo ""
            
            echo "Testing filestore write access..."
            if ! touch /mnt/filestore/.test 2>/dev/null; then
                echo "ERROR: Cannot write to /mnt/filestore"
                ls -la /mnt/filestore/
                exit 1
            fi
            rm -f /mnt/filestore/.test
            echo "Filestore is writable"
            echo ""
            
            echo "Checking if database is already initialized..."
            if psql "postgresql://$${DB_USER}:$${DB_PASSWORD}@$${DB_HOST}:5432/$${DB_NAME}" \
                 -c "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module';" 2>/dev/null | grep -q 1; then
                echo "Database already initialized, skipping..."
                exit 0
            fi
            echo "Database not initialized, proceeding..."
            echo ""
            
            echo "=========================================="
            echo "Starting Odoo initialization..."
            echo "=========================================="
            odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info
            
            echo ""
            echo "=========================================="
            echo "Odoo initialization complete"
            echo "=========================================="
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = ["odoo-addons-volume"]
        depends_on_jobs   = ["nfs-init", "db-init", "odoo-config"]
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
