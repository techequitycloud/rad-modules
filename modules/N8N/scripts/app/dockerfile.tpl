# Use a specific, stable version instead of 'latest'
FROM n8nio/n8n:1.68.0

USER node
WORKDIR /home/node

ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678

EXPOSE 5678

CMD ["n8n", "start"]
