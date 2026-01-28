# Ghost 6.10.3 Custom Dockerfile
FROM ghost:6.10.3-alpine

# Install dependencies for startup script
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    netcat-openbsd

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
