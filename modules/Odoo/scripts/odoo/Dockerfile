FROM ubuntu:noble
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG en_US.UTF-8

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

# Odoo version arguments
ARG ODOO_VERSION=18.0
ARG ODOO_RELEASE=latest

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
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
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-redis \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Install latest postgresql-client (PostgreSQL 16 for compatibility)
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ noble-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
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

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# ✅ CUSTOM: Install Helper Utilities and Tools for Cloud Run/NFS
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    tini \
    nfs-kernel-server \
    nfs-common \
    netbase \
    procps \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ✅ CUSTOM: Install missing Python dependencies
RUN pip3 install --upgrade --break-system-packages lxml-html-clean redis

# Install Odoo
ENV ODOO_VERSION=${ODOO_VERSION}
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.${ODOO_RELEASE}_all.deb \
    && apt-get update \
    && apt-get -y install --no-install-recommends --ignore-missing ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

# ✅ CUSTOM: Copy Cloud Run entrypoint
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh

COPY ./odoo.conf /etc/odoo/

# ✅ CUSTOM: Set permissions and create all required directories for Cloud Run
RUN chown -R odoo:odoo /etc/odoo \
    && chmod 755 /etc/odoo \
    && chmod 644 /etc/odoo/odoo.conf \
    && mkdir -p /mnt/filestore \
    && mkdir -p /mnt/sessions \
    && mkdir -p /var/lib/odoo \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo:odoo /mnt \
    && chown -R odoo:odoo /var/lib/odoo \
    && chown -R odoo:odoo /mnt/extra-addons \
    && chmod 755 /mnt/filestore \
    && chmod 755 /mnt/sessions \
    && chmod 755 /mnt/extra-addons

# ✅ CUSTOM: Optional - Copy custom addons (uncomment if needed)
# COPY addons /mnt/extra-addons

# Mount volumes for persistence
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# ✅ UPDATED: Expose port 8069 (non-privileged port for Cloud Run)
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

# ✅ CUSTOM: Use tini and Cloud Run entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh"]

# ✅ CUSTOM: Explicitly set HTTP port to 8069
CMD ["/entrypoint.sh", "odoo", "--http-port=8069"]
