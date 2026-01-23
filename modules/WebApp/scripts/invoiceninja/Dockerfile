FROM invoiceninja/invoiceninja:5

USER root

# Install Nginx and Supervisor
RUN apk add --no-cache nginx supervisor

# Configure Nginx
RUN rm /etc/nginx/http.d/default.conf
COPY nginx.conf /etc/nginx/http.d/invoiceninja.conf

# Create directory for nginx pid
RUN mkdir -p /run/nginx

# Ensure Supervisor config directory exists and add config
RUN mkdir -p /etc/supervisor.d
COPY supervisor-nginx.ini /etc/supervisor.d/invoiceninja.ini

# Start Supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
