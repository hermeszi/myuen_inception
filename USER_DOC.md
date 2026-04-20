# USER_DOC — User Documentation

## What services does this stack provide?

| Service | Purpose |
|---------|---------|
| NGINX | Web server, handles HTTPS, entry point for all traffic |
| WordPress + php-fpm | The website and its PHP engine |
| MariaDB | Database storing all WordPress content |

The website is accessible at `https://myuen.42.fr` only. HTTP (port 80) is blocked by design.

---

## Starting the project

```bash
cd ~/inception
make
```

This builds all Docker images and starts all three containers in the background.

Wait about 30 seconds on first run for WordPress to initialize.

---

## Stopping the project

```bash
make down
```

This stops and removes containers. Your data is preserved.

---

## Accessing the website

Open your browser and go to:
```
https://myuen.42.fr
```

You will see a certificate warning — this is expected (self-signed certificate). Click "Advanced" and proceed.

---

## Accessing the admin panel

```
https://myuen.42.fr/wp-admin
```

Login with your admin credentials from the `.env` file:
- Username: value of `WP_ADMIN`
- Password: value of `WP_ADMIN_PASSWORD`

---

## Managing credentials

All credentials are stored in `srcs/.env`. This file is gitignored and never committed.

```
MYSQL_DATABASE=wordpress
MYSQL_USER=...
MYSQL_PASSWORD=...
MYSQL_ROOT_PASSWORD=...
WP_ADMIN=...
WP_ADMIN_PASSWORD=...
WP_USER=...
WP_USER_PASSWORD=...
```

---

## Checking that services are running

```bash
# Check all containers are up
docker ps

# Check logs for each service
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx

# Check WordPress users exist
docker exec -it wordpress wp user list --allow-root

# Check database exists
docker exec -it mariadb mariadb -u root -p<root_password> -e "SHOW DATABASES;"
```

Expected: three containers running — `mariadb`, `wordpress`, `nginx`.

---

## WordPress users

Two users are created automatically on first run:

| Username | Role | Email |
|----------|------|-------|
| `WP_ADMIN` value | Administrator | `WP_ADMIN_EMAIL` value |
| `WP_USER` value | Author | `WP_USER_EMAIL` value |
