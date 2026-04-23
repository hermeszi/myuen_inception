myuen@myuen:~/inception/srcs$ docker compose logs wordpress 
wordpress  | Waiting for MariaDB...
wordpress  | WordPress setup complete. Starting php-fpm...
myuen@myuen:~/inception/srcs$ 

#!/bin/bash

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

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



*This project has been created as part of the 42 curriculum by myuen.*

# Inception

## Description

Inception is a system administration project that involves setting up a small infrastructure using Docker and Docker Compose inside a virtual machine. The goal is to build and orchestrate three services — NGINX, WordPress with php-fpm, and MariaDB — each running in its own container, communicating over a private Docker network, with data persisting through named volumes.

The project uses only self-built Docker images based on Debian Bookworm. No pre-built images from DockerHub are used (except the base Debian image).

### Architecture

```
Browser (HTTPS port 443)
        ↓
   [NGINX container]        ← only entry point, handles TLS
        ↓ FastCGI (port 9000)
[WordPress + php-fpm]       ← executes PHP, connects to DB
        ↓ TCP (port 3306)
  [MariaDB container]       ← stores all WordPress data
```

### Design Choices

**Virtual Machines vs Docker**
A VM virtualizes an entire operating system including the kernel. Docker containers share the host kernel and only isolate the application layer. Docker is faster to start, uses less memory, and is easier to reproduce. VMs offer stronger isolation but are heavier.

**Secrets vs Environment Variables**
Environment variables are visible to any process in the container and can be leaked through logs. Docker secrets are mounted as files inside the container with restricted permissions, safer for sensitive data. This project uses a `.env` file (gitignored) passed through docker-compose, without secrets.

**Docker Network vs Host Network**
Host network mode shares the host's network stack — containers can reach each other via localhost but there is no isolation. Docker network creates a private virtual network where containers communicate by service name. This project uses a custom bridge network called `inception` so containers are isolated from the host and from each other except through defined connections.

**Docker Volumes vs Bind Mounts**
Bind mounts link a specific host directory to a container path which is machine-dependent. Named volumes are managed by Docker and more portable. This project uses named volumes with `driver_opts` to control where data is stored on the host (`/home/myuen/data/`), satisfying both the portability of named volumes and the location requirement of the subject.

## Instructions

### Prerequisites
- VirtualBox with Debian Bookworm VM
- Docker Engine and Docker Compose plugin installed
- `/home/myuen/data/mariadb` and `/home/myuen/data/wordpress` directories created
- `/etc/hosts` entry: `127.0.0.1 myuen.42.fr`

### Setup
```bash
# Clone the repository
git clone <repo_url>
cd inception

# Create your .env file (never commit this)
cp srcs/.env.example srcs/.env
# Edit srcs/.env with your credentials

# Create data directories
mkdir -p /home/myuen/data/mariadb
mkdir -p /home/myuen/data/wordpress

# Build and start
make
```

### Access
- Website: `https://myuen.42.fr`
- Admin panel: `https://myuen.42.fr/wp-admin`

### Stop
```bash
make down
```

### Full reset (destroys all data)
```bash
make fclean
```

## Resources

### Docker
- [Docker official documentation](https://docs.docker.com)
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Compose reference](https://docs.docker.com/compose/compose-file/)

### NGINX
- [NGINX beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- [NGINX FastCGI configuration](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)

### MariaDB
- [MariaDB configuration](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/)
- [MariaDB SQL basics](https://mariadb.com/kb/en/basic-sql-statements/)

### WordPress
- [WP-CLI documentation](https://wp-cli.org/)
- [php-fpm configuration](https://www.php.net/manual/en/install.fpm.configuration.php)

### SSL/TLS
- [OpenSSL self-signed certificates](https://www.openssl.org/docs/manmaster/man1/req.html)
- [TLS 1.2 vs TLS 1.3](https://www.cloudflare.com/learning/ssl/why-use-tls-1.3/)

### AI Usage
Claude (Anthropic) was used throughout this project as a Socratic learning tool. Specific uses:
- Explaining Docker concepts (PID 1, layers, networking, volumes)
- Explaining MariaDB config load order problem and fix
- Explaining php-fpm, FastCGI, and why `listen = 0.0.0.0:9000` is required
- Reviewing entrypoint script logic
- Explaining nginx.conf directives (`location ~ \.php$`, `fastcgi_pass`)
