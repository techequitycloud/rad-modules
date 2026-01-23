FROM invoiceninja/invoiceninja:5

USER root

# Install Nginx and Supervisor
RUN apk add --no-cache nginx supervisor

# Configure Nginx
RUN rm /etc/nginx/http.d/default.conf
COPY nginx.conf /etc/nginx/http.d/invoiceninja.conf

# Create directory for nginx pid
RUN mkdir -p /run/nginx

# Create supervisord config that includes our programs
RUN mkdir -p /etc/supervisor.d
COPY supervisor-nginx.ini /etc/supervisor.d/invoiceninja.ini

# Create main supervisord.conf that includes our config
RUN echo "[supervisord]" > /etc/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisord.conf && \
    echo "user=root" >> /etc/supervisord.conf && \
    echo "logfile=/dev/stdout" >> /etc/supervisord.conf && \
    echo "logfile_maxbytes=0" >> /etc/supervisord.conf && \
    echo "pidfile=/var/run/supervisord.pid" >> /etc/supervisord.conf && \
    echo "" >> /etc/supervisord.conf && \
    echo "[include]" >> /etc/supervisord.conf && \
    echo "files = /etc/supervisor.d/*.ini" >> /etc/supervisord.conf

# Start Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
