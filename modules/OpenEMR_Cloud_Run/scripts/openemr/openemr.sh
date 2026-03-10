#!/bin/sh
# Allows customization of openemr credentials, preventing the need for manual setup
#  (Note can force a manual setup by setting MANUAL_SETUP to 'yes')
#  - Required settings for auto installation are MYSQL_HOST and MYSQL_ROOT_PASS
#  -  (note that can force MYSQL_ROOT_PASS to be empty by passing as 'BLANK' variable)
#  - Optional settings for auto installation are:
#    - Setting db parameters MYSQL_USER, MYSQL_PASS, MYSQL_DATABASE
#    - Setting openemr parameters OE_USER, OE_PASS
# TODO: xdebug options should be given here
set -e

# shellcheck source=SCRIPTDIR/utilities/devtoolsLibrary.source
. /root/devtoolsLibrary.source

swarm_wait() {
    if [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
        # true
        return 0
    else
        # false
        return 1
    fi
}

auto_setup() {
    prepareVariables

    # Relax permissions adjustment to avoid failures on broken links/missing files
    # Exclude sites/ directory since it may be NFS-mounted and root cannot chmod there
    find . -path ./sites -prune -o -type f -not -perm 600 -exec chmod 600 {} + 2>/dev/null || true

    #create temporary file cache directory for auto_configure.php to use
    TMP_FILE_CACHE_LOCATION="/tmp/php-file-cache"
    if [ ! -d "${TMP_FILE_CACHE_LOCATION}" ]; then
        mkdir -p "${TMP_FILE_CACHE_LOCATION}"
        chown apache:apache "${TMP_FILE_CACHE_LOCATION}"
    fi

    #create auto_configure.ini to be able to leverage opcache for operations
    touch auto_configure.ini
    echo "opcache.enable=1" >> auto_configure.ini
    echo "opcache.enable_cli=1" >> auto_configure.ini
    echo "opcache.file_cache=${TMP_FILE_CACHE_LOCATION}" >> auto_configure.ini
    echo "opcache.file_cache_only=1" >> auto_configure.ini
    echo "opcache.file_cache_consistency_checks=1" >> auto_configure.ini
    echo "opcache.enable_file_override=1" >> auto_configure.ini
    echo "opcache.max_accelerated_files=1000000" >> auto_configure.ini
    
    # Ensure config file is readable by apache
    chmod 644 auto_configure.ini

    #ensure auto_configure.php is readable by the apache user before running it
    chmod 644 auto_configure.php

    # Re-check if another instance already completed setup (Cloud Run race condition)
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/sqlconf.php ]; then
        RECHECK_CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;" 2>/dev/null) || RECHECK_CONFIG="0"
        if [ "${RECHECK_CONFIG}" = "1" ]; then
            echo "Another instance already completed setup. Skipping auto_configure."
            rm -rf ${TMP_FILE_CACHE_LOCATION}
            rm -f auto_configure.ini
            return 0
        fi
    fi

    #run auto_configure as apache user
    su -s /bin/sh -c "php -c auto_configure.ini auto_configure.php -f ${CONFIGURATION} no_root_db_access=1" apache || return 1

    #remove temporary file cache directory and auto_configure.ini
    rm -r ${TMP_FILE_CACHE_LOCATION}
    rm auto_configure.ini

    echo "OpenEMR configured."
    CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;")
    if [ "${CONFIG}" = "0" ]; then
        echo "Error in auto-config. Configuration failed."
        exit 2
    fi

    setGlobalSettings
}



# AUTHORITY is the right to change OpenEMR's configured state
# - true for singletons, swarm leaders, and the Kubernetes startup job
# - false for swarm members and Kubernetes workers
# OPERATOR is the right to launch Apache and serve OpenEMR
# - true for singletons, swarm members (leader or otherwise), and Kubernetes workers
# - false for the Kubernetes startup job and manual image runs
AUTHORITY=yes
OPERATOR=yes
if [ "${K8S}" = "admin" ]; then
    OPERATOR=no
elif [ "${K8S}" = "worker" ]; then
    AUTHORITY=no
fi

# For Cloud Run: start a temporary health responder to pass startup and liveness probes
# while the OpenEMR installation runs. Cloud Run enforces a hard 10-minute startup timeout
# and kills containers whose port isn't open by then. The OpenEMR SQL schema installation
# can exceed 10 minutes, so we need port open immediately.
HEALTH_PROBE_PID=""
if [ "${OPERATOR}" = "yes" ] && [ "${SWARM_MODE}" != "yes" ] && [ -z "${K8S}" ]; then
    PROBE_PORT="${PORT:-80}"
    mkdir -p /tmp/health-probe/interface/login
    echo '<?php http_response_code(200); echo "starting";' > /tmp/health-probe/interface/login/login.php
    echo '<?php http_response_code(200); echo "ok";' > /tmp/health-probe/index.php
    php -S "0.0.0.0:${PROBE_PORT}" -t /tmp/health-probe >/dev/null 2>&1 &
    HEALTH_PROBE_PID=$!
    echo "Started temporary health responder on port ${PROBE_PORT} (PID: ${HEALTH_PROBE_PID})"
fi

if [ "${SWARM_MODE}" = "yes" ]; then
    # atomically test for leadership (using POSIX-compliant syntax)
    set -C
    ( : > /var/www/localhost/htdocs/openemr/sites/docker-leader ) 2>/dev/null || AUTHORITY=no
    set +C

    if [ "${AUTHORITY}" = "no" ] &&
       [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
        while swarm_wait; do
            echo "Waiting for the docker-leader to finish configuration before proceeding."
            sleep 10;
        done
    fi

    if [ "${AUTHORITY}" = "yes" ]; then
        touch /var/www/localhost/htdocs/openemr/sites/docker-initiated
        if [ ! -f /etc/ssl/openssl.cnf ]; then
            # Restore the emptied /etc/ssl directory
            echo "Restoring empty /etc/ssl directory."
            rsync --owner --group --perms --recursive --links /swarm-pieces/ssl /etc/
        fi
        if [ ! -d /var/www/localhost/htdocs/openemr/sites/default ]; then
            # Restore the emptied /var/www/localhost/htdocs/openemr/sites directory
            echo "Restoring empty /var/www/localhost/htdocs/openemr/sites directory."
            rsync --owner --group --perms --recursive --links /swarm-pieces/sites /var/www/localhost/htdocs/openemr/
        fi
    fi
fi

# SSL setup removed for Cloud Run

UPGRADE_YES=false;
if [ "${AUTHORITY}" = "yes" ]; then
    # Figure out if need to do upgrade
    if [ -f /root/docker-version ]; then
        DOCKER_VERSION_ROOT=$(cat /root/docker-version)
    else
        DOCKER_VERSION_ROOT=0
    fi
    if [ -f /var/www/localhost/htdocs/openemr/docker-version ]; then
        DOCKER_VERSION_CODE=$(cat /var/www/localhost/htdocs/openemr/docker-version)
    else
        DOCKER_VERSION_CODE=0
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/docker-version ]; then
        DOCKER_VERSION_SITES=$(cat /var/www/localhost/htdocs/openemr/sites/default/docker-version)
    else
        DOCKER_VERSION_SITES=0
    fi

    # Only perform upgrade if the sites dir is shared and not entire openemr directory
    if [ "${DOCKER_VERSION_ROOT}" = "${DOCKER_VERSION_CODE}" ] &&
       [ "${DOCKER_VERSION_ROOT}" -gt "${DOCKER_VERSION_SITES}" ]; then
        echo "Plan to try an upgrade from ${DOCKER_VERSION_SITES} to ${DOCKER_VERSION_ROOT}"
        UPGRADE_YES=true;
    fi
fi

# Check if sqlconf.php exists and get config value with error handling
if [ -f /var/www/localhost/htdocs/openemr/sites/default/sqlconf.php ]; then
    CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;" 2>/dev/null) || CONFIG="0"
else
    CONFIG="0"
fi
if [ "${AUTHORITY}" = "no" ] &&
    [ "${CONFIG}" = "0" ]; then
    echo "Critical failure! An OpenEMR worker is trying to run on a missing configuration."
    echo " - Is this due to a Kubernetes grant hiccup?"
    echo "The worker will now terminate."
    exit 1
fi

# key/cert management (if key/cert exists in /root/certs/.. and not in sites/defauly/documents/certificates, then it will be copied into it)
#  current use case is bringing in as secret(s) in kubernetes, but can bring in as shared volume or directly brought in during docker build
#   dir structure:
#    /root/certs/mysql/server/mysql-ca (supported)
#    /root/certs/mysql/client/mysql-cert (supported)
#    /root/certs/mysql/client/mysql-key (supported)
#    /root/certs/couchdb/couchdb-ca (supported)
#    /root/certs/couchdb/couchdb-cert (supported)
#    /root/certs/couchdb/couchdb-key (supported)
#    /root/certs/ldap/ldap-ca (supported)
#    /root/certs/ldap/ldap-cert (supported)
#    /root/certs/ldap/ldap-key (supported)
#    /root/certs/redis/redis-ca (supported)
if [ -f /root/certs/mysql/server/mysql-ca ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca ]; then
    echo "copied over mysql-ca"
    cp /root/certs/mysql/server/mysql-ca /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca
fi
if [ -f /root/certs/mysql/server/mysql-cert ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-cert ]; then
    echo "copied over mysql-cert"
    cp /root/certs/mysql/server/mysql-cert /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-cert
fi
if [ -f /root/certs/mysql/server/mysql-key ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-key ]; then
    echo "copied over mysql-key"
    cp /root/certs/mysql/server/mysql-key /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-key
fi
if [ -f /root/certs/couchdb/couchdb-ca ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-ca ]; then
    echo "copied over couchdb-ca"
    cp /root/certs/couchdb/couchdb-ca /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-ca
fi
if [ -f /root/certs/couchdb/couchdb-cert ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-cert ]; then
    echo "copied over couchdb-cert"
    cp /root/certs/couchdb/couchdb-cert /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-cert
fi
if [ -f /root/certs/couchdb/couchdb-key ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-key ]; then
    echo "copied over couchdb-key"
    cp /root/certs/couchdb/couchdb-key /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/couchdb-key
fi
if [ -f /root/certs/ldap/ldap-ca ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-ca ]; then
    echo "copied over ldap-ca"
    cp /root/certs/ldap/ldap-ca /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-ca
fi
if [ -f /root/certs/ldap/ldap-cert ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-cert ]; then
    echo "copied over ldap-cert"
    cp /root/certs/ldap/ldap-cert /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-cert
fi
if [ -f /root/certs/ldap/ldap-key ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-key ]; then
    echo "copied over ldap-key"
    cp /root/certs/ldap/ldap-key /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/ldap-key
fi
if [ -f /root/certs/redis/redis-ca ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca ]; then
    echo "copied over redis-ca"
    cp /root/certs/redis/redis-ca /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca
fi
if [ -f /root/certs/redis/redis-cert ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert ]; then
    echo "copied over redis-cert"
    cp /root/certs/redis/redis-cert /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert
fi
if [ -f /root/certs/redis/redis-key ] &&
   [ ! -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key ]; then
    echo "copied over redis-key"
    cp /root/certs/redis/redis-key /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key
fi

if [ "${AUTHORITY}" = "yes" ]; then
    if [ "${CONFIG}" = "0" ] &&
       [ "${MYSQL_HOST}" != "" ] &&
       [ "${MYSQL_ROOT_PASS}" != "" ] &&
       [ "${MANUAL_SETUP}" != "yes" ]; then

        echo "Running quick setup!"

        # Prepare database connection variables for the readiness check
        prepareVariables

        # Wait for MySQL to be fully ready (accepting queries, not just port open)
        echo "Waiting for MySQL to accept connections..."
        WAIT_ELAPSED=0
        MAX_WAIT_SECONDS=300
        while [ "${WAIT_ELAPSED}" -lt "${MAX_WAIT_SECONDS}" ]; do
            if mysql -u "${CUSTOM_USER}" --password="${CUSTOM_PASSWORD}" -h "${MYSQL_HOST}" -P "${CUSTOM_PORT}" -e "SELECT 1" "${CUSTOM_DATABASE}" >/dev/null 2>&1; then
                echo "MySQL is ready and accepting queries."
                break
            fi
            WAIT_ELAPSED=$((WAIT_ELAPSED + 5))
            echo "MySQL not ready yet, waiting... (${WAIT_ELAPSED}s/${MAX_WAIT_SECONDS}s)"
            sleep 5
        done
        if [ "${WAIT_ELAPSED}" -ge "${MAX_WAIT_SECONDS}" ]; then
            echo "WARNING: MySQL did not become ready within ${MAX_WAIT_SECONDS} seconds. Attempting setup anyway."
        fi

        SETUP_ATTEMPTS=0
        MAX_SETUP_ATTEMPTS=10
        while ! auto_setup; do
            SETUP_ATTEMPTS=$((SETUP_ATTEMPTS + 1))
            echo "Couldn't set up. Any of these reasons could be what's wrong:"
            echo " - You didn't spin up a MySQL container or connect your OpenEMR container to a mysql instance"
            echo " - MySQL is still starting up and wasn't ready for connection yet"
            echo " - The Mysql credentials were incorrect"
            # Re-check if another instance completed setup during our retry wait
            if [ -f /var/www/localhost/htdocs/openemr/sites/default/sqlconf.php ]; then
                RETRY_CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;" 2>/dev/null) || RETRY_CONFIG="0"
                if [ "${RETRY_CONFIG}" = "1" ]; then
                    echo "Another instance completed setup. Skipping further attempts."
                    break
                fi
            fi
            if [ "${SETUP_ATTEMPTS}" -ge "${MAX_SETUP_ATTEMPTS}" ]; then
                echo "Exceeded ${MAX_SETUP_ATTEMPTS} setup attempts. Exiting to avoid infinite loop."
                echo "If the database was partially configured, you may need to drop and recreate it."
                exit 1
            fi
            # Clean up partially-created tables before retrying to prevent "table already exists" errors
            TABLE_COUNT=$(mysql -u "${CUSTOM_USER}" --password="${CUSTOM_PASSWORD}" -h "${MYSQL_HOST}" -P "${CUSTOM_PORT}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${CUSTOM_DATABASE}'" 2>/dev/null) || TABLE_COUNT="0"
            if [ "${TABLE_COUNT}" -gt "0" ]; then
                echo "Found ${TABLE_COUNT} tables from partial install. Dropping all tables before retry..."
                mysqldump -u "${CUSTOM_USER}" --password="${CUSTOM_PASSWORD}" -h "${MYSQL_HOST}" -P "${CUSTOM_PORT}" --add-drop-table --no-data "${CUSTOM_DATABASE}" 2>/dev/null \
                    | grep ^DROP \
                    | awk 'BEGIN { print "SET FOREIGN_KEY_CHECKS=0;" } { print $0 } END { print "SET FOREIGN_KEY_CHECKS=1;" }' \
                    | mysql -u "${CUSTOM_USER}" --password="${CUSTOM_PASSWORD}" -h "${MYSQL_HOST}" -P "${CUSTOM_PORT}" "${CUSTOM_DATABASE}" 2>/dev/null || true
                echo "Table cleanup complete."
            fi
            # Exponential backoff: 5, 10, 20, 40, 60, 60, 60, ...
            BACKOFF=$((5 * (2 ** (SETUP_ATTEMPTS - 1))))
            if [ "${BACKOFF}" -gt 60 ]; then
                BACKOFF=60
            fi
            echo "Retrying in ${BACKOFF} seconds... (attempt ${SETUP_ATTEMPTS}/${MAX_SETUP_ATTEMPTS})"
            sleep ${BACKOFF};
        done
        echo "Setup Complete!"
        # Re-read CONFIG since auto_setup just set $config = 1 in sqlconf.php
        CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;" 2>/dev/null) || CONFIG="0"
    fi
fi

if
   [ "${AUTHORITY}" = "yes" ] &&
   [ "${CONFIG}" = "1" ] &&
   [ "${MANUAL_SETUP}" != "yes" ]; then
    # OpenEMR has been configured

    if ${UPGRADE_YES}; then
        # Need to do the upgrade
        echo "Attempting upgrade"
        c=${DOCKER_VERSION_SITES}
        while [ "${c}" -le "${DOCKER_VERSION_ROOT}" ]; do
            if [ "${c}" -gt "${DOCKER_VERSION_SITES}" ] ; then
                echo "Start: Processing fsupgrade-${c}.sh upgrade script"
                sh /root/fsupgrade-${c}.sh
                echo "Completed: Processing fsupgrade-${c}.sh upgrade script"
            fi
            c=$(( c + 1 ))
        done
        echo -n ${DOCKER_VERSION_ROOT} > /var/www/localhost/htdocs/openemr/sites/default/docker-version
        echo "Completed upgrade"
    fi
fi

if [ "${REDIS_SERVER}" != "" ] &&
   [ ! -f /etc/php-redis-configured ]; then
    # Doing this redis section before the below openemr file config section since both these sections take some time
    #  and in swarm mode the docker will be functional after this redis section (ie. if do the below config section first
    #  then the breakage time of the pod will be markedly less).

    # Support phpredis build
    #   This will allow building phpredis towards either most recent development version "develop",
    #    or a specific sha1 commit id, such as "e571a81f8d3009aab38cbb88dde865edeb0607ac".
    #    This allows support for tls (ie. encrypted connections) since not available in production
    #    version 5.3.7 .
    if [ "${PHPREDIS_BUILD}" != "" ]; then
      apk update
      apk del --no-cache php83-redis
      apk add --no-cache git php83-dev php83-pecl-igbinary gcc make g++
      mkdir /tmpredis
      cd /tmpredis
      git clone https://github.com/phpredis/phpredis.git
      cd /tmpredis/phpredis
      if [ "${PHPREDIS_BUILD}" != "develop" ]; then
          git reset --hard "${PHPREDIS_BUILD}"
      fi
      # note for php 8.3, needed to change from 'phpize' to:
      phpize83
      # note for php 8.3, needed to change from './configure --enable-redis-igbinary' to:
      ./configure --with-php-config=/usr/bin/php-config83 --enable-redis-igbinary
      make -j $(nproc --all)
      make install
      echo "extension=redis" > /etc/php83/conf.d/20_redis.ini
      rm -fr /tmpredis/phpredis
      apk del --no-cache git php83-dev gcc make g++
      cd /var/www/localhost/htdocs/openemr
    fi

    # Support the following redis auth:
    #   No username and No password set (using redis default user with nopass set)
    #   Both username and password set (using the redis user and pertinent password)
    #   Only password set (using redis default user and pertinent password)
    #   NOTE that only username set is not supported (in this case will ignore the username
    #      and use no username and no password set mode)
    REDIS_PORT_ACTUAL=${REDIS_PORT:-6379}
    REDIS_PATH="${REDIS_SERVER}:${REDIS_PORT_ACTUAL}"
    if [ "${REDIS_USERNAME}" != "" ] &&
       [ "${REDIS_PASSWORD}" != "" ]; then
        echo "redis setup with username and password"
        REDIS_PATH="${REDIS_PATH}?auth[user]=${REDIS_USERNAME}\&auth[pass]=${REDIS_PASSWORD}"
        GET_CONNECTOR="\&"
    elif [ "${REDIS_PASSWORD}" != "" ]; then
        echo "redis setup with password"
        # only a password, thus using the default user which redis has set a password for
        REDIS_PATH="${REDIS_PATH}?auth[pass]=${REDIS_PASSWORD}"
        GET_CONNECTOR="\&"
    else
        # no user or password, thus using the default user which is set to nopass in redis
        # so just keeping original REDIS_PATH: REDIS_PATH="$REDIS_PATH"
        echo "redis setup"
        GET_CONNECTOR="?"
    fi

    if [ "${REDIS_X509}" = "yes" ]; then
        echo "redis x509"
        REDIS_PATH="tls://${REDIS_PATH}${GET_CONNECTOR}stream[cafile]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca\&stream[local_cert]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert\&stream[local_pk]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key"
    elif [ "${REDIS_TLS}" = "yes" ]; then
        echo "redis tls"
        REDIS_PATH="tls://${REDIS_PATH}${GET_CONNECTOR}stream[cafile]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca"
    else
        echo "redis tcp"
        REDIS_PATH="tcp://${REDIS_PATH}"
    fi

    sed -i "s@session.save_handler = files@session.save_handler = redis@" /etc/php83/php.ini
    sed -i "s@;session.save_path = \"/tmp\"@session.save_path = \"${REDIS_PATH}\"@" /etc/php83/php.ini
    # Ensure only configure this one time
    touch /etc/php-redis-configured
fi

if
   [ "${AUTHORITY}" = "yes" ] ||
   [ "${SWARM_MODE}" = "yes" ]; then
    if
    [ "${CONFIG}" = "1" ] &&
    [ "${MANUAL_SETUP}" != "yes" ]; then
    # OpenEMR has been configured

        if [ -f auto_configure.php ]; then
            # This section only runs once after per docker since auto_configure.php gets removed after this script

            # For Cloud Run deployments with NFS mounts, skip the slow find/chmod operations
            # since permissions are already set in the Docker image and the NFS init job
            # handles the sites/ directory permissions. This prevents startup timeouts.
            if [ "${SWARM_MODE}" != "yes" ] && [ -z "${K8S}" ]; then
                echo "Cloud Run mode detected - enforcing strict permissions (excluding NFS sites)"
                find . -maxdepth 1 -not -name "." -not -name "sites" -exec chown -R apache:apache {} +
                find . -maxdepth 1 -not -name "." -not -name "sites" -exec chmod -R u+rwX,g+rX,o-rwx {} +

                # Fix permissions for NFS-mounted files and directories
                # Note: chown might fail on NFS due to root squash, so we ensure loose permissions
                if [ -d sites/default ]; then
                    chmod 777 sites/default
                    chown apache:apache sites/default || true
                fi
                if [ -f sites/default/sqlconf.php ]; then
                    chown apache:apache sites/default/sqlconf.php || true
                    chmod 666 sites/default/sqlconf.php
                fi
                if [ -f sites/default/config.php ]; then
                    chown apache:apache sites/default/config.php || true
                    chmod 666 sites/default/config.php
                fi
                if [ -d sites/default/documents ]; then
                    # Ensure required subdirectories exist on NFS for CryptoGen key storage
                    mkdir -p sites/default/documents/logs_and_misc/methods
                    mkdir -p sites/default/documents/certificates
                    chown -R apache:apache sites/default/documents || true
                    chmod -R 777 sites/default/documents
                fi
            else
                echo "Setting user 'www' as owner of openemr/ and setting file/dir permissions to 400/500"

                # Exclude the entire sites directory since it may be NFS-mounted
                # set all directories to 500 (excluding sites/ which is handled separately)
                find . -type d -not -path "./sites/*" -not -path "./sites" -not -perm 500 -exec chmod 500 {} \+
                # set all file access to 400 (excluding sites/ which is handled separately)
                find . -type f -not -path "./sites/*" -not -path './openemr.sh' -not -perm 400 -exec chmod 400 {} \+

                echo "Default file permissions and ownership set, allowing writing to specific directories"
            fi
            chmod 700 openemr.sh

            # Set file and directory permissions for documents
            #  Note this is only done once in swarm mode (to prevent breakage) since is a shared volume.
            if
               [ "${SWARM_MODE}" != "yes" ] ||
               [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
                # Only set documents permissions if not on NFS (Cloud Run handles this in init job)
                if [ "${SWARM_MODE}" = "yes" ] || [ -n "${K8S}" ]; then
                    echo "Setting sites/default/documents permissions to 700"
                    find sites/default/documents -not -perm 700 -exec chmod 700 {} \+ 2>/dev/null || true
                fi
            fi

            echo "Removing remaining setup scripts"
            #remove all setup scripts
            rm -f admin.php
            rm -f acl_upgrade.php
            rm -f setup.php
            rm -f sql_patch.php
            rm -f sql_upgrade.php
            rm -f ippf_upgrade.php
            rm -f auto_configure.php
            echo "Setup scripts removed, we should be ready to go now!"
        fi
    fi
fi

#  Note this is only done once in swarm mode (to prevent breakage) since is a shared volume.
if
   [ "${SWARM_MODE}" != "yes" ] ||
   [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr adodb/laminas connections
        echo "adjusted permissions for mysql-ca"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-ca
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-cert ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr adodb/laminas connections
        echo "adjusted permissions for mysql-cert"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-cert
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-key ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr adodb/laminas connections
        echo "adjusted permissions for mysql-key"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/mysql-key
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr redis connections
        echo "adjusted permissions for redis-ca"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr redis connections
        echo "adjusted permissions for redis-cert"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert
    fi
    if [ -f /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key ]; then
        # for specific issue in docker and kubernetes that is required for successful openemr redis connections
        echo "adjusted permissions for redis-key"
        chmod 744 /var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key
    fi
fi

if [ "${XDEBUG_IDE_KEY}" != "" ] ||
   [ "${XDEBUG_ON}" = 1 ]; then
   sh xdebug.sh
   #also need to turn off opcache since it can not be turned on with xdebug
   if [ ! -f /etc/php-opcache-jit-configured ]; then
      echo "opcache.enable=0" >> /etc/php83/php.ini
      touch /etc/php-opcache-jit-configured
   fi
else
   # Configure opcache jit if Xdebug is not being used (note opcache is already on, so just need to add setting(s) to php.ini that are different from the default setting(s))
   if [ ! -f /etc/php-opcache-jit-configured ]; then
      echo "opcache.jit=tracing" >> /etc/php83/php.ini
      echo "opcache.jit_buffer_size=100M" >> /etc/php83/php.ini
      touch /etc/php-opcache-jit-configured
   fi
fi

if [ "${AUTHORITY}" = "yes" ] &&
   [ "${SWARM_MODE}" = "yes" ]; then
    # Set flag that the docker-leader configuration is complete
    touch /var/www/localhost/htdocs/openemr/sites/docker-completed
    rm -f /var/www/localhost/htdocs/openemr/sites/docker-leader
fi

if [ "${SWARM_MODE}" = "yes" ]; then
    # Set flag that the instance is ready when in swarm mode
    echo
    echo "swarm mode on: this instance is ready"
    echo
    touch /root/instance-swarm-ready
fi

echo
echo "Love OpenEMR? You can now support the project via the open collective:"
echo " > https://opencollective.com/openemr/donate"
echo

if [ "${OPERATOR}" = yes ]; then
    # Stop the temporary health responder before starting Apache on the same port
    if [ -n "${HEALTH_PROBE_PID}" ] && kill -0 "${HEALTH_PROBE_PID}" 2>/dev/null; then
        echo "Stopping temporary health responder (PID: ${HEALTH_PROBE_PID})..."
        kill "${HEALTH_PROBE_PID}" 2>/dev/null
        wait "${HEALTH_PROBE_PID}" 2>/dev/null || true
        rm -rf /tmp/health-probe
        # Brief pause to ensure the port is released
        sleep 1
    fi

    echo 'Starting PHP-FPM...'
    /usr/sbin/php-fpm83

    # Cloud Run dynamic port configuration
    APACHE_PORT="${PORT:-80}"
    echo "Updating Apache to listen on port ${APACHE_PORT}..."
    sed -i "s/^Listen .*/Listen 0.0.0.0:${APACHE_PORT}/" /etc/apache2/httpd.conf
    echo "ServerName localhost" >> /etc/apache2/httpd.conf

    echo 'Starting apache!'
    exec /usr/sbin/httpd -D FOREGROUND
fi

echo 'OpenEMR configuration tasks have concluded.'