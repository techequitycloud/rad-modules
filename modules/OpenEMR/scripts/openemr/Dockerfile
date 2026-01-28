# Custom OpenEMR Dockerfile for Cloud Run
ARG APP_VERSION=7.0.3
FROM openemr/openemr:${APP_VERSION}

# Switch to root to make modifications
USER root

# Check if sed is already installed, install if needed
# Note: Hardened images may not have apk, so we check first
RUN if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache sed bash; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && apt-get install -y sed bash && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Package manager not found, assuming sed is already installed"; \
    fi

# Verify sed is available
RUN sed --version || echo "Warning: sed not available"

# Copy custom entrypoint
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Set working directory
WORKDIR /var/www/localhost/htdocs/openemr

# Switch back to the original user (if the base image uses one)
# Check what user the base image uses
USER root

# Use custom entrypoint with original command
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["./openemr.sh"]
