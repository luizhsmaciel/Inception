NAME		= inception
LOGIN		= luiz-dos
COMPOSE		= srcs/docker-compose.yml
DATA_PATH	= /home/$(LOGIN)/data

all: build up

build:
	@mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	docker compose -f $(COMPOSE) build

up:
	docker compose -f $(COMPOSE) up -d

down:
	docker compose -f $(COMPOSE) down

stop:
	docker compose -f $(COMPOSE) stop

clean:
	docker compose -f $(COMPOSE) down --rmi all -v --remove-orphans

fclean: clean
	sudo rm -rf $(DATA_PATH)

nocache:
	docker compose -f $(COMPOSE) build --no-cache

re: fclean nocache up

.PHONY: all build up down stop clean fclean nocache re