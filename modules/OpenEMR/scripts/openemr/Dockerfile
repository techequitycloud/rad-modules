# Custom OpenEMR Dockerfile
ARG APP_VERSION=7.0.3
FROM openemr/openemr:${APP_VERSION}

# Install sed for configuration
RUN apk add --no-cache sed

# Copy custom entrypoint to handle Cloud Run socket connections
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Use the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]

# Use the original command from base image
CMD ["./openemr.sh"]

# Keep the original working directory
WORKDIR /var/www/localhost/htdocs/openemr
