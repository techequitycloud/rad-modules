FROM n8nio/n8n:${APP_VERSION}

USER node

CMD ["n8n", "start"]
