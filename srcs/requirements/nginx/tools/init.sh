#!/bin/bash
set -e

mkdir -p /etc/nginx/ssl

if [ ! -f /etc/nginx/ssl/inception.crt ]; then
	openssl req -x509 -nodes -days 365 \
		-newkey rsa:2048 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/C=PT/ST=Lisboa/L=Lisboa/O=42/CN=${DOMAIN_NAME}"

	chmod 600 /etc/nginx/ssl/inception.key
	chmod 644 /etc/nginx/ssl/inception.crt
fi

envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"