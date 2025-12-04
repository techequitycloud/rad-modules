FROM n8nio/n8n:${APP_VERSION}

# Expose n8n port
EXPOSE 5678

# Set working directory
WORKDIR /home/node

# n8n will run on port 5678 by default
CMD ["n8n"]