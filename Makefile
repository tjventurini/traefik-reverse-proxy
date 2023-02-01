init:
	@./scripts/init.sh

start:
	@./scripts/start.sh

up:
	@./scripts/start.sh

down:
	@./scripts/down.sh

stop:
	@./scripts/down.sh

clear: down
	@./scripts/clear.sh

tail:
	@docker compose logs -f

restart: stop start tail