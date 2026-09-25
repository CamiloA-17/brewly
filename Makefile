# Developer shortcuts. Run `make help` to list them.

-include .env
export

DATABASE_URL ?= postgres://brewly:brewly@localhost:5432/brewly_dev?sslmode=disable
DBMATE_MIGRATIONS_DIR ?= database/migrations
DBMATE_NO_DUMP_SCHEMA ?= true
DBMATE ?= dbmate

.PHONY: help db-up db-down db-migrate db-rollback db-reset db-seed db-test \
        shared-test server-run server-test ios-config ios-project ios-test

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

db-seed: ## Load demo data (development only; password from DEMO_PASSWORD)
	@test -n "$(DEMO_PASSWORD)" || { echo "Set DEMO_PASSWORD in .env (at least 8 characters)"; exit 1; }
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -v demo_password="$(DEMO_PASSWORD)" -f database/seeds/dev_seed.sql

db-test: ## Run the SQL test suite
	database/tests/run.sh

shared-test: ## Test the shared Swift package
	swift test --package-path shared/BrewlyShared

server-run: ## Run the API on http://localhost:8080
	swift run --package-path server BrewlyServer serve --hostname 0.0.0.0 --port 8080

server-test: ## Test the API (integration tests need TEST_DATABASE_URL and JWT_SECRET)
	swift test --package-path server

ios-config: ## Create ios/Config/Local.xcconfig (Team ID, API address) if it does not exist
	@if [ -f ios/Config/Local.xcconfig ]; then \
		echo "ios/Config/Local.xcconfig already exists"; \
	else \
		cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig; \
		echo "Created ios/Config/Local.xcconfig: set DEVELOPMENT_TEAM and, for a device, BREWLY_API_BASE_URL"; \
	fi

ios-project: ## Generate ios/Brewly.xcodeproj with XcodeGen
	cd ios && xcodegen generate

ios-test: ## Run the BrewlyKit tests on an iOS simulator
	scripts/ios-test.sh
