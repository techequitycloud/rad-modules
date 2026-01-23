FROM invoiceninja/invoiceninja:5

USER root

# Install Nginx
RUN apk add --no-cache nginx

# Configure Nginx
RUN rm /etc/nginx/http.d/default.conf
COPY nginx.conf /etc/nginx/http.d/invoiceninja.conf

# Create directory for nginx pid
RUN mkdir -p /run/nginx

# Ensure Supervisor config directory exists and add config
RUN mkdir -p /etc/supervisor/conf.d
COPY supervisor-nginx.ini /etc/supervisor/conf.d/nginx.ini
