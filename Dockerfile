FROM ubuntu:18.04

ENV TIMEOUT=120 DOCUMENT_ROOT="/var/www/html" PORT=8080 APACHE_EXTRA_CONF="" APACHE_EXTRA_CONF_DIR="" APACHE_ERROR_LOG="/var/log/apache.err" APACHE_ACCESS_LOG="/var/log/access" ALLOWOVERRIDE="none"
ENV PHP_VERSION="7.2" FPM_START_SERVERS=20 FPM_MIN_CHILDREN=10 FPM_MAX_CHILDREN=30 FPM_MAX_REQUESTS=500 PHP_ERROR_LOG="/var/log/php.err" PHP_DISPLAY_ERRORS="Off" PHP_DEPENDENCIES="common cli fpm soap bz2 opcache zip xsl intl imap mbstring ldap mysql gd memcached redis curl sqlite bcmath"
ENV SUPERVISOR_LOG_PATH="/var/log/" SUPERVISOR_CONF_DIR="/etc/supervisor/" DAEMON_USER="www-data" DAEMON_GROUP="www-data" SUPERVISORCTL_LISTEN_PORT="9001" SUPERVISORCTL_USER="admin" SUPERVISORCTL_PASS="password" DEBIAN_FRONTEND="noninteractive"

### Configure timezone / adding ssmtp / default dep / Install Apache / PHP/FPM (including modules) / cleanup cache
RUN apt-get update && apt-get install unzip cronolog tzdata ssmtp git curl supervisor -y && sed -ri 's@^mailhub=mail$@mailhub=127.0.0.1@' /etc/ssmtp/ssmtp.conf && ln -fs /usr/share/zoneinfo/Europe/Brussels /etc/localtime && dpkg-reconfigure --frontend noninteractive tzdata && apt-cache madison php | grep -q "1:${PHP_VERSION}+" && apt-get install apache2 php${PHP_VERSION} -y && apt-get install `for PHP_DEPENDENCY in ${PHP_DEPENDENCIES}; do echo -n "php${PHP_VERSION}-${PHP_DEPENDENCY} "; done` -y; phpdismod exif readline shmop sysvmsg sysvsem sysvshm wddx; apt-get clean all; rm -rf /var/lib/apt/lists/*; rm -f /var/www/html/index.html

### Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer; composer config -g cache-dir /cache/composer

### Configure php/php-fpm
ADD conf/php-fpm/ /etc/php/$PHP_VERSION/fpm/
ADD conf/php/ /etc/php/$PHP_VERSION/fpm/conf.d/

### Revamp apache configuration
ADD conf/apache2/ /etc/apache2/

### Cleanup php/apache configuration
RUN a2enmod proxy_fcgi rewrite headers; a2disconf php7.2-fpm other-vhosts-access-log; a2dissite 000-default; echo -n "<?php\n  opcache_reset();\n?>" > ${DOCUMENT_ROOT}/flush_opcache.php

### Adding supervisor configuration
COPY conf/supervisor/ /etc/supervisor/
ADD run.sh /

EXPOSE ${PORT} ${SUPERVISORCTL_LISTEN_PORT}

ENTRYPOINT ["/run.sh"]
