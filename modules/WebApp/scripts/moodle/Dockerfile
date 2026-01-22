FROM ubuntu:jammy

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

# Default to latest Moodle version compatible with PHP 8.3 (4.4+)
ARG APP_VERSION=4.4.1

EXPOSE 80 443
ENV DEBIAN_FRONTEND noninteractive

# 1. Install base dependencies and enable universe repository
# We explicitly enable universe to ensure packages like xfonts-75dpi (needed for wkhtmltopdf) are available
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
        cron \
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
        libcurl3-dev && \
    add-apt-repository universe && \
    apt-get update

# 2. Install wkhtmltopdf
# We install fonts and dependencies implicitly via apt-get install ./deb
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

# 3. Install postgresql-client with retry for GPG key
# Keyservers can be flaky, so we try multiple and retry
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
    && apt-get install --no-install-recommends -y postgresql-client-16

# 4. Install PHP and Apache
RUN add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
        apache2 \
        libapache2-mod-php \
        php8.3 \
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
    && chown -R www-data:www-data /var/www/html

# 5. Download and install Moodle
ADD https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz /tmp/
RUN tar -xzvf /tmp/v${APP_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/v${APP_VERSION}.tar.gz \
    && rm -f /var/www/html/index.html

# 6. Copy scripts and config
COPY cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh

COPY moodle-config.php /var/www/html/config.php

COPY foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/apache2/foreground.sh

COPY moodlecron /etc/cron.d/moodlecron
RUN chmod 0644 /etc/cron.d/moodlecron
RUN crontab /etc/cron.d/moodlecron

# 7. Clean up
RUN apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/* /var/lib/cache/* /var/lib/log/*

ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh", "/etc/apache2/foreground.sh"]
