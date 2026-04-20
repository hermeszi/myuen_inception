# DEV_DOC — Developer Documentation

## Prerequisites

- VirtualBox VM running Debian Bookworm
- Docker Engine installed (see README for install steps)
- Docker Compose plugin installed
- `make` installed
- Git installed

---

## Environment setup from scratch

### 1. Create data directories on host
```bash
mkdir -p /home/myuen/data/mariadb
mkdir -p /home/myuen/data/wordpress
```

### 2. Configure local domain
```bash
sudo nano /etc/hosts
# Add this line:
127.0.0.1 myuen.42.fr
```

### 3. Create .env file
```bash
nano ~/inception/srcs/.env
```

Required variables:
```
MYSQL_DATABASE=wordpress
MYSQL_USER=<db_username>
MYSQL_PASSWORD=<db_password>
MYSQL_ROOT_PASSWORD=<root_password>
DOMAIN_NAME=myuen.42.fr
MYSQL_PORT=3306
WP_ADMIN=<wp_admin_username>        # must not contain "admin"
WP_ADMIN_PASSWORD=<wp_admin_pass>
WP_ADMIN_EMAIL=<wp_admin_email>
WP_USER=<wp_second_username>
WP_USER_PASSWORD=<wp_second_pass>
WP_USER_EMAIL=<wp_second_email>     # must be different from admin email
```

### 4. Verify .gitignore
```bash
cat ~/inception/.gitignore
# Must contain:
# srcs/.env
```

---

## Project structure

```
inception/
├── Makefile
└── srcs/
    ├── .env                        ← gitignored
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf
        │   └── tools/entrypoint.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf
            └── tools/entrypoint.sh
```

---

## Build and launch

```bash
# Build images and start all containers
make

# Or directly with docker compose
docker compose -f srcs/docker-compose.yml up --build -d
```

---

## Makefile targets

| Target | Action |
|--------|--------|
| `make` | Build images and start containers |
| `make down` | Stop and remove containers |
| `make re` | Restart (down then up) |
| `make clean` | Stop containers and remove all Docker images |
| `make fclean` | clean + wipe all volume data (full reset) |

---

## Managing containers

```bash
# View running containers
docker ps

# View logs
docker compose -f srcs/docker-compose.yml logs <service>

# Shell into a container
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# View all networks
docker network ls
docker network inspect srcs_inception

# View all volumes
docker volume ls
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data
```

---

## Data persistence

Volume data is stored on the host machine at:
```
/home/myuen/data/mariadb/    ← MariaDB database files
/home/myuen/data/wordpress/  ← WordPress files and uploads
```

These directories survive container restarts and rebuilds. Only `make fclean` wipes them.

Docker named volumes (`srcs_mariadb_data`, `srcs_wordpress_data`) use bind driver options to map to these host directories.

---

## Common debug commands

```bash
# Check MariaDB bind address (should be 0.0.0.0)
docker exec -it mariadb mariadb -u root -p<password> -e "SHOW VARIABLES LIKE 'bind_address';"

# Check WordPress users
docker exec -it wordpress wp user list --allow-root

# Check WordPress database tables exist
docker exec -it mariadb mariadb -u root -p<password> -e "USE wordpress; SHOW TABLES;"

# Test HTTPS works
curl -k https://myuen.42.fr

# Test HTTP is blocked (should fail)
curl http://myuen.42.fr

# Check TLS version
openssl s_client -connect myuen.42.fr:443 -tls1_2
```

---

## Key technical decisions

**MariaDB config load order:** Default `50-server.cnf` in `/etc/mysql/mariadb.conf.d/` sets `bind-address = 127.0.0.1`. Our custom config is named `99-custom.cnf` so it loads after and overrides this.

**php-fpm listen address:** Default `www.conf` uses a Unix socket (`/run/php/php8.2-fpm.sock`). We replace it with our own `www.conf` that sets `listen = 0.0.0.0:9000` so NGINX container can reach it over the Docker network.

**WordPress wait loop:** `depends_on` in docker-compose only waits for the container to start, not for MariaDB to be ready. The WordPress entrypoint script loops until a successful MariaDB connection before proceeding with installation.

**Shared volume:** Both NGINX and WordPress containers mount `wordpress_data` at `/var/www/html`. NGINX needs access to serve static files directly and to know which PHP file to pass to php-fpm.
