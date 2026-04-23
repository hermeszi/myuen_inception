# 🐋 Inception — Process Guide

---

## 1. 💿 Download Debian Bookworm

Download `debian-12.9.0-amd64-netinst` (bookworm). Latest Debian is version 13 (trixie) — use the penultimate stable version (bookworm) as required by the subject.

---

## 2. 🖥️ Set Up VirtualBox VM

During installation, select:
- [X] XFCE — lightweight GUI
- [X] SSH server — so you can terminal into the VM from the school host
- [X] Standard system utilities — basic commands like curl, git

---

## 3. 🔑 Enable Sudo and Add Your User

```bash
su - 
apt update && apt install sudo -y
usermod -aG sudo <login>
```

---

## 4. 🔄 Update System

```bash
sudo apt update && sudo apt full-upgrade -y
```

---

## 5. 🐳 Install Docker Engine

### Add Docker's official GPG key:
```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Add the repository to Apt sources:
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### Install Docker components:
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add yourself to docker group (no sudo needed for docker commands)
sudo usermod -aG docker <login>
```

> ⚠️ Log out and back in for group change to take effect.

---

## 6. 🛠️ Install Useful Tools

```bash
sudo apt install git vim curl wget make net-tools -y

# lazydocker - terminal UI for Docker
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
echo 'alias lzd="lazydocker"' >> ~/.bashrc
source ~/.bashrc
```

---

## 7. 💻 Install VS Code (optional)

```bash
sudo apt install software-properties-common apt-transport-https curl gpg -y
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
sudo apt update && sudo apt install code -y
```

---

## 8. 🔐 Set Up SSH Key for Git

```bash
ssh-keygen -t ed25519 -C "<login>@student.42singapore.sg"
cat ~/.ssh/id_ed25519.pub
# Copy the output and add it to your GitHub account
```

---

## 9. 📁 Set Up Folder Structure

```bash
mkdir -p ~/inception/srcs/requirements/{mariadb,nginx,wordpress}
mkdir -p ~/inception/srcs/requirements/mariadb/{conf,tools}
mkdir -p ~/inception/srcs/requirements/nginx/conf
mkdir -p ~/inception/srcs/requirements/wordpress/{conf,tools}
mkdir -p ~/inception/secrets
touch ~/inception/Makefile
touch ~/inception/srcs/docker-compose.yml
touch ~/inception/srcs/.env
```

---

## 10. 🌐 Configure Local Domain

```bash
sudo nano /etc/hosts
# Add this line:
127.0.0.1 <login>.42.fr
```

---

## 11. 💾 Prepare Volume Directories

```bash
mkdir -p /home/<login>/data/mariadb
mkdir -p /home/<login>/data/wordpress
```

---

## 12. 🙈 Create .gitignore

```bash
cat > ~/inception/.gitignore << EOF
srcs/.env
secrets/
EOF
```

> 🚨 **Never commit `.env` or `secrets/` — passwords in git = instant eval failure.**

---

## 13. ⚙️ Create srcs/.env

```bash
nano ~/inception/srcs/.env
```

```
MYSQL_DATABASE=wordpress
MYSQL_USER=<db_username>
MYSQL_PASSWORD=<db_password>
MYSQL_ROOT_PASSWORD=<db_root_password>
MYSQL_PORT=3306
DOMAIN_NAME=<login>.42.fr
WP_ADMIN=<wp_admin_username>
WP_ADMIN_PASSWORD=<wp_admin_password>
WP_ADMIN_EMAIL=<wp_admin_email>
WP_USER=<wp_second_username>
WP_USER_PASSWORD=<wp_second_password>
WP_USER_EMAIL=<wp_second_email>
```

> ⚠️ **Important:**
> - `WP_ADMIN` must NOT contain "admin" or "administrator"
> - `WP_ADMIN_EMAIL` and `WP_USER_EMAIL` must be different
> - Never use the same password twice in a real project

---

## 14. 🗄️ MariaDB — Dockerfile

`srcs/requirements/mariadb/Dockerfile`

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# 99-custom.cnf loads after 50-server.cnf, so our bind-address will go after and thus overwrite the settings
COPY conf/my.cnf /etc/mysql/mariadb.conf.d/99-custom.cnf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
```

---

## 15. 🗄️ MariaDB — Config File

`srcs/requirements/mariadb/conf/my.cnf`

```ini
[mysqld]
bind-address = 0.0.0.0
port = 3306
```

> 💡 **Why `bind-address = 0.0.0.0`?** Default is `127.0.0.1` (localhost only). WordPress container connects from a different IP on the Docker network, so MariaDB must listen on all interfaces.

> 💡 **Why `99-custom.cnf`?** MariaDB loads config files in order. `50-server.cnf` sets `bind-address = 127.0.0.1`. Naming our file `99-custom.cnf` ensures it loads last and overrides that setting.

---

## 16. 🗄️ MariaDB — Entrypoint Script

`srcs/requirements/mariadb/tools/entrypoint.sh`

```bash
#!/bin/bash

# First run: wordpress database directory doesn't exist yet
if [ ! -d "/var/lib/mysql/wordpress" ]; then

    # Initialize fresh MariaDB data directory
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

    # Start MariaDB temporarily with no networking (setup only)
    # --skip-networking prevents outside connections during initialization
    mysqld_safe --skip-networking #&
    sleep 3

    # Run setup SQL using environment variables from .env
    # EOF heredoc feeds multiple SQL commands to mysql client
    mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF
    # '%' means user can connect from any IP (needed for WordPress container)

    # Stop the temporary MariaDB process
    kill $(cat /var/run/mysqld/mysqld.pid)
    sleep 2

fi

# exec replaces this script with mysqld_safe, making it PID 1
exec mysqld_safe
```

---

## 17. 📝 docker-compose.yml — MariaDB Only (First Test)

`srcs/docker-compose.yml`

```yaml
services:
  mariadb:
    build: requirements/mariadb
    image: mariadb
    container_name: mariadb
    env_file: .env
    environment:
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_PORT=${MYSQL_PORT}
    expose:
      - "3306"
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - inception
    restart: unless-stopped

volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/<login>/data/mariadb

networks:
  inception:
    driver: bridge
```

---

## 18. ✅ Test MariaDB

```bash
cd ~/inception/srcs
docker compose up --build -d
docker compose logs mariadb
```

Expected: `mysqld_safe Starting mariadbd daemon`

### 🔍 Verify database is running and populated:

```bash
# Shell into container
docker exec -it mariadb bash

# Login to MariaDB
mariadb -u root -p<root_password>

# Check databases
SHOW DATABASES;
# Expected: information_schema, mysql, performance_schema, sys, wordpress

# Check wordpress database
USE wordpress;
SHOW TABLES;
# Expected: empty at this stage (WordPress hasn't installed yet)

# Check users
SELECT user, host FROM mysql.user;
# Expected: your db user with host '%', and root with localhost

exit;
exit
```

---

## 19. 🌐 WordPress — Dockerfile

`srcs/requirements/wordpress/Dockerfile`

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# WP-CLI: command line tool to install and configure WordPress
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

# Override default www.conf to listen on 0.0.0.0:9000 instead of unix socket
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
```

### 🔍 Check your php-fpm version:
```bash
docker run -it debian:bookworm bash
apt-get update && apt-get install -y php-fpm
ls /usr/sbin/php-fpm*
# Note the version number (e.g. php-fpm8.2)
exit
```

---

## 20. 🌐 WordPress — php-fpm Config

`srcs/requirements/wordpress/conf/www.conf`

```ini
[www]
user = www-data
group = www-data
listen = 0.0.0.0:9000
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

> 💡 **Why `listen = 0.0.0.0:9000`?** Default uses a Unix socket (`/run/php/php8.2-fpm.sock`). NGINX in a separate container can't reach a Unix socket — it needs TCP. `0.0.0.0:9000` listens on all interfaces.

---

## 21. 🌐 WordPress — Entrypoint Script

`srcs/requirements/wordpress/tools/entrypoint.sh`

```bash
#!/bin/bash

# Wait for MariaDB to be ready before proceeding
# depends_on only waits for container start, not for MariaDB to finish initializing
until mariadb -h mariadb -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then

    echo "Setting up WordPress..."

    # Download WordPress core files to /var/www/html
    wp core download --allow-root

    # Generate wp-config.php with database connection details
    # Port goes into --dbhost as mariadb:<port>
    wp config create \
        --dbname=${MYSQL_DATABASE} \
        --dbuser=${MYSQL_USER} \
        --dbpass=${MYSQL_PASSWORD} \
        --dbhost=mariadb:${MYSQL_PORT} \
        --allow-root

    # Install WordPress — creates all database tables
    wp core install \
        --url=${DOMAIN_NAME} \
        --title="Inception" \
        --admin_user=${WP_ADMIN} \
        --admin_password=${WP_ADMIN_PASSWORD} \
        --admin_email=${WP_ADMIN_EMAIL} \
        --allow-root

    # Create second regular user (author role)
    wp user create ${WP_USER} ${WP_USER_EMAIL} \
        --role=author \
        --user_pass=${WP_USER_PASSWORD} \
        --allow-root

fi

echo "WordPress setup complete. Starting php-fpm..."

# exec replaces this script with php-fpm, making it PID 1
# -F flag keeps php-fpm in foreground (no daemon mode)
exec php-fpm8.2 -F
```

---

## 22. 📝 docker-compose.yml — Add WordPress

Add to `srcs/docker-compose.yml` under services:

```yaml
  wordpress:
    build: requirements/wordpress
    image: wordpress
    container_name: wordpress
    env_file: .env
    environment:
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_PORT=${MYSQL_PORT}
      - DOMAIN_NAME=${DOMAIN_NAME}
      - WP_ADMIN=${WP_ADMIN}
      - WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
      - WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}
      - WP_USER=${WP_USER}
      - WP_USER_PASSWORD=${WP_USER_PASSWORD}
      - WP_USER_EMAIL=${WP_USER_EMAIL}
    expose:
      - "9000"
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception
    depends_on:
      - mariadb
    restart: unless-stopped
```

Add to the `volumes:` section:

```yaml
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/<login>/data/wordpress
```

---

## 23. 🔒 NGINX — Dockerfile

`srcs/requirements/nginx/Dockerfile`

```dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Generate self-signed SSL certificate at build time
# -x509: output certificate not CSR
# -nodes: no passphrase on key
# -days 365: valid for 1 year
# -newkey rsa:2048: generate new 2048-bit RSA key
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx.key \
    -out /etc/ssl/certs/nginx.crt \
    -subj "/C=SG/ST=Singapore/L=Singapore/O=42/CN=<login>.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

# daemon off keeps NGINX in foreground as PID 1
CMD ["nginx", "-g", "daemon off;"]
```

---

## 24. 🔒 NGINX — Config File

`srcs/requirements/nginx/conf/nginx.conf`

```nginx
events {}

http {
    server {
        listen 443 ssl;                                    # port 443, SSL enabled
        ssl_certificate /etc/ssl/certs/nginx.crt;         # certificate file
        ssl_certificate_key /etc/ssl/private/nginx.key;   # private key file
        ssl_protocols TLSv1.2 TLSv1.3;                    # allowed TLS versions only

        root /var/www/html;                               # shared volume with WordPress
        index index.php;                                  # default entry point

        # Route all .php requests to php-fpm via FastCGI
        # ~ = regex match, \.php$ = ends with .php
        location ~ \.php$ {
            fastcgi_pass wordpress:9000;                  # php-fpm address
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
    }
}
```

---

## 25. 📝 docker-compose.yml — Add NGINX

Add to `srcs/docker-compose.yml` under services:

```yaml
  nginx:
    build: requirements/nginx
    image: nginx
    container_name: nginx
    ports:
      - "443:443"
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception
    depends_on:
      - wordpress
    restart: unless-stopped
```

---

## 26. 🔨 Makefile

`~/inception/Makefile`

```makefile
COMPOSE_FILE = srcs/docker-compose.yml

all:
	docker compose -f $(COMPOSE_FILE) up --build -d

down:
	docker compose -f $(COMPOSE_FILE) down

re: down all

clean: down
	docker system prune -af

fclean: clean
	sudo rm -rf /home/<login>/data/mariadb/*
	sudo rm -rf /home/<login>/data/wordpress/*

.PHONY: all down re clean fclean
```

> ⚠️ Indentation must use tabs, not spaces.

---

## 27. 🚀 Build and Test Everything

```bash
cd ~/inception
make fclean   # clean slate
make          # build and start all containers

# Check all 3 containers are running
docker ps

# Check logs
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx
```

---

## 28. ✅ Verify WordPress Is Running

Open browser: `https://<login>.42.fr`

Accept the self-signed certificate warning and proceed. You should see the WordPress site.

```bash
# Test HTTPS works
curl -k https://<login>.42.fr

# Test HTTP is blocked (must fail)
curl http://<login>.42.fr
# Expected: connection refused
```

---

## 29. 🔍 Verify Database Is Populated

After WordPress installs, the database should have tables:

```bash
docker exec -it mariadb mariadb -u root -p<root_password> -e "USE wordpress; SHOW TABLES;"
```

Expected output includes: `wp_posts`, `wp_users`, `wp_options`, `wp_comments` etc.

---

## 30. 👥 Verify Two WordPress Users Exist

```bash
docker exec -it wordpress wp user list --allow-root
```

Expected output:
```
+----+-------------+---------------+-----+---------------------+---------------+
| ID | user_login  | display_name  | ... | user_registered     | roles         |
+----+-------------+---------------+-----+---------------------+---------------+
|  1 | <wp_admin>  | <wp_admin>    | ... | 2026-xx-xx xx:xx:xx | administrator |
|  2 | <wp_user>   | <wp_user>     | ... | 2026-xx-xx xx:xx:xx | author        |
+----+-------------+---------------+-----+---------------------+---------------+
```

> 🚨 **Eval check:** Admin username must not contain "admin" or "administrator".

---

## 31. 💾 Test Data Persistence

```bash
# Create a test post in WordPress admin panel
# https://<login>.42.fr/wp-admin

# Reboot the VM
sudo reboot

# After reboot, restart containers
cd ~/inception
make

# Visit the site — test post must still be there ✅
```

---

## 32. 🔧 Changing Ports (Eval Preparation)

The eval may ask you to change a port live. Know which files to edit for each service.

---

### 🔒 Change NGINX Port

**Files to change:**

1. `srcs/docker-compose.yml`:
```yaml
ports:
  - "8443:443"   # host_port:container_port
```

2. Update WordPress URL in database (WordPress stores the URL and sometimes redirects):
```bash
docker exec -it wordpress wp option update siteurl https://<login>.42.fr:8443 --allow-root
docker exec -it wordpress wp option update home https://<login>.42.fr:8443 --allow-root
```

3. Rebuild:
```bash
make re
```

4. Test: `https://<login>.42.fr:8443`

---

### 🌐 Change WordPress/php-fpm Port

**Files to change:**

1. `srcs/requirements/wordpress/conf/www.conf`:
```ini
listen = 0.0.0.0:9001
```

2. `srcs/requirements/nginx/conf/nginx.conf`:
```nginx
fastcgi_pass wordpress:9001;
```

3. Rebuild: `make re`

---

### 🗄️ Change MariaDB Port

**Files to change:**

1. `srcs/requirements/mariadb/conf/my.cnf`:
```ini
[mysqld]
bind-address = 0.0.0.0
port = 3307
```

2. `srcs/.env`:
```
MYSQL_PORT=3307
```

3. The WordPress entrypoint script reads `${MYSQL_PORT}` for both the wait loop and `wp config create`, so no script changes needed.

4. Wipe data and rebuild (wp-config.php has old port baked in):
```bash
make fclean
make
```

---

## 📚 Key Concepts for Eval

| Concept | Summary |
|---------|---------|
| 🐳 **Docker vs VM** | Containers share the host kernel, VMs virtualize the entire OS. Docker is faster and lighter; VMs offer stronger isolation. |
| 📋 **docker-compose vs docker run** | docker-compose orchestrates multiple containers defined in a YAML file. `docker run` starts a single container manually. |
| 💾 **Named volumes vs bind mounts** | Bind mounts directly map a host path — fragile and machine-dependent. Named volumes are managed by Docker. This project uses named volumes with `driver_opts` to control host storage location. |
| 🌐 **Docker network vs host network** | Host network shares the host's network stack (no isolation). Docker bridge network creates a private virtual network where containers communicate by service name. |
| 🔐 **Secrets vs environment variables** | Env vars are visible to all processes and can appear in logs. Secrets are mounted as files with restricted permissions — safer for sensitive data. |
| ⚙️ **PID 1** | Docker watches the first process. If it exits, the container stops. Services must run in foreground (`daemon off` for NGINX, `-F` for php-fpm, `exec mysqld_safe` for MariaDB). |
| ⚡ **FastCGI** | Protocol NGINX uses to send PHP requests to php-fpm. NGINX handles HTTP/HTTPS; php-fpm executes PHP code and returns HTML. |
| 🔧 **php-fpm** | PHP FastCGI Process Manager. Keeps PHP worker processes alive and ready. WordPress is just PHP files — php-fpm is what executes them. |
