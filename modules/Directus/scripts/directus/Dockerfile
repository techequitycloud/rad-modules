# Directus with GCS Fuse Mount Support - Production Ready
ARG DIRECTUS_VERSION=11.1.0
FROM directus/directus:${DIRECTUS_VERSION}

USER root

# Install utilities
RUN apk add --no-cache \
    tini \
    curl \
    bash \
    postgresql-client

# Create directories
RUN mkdir -p \
    /directus/uploads \
    /directus/extensions \
    /directus/database && \
    chown -R node:node /directus && \
    chmod -R 755 /directus/

# Copy custom entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown node:node /usr/local/bin/docker-entrypoint.sh

USER node

WORKDIR /directus

# Environment variables
ENV NODE_ENV=production \
    PORT=8055 \
    STORAGE_LOCATIONS=local \
    STORAGE_LOCAL_ROOT=/directus/uploads \
    LOG_LEVEL=info \
    LOG_STYLE=pretty \
    DB_CLIENT=pg

EXPOSE 8055

# Use tini and custom entrypoint
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]

# Start Directus
CMD ["node", "cli.js", "start"]
