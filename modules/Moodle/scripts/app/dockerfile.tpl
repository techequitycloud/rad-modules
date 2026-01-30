FROM ubuntu:24.04
ARG APP_VERSION
EXPOSE 80 443
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -y
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    wget \
    gnupg2 \
    gosu pwgen curl libcurl4 libcurl3-dev unzip cron \
    wget supervisor locales apache2 libapache2-mod-php \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update

# Install Helper Utilities and Tools 
RUN apt-get update -y && apt-get install -y tini \
nfs-kernel-server \
nfs-common \
netbase \
procps \
net-tools

RUN apt-get -y install php8.3 php8.3-gd php8.3-pgsql php8.3-curl php8.3-xmlrpc php8.3-intl \
    php8.3-mysql php8.3-xml php8.3-mbstring php8.3-zip php8.3-soap php8.3-ldap php8.3-redis \
    && apt-get -y install software-properties-common \
    && chown -R www-data:www-data /var/www/html && apt-get clean
ADD https://github.com/moodle/moodle/archive/refs/tags/v$${APP_VERSION}.tar.gz /tmp/
RUN tar -xzvf /tmp/v$${APP_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/v$${APP_VERSION}.tar.gz
RUN rm /var/www/html/index.html
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh
COPY moodle-config.php /var/www/html/config.php
COPY foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/apache2/foreground.sh
COPY moodlecron /etc/cron.d/moodlecron
RUN chmod 0644 /etc/cron.d/moodlecron
RUN crontab /etc/cron.d/moodlecron
RUN apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh", "/etc/apache2/foreground.sh"]
