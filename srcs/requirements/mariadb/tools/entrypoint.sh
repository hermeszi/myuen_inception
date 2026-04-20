#!/bin/bash

# First run: data directory for our database doesn't exist yet
if [ ! -d "/var/lib/mysql/wordpress" ]; then

    echo "Initializing MariaDB data directory and setting up database..."

    # Initialize fresh MariaDB data directory
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    # Start MariaDB temporarily with no networking (setup only)
    mysqld_safe --skip-networking &
    sleep 3

    # Run setup SQL using environment variables from .env
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

    # Stop the temporary MariaDB process
    kill $(cat /var/run/mysqld/mysqld.pid)
    sleep 2

fi

# Start MariaDB as PID 1 (replaces this script process)
echo "Starting MariaDB..."
exec mysqld_safe