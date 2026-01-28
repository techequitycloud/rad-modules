ARG APP_VERSION=latest
FROM n8nio/n8n:${APP_VERSION}

USER root

# Install python3 and other useful tools often needed by n8n custom nodes or scripts
# Note: n8n image is Alpine-based, use /sbin/apk with full path as apk may not be in PATH
RUN /sbin/apk add --no-cache \
    python3 \
    py3-pip \
    git \
    bash \
    curl \
    jq

USER node
