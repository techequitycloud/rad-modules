FROM odoo:${APP_VERSION}
MAINTAINER Odoo S.A. <info@odoo.com>

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Switch to root to install dependencies and configure the image
USER root

# Install Helper Utilities and Tools
# nfs-common: for NFS
# net-tools: for networking utils
# postgresql-client: for db checks
# tini: for signal handling
# build-essential, python3-dev: for compiling python packages if needed
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    tini \
    nfs-common \
    net-tools \
    postgresql-client \
    build-essential \
    python3-dev \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Portal Libraries
# Using --break-system-packages as Odoo 18+ official images are based on newer Debian/Ubuntu
# where system python is externally managed. We install into the system environment to coincide with Odoo.
RUN pip3 install --upgrade --break-system-packages \
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

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh
COPY ./odoo.conf /etc/odoo/

# Set permissions
# Ensure odoo user can write to config (modified by entrypoint) and mount points
RUN chown odoo:odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt \
    && chown -R odoo:odoo /mnt

# Create addon directory
RUN mkdir -p /extra-addons \
    && chmod -R 755 /extra-addons \
    && chown -R odoo:odoo /extra-addons

# Copy wait-for-psql.py
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
RUN chmod +x /usr/local/bin/wait-for-psql.py

# Set the default config file
ENV ODOO_RC /etc/odoo/odoo.conf

# Switch back to odoo user for runtime
USER odoo

# Expose Odoo services
EXPOSE 8069 8071 8072

# Use custom entrypoint logic
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh"]
CMD /entrypoint.sh odoo
