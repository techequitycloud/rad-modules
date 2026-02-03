locals {
  openemr_module = {
    app_name            = "openemr"
    application_version = var.application_version
    display_name        = "OpenEMR"
    description         = "This module can be used to deploy OpenEMR"
    container_image     = ""

    image_source           = "custom"
    enable_image_mirroring = false

    container_build_config = {
      enabled            = true
      dockerfile_path    = "Dockerfile"
      context_path       = "openemr"
      dockerfile_content = null
      build_args         = {}
      artifact_repo_name = null
    }
    container_port = 80
    database_type  = "MYSQL_8_0"
    db_name        = "openemr"
    db_user        = "openemr"

    enable_cloudsql_volume     = true
    cloudsql_volume_mount_path = "/cloudsql"

    nfs_enabled    = true
    nfs_mount_path = "/var/www/localhost/htdocs/openemr/sites"

    gcs_volumes = []

    container_resources = {
      cpu_limit    = "2000m"


      
      memory_limit = "4Gi"
    }

    min_instance_count = 1
    max_instance_count = 1

    environment_variables = {
      PHP_MEMORY_LIMIT        = "512M"
      PHP_MAX_EXECUTION_TIME  = "60"
      PHP_UPLOAD_MAX_FILESIZE = "64M"
      PHP_POST_MAX_SIZE       = "64M"
      SMTP_HOST               = ""
      SMTP_PORT               = "25"
      SMTP_USER               = ""
      SMTP_PASSWORD           = ""
      SMTP_SSL                = "false"
      EMAIL_FROM              = "openemr@example.com"
    }

    initialization_jobs = [
      # Job 1: NFS Initialization and Backup Restore
      {
        name        = "nfs-init"
        description = "Initialize NFS directories for OpenEMR and restore backup if provided"
        image       = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"
        command     = ["/bin/bash", "-c"]
        env_vars = {
          NFS_MOUNT_PATH = "/var/www/localhost/htdocs/openemr/sites"
        }
        args = [
          <<-EOT
            set -e

            echo "================================================"
            echo "Starting OpenEMR NFS Setup Job"
            echo "================================================"

            # Expected Env Vars:
            # NFS_MOUNT_PATH
            # DB_HOST, DB_NAME, DB_USER, DB_PASS, ROOT_PASS
            # BACKUP_FILEID

            # Env Var Fallbacks
            DB_HOST="$${DB_HOST:-$${MYSQL_HOST}}"
            DB_PASS="$${DB_PASS:-$${DB_PASSWORD}}"
            ROOT_PASS="$${ROOT_PASS:-$${ROOT_PASSWORD}}"
            DB_USER="$${DB_USER:-$${MYSQL_USER}}"
            DB_NAME="$${DB_NAME:-$${MYSQL_DATABASE}}"

            if [ -z "$${NFS_MOUNT_PATH}" ]; then
              echo "Error: NFS_MOUNT_PATH is not set."
              exit 1
            fi

            APP_DIR="$${NFS_MOUNT_PATH}"

            # Install packages
            echo "Installing packages..."
            apk add --no-cache bash python3 py3-pip unzip curl sed

            echo "Working Directory: $${APP_DIR}"

            # Set ownership (OpenEMR runs as 1000)
            echo "Setting ownership..."
            chown 1000:1000 "$${APP_DIR}"
            chmod 775 "$${APP_DIR}"

            # Download and Restore Backup if provided
            if [ -n "$${BACKUP_FILEID}" ]; then
              echo "Downloading backup..."
              # Use a temp file
              BACKUP_FILE="/tmp/backup.zip"

              if [[ "$${BACKUP_FILEID}" == gs://* ]]; then
                 echo "Detected GCS URI. Using gsutil..."
                 if gsutil cp "$${BACKUP_FILEID}" "$${BACKUP_FILE}"; then
                    echo "✓ Backup downloaded from GCS"
                 else
                    echo "✗ GCS download failed"
                    exit 1
                 fi
              else
                 echo "Assuming GDrive ID. Installing gdown..."
                 apk add --no-cache python3 py3-pip
                 pip3 install gdown --break-system-packages
                 if gdown "$${BACKUP_FILEID}" -O "$${BACKUP_FILE}"; then
                    echo "✓ Backup downloaded from GDrive"
                 else
                    echo "✗ GDrive download failed"
                    exit 1
                 fi
              fi

              if [ -f "$${BACKUP_FILE}" ]; then
                echo "Extracting backup to $${APP_DIR}..."
                # Clean target dir
                rm -rf "$${APP_DIR}"/*

                # Unzip to temp
                mkdir -p /tmp/restore
                unzip -q "$${BACKUP_FILE}" -d /tmp/restore

                # Move contents
                if [ -d "/tmp/restore/$${DB_NAME}" ]; then
                  mv /tmp/restore/$${DB_NAME}/* "$${APP_DIR}"/
                else
                  mv /tmp/restore/* "$${APP_DIR}"/
                fi

                echo "✓ Files restored"

                # Update sqlconf.php
                SQLCONF_FILE="$${APP_DIR}/default/sqlconf.php"
                if [ -f "$${SQLCONF_FILE}" ]; then
                  echo "Updating $${SQLCONF_FILE}..."

                  # Check if DB_HOST is a socket path
                  if echo "$${DB_HOST}" | grep -q "^/"; then
                      echo "DB_HOST is a socket path. Setting host to localhost in config."
                      FINAL_HOST="localhost"
                  else
                      FINAL_HOST="$${DB_HOST}"
                  fi

                  sed -i "s/[$$]host\\s*=\\s*'[^']*'/\$host = '$${FINAL_HOST}'/" "$${SQLCONF_FILE}"
                  sed -i "s/[$$]port\\s*=\\s*'[^']*'/\$port = '3306'/" "$${SQLCONF_FILE}"
                  sed -i "s/[$$]login\\s*=\\s*'[^']*'/\$login = '$${DB_USER}'/" "$${SQLCONF_FILE}"
                  sed -i "s/[$$]pass\\s*=\\s*'[^']*'/\$pass = '$${DB_PASS}'/" "$${SQLCONF_FILE}"
                  sed -i "s/[$$]dbase\\s*=\\s*'[^']*'/\$dbase = '$${DB_NAME}'/" "$${SQLCONF_FILE}"

                  if ! grep -q "[$$]rootpass" "$${SQLCONF_FILE}"; then
                    sed -i "/[$$]pass\\s*=\\s*'[^']*'/a \$rootpass = '$${ROOT_PASS}';" "$${SQLCONF_FILE}"
                  else
                    sed -i "s/[$$]rootpass\\s*=\\s*'[^']*'/\$rootpass = '$${ROOT_PASS}'/" "$${SQLCONF_FILE}"
                  fi

                  echo "✓ Config updated"
                else
                  echo "⚠ sqlconf.php not found at $${SQLCONF_FILE}"
                fi

                # Permissions update
                echo "Updating permissions..."
                chown -R 1000:1000 "$${APP_DIR}"
                find "$${APP_DIR}" -type d -exec chmod 755 {} \;
                find "$${APP_DIR}" -type f -exec chmod 644 {} \;
                if [ -d "$${APP_DIR}/default/documents" ]; then
                  chmod -R 755 "$${APP_DIR}/default/documents"
                fi
                if [ -f "$${SQLCONF_FILE}" ]; then
                  chmod 600 "$${SQLCONF_FILE}"
                fi

              else
                echo "✗ Zip file not found"
                exit 1
              fi
            else
              echo "ℹ No backup specified. Creating default site structure..."

              # Create default directory if it doesn't exist
              if [ ! -d "$${APP_DIR}/default" ]; then
                mkdir -p "$${APP_DIR}/default"
                chown 1000:1000 "$${APP_DIR}/default"
                chmod 755 "$${APP_DIR}/default"
                echo "✓ Created default site directory"
              fi

              # Create required OpenEMR subdirectories
              echo "Creating OpenEMR required directories..."
              mkdir -p "$${APP_DIR}/default/documents/smarty/gacl"
              mkdir -p "$${APP_DIR}/default/documents/smarty/main"
              mkdir -p "$${APP_DIR}/default/documents/smarty/templates_c"
              mkdir -p "$${APP_DIR}/default/documents/mpdf/ttfontdata"
              mkdir -p "$${APP_DIR}/default/documents/onsite_portal_documents"
              mkdir -p "$${APP_DIR}/default/documents/logs"
              mkdir -p "$${APP_DIR}/default/documents/era"
              mkdir -p "$${APP_DIR}/default/documents/edi"
              mkdir -p "$${APP_DIR}/default/documents/procedure_results"
              chown -R 1000:1000 "$${APP_DIR}/default/documents"
              chmod -R 777 "$${APP_DIR}/default/documents"
              echo "✓ Created OpenEMR required directories"

              # Create sqlconf.php if it doesn't exist or is corrupted
              SQLCONF_FILE="$${APP_DIR}/default/sqlconf.php"
              if [ -f "$${SQLCONF_FILE}" ] && ! grep -q '$$host' "$${SQLCONF_FILE}" 2>/dev/null; then
                echo "⚠ Existing sqlconf.php is corrupted, removing..."
                rm -f "$${SQLCONF_FILE}"
              fi
              if [ ! -f "$${SQLCONF_FILE}" ]; then

                # Check if DB_HOST is a socket path
                if echo "$${DB_HOST}" | grep -q "^/"; then
                    FINAL_HOST="localhost"
                else
                    FINAL_HOST="$${DB_HOST}"
                fi

                cat > "$${SQLCONF_FILE}" <<SQLEOF
<?php
//  OpenEMR
//  MySQL Config

\$host	= '$${FINAL_HOST}';
\$port	= '3306';
\$login	= '$${DB_USER}';
\$pass	= '$${DB_PASS}';
\$dbase	= '$${DB_NAME}';

\$rootpass	= '$${ROOT_PASS}';

//Added by OpenEMR Configuration:
\$config = 0;
SQLEOF

                chown 1000:1000 "$${SQLCONF_FILE}"
                chmod 600 "$${SQLCONF_FILE}"
                echo "✓ Created default sqlconf.php"
              fi

              # Create config.php if it doesn't exist
              CONFIG_FILE="$${APP_DIR}/default/config.php"
              if [ ! -f "$${CONFIG_FILE}" ]; then
                cat > "$${CONFIG_FILE}" <<'CONFIGEOF'
<?php

use OpenEMR\Common\Crypto\CryptoGen;

if (empty($GLOBALS['ongoing_sql_upgrade'])) {
    $cryptoGen = new CryptoGen();
    $GLOBALS['more_secure']['print_command'] = 'lpr -P HPLaserjet6P -o cpi=10 -o lpi=6 -o page-left=72 -o page-top=72';
    $GLOBALS['more_secure']['hylafax_enscript'] = 'enscript -M Letter -B -e^ --margins=36:36:36:36';
    foreach ($GLOBALS['more_secure'] as $key => $value) {
        $GLOBALS['more_secure'][$key] = $cryptoGen->encryptStandard($value);
    }
}

$GLOBALS['oer_config']['ofx']['bankid']     = "123456789";
$GLOBALS['oer_config']['ofx']['acctid']     = "123456789";
$GLOBALS['oer_config']['prescriptions']['format'] = "";
$GLOBALS['oer_config']['documents']['repopath'] = $GLOBALS['OE_SITE_DIR'] . "/documents/";
$GLOBALS['oer_config']['documents']['file_command_path'] = "/usr/bin/file";
$GLOBALS['oer_config']['prescriptions']['logo_pic'] = "Rx.png";
$GLOBALS['oer_config']['prescriptions']['sig_pic'] = "sig.png";
$GLOBALS['oer_config']['prescriptions']['use_signature'] = false;
$GLOBALS['oer_config']['prescriptions']['shading'] = false;
$GLOBALS['oer_config']['prescriptions']['sendfax'] = '';
$GLOBALS['oer_config']['prescriptions']['prefix'] = '';
$GLOBALS['oer_config']['druglabels']['paper_size'] = [0, 0, 216, 216];
$GLOBALS['oer_config']['druglabels']['left']   = 18;
$GLOBALS['oer_config']['druglabels']['right']  = 18;
$GLOBALS['oer_config']['druglabels']['top']    = 18;
$GLOBALS['oer_config']['druglabels']['bottom'] = 18;
$GLOBALS['oer_config']['druglabels']['logo_pic'] = 'druglogo.png';
$GLOBALS['oer_config']['druglabels']['disclaimer'] =
  'Caution: Federal law prohibits dispensing without a prescription. ' .
  'Use only as directed.';

$GLOBALS['oer_config']['prescriptions']['logo'] = __DIR__ .
  "/../../interface/pic/" . $GLOBALS['oer_config']['prescriptions']['logo_pic'];
$GLOBALS['oer_config']['prescriptions']['signature'] = __DIR__ .
  "/../../interface/pic/" . $GLOBALS['oer_config']['prescriptions']['sig_pic'];

$GLOBALS['oer_config']['druglabels']['logo'] = __DIR__ .
  "/../../interface/pic/" . $GLOBALS['oer_config']['druglabels']['logo_pic'];

$GLOBALS['oer_config']['documents']['repository'] = $GLOBALS['oer_config']['documents']['repopath'];
CONFIGEOF

                chown 1000:1000 "$${CONFIG_FILE}"
                chmod 600 "$${CONFIG_FILE}"
                echo "✓ Created default config.php"
              fi
            fi

            echo "================================================"
            echo "✓ OpenEMR NFS Setup Completed"
            echo "================================================"
          EOT
        ]
        mount_nfs         = true
        mount_gcs_volumes = []
        depends_on_jobs   = []
        execute_on_apply  = true
      },

      # Job 2: Database Initialization
      {
        name        = "db-init"
        description = "Create MySQL Database and User"
        image       = "alpine:3.19"
        command     = ["/bin/sh", "-c"]
        args = [
          <<-EOT
            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use DB_IP if available, else DB_HOST.
            TARGET_DB_HOST="$${DB_IP:-$${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Check if using Unix socket or TCP
            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "Using Unix socket connection."
                # Verify socket existence (optional, or just retry connection)
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
        depends_on_jobs   = []
        execute_on_apply  = true
      }
    ]

    startup_probe = {
      enabled               = true
      type                  = "TCP"
      path                  = "/"
      initial_delay_seconds = 240
      timeout_seconds       = 60
      period_seconds        = 240
      failure_threshold     = 5
    }

    liveness_probe = {
      enabled               = true
      type                  = "HTTP"
      path                  = "/interface/login/login.php"
      initial_delay_seconds = 300
      timeout_seconds       = 60
      period_seconds        = 60
      failure_threshold     = 3
    }
  }

  application_modules = {
    openemr = local.openemr_module
  }

  module_env_vars = {
    MYSQL_DATABASE = local.database_name_full
    MYSQL_USER     = local.database_user_full
    MYSQL_HOST     = local.db_internal_ip
    # MYSQL_HOST     = local.enable_cloudsql_volume ? "${local.cloudsql_volume_mount_path}/${local.project.project_id}:${local.db_instance_region}:${local.db_instance_name}" : local.db_internal_ip
    MYSQL_PORT      = "3306"
    OE_USER         = "admin"
    MANUAL_SETUP    = "no"
    BACKUP_FILEID   = local.final_backup_uri != null ? local.final_backup_uri : ""
    SWARM_MODE      = "no"
    REDIS_SERVER    = var.enable_redis ? (var.redis_host != "" ? var.redis_host : (local.nfs_server_exists ? local.nfs_internal_ip : "")) : ""
    REDIS_PORT      = var.enable_redis ? (var.redis_port != "" ? var.redis_port : "6379") : ""
    MYSQL_ROOT_PASS = "BLANK"
  }

  module_secret_env_vars = {

    OE_PASS    = try(google_secret_manager_secret.openemr_admin_password[0].secret_id, "")
    MYSQL_PASS = try(google_secret_manager_secret.db_password[0].secret_id, "")
  }

  module_storage_buckets = []
}

# ==============================================================================
# OPENEMR SPECIFIC RESOURCES
# ==============================================================================
resource "random_password" "openemr_admin_password" {
  count   = 1
  length  = 20
  special = false
}

resource "google_secret_manager_secret" "openemr_admin_password" {
  count     = 1
  secret_id = "${local.wrapper_prefix}-admin-password"
  replication {
    auto {}
  }
  project = var.existing_project_id
}

resource "google_secret_manager_secret_version" "openemr_admin_password" {
  count       = 1
  secret      = google_secret_manager_secret.openemr_admin_password[0].id
  secret_data = random_password.openemr_admin_password[0].result
}
