#!/bin/bash
set -e

WP_PATH="/var/www/html"

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

until mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${DB_PASSWORD}" --silent 2>/dev/null; do
	echo "Waiting for MariaDB..."
	sleep 1
done

if [ ! -f "${WP_PATH}/wp-config.php" ]; then
	wp config create \
		--path="${WP_PATH}" \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb \
		--allow-root
fi

if ! wp core is-installed --path="${WP_PATH}" --allow-root 2>/dev/null; then
	wp core install \
		--path="${WP_PATH}" \
		--url="${DOMAIN_NAME}" \
		--title="${WP_TITLE}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email \
		--allow-root

	wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
		--path="${WP_PATH}" \
		--user_pass="${WP_USER_PASSWORD}" \
		--role=author \
		--allow-root
else
	wp core verify-checksums --path="${WP_PATH}" --allow-root || echo "Warning: some WordPress files are modified"
fi

chown -R www-data:www-data "${WP_PATH}"

exec php-fpm8.2 -F