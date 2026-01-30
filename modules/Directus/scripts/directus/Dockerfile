# Directus for Google Cloud Run - Production Ready
ARG DIRECTUS_VERSION=11.1.0
FROM directus/directus:${DIRECTUS_VERSION}

USER root

# Install only essential utilities for Cloud Run
RUN apk add --no-cache \
    curl \
    bash \
    postgresql-client

# Install GCS storage driver
RUN npm install -g npm@latest && \
    npm install @directus/storage-driver-gcs@11.1.0

# Create extensions directory (no uploads - using GCS)
RUN mkdir -p /directus/extensions && \
    chown -R node:node /directus/extensions && \
    chmod -R 755 /directus/extensions

# Copy custom entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown node:node /usr/local/bin/docker-entrypoint.sh

USER node

WORKDIR /directus

# Environment variables for Cloud Run
ENV NODE_ENV=production \
    LOG_LEVEL=info \
    LOG_STYLE=json \
    DB_CLIENT=pg

# Cloud Run provides PORT dynamically
EXPOSE 8055

# No tini needed - Cloud Run handles signals
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start Directus
CMD ["node", "cli.js", "start"]
