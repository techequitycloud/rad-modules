FROM n8nio/n8n:${APP_VERSION}

EXPOSE 5678

CMD ["n8n", "start"]
