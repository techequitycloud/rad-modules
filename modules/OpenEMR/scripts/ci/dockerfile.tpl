FROM openemr/openemr:7.0.3

# Ensure permissions work across shared volumes
RUN usermod -u 1000 apache

WORKDIR /var/www/localhost/htdocs/openemr
VOLUME [ "/etc/letsencrypt/", "/etc/ssl" ]

# configure apache & php properly
ENV APACHE_LOG_DIR=/var/log/apache2
COPY php.ini /etc/php83/php.ini
COPY openemr.conf /etc/apache2/conf.d/

# add runner and auto_configure and prevent auto_configure from being run w/o being enabled
COPY openemr.sh ssl.sh xdebug.sh auto_configure.php /var/www/localhost/htdocs/openemr/
COPY utilities/unlock_admin.php utilities/unlock_admin.sh /root/
RUN chmod 500 openemr.sh ssl.sh xdebug.sh /root/unlock_admin.sh \
    && chmod 000 auto_configure.php /root/unlock_admin.php

# bring in pieces used for automatic upgrade process
COPY upgrade/docker-version \
     upgrade/fsupgrade-1.sh \
     upgrade/fsupgrade-2.sh \
     upgrade/fsupgrade-3.sh \
     upgrade/fsupgrade-4.sh \
     upgrade/fsupgrade-5.sh \
     upgrade/fsupgrade-6.sh \
     upgrade/fsupgrade-7.sh \
     /root/
RUN chmod 500 \
    /root/fsupgrade-1.sh \
    /root/fsupgrade-2.sh \
    /root/fsupgrade-3.sh \
    /root/fsupgrade-4.sh \
    /root/fsupgrade-5.sh \
    /root/fsupgrade-6.sh \
    /root/fsupgrade-7.sh

# fix issue with apache2 dying prematurely
RUN mkdir -p /run/apache2

# Copy dev tools library to root
COPY utilities/devtoolsLibrary.source /root/

# Ensure swarm/orchestration pieces are available if needed
RUN mkdir -p /swarm-pieces \
    && rsync --owner --group --perms --delete --recursive --links /etc/ssl /swarm-pieces/ \
    && rsync --owner --group --perms --delete --recursive --links /var/www/localhost/htdocs/openemr/sites /swarm-pieces/

COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh

CMD ["/cloudrun-entrypoint.sh", "./openemr.sh"]

EXPOSE 80 443
