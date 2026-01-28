# Custom OpenEMR Dockerfile
#
# This Dockerfile allows for customization of the official OpenEMR image.
# It supports dynamic versioning via the APP_VERSION build argument.

ARG APP_VERSION=7.0.3
FROM openemr/openemr:${APP_VERSION}

# Install tini for proper process management
RUN apk add --no-cache tini

# Copy custom entrypoint to handle Cloud Run socket connections
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
