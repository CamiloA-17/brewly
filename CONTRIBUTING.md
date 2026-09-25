# Contributing to Brewly

## Language

Everything in the repository is written in **English**: code, comments, SQL, documentation,
branch names and commit messages. User-facing text lives in String Catalogs (`*.xcstrings`)
with English as the source language and Spanish translations.

## Branches

`main` always builds and passes CI. Work happens in short-lived branches created from `main`
and merged back through a pull request:

| Prefix | Use | Example |
|---|---|---|
| `feature/` | New features | `feature/recipe-timer` |
| `bugfix/` | Bug fixes | `bugfix/ratio-rounding` |
| `release/` | Preparing a release | `release/0.2.0` |
| `hotfix/` | Urgent fixes in production | `hotfix/login-crash` |

Use lowercase words separated by hyphens after the prefix.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <summary in the imperative mood>
```

- **Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`.
- **Scopes:** `database`, `shared`, `server`, `ios`, `docs`, or a feature name.
- Keep the summary under ~72 characters and explain the *why* in the body when it is not obvious.

Example: `feat(ios): prefill recipe parameters from the brew method`

## Pull requests

- Keep them focused; one feature or fix per pull request.
- CI must be green: database, shared package, server and iOS jobs.
- Add or update tests with the change, and the docs when behavior changes.

## Conventions

### Database

- Never edit a migration that has been merged; add a new one (`dbmate new <name>`).
- Every migration has a working `-- migrate:down` section; CI rolls everything back and up again.
- Tables are plural `snake_case`; constraints are named `<table>_<meaning>`.
- Enumerations live in DOMAINs or CHECK constraints and are mirrored by the enums in
  `shared/BrewlyShared/Sources/BrewlyCore/Models/Enumerations.swift`. Change both together.
- Add SQL tests in `database/tests` for new constraints.

### Swift

- Swift 6 language mode with strict concurrency.
- Business rules shared by app and server go in `BrewlyCore`; API shapes go in `BrewlyAPI`.
- iOS features depend only on `BrewlyDomain` and `BrewlyDesignSystem`, never on the data layer.
- Server features follow controller → service → repository; SQL stays in repositories.

## Running the checks locally

The database checks need Docker and the `psql` client (`brew install libpq`, then add
`$(brew --prefix libpq)/bin` to your `PATH`). They pass on an empty or a seeded database.

```bash
make db-up && make db-test
make shared-test
TEST_DATABASE_URL=postgres://brewly:brewly@localhost:5432/brewly_test make server-test
make ios-project && make ios-test
```
