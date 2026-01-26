ARG APP_VERSION=latest
FROM n8nio/n8n:${APP_VERSION}

USER root

# Install python3 and other useful tools often needed by n8n custom nodes or scripts
RUN apk add --update --no-cache \
    python3 \
    py3-pip \
    git \
    bash \
    curl \
    jq

# Clean up
RUN rm -rf /var/cache/apk/*

USER node
