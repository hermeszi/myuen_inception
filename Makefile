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

.PHONY: all down re clean fcleanCOMPOSE_FILE = srcs/docker-compose.yml