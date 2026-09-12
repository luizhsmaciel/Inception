FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
	php8.2-fpm \
	php8.2-mysqli \
	php8.2-curl \
	php8.2-gd \
	php8.2-xml \
	php8.2-mbstring \
	mariadb-client \
	curl \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

RUN sed -i 's|^memory_limit = .*|memory_limit = 512M|' /etc/php/8.2/fpm/php.ini

RUN curl -sS -o /usr/local/bin/wp \
	https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html \
	&& curl -sS -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz \
	&& tar -xzf /tmp/wordpress.tar.gz -C /var/www/html --strip-components=1 \
	&& rm -f /tmp/wordpress.tar.gz

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["init.sh"]
