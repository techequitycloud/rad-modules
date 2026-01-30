# Ghost Custom Dockerfile
ARG APP_VERSION=6.14.0
FROM ghost:${APP_VERSION}
 
# Install dependencies for startup script
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy custom entrypoint script
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Create content directory with correct permissions
RUN mkdir -p /var/lib/ghost/content && \
    chown -R node:node /var/lib/ghost/content

# Set working directory
WORKDIR /var/lib/ghost

# Expose Ghost port
EXPOSE 2368

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["node", "current/index.js"]
