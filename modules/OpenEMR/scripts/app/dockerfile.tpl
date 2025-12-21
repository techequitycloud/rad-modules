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
