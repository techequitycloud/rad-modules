FROM invoiceninja/invoiceninja:5

USER root

# Install Nginx and Supervisor
RUN apk add --no-cache nginx supervisor

# Configure Nginx
RUN rm /etc/nginx/http.d/default.conf
COPY nginx.conf /etc/nginx/http.d/invoiceninja.conf

# Create directory for nginx pid
RUN mkdir -p /run/nginx

# Create supervisord main configuration
RUN mkdir -p /etc/supervisor.d && \
    printf '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/dev/stdout\n\
logfile_maxbytes=0\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[include]\n\
files = /etc/supervisor.d/*.ini\n' > /etc/supervisord.conf

# Add supervisor program configs
COPY supervisor-nginx.ini /etc/supervisor.d/invoiceninja.ini

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
