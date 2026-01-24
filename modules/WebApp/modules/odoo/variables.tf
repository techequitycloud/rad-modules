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
        
        if [ ! -f /mnt/odoo.conf ]; then
            echo "ERROR: /mnt/odoo.conf not found"
            exit 1
        fi
        
        if [ ! -d /mnt/filestore ]; then
            echo "ERROR: /mnt/filestore not found"
            exit 1
        fi
        
        if ! touch /mnt/filestore/.test 2>/dev/null; then
            echo "ERROR: Cannot write to /mnt/filestore"
            ls -la /mnt/filestore/
            exit 1
        fi
        rm -f /mnt/filestore/.test
        
        echo "All checks passed"
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
            
            echo "Current /mnt contents:"
            ls -la /mnt/ 2>/dev/null || echo "Empty or not accessible"
            
            echo "Creating directories..."
            mkdir -p /mnt/filestore /mnt/sessions /mnt/backups
            
            echo "Setting ownership and permissions..."
            if chown -R 101:101 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null; then
              echo "Ownership set to 101:101"
              chmod -R 775 /mnt/filestore /mnt/sessions /mnt/backups
              echo "Permissions set to 775"
            else
              echo "chown failed, using 777 permissions"
              chmod -R 777 /mnt/filestore /mnt/sessions /mnt/backups
              echo "Permissions set to 777"
            fi
            
            echo ""
            echo "Final directory listing:"
            ls -la /mnt/
            echo ""
            echo "Filestore permissions:"
            ls -la /mnt/filestore/
            echo ""
            
            if touch /mnt/filestore/.test 2>/dev/null; then
              echo "Write test successful"
              rm -f /mnt/filestore/.test
            else
              echo "Write test failed"
              echo "Current user: $(id)"
            fi
            
            echo "NFS initialization complete"
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 2: Database Initialization
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
            
            echo "Environment Check:"
            echo "  DB_HOST: $${DB_HOST:-NOT_SET}"
            echo "  DB_PORT: 5432"
            echo "  DB_USER: $${DB_USER:-NOT_SET}"
            echo "  DB_NAME: $${DB_NAME:-NOT_SET}"
            echo ""
            
            if [ -z "$${DB_HOST}" ]; then
              echo "ERROR: DB_HOST is not set!"
              exit 1
            fi
            
            if [ -z "$${ROOT_PASSWORD}" ]; then
              echo "ERROR: ROOT_PASSWORD is not set!"
              exit 1
            fi
            
            echo "Installing tools..."
            apk update && apk add --no-cache postgresql-client netcat-openbsd
            echo ""
            
            # Skip DNS check for private IPs
            if echo "$${DB_HOST}" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'; then
              echo "Detected private IP address: $${DB_HOST}"
              echo "Skipping DNS resolution check"
            else
              echo "Testing DNS resolution for $${DB_HOST}..."
              nslookup $${DB_HOST} 2>&1 | grep -q "Address:" && echo "DNS OK" || echo "DNS warning"
            fi
            echo ""
            
            echo "Testing network connectivity to $${DB_HOST}:5432..."
            if timeout 5 nc -zv $${DB_HOST} 5432 2>&1; then
              echo "Port 5432 is reachable"
            else
              echo "ERROR: Cannot reach $${DB_HOST}:5432"
              echo "Check VPC connector or use public IP"
              exit 1
            fi
            echo ""
            
            echo "Connecting to database..."
            export PGPASSWORD=$${ROOT_PASSWORD}
            export PGCONNECT_TIMEOUT=5
            
            MAX_RETRIES=60
            RETRY_COUNT=0
            
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; then
                echo "Database connected after $RETRY_COUNT attempts"
                break
              fi
              
              RETRY_COUNT=`expr $RETRY_COUNT + 1`
              
              if [ `expr $RETRY_COUNT % 10` -eq 0 ]; then
                echo "Attempt $RETRY_COUNT/$MAX_RETRIES"
                psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' 2>&1 || true
              else
                echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
              fi
              
              sleep 2
            done
            
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
              echo "ERROR: Failed to connect after $MAX_RETRIES attempts"
              exit 1
            fi
            
            echo ""
            echo "Creating database role..."
            psql -h $${DB_HOST} -p 5432 -U postgres -d postgres <<EOF
            DO \$\$
            BEGIN
              IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$${DB_USER}') THEN
                CREATE ROLE "$${DB_USER}" WITH LOGIN PASSWORD '$${DB_PASSWORD}';
              ELSE
                ALTER ROLE "$${DB_USER}" WITH PASSWORD '$${DB_PASSWORD}';
              END IF;
            END
            \$\$;
            ALTER ROLE "$${DB_USER}" CREATEDB;
            GRANT ALL PRIVILEGES ON DATABASE postgres TO "$${DB_USER}";
            EOF
            echo "Role configured"
            echo ""
      
            echo "Creating database..."
            if ! psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$${DB_NAME}'" | grep -q 1; then
              export PGPASSWORD=$${DB_PASSWORD}
              psql -h $${DB_HOST} -p 5432 -U $${DB_USER} -d postgres -c "CREATE DATABASE \"$${DB_NAME}\" OWNER \"$${DB_USER}\";"
              echo "Database created"
            else
              echo "Database already exists"
            fi
            echo ""
      
            export PGPASSWORD=$${ROOT_PASSWORD}
            psql -h $${DB_HOST} -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$${DB_NAME}\" TO \"$${DB_USER}\";"
            echo "Privileges granted"
            echo ""
            echo "Database initialization complete"
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },
      
      # Job 3: Configuration Generation (INLINE SCRIPT)
      {
        name            = "odoo-config"
        description     = "Generate Odoo configuration file"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "=========================================="
            echo "Generating Odoo Configuration File"
            echo "=========================================="
            
            CONFIG_FILE="/mnt/odoo.conf"
            
            # Verify NFS mount is writable
            if [ ! -d "/mnt" ]; then
                echo "ERROR: /mnt directory does not exist"
                exit 1
            fi
            
            if ! touch /mnt/.test 2>/dev/null; then
                echo "ERROR: Cannot write to /mnt"
                ls -la /mnt/
                exit 1
            fi
            rm -f /mnt/.test
            
            echo "NFS mount is writable"
            
            # Validate required environment variables
            if [ -z "$${DB_HOST}" ] || [ -z "$${DB_USER}" ] || [ -z "$${DB_PASSWORD}" ] || [ -z "$${DB_NAME}" ]; then
                echo "ERROR: Missing required database environment variables"
                echo "DB_HOST: $${DB_HOST:-NOT SET}"
                echo "DB_USER: $${DB_USER:-NOT SET}"
                echo "DB_PASSWORD: $${DB_PASSWORD:+SET}"
                echo "DB_NAME: $${DB_NAME:-NOT SET}"
                exit 1
            fi
            
            echo "Environment variables validated"
            echo "DB_HOST: $${DB_HOST}"
            echo "DB_PORT: $${DB_PORT:-5432}"
            echo "DB_NAME: $${DB_NAME}"
            echo "DB_USER: $${DB_USER}"
            
            # Generate configuration file
            cat > "$${CONFIG_FILE}" << 'EOF'
            [options]
            #########################################################################
            # Database Configuration
            #########################################################################
            db_host = $${DB_HOST}
            db_port = $${DB_PORT:-5432}
            db_user = $${DB_USER}
            db_password = $${DB_PASSWORD}
            db_name = $${DB_NAME}
            db_maxconn = 64
            db_template = template0
            
            #########################################################################
            # Admin Password
            #########################################################################
            admin_passwd = $${ODOO_MASTER_PASS}
            
            #########################################################################
            # Paths
            #########################################################################
            data_dir = /mnt/filestore
            addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
            
            #########################################################################
            # Server Configuration
            #########################################################################
            xmlrpc_port = 8069
            longpolling_port = 8072
            proxy_mode = True
            logfile = /var/log/odoo/odoo.log
            log_level = info
            log_handler = :INFO
            log_db = False
            
            #########################################################################
            # Worker Configuration
            #########################################################################
            workers = 4
            max_cron_threads = 2
            
            #########################################################################
            # Resource Limits
            #########################################################################
            limit_memory_hard = 1610612736
            limit_memory_soft = 671088640
            limit_request = 8192
            
            #########################################################################
            # Time Limits
            #########################################################################
            limit_time_cpu = 600
            limit_time_real = 1200
            limit_time_real_cron = -1
            
            #########################################################################
            # Security
            #########################################################################
            list_db = False
            
            #########################################################################
            # Performance
            #########################################################################
            server_wide_modules = base,web
            unaccent = True
            EOF
            
            # Append SMTP configuration if host is set
            if [ -n "$${SMTP_HOST}" ]; then
                cat >> "$${CONFIG_FILE}" << 'SMTP_EOF'
            
            #########################################################################
            # SMTP Configuration
            #########################################################################
            smtp_server = $${SMTP_HOST}
            smtp_port = $${SMTP_PORT:-25}
            SMTP_EOF
                
                [ -n "$${SMTP_USER}" ] && echo "smtp_user = $${SMTP_USER}" >> "$${CONFIG_FILE}"
                [ -n "$${SMTP_PASSWORD}" ] && echo "smtp_password = $${SMTP_PASSWORD}" >> "$${CONFIG_FILE}"
                
                if [ "$${SMTP_SSL}" = "true" ]; then
                    echo "smtp_ssl = True" >> "$${CONFIG_FILE}"
                else
                    echo "smtp_ssl = False" >> "$${CONFIG_FILE}"
                fi
                
                [ -n "$${EMAIL_FROM}" ] && echo "email_from = $${EMAIL_FROM}" >> "$${CONFIG_FILE}"
                
                echo "SMTP configuration added"
            fi
            
            # Set proper permissions (Odoo runs as UID 101)
            chown 101:101 "$${CONFIG_FILE}" 2>/dev/null || echo "Warning: Could not set ownership"
            chmod 640 "$${CONFIG_FILE}"
            
            echo "Configuration file created at $${CONFIG_FILE}"
            echo ""
            echo "File permissions:"
            ls -la "$${CONFIG_FILE}"
            echo ""
            echo "Configuration file contents (with secrets masked):"
            echo "=========================================="
            sed -e 's/\(password.*=\).*/\1 ***MASKED***/g' \
                -e 's/\(admin_passwd.*=\).*/\1 ***MASKED***/g' \
                "$${CONFIG_FILE}"
            echo "=========================================="
            echo ""
            echo "Odoo configuration generation complete"
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = ["nfs-init"]
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
            
            echo "Checking NFS mount..."
            if [ ! -d /mnt ]; then
                echo "ERROR: /mnt not found"
                exit 1
            fi
            
            echo "NFS contents:"
            ls -la /mnt/ || exit 1
            echo ""
            
            echo "Checking GCS mount..."
            if [ ! -d /mnt/extra-addons ]; then
                echo "ERROR: /mnt/extra-addons not found"
                exit 1
            fi
            ls -la /mnt/extra-addons || exit 1
            echo "GCS mount verified"
            echo ""
            
            echo "Waiting for odoo.conf..."
            MAX_RETRIES=30
            RETRY_COUNT=0
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if [ -f /mnt/odoo.conf ]; then
                echo "Config file found"
                break
              fi
              RETRY_COUNT=`expr $RETRY_COUNT + 1`
              echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
              sleep 2
            done
            
            if [ ! -f /mnt/odoo.conf ]; then
              echo "ERROR: /mnt/odoo.conf not found"
              ls -la /mnt/
              exit 1
            fi
            echo ""
            
            echo "Verifying config file..."
            if ! cat /mnt/odoo.conf > /dev/null 2>&1; then
              echo "ERROR: Cannot read /mnt/odoo.conf"
              ls -la /mnt/odoo.conf
              exit 1
            fi
            echo "Config file readable"
            echo ""
            
            echo "Checking filestore..."
            if [ ! -d /mnt/filestore ]; then
                echo "ERROR: /mnt/filestore not found"
                exit 1
            fi
            echo "Filestore found"
            echo ""
            
            echo "Testing write access..."
            if ! touch /mnt/filestore/.test 2>/dev/null; then
                echo "ERROR: Cannot write to /mnt/filestore"
                ls -la /mnt/filestore/
                exit 1
            fi
            rm -f /mnt/filestore/.test
            echo "Filestore writable"
            echo ""
            
            echo "Checking if DB already initialized..."
            if psql "postgresql://$${DB_USER}:$${DB_PASSWORD}@$${DB_HOST}:5432/$${DB_NAME}" \
                 -c "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module';" 2>/dev/null | grep -q 1; then
                echo "Database already initialized"
                exit 0
            fi
            echo "Initializing database..."
            echo ""
            
            echo "=========================================="
            echo "Starting Odoo initialization..."
            echo "=========================================="
            odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info
            
            echo ""
            echo "Odoo initialization complete"
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
