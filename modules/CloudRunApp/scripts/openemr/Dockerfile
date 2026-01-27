# Custom OpenEMR Dockerfile
#
# This Dockerfile allows for customization of the official OpenEMR image.
# It supports dynamic versioning via the APP_VERSION build argument.

ARG APP_VERSION=7.0.3
FROM openemr/openemr:${APP_VERSION}

# Add any custom configuration, scripts, or dependencies here.
# For example:
# COPY custom.ini /etc/php81/conf.d/
# RUN apk add --no-cache some-package

# Ensure permissions are correct if modifying files
# RUN chown -R apache:apache /var/www/localhost/htdocs/openemr
