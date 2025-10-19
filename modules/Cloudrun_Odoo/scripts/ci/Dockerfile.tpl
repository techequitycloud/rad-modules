FROM ubuntu:jammy
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG en_US.UTF-8

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

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
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils && \
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

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss

# Install Portal Libraries
RUN pip3 install --upgrade \
	paramiko \
	dropbox \
	google-cloud \
	google-cloud-channel \
	google-cloud-billing \
	google-cloud-pubsub \
	google-cloud-secret-manager \
	google-cloud-resource-manager \
	google-cloud-billing-budgets \
	google-api-python-client

# Install Odoo
RUN curl -o odoo.deb -sSL http://nightly.odoo.com/${APP_VERSION}/nightly/deb/odoo_${APP_VERSION}.${APP_RELEASE}_all.deb \
    && echo "${APP_SHA} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Install Helper Utilities and Tools 
RUN apt-get update -y && apt-get install -y tini \
	nfs-kernel-server \
	nfs-common \
	netbase \
	procps \
	net-tools \
	wget \
	unzip \
	&& apt-get clean

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh
COPY ./odoo.conf /etc/odoo/

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt \
    && chown -R odoo /mnt

# Create addon directory
RUN mkdir /extra-addons \
    && chmod -R 755 /extra-addons \
    && chown -R odoo /extra-addons

# Copy addons 
# COPY addons /extra-addons

# Expose Odoo services
EXPOSE 80 8069 8071 8072

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
# USER odoo

ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh"]
CMD /entrypoint.sh odoo