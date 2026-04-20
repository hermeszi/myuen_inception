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

COPY conf/my.cnf /etc/mysql/conf.d/
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
