init:
	@./scripts/init.sh

start:
	@./scripts/start.sh

down:
	@./scripts/down.sh

stop:
	@./scripts/down.sh

clear: down
	@./scripts/clear.sh