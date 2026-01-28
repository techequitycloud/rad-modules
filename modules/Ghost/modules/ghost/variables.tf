# Copyright 2024 (c) Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

#########################################################################
# Ghost Preset Configuration - Version 6.10.3
#########################################################################

locals {
  ghost_module = {
    app_name            = "ghost"
    description         = "Ghost - Professional publishing platform"
    container_image     = "ghost:6.10.3-alpine"  # ✅ Updated to 6.10.3
    application_version = "6.10.3"
    enable_image_mirroring = true

    # ✅ Use official image (recommended)
    image_source = "build"

    # Custom build configuration (only if you need URL auto-detection)
    container_build_config = {
      enabled            = false  # Set to true if using custom Dockerfile
      dockerfile_path    = "Dockerfile"
      context_path       = "."
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    container_port  = 2368
    database_type   = "MYSQL_8_0"  # Ghost 6.x requires MySQL 8.0+
    db_name         = "ghost"
    db_user         = "ghost"

    # ✅ Enable CloudSQL volume for better performance
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    # Storage volumes for Ghost content
    gcs_volumes = [{
      name       = "ghost-content"
      mount_path = "/var/lib/ghost/content"
      read_only  = false
      mount_options = [
        "implicit-dirs",
        "metadata-cache-ttl-secs=60",
        "stat-cache-ttl-secs=60",
        "type-cache-ttl-secs=60",
        "uid=1000",      # Ghost user
        "gid=1000",      # Ghost group
        "dir-mode=755",
        "file-mode=644"
      ]
    }]

    # ✅ Updated resource limits for Ghost 6.x (requires more memory)
    container_resources = {
      cpu_limit    = "2000m"      # Increased from 1000m
      memory_limit = "4Gi"        # Increased from 2Gi (Ghost 6.x is more resource-intensive)
    }
    min_instance_count = 0
    max_instance_count = 5        # Increased for better scaling

    # ✅ Environment variables for Ghost 6.10.3
    environment_variables = {
      # Node Environment
      NODE_ENV = "production"
      
      # Ghost 6.x Configuration
      logging__transports = "[\"stdout\"]"
      logging__level = "info"
      
      # ✅ Privacy settings (new in Ghost 6.x)
      privacy__useUpdateCheck = "false"
      privacy__useGravatar = "true"
      privacy__useRpcPing = "false"
      
      # ✅ Database Connection via Unix Socket (faster)
      database__client = "mysql"
      database__connection__host = "127.0.0.1"  # Will be overridden in main.tf
      database__connection__port = "3306"
      database__connection__user = "ghost"
      database__connection__database = "ghost"
      
      # ✅ Connection pool settings (optimized for Ghost 6.x)
      database__pool__min = "2"
      database__pool__max = "20"  # Increased from 10
      database__connection__charset = "utf8mb4"
      
      # ✅ Ghost 6.x performance settings
      database__useNullAsDefault = "false"
      
      # ✅ Content API settings
      admin__url = ""  # Will be set in main.tf
      
      # ✅ Caching (new in Ghost 6.x)
      caching__frontend__maxAge = "600"
      caching__301__maxAge = "31536000"
      
      # ✅ Image optimization
      imageOptimization__resize = "true"
      imageOptimization__contentImageSizes = "w=600,w=1000,w=1600,w=2400"
      
      # ✅ Mail Configuration - Disabled by default
      # Uncomment and configure if needed
      # mail__transport = "SMTP"
      # mail__from = "noreply@yourdomain.com"
    }

    # ✅ Database password via secrets
    secret_environment_variables = {
      database__connection__password = "ghost-db-password"
    }

    # MySQL plugins (not needed for Ghost)
    enable_mysql_plugins = false
    mysql_plugins        = []

    # ✅ Updated Initialization Jobs for Ghost 6.10.3
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Initialize Ghost 6.10.3 Database with MySQL 8.0 settings"
        image           = "mysql:8.0-debian"  # ✅ Updated to use MySQL 8.0 image
        command         = ["/bin/bash", "-c"]
        args            = [
          <<-EOT
            set -e
            
            echo "=========================================="
            echo "Ghost 6.10.3 Database Initialization"
            echo "MySQL 8.0 Configuration"
            echo "=========================================="
            
            # Use DB_IP (private IP) instead of 127.0.0.1
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Target DB Host: $TARGET_DB_HOST"
            
            # Validate required variables
            if [ -z "$DB_PASSWORD" ]; then
              echo "ERROR: DB_PASSWORD is not set"
              exit 1
            fi
            
            if [ -z "$ROOT_PASSWORD" ]; then
              echo "ERROR: ROOT_PASSWORD is not set"
              exit 1
            fi
            
            # Wait for database to be ready
            echo "Waiting for MySQL at $TARGET_DB_HOST:3306..."
            MAX_RETRIES=30
            RETRY_COUNT=0
            
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if mysqladmin ping -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD --silent 2>/dev/null; then
                echo "✓ MySQL is ready"
                break
              fi
              RETRY_COUNT=$((RETRY_COUNT + 1))
              echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
              sleep 2
            done
            
            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
              echo "ERROR: Could not connect to MySQL after $MAX_RETRIES attempts"
              exit 1
            fi
            
            # Test root connection
            echo "Testing root connection..."
            if ! mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD -e "SELECT VERSION();" > /dev/null 2>&1; then
              echo "ERROR: Could not connect as root user"
              exit 1
            fi
            
            # Get MySQL version
            MYSQL_VERSION=$(mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD -sN -e "SELECT VERSION();")
            echo "✓ Connected to MySQL $MYSQL_VERSION"
            
            # ✅ Create database with Ghost 6.x requirements
            echo "Creating database '$DB_NAME' with utf8mb4..."
            mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD <<EOF
-- Create database with proper character set for Ghost 6.x
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_0900_ai_ci;  -- MySQL 8.0 default collation

-- Set database-level settings for Ghost 6.x
ALTER DATABASE \`$DB_NAME\` 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_0900_ai_ci;
EOF
            
            echo "✓ Database created"
            
            # ✅ Create user with MySQL 8.0 authentication
            echo "Creating user '$DB_USER' with caching_sha2_password..."
            mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD <<EOF
-- Drop user if exists (for idempotency)
DROP USER IF EXISTS '$DB_USER'@'%';

-- Create user with MySQL 8.0 native authentication
-- Ghost 6.x supports caching_sha2_password
CREATE USER '$DB_USER'@'%' 
  IDENTIFIED WITH caching_sha2_password BY '$DB_PASSWORD';

-- Grant all privileges on Ghost database
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';

-- Grant necessary global privileges for Ghost migrations
GRANT CREATE, ALTER, DROP, INDEX, REFERENCES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';

-- Apply changes
FLUSH PRIVILEGES;
EOF
            
            echo "✓ User created with privileges"
            
            # ✅ Set MySQL 8.0 specific settings for Ghost 6.x
            echo "Configuring MySQL settings for Ghost 6.x..."
            mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD <<EOF
-- Set session variables for Ghost compatibility
SET GLOBAL sql_mode = 'TRADITIONAL';
SET GLOBAL innodb_strict_mode = ON;
SET GLOBAL innodb_file_per_table = ON;

-- Optimize for Ghost workload
SET GLOBAL max_allowed_packet = 67108864;  -- 64MB
SET GLOBAL innodb_buffer_pool_size = 268435456;  -- 256MB (adjust based on instance size)
EOF
            
            echo "✓ MySQL settings configured"
            
            # Verify user can connect
            echo "Verifying user connection..."
            if mysql -h $TARGET_DB_HOST -u $DB_USER -p$DB_PASSWORD -e "USE \`$DB_NAME\`; SELECT 1;" > /dev/null 2>&1; then
              echo "✓ User connection verified"
            else
              echo "ERROR: User cannot connect to database"
              exit 1
            fi
            
            # ✅ Display database info
            echo ""
            echo "Database Information:"
            mysql -h $TARGET_DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
              SELECT 
                @@character_set_database as charset,
                @@collation_database as collation,
                @@version as mysql_version;
            "
            
            echo ""
            echo "=========================================="
            echo "✓ Ghost 6.10.3 database initialization complete"
            echo "=========================================="
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
        timeout_seconds   = 300
        max_retries       = 1
        depends_on_jobs   = []
        
        env_vars = {}
        secret_env_vars = {}
      }
    ]

    # ✅ Updated health checks for Ghost 6.x
    startup_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/ghost/api/v3/admin/site/"  # ✅ Ghost 6.x API endpoint
      initial_delay_seconds = 90   # Ghost 6.x takes longer to start
      timeout_seconds       = 10
      period_seconds        = 10
      failure_threshold     = 10   # More lenient for initial startup
    }
    
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 60
      timeout_seconds       = 5
      period_seconds        = 30
      failure_threshold     = 3
    }
    
    # ✅ Readiness probe (new)
    readiness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/"
      initial_delay_seconds = 30
      timeout_seconds       = 5
      period_seconds        = 10
      failure_threshold     = 3
    }
  }
}

output "ghost_module" {
  description = "Ghost 6.10.3 application module configuration"
  value       = local.ghost_module
}
