# Shortcuts for running and checking the Sales KPI Dashboard.
# Run `make` (or `make help`) to list them.

COMPOSE ?= docker compose
API     := http://localhost:8010
WEB     := http://localhost:5173

.DEFAULT_GOAL := help
.PHONY: help up down restart reset logs ps check compile build verify psql

help: ## List the available commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  make %-9s %s\n", $$1, $$2}'

up: ## Build and start everything in the background, then wait until the API is ready
	$(COMPOSE) up --build -d
	@printf "Waiting for the API"; \
	for i in $$(seq 1 60); do \
	  if curl -sf $(API)/api/health >/dev/null; then \
	    printf "\nReady:\n  Dashboard  $(WEB)\n  API        $(API)/api/summary\n  Postgres   localhost:5442 (sales/sales/sales)\n"; exit 0; \
	  fi; printf "."; sleep 1; \
	done; \
	printf "\nAPI not ready after 60s; see: make logs\n"; exit 1

down: ## Stop everything (the data is kept)
	$(COMPOSE) down

restart: down up ## Stop, then start again (the data is kept)

reset: ## Wipe the database and start fresh with new sample data
	$(COMPOSE) down -v
	@$(MAKE) --no-print-directory up

logs: ## Follow the logs from all services (Ctrl+C to stop)
	$(COMPOSE) logs -f

ps: ## Show which services are running
	$(COMPOSE) ps

check: ## Run the automated checks (scripts/check.sh)
	bash scripts/check.sh

compile: ## Syntax-check the backend Python files
	$(COMPOSE) exec -T api python -m py_compile main.py db.py sales/routes.py && echo "Backend compiles"

build: ## Production build of the frontend (catches JSX errors)
	$(COMPOSE) exec -T web npm run build

verify: compile build check ## Run all three checks: compile, build, check

psql: ## Open a Postgres shell on the sales database
	$(COMPOSE) exec db psql -U sales sales
