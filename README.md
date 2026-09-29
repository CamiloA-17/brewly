# Brewly

Brewly is a native iOS brewing companion. Keep a shelf of coffee beans, create reusable
recipes, follow each preparation with a step timer, and record the actual cup as a **brew
session**. Brewly keeps those observations separate from recipes so you can compare attempts
and make one deliberate adjustment at a time.

The home screen starts with your last cup and your private recipes. Existing recipe results are
copied into brew sessions by a migration. The former social data was development-only and has
been removed together with recipe discovery, saves and remixes.

## Stack

| Layer | Technology |
|---|---|
| iOS app | Swift 6, SwiftUI, Observation, iOS 17+, MVVM + Clean Architecture in SPM modules, XcodeGen |
| API | Swift 6, [Vapor 4](https://vapor.codes), SQLKit (explicit SQL), JWT |
| Shared code | `BrewlyShared` Swift package: domain vocabulary, validation rules and API contract |
| Database | PostgreSQL 17 (schema compatible with 16+), SQL-first migrations with [dbmate](https://github.com/amacneil/dbmate) |
| CI | GitHub Actions: database, shared package (Linux), server (Linux + PostgreSQL), iOS (macOS) |

## Repository layout

```
.
├── database/            # PostgreSQL: migrations (dbmate), dev seed, SQL tests
├── shared/BrewlyShared/ # BrewlyCore (vocabulary + rules) and BrewlyAPI (DTOs)
├── server/              # Vapor API (BrewlyServer) + Dockerfile
├── ios/                 # XcodeGen spec, thin app target and the BrewlyKit package
├── docs/                # Architecture, database, API and decision records
├── scripts/             # Helper scripts (iOS tests)
├── docker-compose.yml   # PostgreSQL + migrations (+ optional API container)
└── Makefile             # Common tasks: `make help`
```

## Getting started

Requirements: Docker, Xcode 16 or later (Xcode 26 recommended), [dbmate](https://github.com/amacneil/dbmate),
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and the `psql` client, used by `make db-seed` and
`make db-test`. PostgreSQL itself runs in Docker; only the client is needed on your Mac:

```bash
brew install dbmate xcodegen libpq
# libpq is keg-only, so add psql to your PATH:
echo 'export PATH="$(brew --prefix libpq)/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

```bash
cp .env.example .env   # then set JWT_SECRET and DEMO_PASSWORD

# 1. Database: PostgreSQL + migrations, then demo data
make db-up
make db-seed          # demo users ana@example.com and leo@example.com, password = DEMO_PASSWORD

# 2. API on http://localhost:8080
make server-run
curl http://localhost:8080/health

# 3. iOS app
make ios-project      # generates ios/Brewly.xcodeproj
open ios/Brewly.xcodeproj
```

Run the **Brewly** scheme on an iOS simulator. Debug builds talk to `http://localhost:8080`
(`BREWLY_API_BASE_URL` in `ios/Config/Brewly.xcconfig`). Release builds use
`https://brewly.camilomolano.dev` from [`ios/project.yml`](ios/project.yml). To run on a device,
set your `DEVELOPMENT_TEAM` and override the Debug URL in `ios/Config/Local.xcconfig`.

## Tests

```bash
make db-test          # SQL tests (needs a migrated database)
make shared-test      # shared package, runs on macOS and Linux
TEST_DATABASE_URL=postgres://<user>:<password>@localhost:5432/brewly_test make server-test
make ios-test         # BrewlyKit on the newest iPhone simulator
```

Server integration tests truncate every table, so they only run against `TEST_DATABASE_URL`
(create a separate `brewly_test` database and migrate it with
`DATABASE_URL=… dbmate up`).

## Documentation

- [Architecture](docs/architecture.md): system overview, iOS and server layers, auth flow, roadmap.
- [Database](docs/database.md): entity-relationship diagram and integrity rules.
- [API](docs/api.md): endpoints, errors and pagination.
- [Deployment](docs/deployment.md): Railway configuration, domain, migrations and smoke tests.
- [Decision records](docs/adr): why things are the way they are.
- [Contributing](CONTRIBUTING.md): branches, commits and conventions.

## License

[MIT](LICENSE)
