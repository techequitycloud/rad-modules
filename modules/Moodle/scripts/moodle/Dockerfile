FROM ubuntu:jammy

# Retrieve the target architecture
ARG TARGETARCH
ARG APP_VERSION=4.5.1

EXPOSE 8080
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        gnupg \
        gnupg2 \
        wget \
        software-properties-common \
        xz-utils \
        unzip \
        git \
        locales \
        supervisor \
        gosu \
        pwgen \
        libcurl4 \
        libssl-dev \
        net-tools \
        procps \
        tini \
        nfs-common \
        netbase \
        fonts-noto-cjk \
        node-less \
        npm \
        libcurl3-dev \
        sudo && \
    add-apt-repository universe && \
    apt-get update

# 2. Install wkhtmltopdf
RUN if [ -z "$TARGETARCH" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=$TARGETARCH && \
    case $TARGETARCH in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_$WKHTMLTOPDF_ARCH.deb \
    && echo $WKHTMLTOPDF_SHA wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf wkhtmltox.deb

# 3. Install PostgreSQL client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && echo "Fetching GPG key..." \
    && (gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$repokey" || \
        gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "$repokey" || \
        gpg --batch --keyserver pgp.mit.edu --recv-keys "$repokey" || \
        (sleep 5 && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$repokey")) \
    && gpg --batch --armor --export "$repokey" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update \
    && apt-get install --no-install-recommends -y postgresql-client-15

# 4. Install PHP 8.3 and Apache
RUN add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
        apache2 \
        libapache2-mod-php8.3 \
        php8.3 \
        php8.3-cli \
        php8.3-common \
        php8.3-gd \
        php8.3-pgsql \
        php8.3-curl \
        php8.3-xmlrpc \
        php8.3-intl \
        php8.3-xml \
        php8.3-mbstring \
        php8.3-zip \
        php8.3-soap \
        php8.3-ldap \
        php8.3-redis \
        php8.3-opcache

# 5. Configure Apache
RUN sed -i 's/80/8080/g' /etc/apache2/ports.conf /etc/apache2/sites-available/*.conf && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod ssl

# 6. Configure PHP
RUN sed -i "s/.*max_input_vars.*/max_input_vars = 5000/" /etc/php/8.3/apache2/php.ini && \
    sed -i "s/.*memory_limit.*/memory_limit = 512M/" /etc/php/8.3/apache2/php.ini && \
    sed -i "s/.*post_max_size.*/post_max_size = 512M/" /etc/php/8.3/apache2/php.ini && \
    sed -i "s/.*upload_max_filesize.*/upload_max_filesize = 512M/" /etc/php/8.3/apache2/php.ini && \
    sed -i "s/.*max_execution_time.*/max_execution_time = 300/" /etc/php/8.3/apache2/php.ini

# 7. Download and install Moodle
RUN curl -fSL "https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz" -o /tmp/moodle.tar.gz \
    && tar -xzf /tmp/moodle.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/moodle.tar.gz \
    && rm -f /var/www/html/index.html \
    && chown -R www-data:www-data /var/www/html

# 8. Create necessary directories
RUN mkdir -p /var/run/apache2 /var/log/apache2 && \
    chown -R www-data:www-data /var/run/apache2 /var/log/apache2

# 9. Copy configuration files
COPY moodle-config.php /var/www/html/config.php
COPY foreground.sh /etc/apache2/foreground.sh
COPY cloudrun-entrypoint.sh /cloudrun-entrypoint.sh

# 10. Set permissions
RUN chmod +x /etc/apache2/foreground.sh /cloudrun-entrypoint.sh && \
    chown www-data:www-data /var/www/html/config.php

# 11. Clean up
RUN apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Switch to www-data user
USER www-data

# Use tini as init system
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh"]
CMD ["/etc/apache2/foreground.sh"]
