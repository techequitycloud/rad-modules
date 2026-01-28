FROM ghost:5-alpine

# Install curl and jq for startup script
RUN apk add --no-cache curl jq bash

# Create config directory
RUN mkdir -p /var/lib/ghost/config

# Copy custom entrypoint script
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Copy config template (optional - can use env vars instead)
COPY config.production.json /var/lib/ghost/config.production.json

# Set working directory
WORKDIR /var/lib/ghost

# Expose Ghost port
EXPOSE 2368

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["node", "current/index.js"]
