locals {
  wordpress_module = {
    app_name        = "wp"
    description     = "WordPress CMS - Popular content management system for websites and blogs"
    container_image = "wordpress"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "wp"
    db_user         = "wp"
    application_version = var.application_version
    application_sha     = "52d5f05c96a9155f78ed84700264307e5dea14b4"

    image_source    = "custom"

    # ✅ Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "scripts/wordpress"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }

    # Performance optimization
    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/var/run/mysqld"

    # Storage volumes
    gcs_volumes = [{
      name       = "wp-uploads"
      mount_path = "/var/www/html/wp-content"
      read_only  = false
      mount_options = ["implicit-dirs", "metadata-cache-ttl-secs=60"]
    }]

    # Resource limits
    container_resources = {
      cpu_limit    = "1000m"
      memory_limit = "2Gi"
    }
    min_instance_count = 1
    max_instance_count = 3

    # Environment variables
    environment_variables = {
      WORDPRESS_DB_HOST      = "localhost:/tmp/mysqld.sock"
      WORDPRESS_TABLE_PREFIX = "wp_"
      WORDPRESS_DEBUG        = "false"
    }

    # MySQL plugins
    enable_mysql_plugins = false
    mysql_plugins        = []

    # Initialization Jobs
    initialization_jobs = [
      {
        name            = "db-init"
        description     = "Create WordPress Database and User"
        image           = "alpine:3.19"
        command         = ["/bin/sh", "-c"]
        args            = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use WORDPRESS_DB_HOST which is available in static envs (mapped to internal IP)
            DB_HOST_VAL=$WORDPRESS_DB_HOST
            echo "Using DB Host: $DB_HOST_VAL"

            # Check if DB_HOST_VAL is set
            if [ -z "$DB_HOST_VAL" ]; then
              echo "Error: WORDPRESS_DB_HOST is not set."
              exit 1
            fi

            # DB_PASSWORD and ROOT_PASSWORD are automatically injected by CloudRunApp/jobs.tf
            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set. It should be injected by CloudRunApp/jobs.tf."
              exit 1
            fi

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set. It should be injected by CloudRunApp/jobs.tf."
              exit 1
            fi

            # Extract socket path if present (e.g. localhost:/path/to/socket -> /path/to/socket)
            if echo "$DB_HOST_VAL" | grep -q "localhost:"; then
              SOCKET_PATH=$(echo "$DB_HOST_VAL" | cut -d: -f2)
              DB_HOST="localhost"
            elif echo "$DB_HOST_VAL" | grep -q "^/"; then
              SOCKET_PATH="$DB_HOST_VAL"
              DB_HOST="localhost"
            else
              SOCKET_PATH=""
              DB_HOST="$DB_HOST_VAL"
            fi

            if [ -n "$SOCKET_PATH" ]; then
                echo "Detected Socket Path Configuration: $SOCKET_PATH"
                # Hardcoded search directory where Cloud SQL volume is mounted
                SEARCH_DIR="/var/run/mysqld"

                # Wait for search directory to exist
                echo "Waiting for Cloud SQL volume at $SEARCH_DIR..."
                until [ -d "$SEARCH_DIR" ]; do
                    sleep 2
                done

                # Check for existing sockets in the search directory
                echo "Searching for sockets in $SEARCH_DIR..."
                FOUND_SOCKET=$(find "$SEARCH_DIR" -maxdepth 1 -type s | head -n 1)

                if [ -n "$FOUND_SOCKET" ]; then
                    echo "Found existing socket: $FOUND_SOCKET"
                    # Create symlink at the expected location (SOCKET_PATH)
                    echo "Symlinking $FOUND_SOCKET to $SOCKET_PATH"
                    ln -sf "$FOUND_SOCKET" "$SOCKET_PATH"
                else
                    echo "No socket found yet in $SEARCH_DIR"
                fi

                echo "Waiting for socket file: $SOCKET_PATH..."
                until [ -S "$SOCKET_PATH" ]; do
                    echo "Waiting for socket $SOCKET_PATH..."

                    # Periodically check and relink if needed
                    if [ ! -e "$SOCKET_PATH" ]; then
                         FOUND_SOCKET=$(find "$SEARCH_DIR" -maxdepth 1 -type s | head -n 1)
                         if [ -n "$FOUND_SOCKET" ]; then
                             echo "Found socket: $FOUND_SOCKET. Symlinking to $SOCKET_PATH..."
                             ln -sf "$FOUND_SOCKET" "$SOCKET_PATH"
                         fi
                    fi

                    sleep 2
                done
            else
                echo "Waiting for TCP host: $DB_HOST"
                until nc -z "$DB_HOST" 3306; do
                  echo "Waiting for MySQL port 3306..."
                  sleep 2
                done
            fi

            # Configure .my.cnf
            if [ -n "$SOCKET_PATH" ]; then
                cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASSWORD
socket=$SOCKET_PATH
EOF
            else
                cat > ~/.my.cnf << EOF
[client]
user=root
password=$ROOT_PASSWORD
host=$DB_HOST
EOF
            fi
            chmod 600 ~/.my.cnf

            echo "Creating User $DB_USER if not exists..."
            mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF

            echo "Creating Database $DB_NAME if not exists..."
            mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"

            echo "Granting privileges..."
            mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

            rm -f ~/.my.cnf
            echo "DB Init complete."
          EOT
        ]
        mount_nfs         = false
        mount_gcs_volumes = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 240
      period_seconds        = 240
      failure_threshold     = 1
    }
    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/wp-admin/install.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  application_modules = {
    wordpress = local.wordpress_module
  }

  module_env_vars = {
    WORDPRESS_DB_NAME = local.database_name_full
    WORDPRESS_DB_USER = local.database_user_full
  }

  module_secret_env_vars = {
    WORDPRESS_DB_PASSWORD = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = [
    {
      name_suffix = "wp-uploads"
      location    = var.deployment_region
    }
  ]
}
