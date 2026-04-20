
# myuen_inception
documentation and files for ft_inception @ 42

1. downloaded debian-12.9.0-amd64-netinst (bookworm), as latest Debian is version 13 (trixie).
2. set up vm using vituralbox -
  [X] XFCE (Check this for your lightweight GUI).
  [X] SSH server (Check this so you can terminal into the VM from the school host).
  [X] standard system utilities (Check this for basic commands like curl or git).
3. Enable Sudo and Add me as User
```
su - <password>
apt update && apt install sudo -y
usermod -aG sudo myuen
```
4. update system
```
   sudo apt update && sudo apt full-upgrade -y
```
5. Install the Docker Engine

### Add Docker's official GPG key:
```
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Add the repository to Apt sources:
```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### Install Docker components:
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#add myself to docker group
sudo usermod -aG docker mingde
```

6. Setup the Folder Structure
```
mkdir -p ~/inception/srcs/requirements/{mariadb,nginx,wordpress}
mkdir -p ~/inception/srcs/requirements/mariadb/conf
mkdir -p ~/inception/srcs/requirements/mariadb/tools
mkdir -p ~/inception/srcs/requirements/nginx/conf
mkdir -p ~/inception/srcs/requirements/nginx/tools
mkdir -p ~/inception/srcs/requirements/wordpress/conf
mkdir -p ~/inception/srcs/requirements/wordpress/tools
touch ~/inception/Makefile
touch ~/inception/srcs/docker-compose.yml
touch ~/inception/srcs/.env
```
7. Configure the Local Domain
```
sudo nano /etc/hosts
127.0.0.1 myuen.42.fr
```
8. Prepare volume
```
mkdir -p /home/myuen/data/mariadb
mkdir -p /home/myuen/data/wordpress
```

9. Install VS Code
```
sudo apt update
sudo apt install software-properties-common apt-transport-https curl gpg -y

# 2. Import Microsoft's GPG Key
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg

# 3. Add the Repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

# 4. Vscode
sudo apt update
sudo apt install code -y
```

10. Install useful tools
```
sudo apt install git
sudo apt install vim
sudo apt install curl wget
sudo apt install make
sudo apt install net-tools

#lazydocker
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
nano ~/.bashrc
# Add local binaries to path
export PATH="$PATH:$HOME/.local/bin"

# Optional: shortcut alias
alias lzd='lazydocker'

#Portainer
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
```
11. SSH
```
ssh-keygen -t ed25519 -C "myuen@student.42singapore.sg"
cat ~/.ssh/id_ed25519.pub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFDelOUviJ2rxUji6Ok4SMg8NDCxtbdiAtP4GMXKvdcY myuen@student.42singapore.sg

```

12. Create srcs/requirements/mariadb/Dockerfile:
```
dockerfileFROM debian:bookworm

RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

#COPY conf/my.cnf /etc/mysql/my.cnf LOAD ORDER problem
COPY conf/my.cnf /etc/mysql/mariadb.conf.d/99custom.cnf

COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/entrypoint.sh"]
```

13. create the MariaDB config file srcs/requirements/mariadb/conf/my.cnf:
```
[mysqld]
bind-address = 0.0.0.0
port = 3306
```

14. Create srcs/requirements/mariadb/tools/entrypoint.sh:
```
#!/bin/bash

# First run: data directory for our database doesn't exist yet
if [ ! -d "/var/lib/mysql/wordpress" ]; then

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
exec mysqld_safe
```

15. srcs/.env:
```
MYSQL_DATABASE=wordpress
MYSQL_USER=myuen
MYSQL_PASSWORD=4321
MYSQL_ROOT_PASSWORD=1234
DOMAIN_NAME=myuen.42.fr
```

16. srcs/docker-compose.yml (MariaDB only for now):
```
services:
  mariadb:                    # service name = container hostname on Docker network
    build: requirements/mariadb   # where to find the Dockerfile
    container_name: mariadb   # actual container name (must match service name for eval)
    env_file: .env            # load all variables from .env file
    environment:              # pass specific vars into container
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql  # named volume : path inside container
    networks:
      - inception             # which Docker network to join
    restart: unless-stopped   # restart on crash, but not if manually stopped

volumes:
  mariadb_data:               # define the named volume
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/myuen/data/mariadb  # where data lives on host machine

networks:
  inception:
    driver: bridge            # standard Docker network type
```
17.  Add .env to .gitignore:

18. check
```
docker compose up --build -d

docker compose logs mariadb
```

18. Shell into the container
```
docker exec -it mariadb bash
mariadb -u root -p
SHOW DATABASES;
```

19. Create srcs/requirements/wordpress/Dockerfile:
```
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    php-fpm \
    php-mysql \
    curl \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
```

20.create wordpress entrypoint.sh
```
#!/bin/bash

# Wait for MariaDB to be ready
until mariadb -h mariadb -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then

    # Download WordPress files
    wp core download --allow-root

    # Create wp-config.php using env variables
    wp config create \
        --dbname=${MYSQL_DATABASE} \
        --dbuser=${MYSQL_USER} \
        --dbpass=${MYSQL_PASSWORD} \
        --dbhost=mariadb \
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

# Start php-fpm as PID 1
exec php-fpm8.2 -F
```

21. Add new passwords to .env
```
WP_ADMIN=myuen
WP_ADMIN_PASSWORD=1234
WP_ADMIN_EMAIL=myuen@student.42singapore.sg
WP_USER=user
WP_USER_PASSWORD=4321
WP_USER_EMAIL=myuen@42mail.sutd.edu.sg
```
22. check wordpress fpm version
```
docker run -it debian:bookworm bash
apt-get update && apt-get install -y php-fpm
ls /usr/sbin/php-fpm*
```

23. add WordPress to docker-compose.yml:
```
wordpress:
    build: requirements/wordpress
    container_name: wordpress
    env_file: .env
    environment:
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - DOMAIN_NAME=${DOMAIN_NAME}
      - WP_ADMIN=${WP_ADMIN}
      - WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
      - WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}
      - WP_USER=${WP_USER}
      - WP_USER_PASSWORD=${WP_USER_PASSWORD}
      - WP_USER_EMAIL=${WP_USER_EMAIL}
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception
    depends_on:
      - mariadb
    restart: unless-stopped
```

24. add the volume
```
wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/myuen/data/wordpress
```      
25. replace wordpress default confi - srcs/requirements/wordpress/conf/www.conf
```
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

26. test wordpress
```
docker compose down
docker compose up --build -d
docker compose logs wordpress
docker exec -it mariadb mariadb -u root -p -e "USE wordpress; SHOW TABLES;"
```
27. generate a nginx Dockerfile with self-signed SSL
```
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx.key \
    -out /etc/ssl/certs/nginx.crt \
    -subj "/C=SG/ST=Singapore/L=Singapore/O=42/CN=myuen.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
```
28. ~/inception/srcs/requirements/nginx/conf/nginx.conf
```
events {}

http {
    server {
        listen 443 ssl;                                    # port 443, SSL enabled
        ssl_certificate /etc/ssl/certs/nginx.crt;         # certificate file
        ssl_certificate_key /etc/ssl/private/nginx.key;   # private key file
        ssl_protocols TLSv1.2 TLSv1.3;                   # allowed TLS versions only

        root /var/www/html;                               # where WordPress files are
        index index.php;                                  # default file to serve

        # location ~ \.php$ means:
        # ~        = use regex matching
        # \.php    = match files ending in .php (\ escapes the dot)
        # $        = end of string
        # so: "for any request ending in .php, do this:"
        location ~ \.php$ {
            fastcgi_pass wordpress:9000;                  # send to php-fpm
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;  # tell php-fpm which file to run
            include fastcgi_params;                       # standard FastCGI parameters
        }
    }
}
```
29. Add to docker compose vol info

```
nginx:
    build: requirements/nginx
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
30. test curl https://myuen.42.fr and http://myuen.42.fr

31. Makefile
```
COMPOSE_FILE = srcs/docker-compose.yml

all:
	docker compose -f $(COMPOSE_FILE) up --build -d

down:
	docker compose -f $(COMPOSE_FILE) down

re: down all

clean: down
	docker system prune -af

fclean: clean
	sudo rm -rf /home/myuen/data/mariadb/*
	sudo rm -rf /home/myuen/data/wordpress/*

.PHONY: all down re clean fclean
```
32. test wordpress data persistance
```
Go to https://myuen.42.fr/wp-admin
Login with your admin credentials (myuen / your password)
Go to Posts → Add New
Write a test post, publish it
Visit the site and confirm you see the post
```
33. show 2 wordpress user
```
docker exec -it wordpress wp user list --allow-root
```
