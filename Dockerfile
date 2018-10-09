FROM php:5.6-fpm-stretch as httpd-php

ARG php_modules="soap bz2 calendar exif pdo_mysql opcache zip xsl intl mcrypt mbstring ldap sockets iconv gd oci8"

ARG dev_deps="unzip libxml2-dev libbz2-dev zlib1g-dev libxslt1-dev libmcrypt-dev libldap2-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libmemcached-dev"

ARG run_deps="apache2 supervisor libfreetype6 libjpeg62-turbo libmemcached11 libxml2 libmcrypt4 libldap-common libxslt1.1 libaio1 libmemcachedutil2"

ENV DOCUMENT_ROOT /var/www/html

ENV PORT 8080

ENV APACHE_EXTRA_CONF ""

ENV APACHE_EXTRA_CONF_DIR ""

ENV APACHE_ERROR_LOG /dev/fd/2

ENV APACHE_ACCESS_LOG /dev/fd/1

ENV FPM_MIN_CHILDREN 3

ENV FPM_MAX_CHILDREN 5

ENV PHP_ERROR_LOG /dev/fd/2

ENV DAEMON_USER "www-data"

ENV DAEMON_GROUP "www-data"

### Add ssmtp & bash
#RUN apk add --no-cache ssmtp bash

# Install PHP Modules
RUN apt-get update &&\
    # APT deps :
    apt-get -y install $run_deps &&\
    apt-get -y install $dev_deps &&\

    # OCI8 deps :
    curl https://repo.ne-dev.eu/deb/instantclient-basic-linux.x64-12.2.0.1.0.zip > /tmp/instantclient-basic-linux.zip &&\
    unzip /tmp/instantclient-basic-linux.zip -d /usr/local/ &&\
    curl https://repo.ne-dev.eu/deb/instantclient-sdk-linux.x64-12.2.0.1.0.zip > /tmp/instantclient-sdk-linux.zip &&\
    unzip /tmp/instantclient-sdk-linux.zip -d /usr/local/ &&\
    ln -s /usr/local/instantclient_12_2/libclntsh.so.12.1 /usr/local/instantclient_12_2/libclntsh.so &&\
    echo /usr/local/instantclient_12_2 > /etc/ld.so.conf.d/oracle-instantclient.conf && ldconfig &&\

    # Setup modules :
    docker-php-source extract &&\
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ &&\
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ &&\
    docker-php-ext-configure oci8 --with-oci8=instantclient,/usr/local/instantclient_12_2 &&\
    docker-php-ext-install -j$(nproc) $php_modules &&\

    # Setup redis/memcached module :
    pecl install igbinary &&\
    docker-php-ext-enable igbinary &&\
    echo '' | pecl install memcached-2.2.0 &&\
    docker-php-ext-enable memcached &&\
    cd /tmp &&\
    pecl bundle redis &&\
    cd redis &&\
    phpize &&\
    ./configure --enable-redis-igbinary --enable-redis-lzf && make -j && make install &&\
    cd / &&\
    docker-php-source delete &&\
    docker-php-ext-enable redis &&\

    # Clean our mess
    apt-get -y autoremove --purge $dev_deps &&\
    apt-get -y clean &&\
    rm -rf /var/lib/apt/lists/* &&\
    rm -rf /tmp/* &&\
    ln -s /usr/local/etc/ /etc/php

ADD phpfpm_conf/www.conf /etc/php/php-fpm.d/
ADD php_conf/ /usr/local/etc/php/conf.d/

ADD phpfpm_conf/www.conf /etc/php/php-fpm.d/

ADD apache2_conf/ /etc/apache2/

ADD supervisor.conf /etc/supervisor/conf.d/php.conf

ADD run.sh /

EXPOSE 8080

ENTRYPOINT ["/run.sh"]

# Image with Java
FROM httpd-php as httpd-php-full

RUN apt-get update &&\
    mkdir -p /usr/share/man/man1 &&\
    apt-get install -y openjdk-8-jre-headless  &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

# Dev image
FROM httpd-php as httpd-php-dev

RUN docker-php-source extract &&\
    pecl install xdebug-2.5.5 &&\
    docker-php-ext-enable xdebug &&\
    docker-php-source delete