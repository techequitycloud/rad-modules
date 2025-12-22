FROM openemr/openemr:7.0.3

# Override PHP memory limit in the correct location
RUN echo "memory_limit = 2048M" > /etc/php83/conf.d/zz-custom.ini && \
    echo "upload_max_filesize = 128M" >> /etc/php83/conf.d/zz-custom.ini && \
    echo "post_max_size = 128M" >> /etc/php83/conf.d/zz-custom.ini && \
    echo "max_execution_time = 300" >> /etc/php83/conf.d/zz-custom.ini && \
    echo "max_input_time = 300" >> /etc/php83/conf.d/zz-custom.ini && \
    echo "max_input_vars = 3000" >> /etc/php83/conf.d/zz-custom.ini

# Also update PHP-FPM configuration if it exists
RUN if [ -f /etc/php83/php-fpm.d/www.conf ]; then \
        echo "php_admin_value[memory_limit] = 2048M" >> /etc/php83/php-fpm.d/www.conf; \
    fi

# Verify the configuration
RUN php -i | grep memory_limit

# Install mysql-client for database checks in entrypoint
RUN apk add --no-cache mysql-client bash

# Verify OpenEMR installation and templates
RUN echo "=== Verifying OpenEMR Installation ===" && \
    OPENEMR_ROOT="/var/www/localhost/htdocs/openemr" && \
    if [ -d "$OPENEMR_ROOT" ]; then \
        echo "✓ OpenEMR found at: $OPENEMR_ROOT"; \
        ls -la "$OPENEMR_ROOT" | head -20; \
    else \
        echo "Searching for OpenEMR..."; \
        find / -name "openemr" -type d 2>/dev/null | grep -v proc; \
    fi

RUN echo "=== Checking Templates Directory ===" && \
    OPENEMR_ROOT="/var/www/localhost/htdocs/openemr" && \
    if [ -d "$OPENEMR_ROOT/templates" ]; then \
        echo "✓ Templates directory found"; \
        ls -la "$OPENEMR_ROOT/templates/" | head -20; \
        if [ -d "$OPENEMR_ROOT/templates/login" ]; then \
            echo "✓ Login templates found:"; \
            ls -la "$OPENEMR_ROOT/templates/login/"; \
        else \
            echo "⚠ Login templates directory not found"; \
        fi; \
        echo "=== Available Twig Templates ==="; \
        find "$OPENEMR_ROOT/templates" -name "*.twig" -type f | head -20; \
    else \
        echo "⚠ Templates directory not found at expected location"; \
        find / -path "*/openemr/templates" -type d 2>/dev/null; \
    fi

# Verify critical template files exist
RUN OPENEMR_ROOT="/var/www/localhost/htdocs/openemr" && \
    TEMPLATE_FILE="$OPENEMR_ROOT/templates/login/login_layout_a.html.twig" && \
    if [ -f "$TEMPLATE_FILE" ]; then \
        echo "✓ login_layout_a.html.twig found"; \
    else \
        echo "⚠ WARNING: login_layout_a.html.twig not found at $TEMPLATE_FILE"; \
        echo "Searching for login templates..."; \
        find "$OPENEMR_ROOT" -name "*login*.twig" -type f 2>/dev/null || true; \
    fi

# Copy custom entrypoint script
COPY cloudrun-entrypoint.sh /usr/local/bin/cloudrun-entrypoint.sh
RUN chmod +x /usr/local/bin/cloudrun-entrypoint.sh

# Create sites directory if it doesn't exist
RUN mkdir -p /var/www/localhost/htdocs/openemr/sites/default && \
    chown -R apache:apache /var/www/localhost/htdocs/openemr/sites && \
    chmod -R 755 /var/www/localhost/htdocs/openemr/sites

# Set custom entrypoint
ENTRYPOINT ["/usr/local/bin/cloudrun-entrypoint.sh"]

# Default command (will be passed to the entrypoint)
CMD ["/usr/local/bin/docker-entrypoint.sh"]