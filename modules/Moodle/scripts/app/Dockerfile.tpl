FROM ubuntu:24.04
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
ADD https://github.com/moodle/moodle/archive/refs/tags/v${APP_VERSION}.tar.gz /tmp/
RUN tar -xzvf /tmp/v${APP_VERSION}.tar.gz -C /var/www/html/ --strip-components=1 \
    && rm /tmp/v${APP_VERSION}.tar.gz
ADD https://moodle.org/plugins/download.php/36832/tool_heartbeat_moodle45_2024111802.zip /tmp/
RUN unzip -q -o /tmp/tool_heartbeat_moodle45_2024111802.zip -d /var/www/html/admin/tool \
    && rm /tmp/tool_heartbeat_moodle45_2024111802.zip
ADD https://moodle.org/plugins/download.php/36256/tool_inactive_user_cleanup_moodle50_2025051900.zip /tmp/
RUN unzip -q -o /tmp/tool_inactive_user_cleanup_moodle50_2025051900.zip -d /var/www/html/admin/tool \
    && rm /tmp/tool_inactive_user_cleanup_moodle50_2025051900.zip
ADD https://moodle.org/plugins/download.php/36537/tool_certificate_moodle50_2025061000.zip /tmp/
RUN unzip -q -o /tmp/tool_certificate_moodle50_2025061000.zip -d /var/www/html/admin/tool \
    && rm /tmp/tool_certificate_moodle50_2025061000.zip
ADD https://moodle.org/plugins/download.php/34605/availability_paypal_moodle45_2025012400.zip /tmp/
RUN unzip -q -o /tmp/availability_paypal_moodle45_2025012400.zip -d /var/www/html/availability/conditions \
    && rm /tmp/availability_paypal_moodle45_2025012400.zip
ADD https://moodle.org/plugins/download.php/35649/block_completion_progress_moodle50_2025041400.zip /tmp/
RUN unzip -q -o /tmp/block_completion_progress_moodle50_2025041400.zip -d /var/www/html/blocks \
    && rm /tmp/block_completion_progress_moodle50_2025041400.zip
ADD https://moodle.org/plugins/download.php/36948/block_xp_moodle50_2025041303.zip /tmp/
RUN unzip -q -o /tmp/block_xp_moodle50_2025041303.zip -d /var/www/html/blocks \
    && rm /tmp/block_xp_moodle50_2025041303.zip
ADD https://moodle.org/plugins/download.php/36795/format_grid_moodle50_2025040700.zip /tmp/
RUN unzip -q -o /tmp/format_grid_moodle50_2025040700.zip -d /var/www/html/course/format \
    && rm /tmp/format_grid_moodle50_2025040700.zip
ADD https://moodle.org/plugins/download.php/36631/format_onetopic_moodle50_2025021901.zip /tmp/
RUN unzip -q -o /tmp/format_onetopic_moodle50_2025021901.zip -d /var/www/html/course/format \
    && rm /tmp/format_onetopic_moodle50_2025021901.zip
ADD https://moodle.org/plugins/download.php/36759/format_topcoll_moodle50_2025041702.zip /tmp/
RUN unzip -q -o /tmp/format_topcoll_moodle50_2025041702.zip -d /var/www/html/course/format \
    && rm /tmp/format_topcoll_moodle50_2025041702.zip
ADD https://moodle.org/plugins/download.php/35282/enrol_autoenrol_moodle45_2025031400.zip /tmp/
RUN unzip -q -o /tmp/enrol_autoenrol_moodle45_2025031400.zip -d /var/www/html/enrol \
    && rm /tmp/enrol_autoenrol_moodle45_2025031400.zip
ADD https://moodle.org/plugins/download.php/33162/paygw_stripe_moodle44_2024091700.zip /tmp/
RUN unzip -q -o /tmp/paygw_stripe_moodle44_2024091700.zip -d /var/www/html/paygw \
    && rm /tmp/paygw_stripe_moodle44_2024091700.zip
ADD https://moodle.org/plugins/download.php/36381/enrol_stripepayment_moodle50_2025052900.zip /tmp/
RUN unzip -q -o /tmp/enrol_stripepayment_moodle50_2025052900.zip -d /var/www/html/enrol \
    && rm /tmp/enrol_stripepayment_moodle50_2025052900.zip
ADD https://moodle.org/plugins/download.php/35656/enrol_xp_moodle50_2025041100.zip /tmp/
RUN unzip -q -o /tmp/enrol_xp_moodle50_2025041100.zip -d /var/www/html/enrol \
    && rm /tmp/enrol_xp_moodle50_2025041100.zip
ADD https://moodle.org/plugins/download.php/36093/filter_filtercodes_moodle50_2025050500.zip /tmp/
RUN unzip -q -o /tmp/filter_filtercodes_moodle50_2025050500.zip -d /var/www/html/filter \
    && rm /tmp/filter_filtercodes_moodle50_2025050500.zip
ADD https://moodle.org/plugins/download.php/36586/local_helpdesk_moodle50_2025061700.zip /tmp/
RUN unzip -q -o /tmp/local_helpdesk_moodle50_2025061700.zip -d /var/www/html/local \
    && rm /tmp/local_helpdesk_moodle50_2025061700.zip
ADD https://moodle.org/plugins/download.php/36652/local_kopere_dashboard_moodle50_2025062600.zip /tmp/
RUN unzip -q -o /tmp/local_kopere_dashboard_moodle50_2025062600.zip -d /var/www/html/local \
    && rm /tmp/local_kopere_dashboard_moodle50_2025062600.zip
ADD https://moodle.org/plugins/download.php/36651/local_kopere_bi_moodle50_2025062600.zip /tmp/
RUN unzip -q -o /tmp/local_kopere_bi_moodle50_2025062600.zip -d /var/www/html/local \
    && rm /tmp/local_kopere_bi_moodle50_2025062600.zip
ADD https://moodle.org/plugins/download.php/33392/local_contact_moodle50_2024100300.zip /tmp/
RUN unzip -q -o /tmp/local_contact_moodle50_2024100300.zip -d /var/www/html/local \
    && rm /tmp/local_contact_moodle50_2024100300.zip
ADD https://moodle.org/plugins/download.php/25407/local_pages_moodle311_2021110400.zip /tmp/
RUN unzip -q -o /tmp/local_pages_moodle311_2021110400.zip -d /var/www/html/local \
    && rm /tmp/local_pages_moodle311_2021110400.zip
ADD https://moodle.org/plugins/download.php/36235/local_staticpage_moodle50_2025041400.zip /tmp/
RUN unzip -q -o /tmp/local_staticpage_moodle50_2025041400.zip -d /var/www/html/local \
    && rm /tmp/local_staticpage_moodle50_2025041400.zip
ADD https://moodle.org/plugins/download.php/34915/local_deleteoldquizattempts_moodle50_2025021600.zip /tmp/
RUN unzip -q -o /tmp/local_deleteoldquizattempts_moodle50_2025021600.zip -d /var/www/html/local \
    && rm /tmp/local_deleteoldquizattempts_moodle50_2025021600.zip
ADD https://moodle.org/plugins/download.php/35762/mod_realtimequiz_moodle50_2025041900.zip /tmp/
RUN unzip -q -o /tmp/mod_realtimequiz_moodle50_2025041900.zip -d /var/www/html/mod \
    && rm /tmp/mod_realtimequiz_moodle50_2025041900.zip
ADD https://moodle.org/plugins/download.php/12990/mod_activequiz_moodle32_2017010400.zip /tmp/
RUN unzip -q -o /tmp/mod_activequiz_moodle32_2017010400.zip -d /var/www/html/mod \
    && rm /tmp/mod_activequiz_moodle32_2017010400.zip
ADD https://moodle.org/plugins/download.php/36539/mod_coursecertificate_moodle50_2025061000.zip /tmp/
RUN unzip -q -o /tmp/mod_coursecertificate_moodle50_2025061000.zip -d /var/www/html/mod \
    && rm /tmp/mod_coursecertificate_moodle50_2025061000.zip
ADD https://moodle.org/plugins/download.php/36504/mod_customcert_moodle50_2025041400.zip /tmp/
RUN unzip -q -o /tmp/mod_customcert_moodle50_2025041400.zip -d /var/www/html/mod \
    && rm /tmp/mod_customcert_moodle50_2025041400.zip
ADD https://moodle.org/plugins/download.php/31817/mod_diary_moodle45_2024042400.zip /tmp/
RUN unzip -q -o /tmp/mod_diary_moodle45_2024042400.zip -d /var/www/html/mod \
    && rm /tmp/mod_diary_moodle45_2024042400.zip
ADD https://moodle.org/plugins/download.php/29096/mod_googlemeet_moodle42_2023050101.zip /tmp/
RUN unzip -q -o /tmp/mod_googlemeet_moodle42_2023050101.zip -d /var/www/html/mod \
    && rm /tmp/mod_googlemeet_moodle42_2023050101.zip
ADD https://moodle.org/plugins/download.php/36449/mod_hotquestion_moodle50_2025060200.zip /tmp/
RUN unzip -q -o /tmp/mod_hotquestion_moodle50_2025060200.zip -d /var/www/html/mod \
    && rm /tmp/mod_hotquestion_moodle50_2025060200.zip
ADD https://moodle.org/plugins/download.php/29947/mod_journal_moodle42_2023091500.zip /tmp/
RUN unzip -q -o /tmp/mod_journal_moodle42_2023091500.zip -d /var/www/html/mod \
    && rm /tmp/mod_journal_moodle42_2023091500.zip
ADD https://moodle.org/plugins/download.php/35241/mod_publication_moodle45_2024101803.zip /tmp/
RUN unzip -q -o /tmp/mod_publication_moodle45_2024101803.zip -d /var/www/html/mod \
    && rm /tmp/mod_publication_moodle45_2024101803.zip
ADD https://moodle.org/plugins/download.php/33023/mod_questionnaire_moodle44_2022121601.zip /tmp/
RUN unzip -q -o /tmp/mod_questionnaire_moodle44_2022121601.zip -d /var/www/html/mod \
    && rm /tmp/mod_questionnaire_moodle44_2022121601.zip
ADD https://moodle.org/plugins/download.php/29293/mod_scheduler_moodle42_2023052300.zip /tmp/
RUN unzip -q -o /tmp/mod_scheduler_moodle42_2023052300.zip -d /var/www/html/mod \
    && rm /tmp/mod_scheduler_moodle42_2023052300.zip
ADD https://moodle.org/plugins/download.php/35470/mod_teamup_moodle45_2025032900.zip /tmp/
RUN unzip -q -o /tmp/mod_teamup_moodle45_2025032900.zip -d /var/www/html/mod \
    && rm /tmp/mod_teamup_moodle45_2025032900.zip
ADD https://moodle.org/plugins/download.php/32660/mod_tutorialbooking_moodle43_2024030600.zip /tmp/
RUN unzip -q -o /tmp/mod_tutorialbooking_moodle43_2024030600.zip -d /var/www/html/mod \
    && rm /tmp/mod_tutorialbooking_moodle43_2024030600.zip
ADD https://moodle.org/plugins/download.php/26177/report_customsql_moodle40_2022031800.zip /tmp/
RUN unzip -q -o /tmp/report_customsql_moodle40_2022031800.zip -d /var/www/html/report \
    && rm /tmp/report_customsql_moodle40_2022031800.zip
RUN wget --timeout=120 -q https://drive.google.com/uc?id=1qpigYUDhs07X9pN8Sl_IJ3jCpv3MRya1 -O /tmp/space.zip
RUN unzip -q -o /tmp/space.zip -d /var/www/html/theme
RUN rm /tmp/space.zip
RUN rm /var/www/html/index.html
COPY ./cloudrun-entrypoint.sh /
RUN chmod +x /cloudrun-entrypoint.sh
COPY moodle-config.php /var/www/html/config.php
COPY foreground.sh /etc/apache2/foreground.sh
RUN chmod +x /etc/apache2/foreground.sh
COPY moodlecron /etc/cron.d/moodlecron
RUN chmod 0644 /etc/cron.d/moodlecron
RUN crontab /etc/cron.d/moodlecron
RUN apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/lib/dpkg/* /var/lib/cache/* /var/lib/log/*
# ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh"]
# CMD /etc/apache2/foreground.sh
ENTRYPOINT ["/usr/bin/tini", "--", "/cloudrun-entrypoint.sh", "/etc/apache2/foreground.sh"]
