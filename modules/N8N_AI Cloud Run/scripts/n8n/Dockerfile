# Build from standard Alpine instead of hardened image
FROM node:22-alpine3.22

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    git \
    bash \
    curl \
    jq \
    tini \
    su-exec

# Install n8n globally
RUN npm install -g n8n@2.4.7

# Create node user
RUN addgroup -g 1000 node 2>/dev/null || true && \
    adduser -u 1000 -G node -s /bin/sh -D node 2>/dev/null || true

# Set up directories
RUN mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

# Switch to node user
USER node

WORKDIR /home/node

# Environment variables
ENV N8N_USER_FOLDER=/home/node/.n8n
ENV N8N_PORT=5678

EXPOSE 5678

# Use tini as init system
ENTRYPOINT ["tini", "--"]
CMD ["n8n"]
