FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx-light \
	openssl \
	gettext-base \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /etc/nginx/sites-enabled/default

COPY conf/nginx.conf.template /etc/nginx/templates/default.conf.template

COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

EXPOSE 443

ENTRYPOINT ["init.sh"]
