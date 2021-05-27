# This will build from the v1.1 branch of Winter CMS

FROM dynamedia/docker-nginx-fpm:v1.20.0_8.0.x

LABEL maintainer="Rob Ballantyne <rob@dynamedia.uk>"

### Install supplementary packages required by Winter CMS ###

RUN apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        ca-certificates    \
        vim                \
        nano               \
        curl               \
        zlib1g             \
        libssl1.1          \
        libpcre3           \
        libxml2            \
        libyajl2           \
        sendmail-bin       \
        cron               \
        supervisor && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        nodejs && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    ldconfig && \
    npm install yarn -g && \
    mv /usr/local/bin/entrypoint.sh /usr/local/bin/nginx-fpm-entrypoint.sh && \
    cd /var/www/ && \
    rm -rf app

# These are the files and directories we mount via docker-compose.yml, but they get copied into the image when it's built
COPY ./.config/php/default/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY ./.config/php/default/php.ini /usr/local/etc/php/php.ini

COPY ./.config/nginx/default/nginx.conf /etc/nginx/nginx.conf
COPY ./.config/nginx/default/sites-enabled /etc/nginx/sites-enabled

RUN rm /etc/nginx/sites-enabled/conf.d/php.conf

COPY ./.config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ./.config/user.crontab /user.crontab

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /var/www/app/

ENTRYPOINT ["entrypoint.sh"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
