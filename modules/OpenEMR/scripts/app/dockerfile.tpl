FROM openemr/openemr:${APP_VERSION}

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

# Copy custom entrypoint and DB check script
COPY cloudrun-entrypoint.sh /usr/local/bin/cloudrun-entrypoint.sh
COPY db_check.php /usr/local/bin/db_check.php

# Ensure scripts are executable
RUN chmod +x /usr/local/bin/cloudrun-entrypoint.sh

# Set the new entrypoint
ENTRYPOINT ["/usr/local/bin/cloudrun-entrypoint.sh"]

# Default command (matches upstream default usually, but good to be explicit if known.
# Since we hand off to openemr.sh which handles empty CMD, we can leave CMD empty or default)
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
