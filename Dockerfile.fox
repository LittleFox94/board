FROM alpine:3.8 AS build

ADD     . /code
WORKDIR /code
RUN     apk add -u --no-cache npm php7  && \
        npm install -g grunt            && \
        npm install                     && \
        grunt build:docker


FROM alpine:3.8

# update & install package
RUN apk add -u --no-cache \
        bash \
        curl \
        jq \
        msmtp \
        nginx \
        php7 \
        php7-curl \
        php7-fpm \
        php7-imagick \
        php7-imap \
        php7-json \
        php7-ldap \
        php7-mbstring \
        php7-pdo_pgsql \
        php7-pgsql \
        php7-xml \
        postgresql-client \
        unzip \
        tzdata                                                && \
    sed -i 's/nobody/nginx/g' /etc/php7/php-fpm.d/www.conf    && \
    echo 'sendmail_path = /usr/bin/msmtp -t' > /etc/php7/php.ini && \
    rm /etc/nginx/conf.d/default.conf                       

# after initial setup of deps to improve rebuilding speed
ENV ROOT_DIR=/var/lib/nginx/html \
    CONF_FILE=/etc/nginx/conf.d/restyaboard.conf \
    SMTP_DOMAIN=localhost \
    SMTP_USERNAME=root \
    SMTP_PASSWORD=root \
    SMTP_SERVER=localhost \
    SMTP_PORT=465 \
    TZ=Etc/UTC

# deploy app
COPY --from=0 /code/restyaboard-docker.zip /tmp/restyaboard.zip
RUN unzip /tmp/restyaboard.zip -d ${ROOT_DIR} && \
    rm /tmp/restyaboard.zip && \
    chown -R nginx:nginx ${ROOT_DIR}

# install apps
ADD docker-scripts/install_apps.sh /tmp/
RUN chmod +x /tmp/install_apps.sh
RUN . /tmp/install_apps.sh && \
    chown -R nginx:nginx ${ROOT_DIR}

# configure app
WORKDIR ${ROOT_DIR}
RUN cp restyaboard.conf ${CONF_FILE} && \
    sed -i "s/server_name.*$/server_name \"localhost\";/" ${CONF_FILE} && \
	sed -i "s|listen 80.*$|listen 80;|" ${CONF_FILE} && \
    sed -i "s|root.*html|root ${ROOT_DIR}|" ${CONF_FILE}

# entrypoint
COPY docker-scripts/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
