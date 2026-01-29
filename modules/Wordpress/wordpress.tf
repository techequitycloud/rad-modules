locals {
  wordpress_module = {
    app_name        = "wp"
    description     = "WordPress CMS - Popular content management system for websites and blogs"
    container_image = "wordpress:6.8.1-apache"
    container_port  = 80
    database_type   = "MYSQL_8_0"
    db_name         = "wp"
    db_user         = "wp"
    application_version = "6.8.1"
    application_sha     = "52d5f05c96a9155f78ed84700264307e5dea14b4"

    # image_source    = "prebuilt"
    image_source    = "build"

    # ✅ Custom build configuration
    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "."
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
      WORDPRESS_DB_HOST      = "localhost:/var/run/mysqld/mysqld.sock"
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

            # Use DB_IP (internal IP injected by CloudRunApp/jobs.tf) for TCP connection
            # WORDPRESS_DB_HOST points to a Unix socket path used by the Cloud Run service,
            # but the db-init job should connect via TCP to the database internal IP.
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Check if TARGET_DB_HOST is set
            if [ -z "$TARGET_DB_HOST" ]; then
              echo "Error: DB_HOST is not set."
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

            # Check if using Unix socket or TCP
            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "Using Unix socket connection."
            else
                echo "Using TCP connection."
                echo "Waiting for database..."
                until nc -z $TARGET_DB_HOST 3306; do
                  echo "Waiting for MySQL port 3306..."
                  sleep 2
                done
            fi

            cat > ~/.my.cnf << EOF
[client]
user=root
password=$${ROOT_PASSWORD}
EOF

            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "socket=$TARGET_DB_HOST" >> ~/.my.cnf
            else
                echo "host=$TARGET_DB_HOST" >> ~/.my.cnf
            fi

            chmod 600 ~/.my.cnf

            echo "Creating User $${DB_USER} if not exists..."
            mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASSWORD}';
ALTER USER '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF

            echo "Creating Database $${DB_NAME} if not exists..."
            mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`$${DB_NAME}\`;"

            echo "Granting privileges..."
            mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`$${DB_NAME}\`.* TO '$${DB_USER}'@'%';
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
