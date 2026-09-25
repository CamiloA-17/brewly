# Brewly

Brewly is a native iOS social network for coffee lovers and baristas. People keep a shelf of
**their own coffee beans** (farm, altitude, varietal, process, roast…), mark the **brew methods**
they use from a catalog shared by everyone, and write **recipes** with every parameter a barista
needs to reproduce a cup: bean, method, dose, ratio, grind, temperature, times, water, steps and
results (TDS and extraction yield). Recipes, beans and posts are shared with the community.

> Status: initial architecture and working skeleton. Auth, catalogs, beans and recipes work end
> to end; the social layer (feed, posts, likes, comments, follows) is modeled in the database and
> comes next. See [the roadmap](docs/architecture.md#roadmap).

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

Requirements: Docker, Xcode 16 or later (Xcode 26 recommended), [dbmate](https://github.com/amacneil/dbmate)
and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install dbmate xcodegen`).

```bash
cp .env.example .env

# 1. Database: PostgreSQL + migrations, then demo data
make db-up
make db-seed          # demo users: ana@brewly.dev / leo@brewly.dev, password "brewly-demo"

# 2. API on http://localhost:8080
make server-run
curl http://localhost:8080/health

# 3. iOS app
make ios-project      # generates ios/Brewly.xcodeproj
open ios/Brewly.xcodeproj
```

Run the **Brewly** scheme on an iOS simulator. Debug builds talk to `http://localhost:8080`
(`BREWLY_API_BASE_URL` in [`ios/project.yml`](ios/project.yml)). To run on a device, set your
`DEVELOPMENT_TEAM` and point the base URL to your Mac's LAN address.

## Tests

```bash
make db-test          # SQL tests (needs a migrated database)
make shared-test      # shared package, runs on macOS and Linux
TEST_DATABASE_URL=postgres://brewly:brewly@localhost:5432/brewly_test make server-test
make ios-test         # BrewlyKit on the newest iPhone simulator
```

Server integration tests truncate every table, so they only run against `TEST_DATABASE_URL`
(create a separate `brewly_test` database and migrate it with
`DATABASE_URL=… dbmate up`).

## Documentation

- [Architecture](docs/architecture.md): system overview, iOS and server layers, auth flow, roadmap.
- [Database](docs/database.md): entity-relationship diagram and integrity rules.
- [API](docs/api.md): endpoints, errors and pagination.
- [Decision records](docs/adr): why things are the way they are.
- [Contributing](CONTRIBUTING.md): branches, commits and conventions.

## License

[MIT](LICENSE)
