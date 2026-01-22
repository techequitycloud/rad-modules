FROM ubuntu:jammy

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

EXPOSE 80 443
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -y

# Install wkhtmltopdf (Reference from Odoo) and other base dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        xz-utils \
        software-properties-common \
        wget \
        gnupg2 \
        gosu pwgen libcurl4 libcurl3-dev unzip cron \
        supervisor locales apache2 libapache2-mod-php && \
    if [ -z "$TARGETARCH" ]; then \
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
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Add PHP PPA
RUN add-apt-repository ppa:ondrej/php \
    && apt-get update

# Install Helper Utilities and Tools 
RUN apt-get update -y && apt-get install -y tini \
    nfs-kernel-server \
    nfs-common \
    netbase \
    procps \
    net-tools

# install latest postgresql-client (Reference from Odoo)
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$repokey" \
    && gpg --batch --armor --export "$repokey" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && (apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=120 --allow-releaseinfo-change || \
        (sleep 5 && apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=120 --allow-releaseinfo-change) || \
        (sleep 10 && apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=120 --allow-releaseinfo-change)) \
    && apt-get install --no-install-recommends -y -o Acquire::Retries=3 postgresql-client-16 \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install Moodle PHP dependencies (Removed php8.3-mysql)
RUN apt-get -y install php8.3 php8.3-gd php8.3-pgsql php8.3-curl php8.3-xmlrpc php8.3-intl \
    php8.3-xml php8.3-mbstring php8.3-zip php8.3-soap php8.3-ldap php8.3-redis \
    && apt-get -y install software-properties-common \
    && chown -R www-data:www-data /var/www/html && apt-get clean

ADD https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz /tmp/
RUN tar -xzvf /tmp/v${APP_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/v${APP_VERSION}.tar.gz
RUN rm /var/www/html/index.html
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh
COPY moodle-config.php /var/www/html/config.php
COPY foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/apache2/foreground.sh
COPY moodlecron /etc/cron.d/moodlecron
RUN chmod 0644 /etc/cron.d/moodlecron
RUN crontab /etc/cron.d/moodlecron
RUN apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/* /var/lib/cache/* /var/lib/log/*
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh", "/etc/apache2/foreground.sh"]
