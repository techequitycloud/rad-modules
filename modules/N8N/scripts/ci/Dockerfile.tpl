FROM n8nio/n8n:latest

USER root
RUN npm install -g n8n
USER node

CMD ["n8n", "start"]
