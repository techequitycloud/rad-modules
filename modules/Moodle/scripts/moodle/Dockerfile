FROM ubuntu:24.04
ARG APP_VERSION
EXPOSE 80 443
ENV DEBIAN_FRONTEND noninteractive

# Install dependencies and Moodle
RUN apt-get update && apt-get install -y software-properties-common \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y \
    curl \
    wget \
    gnupg2 \
    gosu \
    pwgen \
    libcurl4 \
    libcurl4-openssl-dev \
    unzip \
    locales \
    apache2 \
    libapache2-mod-php \
    tini \
    nfs-kernel-server \
    nfs-common \
    netbase \
    procps \
    net-tools \
    php8.3 \
    php8.3-gd \
    php8.3-pgsql \
    php8.3-curl \
    php8.3-xmlrpc \
    php8.3-intl \
    php8.3-mysql \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-zip \
    php8.3-soap \
    php8.3-ldap \
    php8.3-redis \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/* /var/lib/cache/* /var/lib/log/* \
    && ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

# Install Moodle
RUN curl -L https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz -o /tmp/moodle.tar.gz \
    && tar -xzvf /tmp/moodle.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/moodle.tar.gz \
    && rm -f /var/www/html/index.html \
    && chown -R www-data:www-data /var/www/html

# Copy scripts and config
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh

COPY moodle-config.php /var/www/html/config.php
RUN chown www-data:www-data /var/www/html/config.php

COPY foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/apache2/foreground.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh", "/etc/apache2/foreground.sh"]
