ARG APP_VERSION=latest
FROM wordpress:${APP_VERSION}

# Install any additional dependencies here
# RUN apt-get update && apt-get install -y ...

# Copy custom entrypoint script
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Set the custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
