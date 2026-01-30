#!/bin/sh
# OpenEMR startup script optimized for Google Cloud Run
set -e

# Source dev tools library
. /root/devtoolsLibrary.source

swarm_wait() {
    if [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
        return 0
    else
        return 1
    fi
}

auto_setup() {
    prepareVariables
    find . -not -perm 600 -exec chmod 600 {} \+

    # Create temporary file cache for auto_configure.php
    TMP_FILE_CACHE_LOCATION="/tmp/php-file-cache"
    mkdir -p ${TMP_FILE_CACHE_LOCATION}

    # Create auto_configure.ini for opcache
    touch auto_configure.ini
    echo "opcache.enable=1" >> auto_configure.ini
    echo "opcache.enable_cli=1" >> auto_configure.ini
    echo "opcache.file_cache=${TMP_FILE_CACHE_LOCATION}" >> auto_configure.ini
    echo "opcache.file_cache_only=1" >> auto_configure.ini
    echo "opcache.file_cache_consistency_checks=1" >> auto_configure.ini
    echo "opcache.enable_file_override=1" >> auto_configure.ini
    echo "opcache.max_accelerated_files=1000000" >> auto_configure.ini

    # Run auto_configure
    php auto_configure.php -c auto_configure.ini -f ${CONFIGURATION} || return 1

    # Cleanup
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

# Authority and operator flags
AUTHORITY=yes
OPERATOR=yes

if [ "${K8S}" = "admin" ]; then
    OPERATOR=no
elif [ "${K8S}" = "worker" ]; then
    AUTHORITY=no
fi

# Swarm mode handling
if [ "${SWARM_MODE}" = "yes" ]; then
    set -o noclobber
    { > /var/www/localhost/htdocs/openemr/sites/docker-leader ; } &> /dev/null || AUTHORITY=no
    set +o noclobber

    if [ "${AUTHORITY}" = "no" ] && [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
        while swarm_wait; do
            echo "Waiting for docker-leader to finish configuration..."
            sleep 10
        done
    fi

    if [ "${AUTHORITY}" = "yes" ]; then
        touch /var/www/localhost/htdocs/openemr/sites/docker-initiated
        if [ ! -f /etc/ssl/openssl.cnf ]; then
            echo "Restoring /etc/ssl directory."
            rsync --owner --group --perms --recursive --links /swarm-pieces/ssl /etc/
        fi
        if [ ! -d /var/www/localhost/htdocs/openemr/sites/default ]; then
            echo "Restoring sites directory."
            rsync --owner --group --perms --recursive --links /swarm-pieces/sites /var/www/localhost/htdocs/openemr/
        fi
    fi
fi

if [ "${AUTHORITY}" = "yes" ]; then
    sh ssl.sh
fi

# Upgrade handling
UPGRADE_YES=false
if [ "${AUTHORITY}" = "yes" ]; then
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

    if [ "${DOCKER_VERSION_ROOT}" = "${DOCKER_VERSION_CODE}" ] && \
       [ "${DOCKER_VERSION_ROOT}" -gt "${DOCKER_VERSION_SITES}" ]; then
        echo "Planning upgrade from ${DOCKER_VERSION_SITES} to ${DOCKER_VERSION_ROOT}"
        UPGRADE_YES=true
    fi
fi

# Check configuration status
CONFIG=$(php -r "require_once('/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php'); echo \$config;")
if [ "${AUTHORITY}" = "no" ] && [ "${CONFIG}" = "0" ]; then
    echo "Critical failure! Worker trying to run on missing configuration."
    exit 1
fi

# Certificate management (for Cloud SQL, Redis, etc.)
for cert_type in mysql couchdb ldap redis; do
    for cert_file in ca cert key; do
        cert_path="/root/certs/${cert_type}/${cert_type}-${cert_file}"
        dest_path="/var/www/localhost/htdocs/openemr/sites/default/documents/certificates/${cert_type}-${cert_file}"

        if [ -f "${cert_path}" ] && [ ! -f "${dest_path}" ]; then
            echo "Copied ${cert_type}-${cert_file}"
            cp "${cert_path}" "${dest_path}"
        fi
    done
done

# Auto setup if needed
if [ "${AUTHORITY}" = "yes" ]; then
    if [ "${CONFIG}" = "0" ] && \
       [ "${MYSQL_HOST}" != "" ] && \
       [ "${MYSQL_ROOT_PASS}" != "" ] && \
       [ "${MANUAL_SETUP}" != "yes" ]; then
        echo "Running automated setup..."
        while ! auto_setup; do
            echo "Setup failed. Retrying..."
            echo " - Verify MySQL container is running"
            echo " - Check MySQL credentials"
            sleep 1
        done
        echo "Setup complete!"
    fi
fi

# Perform upgrade if needed
if [ "${AUTHORITY}" = "yes" ] && [ "${CONFIG}" = "1" ] && [ "${MANUAL_SETUP}" != "yes" ]; then
    if ${UPGRADE_YES}; then
        echo "Attempting upgrade..."
        c=${DOCKER_VERSION_SITES}
        while [ "${c}" -le "${DOCKER_VERSION_ROOT}" ]; do
            if [ "${c}" -gt "${DOCKER_VERSION_SITES}" ]; then
                echo "Processing fsupgrade-${c}.sh"
                sh /root/fsupgrade-${c}.sh
            fi
            c=$((c + 1))
        done
        echo -n ${DOCKER_VERSION_ROOT} > /var/www/localhost/htdocs/openemr/sites/default/docker-version
        echo "Upgrade completed"
    fi
fi

# Redis configuration
if [ "${REDIS_SERVER}" != "" ] && [ ! -f /etc/php-redis-configured ]; then
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
        phpize83
        ./configure --with-php-config=/usr/bin/php-config83 --enable-redis-igbinary
        make -j $(nproc --all)
        make install
        echo "extension=redis" > /etc/php83/conf.d/20_redis.ini
        rm -fr /tmpredis
        apk del --no-cache git php83-dev gcc make g++
        cd /var/www/localhost/htdocs/openemr
    fi

    REDIS_PATH="${REDIS_SERVER}:6379"
    if [ "${REDIS_USERNAME}" != "" ] && [ "${REDIS_PASSWORD}" != "" ]; then
        REDIS_PATH="${REDIS_PATH}?auth[user]=${REDIS_USERNAME}\&auth[pass]=${REDIS_PASSWORD}"
        GET_CONNECTOR="\&"
    elif [ "${REDIS_PASSWORD}" != "" ]; then
        REDIS_PATH="${REDIS_PATH}?auth[pass]=${REDIS_PASSWORD}"
        GET_CONNECTOR="\&"
    else
        GET_CONNECTOR="?"
    fi

    if [ "${REDIS_X509}" = "yes" ]; then
        REDIS_PATH="tls://${REDIS_PATH}${GET_CONNECTOR}stream[cafile]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca\&stream[local_cert]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-cert\&stream[local_pk]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-key"
    elif [ "${REDIS_TLS}" = "yes" ]; then
        REDIS_PATH="tls://${REDIS_PATH}${GET_CONNECTOR}stream[cafile]=file:///var/www/localhost/htdocs/openemr/sites/default/documents/certificates/redis-ca"
    else
        REDIS_PATH="tcp://${REDIS_PATH}"
    fi

    sed -i "s@session.save_handler = files@session.save_handler = redis@" /etc/php83/php.ini
    sed -i "s@;session.save_path = \"/tmp\"@session.save_path = \"${REDIS_PATH}\"@" /etc/php83/php.ini
    touch /etc/php-redis-configured
fi

# File permissions configuration
if [ "${AUTHORITY}" = "yes" ] || [ "${SWARM_MODE}" = "yes" ]; then
    if [ "${CONFIG}" = "1" ] && [ "${MANUAL_SETUP}" != "yes" ]; then
        if [ -f auto_configure.php ]; then
            echo "Setting file/directory permissions..."
            find . -type d -not -path "./sites/default/documents/*" -not -perm 500 -exec chmod 500 {} \+
            find . -type f -not -path "./sites/default/documents/*" -not -path './openemr.sh' -not -perm 400 -exec chmod 400 {} \+
            chmod 700 openemr.sh

            if [ "${SWARM_MODE}" != "yes" ] || [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
                echo "Setting sites/default/documents permissions..."
                find sites/default/documents -not -perm 700 -exec chmod 700 {} \+
            fi

            echo "Removing setup scripts..."
            rm -f admin.php acl_upgrade.php setup.php sql_patch.php sql_upgrade.php ippf_upgrade.php auto_configure.php
        fi
    fi
fi

# Certificate permissions
if [ "${SWARM_MODE}" != "yes" ] || [ ! -f /var/www/localhost/htdocs/openemr/sites/docker-completed ]; then
    for cert in mysql-ca mysql-cert mysql-key redis-ca redis-cert redis-key; do
        cert_file="/var/www/localhost/htdocs/openemr/sites/default/documents/certificates/${cert}"
        if [ -f "${cert_file}" ]; then
            echo "Adjusted permissions for ${cert}"
            chmod 744 "${cert_file}"
        fi
    done
fi

# XDebug or OPcache configuration
if [ "${XDEBUG_IDE_KEY}" != "" ] || [ "${XDEBUG_ON}" = 1 ]; then
    sh xdebug.sh
    if [ ! -f /etc/php-opcache-jit-configured ]; then
        echo "opcache.enable=0" >> /etc/php83/php.ini
        touch /etc/php-opcache-jit-configured
    fi
else
    if [ ! -f /etc/php-opcache-jit-configured ]; then
        echo "opcache.jit=tracing" >> /etc/php83/php.ini
        echo "opcache.jit_buffer_size=100M" >> /etc/php83/php.ini
        touch /etc/php-opcache-jit-configured
    fi
fi

# Swarm mode completion
if [ "${AUTHORITY}" = "yes" ] && [ "${SWARM_MODE}" = "yes" ]; then
    touch /var/www/localhost/htdocs/openemr/sites/docker-completed
    rm -f /var/www/localhost/htdocs/openemr/sites/docker-leader
fi

if [ "${SWARM_MODE}" = "yes" ]; then
    echo "Swarm mode: instance ready"
    touch /root/instance-swarm-ready
fi

echo ""
echo "Love OpenEMR? Support via: https://opencollective.com/openemr/donate"
echo ""

# Start services (Cloud Run optimized)
if [ "${OPERATOR}" = yes ]; then
    # Configure Apache to listen on Cloud Run PORT
    sed -i "s/^Listen 80$/Listen ${PORT:-8080}/" /etc/apache2/httpd.conf
    sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT:-8080}>/" /etc/apache2/conf.d/openemr.conf

    echo 'Starting PHP-FPM...'
    /usr/sbin/php-fpm83

    echo "Starting Apache on port ${PORT:-8080}..."
    exec /usr/sbin/httpd -D FOREGROUND
fi

echo 'OpenEMR configuration tasks concluded.'
