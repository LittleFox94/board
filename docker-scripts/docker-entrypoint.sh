#!/bin/sh
set -e

if [ "$1" = 'start' ]; then

  # config
  sed -i \
      -e "s/^.*'R_DB_HOST'.*$/define('R_DB_HOST', '${POSTGRES_HOST}');/g" \
      -e "s/^.*'R_DB_PORT'.*$/define('R_DB_PORT', '5432');/g" \
      -e "s/^.*'R_DB_USER'.*$/define('R_DB_USER', '${POSTGRES_USER}');/g" \
      -e "s/^.*'R_DB_PASSWORD'.*$/define('R_DB_PASSWORD', '${POSTGRES_PASSWORD}');/g" \
      -e "s/^.*'R_DB_NAME'.*$/define('R_DB_NAME', '${POSTGRES_DB}');/g" \
      ${ROOT_DIR}/server/php/config.inc.php
  echo $TZ > /etc/timezone
  rm /etc/localtime
  cp /usr/share/zoneinfo/$TZ /etc/localtime
  sed -i "s|;date.timezone = |date.timezone = ${TZ}|" /etc/php7/php.ini

  # smtp config
  cat > /etc/msmtprc <<EOF
# Set default values for all following accounts.
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
syslog         on

account        smtp
host           $SMTP_SERVER
port           $SMTP_PORT
from           $SMTP_EMAIL
user           $SMTP_USERNAME
password       $SMTP_PASSWORD

# Set a default account
account default : smtp
aliases        /etc/aliases
EOF

  # init db
  export PGHOST=${POSTGRES_HOST}
  export PGPORT=5432
  export PGUSER=${POSTGRES_USER}
  export PGPASSWORD=${POSTGRES_PASSWORD}
  export PGDATABASE=${POSTGRES_DB}
  set +e
  while :
  do
    psql -c "\q"
    if [ "$?" = 0 ]; then
      break
    fi
    sleep 1
  done
  if [ "$(psql -c '\d')" = "" ]; then
    psql -f "${ROOT_DIR}/sql/restyaboard_with_empty_data.sql"
  fi
  set -e

  ## cron shell
  echo "*/5  * * * * bash ${ROOT_DIR}/server/php/shell/instant_email_notification.sh" >> /var/spool/cron/crontabs/root
  echo "0    * * * * bash ${ROOT_DIR}/server/php/shell/periodic_email_notification.sh" >> /var/spool/cron/crontabs/root
  echo "*/30 * * * * bash ${ROOT_DIR}/server/php/shell/imap.sh" >> /var/spool/cron/crontabs/root
  echo "*/5  * * * * bash ${ROOT_DIR}/server/php/shell/webhook.sh" >> /var/spool/cron/crontabs/root
  echo "*/5  * * * * bash ${ROOT_DIR}/server/php/shell/card_due_notification.sh" >> /var/spool/cron/crontabs/root

  mkdir /run/nginx

  mkdir -p /var/lib/nginx/html/tmp/cache
  chown -R nginx:nginx /var/lib/nginx/html/tmp/cache

  mkdir -p /var/lib/nginx/html/media
  chown -R nginx:nginx /var/lib/nginx/html/media

  # service start
  php-fpm7
  crond -b -L /var/log/cron.log
  nginx

  exec tail -F /var/log/nginx/*.log /var/log/cron.log
fi

exec "$@"
