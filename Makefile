# Makefile for Orc Orchestration Engine
.DEFAULT_GOAL := help

# Variables
COMPOSE_FILE := docker/compose.yml
DOCKER_COMPOSE := docker compose -f $(COMPOSE_FILE)
SERVER_CONTAINER := orc-server
DB_CONTAINER := orc-postgres

# Colors for help
CYAN := \033[36m
RESET := \033[0m

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)Orc Orchestration Engine - Available Commands$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# Core Docker Compose Commands
.PHONY: up
up: ## Start all services in background
	$(DOCKER_COMPOSE) up -d

.PHONY: down
down: ## Stop and remove containers
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: ## Restart all services
	$(DOCKER_COMPOSE) restart

.PHONY: ps
ps: ## Show container status
	$(DOCKER_COMPOSE) ps

.PHONY: logs
logs: ## Follow logs for all services
	$(DOCKER_COMPOSE) logs -f

.PHONY: logs-server
logs-server: ## Follow server logs only
	$(DOCKER_COMPOSE) logs -f $(SERVER_CONTAINER)

.PHONY: logs-db
logs-db: ## Follow database logs only
	$(DOCKER_COMPOSE) logs -f $(DB_CONTAINER)

# Build & Clean
.PHONY: build
build: ## Build/rebuild Docker images
	$(DOCKER_COMPOSE) build

.PHONY: rebuild
rebuild: ## Rebuild images without cache and restart
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d

.PHONY: clean
clean: ## Stop containers and remove volumes (fresh start)
	$(DOCKER_COMPOSE) down -v

.PHONY: prune
prune: ## Deep clean - remove unused images, networks, volumes
	$(DOCKER_COMPOSE) down -v --rmi local
	docker system prune -f

# Database Management
.PHONY: db-shell
db-shell: ## Open PostgreSQL shell
	$(DOCKER_COMPOSE) exec $(DB_CONTAINER) psql -U orc_user -d orc_db

.PHONY: db-migrate
db-migrate: ## Run database migrations
	@echo "Migrations run automatically on container start via /docker-entrypoint-initdb.d"
	@echo "To re-run migrations, use: make db-reset"

.PHONY: db-reset
db-reset: ## Drop DB, recreate, and run migrations
	$(DOCKER_COMPOSE) down -v
	$(DOCKER_COMPOSE) up -d $(DB_CONTAINER)
	@echo "Waiting for database to be ready..."
	@sleep 5
	$(DOCKER_COMPOSE) up -d

.PHONY: db-backup
db-backup: ## Backup database to file (usage: make db-backup FILE=backup.sql)
	@mkdir -p backups
	$(DOCKER_COMPOSE) exec -T $(DB_CONTAINER) pg_dump -U orc_user orc_db > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup created in backups/"

.PHONY: db-restore
db-restore: ## Restore database from file (usage: make db-restore FILE=backup.sql)
	@if [ -z "$(FILE)" ]; then echo "Please specify FILE=<path>"; exit 1; fi
	$(DOCKER_COMPOSE) exec -T $(DB_CONTAINER) psql -U orc_user -d orc_db < $(FILE)

# Development Tools
.PHONY: shell
shell: ## Shell into orc-server container
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) /bin/sh

.PHONY: db-only
db-only: ## Start only the database (for local Go development)
	$(DOCKER_COMPOSE) up -d $(DB_CONTAINER)

.PHONY: exec
exec: ## Execute command in server container (usage: make exec cmd="ls -la")
	@if [ -z "$(cmd)" ]; then echo "Please specify cmd=\"<command>\""; exit 1; fi
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) $(cmd)

.PHONY: watch
watch: ## Follow logs with timestamps
	$(DOCKER_COMPOSE) logs -f --tail=100 --timestamps

.PHONY: health
health: ## Check health status of all services
	@$(DOCKER_COMPOSE) ps
	@echo ""
	@echo "Database health:"
	@$(DOCKER_COMPOSE) exec $(DB_CONTAINER) pg_isready -U orc_user -d orc_db || echo "Database not ready"

# Testing Helpers
.PHONY: test
test: ## Run tests in container
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) go test ./...

.PHONY: test-verbose
test-verbose: ## Run tests with verbose output
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) go test -v ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage report
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) go test -coverprofile=coverage.out ./...
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) go tool cover -html=coverage.out -o coverage.html

.PHONY: test-integration
test-integration: ## Run integration tests
	$(DOCKER_COMPOSE) exec $(SERVER_CONTAINER) go test -tags=integration ./...

# Go Development (Local)
.PHONY: run-local
run-local: ## Run server locally (assumes DB is in Docker)
	@echo "Make sure database is running: make db-only"
	DATABASE_URL=postgres://orc_user:orc_password@localhost:5432/orc_db?sslmode=disable go run cmd/server/main.go

.PHONY: fmt
fmt: ## Format Go code
	go fmt ./...

.PHONY: lint
lint: ## Run golangci-lint
	golangci-lint run

.PHONY: mod
mod: ## Download and tidy Go modules
	go mod download
	go mod tidy

# Complete workflow commands
.PHONY: dev
dev: build up logs ## Build and start development environment with logs

.PHONY: fresh
fresh: clean up ## Fresh start - remove everything and start clean

.PHONY: status
status: ps health ## Show complete status of all services
