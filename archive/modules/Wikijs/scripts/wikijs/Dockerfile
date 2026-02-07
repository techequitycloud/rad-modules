FROM requarks/wiki:2

# Switch to root to install packages
USER root

# Install dependencies for PDF rendering (Chromium)
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Environment variables for Puppeteer
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Switch back to the default user (wiki: 1000)
USER 1000
