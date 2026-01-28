# Directus with GCS Fuse Mount
ARG DIRECTUS_VERSION=11.1.0
FROM directus/directus:${DIRECTUS_VERSION}

USER root

# Ensure the uploads directory exists with correct permissions
RUN mkdir -p /directus/uploads && \
    chown -R node:node /directus/uploads && \
    chmod -R 755 /directus/uploads

USER node

WORKDIR /directus

ENV NODE_ENV=production
ENV PORT=8055
ENV STORAGE_LOCATIONS=local
ENV STORAGE_LOCAL_ROOT=/directus/uploads

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8055/server/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

EXPOSE 8055
