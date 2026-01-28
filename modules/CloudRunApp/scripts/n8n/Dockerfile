ARG APP_VERSION=latest
FROM n8nio/n8n:${APP_VERSION}

USER root

# Install python3 and other useful tools often needed by n8n custom nodes or scripts
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    bash \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

USER node
