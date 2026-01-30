FROM php:8.3-apache

ARG APP_VERSION
ENV MOODLE_VERSION=${APP_VERSION} \
    MOODLE_DATA_DIR=/var/moodledata \
    MOODLE_WWW_DIR=/var/www/html \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies and PHP extensions
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        git \
        unzip \
        locales \
        ghostscript \
        cron \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt1-dev \
        default-mysql-client \
        postgresql-client \
        libicu-dev \
        libzip-dev \
        libldap2-dev \
        libonig-dev \
        libcurl4-openssl-dev \
        tini \
    ; \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    ; \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu; \
    docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        mysqli \
        pgsql \
        pdo_mysql \
        pdo_pgsql \
        opcache \
        soap \
        zip \
        exif \
        xmlrpc \
        ldap \
        mbstring \
        curl \
        bcmath \
    ; \
    pecl install redis; \
    docker-php-ext-enable redis; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    ln -sf /dev/stdout /var/log/apache2/access.log; \
    ln -sf /dev/stderr /var/log/apache2/error.log

# Configure PHP
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=256'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
    { \
        echo 'memory_limit = 512M'; \
        echo 'upload_max_filesize = 512M'; \
        echo 'post_max_size = 512M'; \
        echo 'max_execution_time = 300'; \
        echo 'max_input_time = 300'; \
        echo 'max_input_vars = 5000'; \
        echo 'file_uploads = On'; \
    } > /usr/local/etc/php/conf.d/moodle.ini; \
    { \
        echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT'; \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'log_errors_max_len = 1024'; \
        echo 'ignore_repeated_errors = On'; \
        echo 'html_errors = Off'; \
    } > /usr/local/etc/php/conf.d/error-logging.ini

# Configure Apache
RUN set -eux; \
    a2enmod rewrite expires headers remoteip; \
    { \
        echo 'RemoteIPHeader X-Forwarded-For'; \
        echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
        echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
        echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
        echo 'RemoteIPInternalProxy 169.254.0.0/16'; \
        echo 'RemoteIPInternalProxy 127.0.0.0/8'; \
    } > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' /etc/apache2/apache2.conf

# Install Moodle
RUN set -eux; \
    mkdir -p ${MOODLE_WWW_DIR} ${MOODLE_DATA_DIR}; \
    curl -fSL "https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz" -o /tmp/moodle.tgz; \
    tar -xzf /tmp/moodle.tgz -C ${MOODLE_WWW_DIR} --strip-components=1; \
    rm /tmp/moodle.tgz; \
    chown -R www-data:www-data ${MOODLE_WWW_DIR} ${MOODLE_DATA_DIR}; \
    chmod -R 755 ${MOODLE_WWW_DIR}; \
    chmod -R 770 ${MOODLE_DATA_DIR}

# Create Cron
RUN echo "*/1 * * * * www-data /usr/local/bin/php ${MOODLE_WWW_DIR}/admin/cli/cron.php >/dev/null 2>&1" > /etc/cron.d/moodle-cron && \
    chmod 0644 /etc/cron.d/moodle-cron && \
    crontab /etc/cron.d/moodle-cron

# Copy entrypoint and config
COPY docker-entrypoint.sh /usr/local/bin/
COPY moodle-config-template.php /usr/local/share/moodle-config-template.php
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Healthcheck
RUN echo '#!/bin/bash' > /usr/local/bin/healthcheck.sh && \
    echo 'curl -f http://localhost/login/index.php || exit 1' >> /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh

WORKDIR ${MOODLE_WWW_DIR}
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
