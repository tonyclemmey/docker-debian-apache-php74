FROM php:7.4-apache
LABEL maintainer="Tony Clemmey <tonyclemmey@gmail.com>" \
      Description="Based on the php:7.4-apache image. Add PHP extensions and other stuff" \
      Version="1.0"
ENV DEBIAN_FRONTEND noninteractive

# Replacing the internal user/group (https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works)
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN userdel -f www-data && \
    if getent group www-data ; then groupdel www-data; fi && \
    groupadd -g ${GROUP_ID} www-data && \
    useradd -l -u ${USER_ID} -g www-data www-data && \
    install -d -m 0755 -o www-data -g www-data /home/www-data && \
    chown --changes --silent --no-dereference --recursive \
      --from=33:33 ${USER_ID}:${GROUP_ID} \
    /home/www-data \
    /var/www

# Set the domain
ARG URL=mysite.test
ENV DOMAIN_URL $URL

# Easily install PHP extension in Docker containers (https://github.com/mlocati/docker-php-extension-installer)
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

# Install some stuff (ffmpeg, apache mods, php exts)
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils ffmpeg && \
    a2enmod ssl && a2enmod rewrite && a2enmod headers && \
    install-php-extensions gd imagick intl mcrypt pdo_mysql redis zip && \
    apt-get clean && apt-get autoclean && apt-get autoremove --purge && \
    rm -rf /var/lib/apt/lists/*

# Apache config & PHP ini
COPY ./000-default.conf /etc/apache2/sites-enabled/000-default.conf
COPY ./php.ini /usr/local/etc/php/conf.d/php.ini

# Webroot dir
RUN mkdir /var/www/web

# Code
COPY ./code/ /var/www/

# CMS requirements check script
# COPY ./check /var/www/web/check

# DB Manager Adminer
COPY ./adminer /var/www/web/adminer

# Create SSL / SimpleSAML certs
RUN openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj \
    "/C=GB/ST=state/L=city/O=organization/CN=$DOMAIN_URL" \
    -keyout ./$DOMAIN_URL.key -out ./$DOMAIN_URL.crt && \
    cp ./$DOMAIN_URL.crt /etc/ssl/certs/$DOMAIN_URL.crt && \
    cp ./$DOMAIN_URL.key /etc/ssl/certs/$DOMAIN_URL.key

# Set Permissions
RUN chown -Rf www-data:www-data /var/www && \
    rm -rf /var/www/html

EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/apache2ctl", "-D",  "FOREGROUND"]
