# Developer shortcuts. Run `make help` to list them.

-include .env
export

DATABASE_URL ?= postgres://brewly:brewly@localhost:5432/brewly_dev?sslmode=disable
DBMATE_MIGRATIONS_DIR ?= database/migrations
DBMATE_NO_DUMP_SCHEMA ?= true
DBMATE ?= dbmate

.PHONY: help db-up db-down db-migrate db-rollback db-reset db-seed db-test \
        shared-test server-run server-test ios-project ios-test

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

db-up: ## Start PostgreSQL and apply migrations (docker compose)
	docker compose up -d db migrate

db-down: ## Stop the local stack
	docker compose down

db-migrate: ## Apply pending migrations
	$(DBMATE) --wait up

db-rollback: ## Roll back the latest migration
	$(DBMATE) rollback

db-reset: ## Drop, recreate and migrate the database
	$(DBMATE) drop && $(DBMATE) --wait up

db-seed: ## Load demo data (development only)
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f database/seeds/dev_seed.sql

db-test: ## Run the SQL test suite
	database/tests/run.sh

shared-test: ## Test the shared Swift package
	swift test --package-path shared/BrewlyShared

server-run: ## Run the API on http://localhost:8080
	swift run --package-path server BrewlyServer serve --hostname 0.0.0.0 --port 8080

server-test: ## Test the API (integration tests need DATABASE_URL)
	swift test --package-path server

ios-project: ## Generate ios/Brewly.xcodeproj with XcodeGen
	cd ios && xcodegen generate

ios-test: ## Run the BrewlyKit tests on an iOS simulator
	scripts/ios-test.sh
