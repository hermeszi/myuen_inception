#!/bin/bash

# Wait for MariaDB to be ready
until mariadb -h mariadb -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then

    echo "Setting up WordPress..."
    # Download WordPress files
    wp core download --allow-root

    # Create wp-config.php using env variables
    wp config create \
        --dbname=${MYSQL_DATABASE} \
        --dbuser=${MYSQL_USER} \
        --dbpass=${MYSQL_PASSWORD} \
        --dbhost=mariadb:${MYSQL_PORT} \
        --allow-root

    # Install WordPress and create DB tables
    wp core install \
        --url=${DOMAIN_NAME} \
        --title="Inception" \
        --admin_user=${WP_ADMIN} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --allow-root

    # Create second regular user
    wp user create ${WP_USER} ${WP_USER_EMAIL} \
        --role=author \
        --user_pass=${WP_USER_PASSWORD} \
        --allow-root

fi

echo "WordPress setup complete. Starting php-fpm..."
# Start php-fpm as PID 1
exec php-fpm8.2 -F
