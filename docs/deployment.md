# Deployment

Brewly's production API runs on Railway with PostgreSQL in the same region. The iOS Release
configuration calls `https://brewly.camilomolano.dev`. Production starts with an empty user
database: dbmate migrations create the schema and six global catalogs. Never run
`database/seeds/dev_seed.sql` against production.

## Before the first deploy

1. Push the tested `feature/guided-brew-coach` branch and check all four GitHub Actions jobs.
   Connect the Railway API service to that branch for the first release; switch its GitHub source
   to `main` after the changes are integrated. Do not use a restrictive root directory: the
   Docker build needs `server/`, `shared/` and `database/` from the repository root.
2. In one Railway project and environment, create a PostgreSQL service and an API service in
   the same region. Set the API builder to Dockerfile and its path to `server/Dockerfile`.
3. Give the API service `DATABASE_URL` as a reference to the PostgreSQL service's private
   `DATABASE_URL` (for example `${{Postgres.DATABASE_URL}}`, if the service is named `Postgres`).
   Set `JWT_SECRET` to a new random value of at least 32 characters, `LOG_LEVEL=info`, and
   `PORT=8080` if Railway did not inject it. Keep secrets in Railway only.
4. Set the API pre-deploy command to `dbmate --wait migrate`, with a 300-second timeout. The
   image contains dbmate and `/app/database/migrations`; the command must finish successfully
   before the API starts. Set the healthcheck path to `/health` with a 300-second timeout.
   Do not enable serverless sleep for the API.
5. Enable daily PostgreSQL backups. Set a workspace compute usage email alert at US$5 and a
   hard limit at US$10. Hitting the hard limit stops workloads, including the API and database.

The existing `server/Dockerfile` is also used by the local Compose stack. Vapor reads `PORT`
at startup and otherwise listens on 8080. A failed migration stops the new deployment; inspect
the pre-deploy logs and fix the migration rather than running the development seed.

Railway's current configuration path for a new service is its dashboard or Infrastructure as
Code. New services cannot opt into the older `railway.toml` config-as-code format.

## Domain and iOS

Add `brewly.camilomolano.dev` as a custom HTTP domain on the API service. Add both the CNAME
and ownership TXT records exactly as Railway reports them at the DNS provider. Wait for domain
verification and an issued HTTPS certificate. `ios/project.yml` sets the Release base URL to
that domain. Debug builds use localhost unless `ios/Config/Local.xcconfig` overrides it for a
physical iPhone; the local override is ignored by Git.

## Smoke test and recovery

1. `GET https://brewly.camilomolano.dev/health` returns 200 with `database: "ok"`.
2. Confirm `/v1/catalog` requires a bearer token, then register a temporary account and check
   the six catalogs. Create one bean, a recipe, and a brew session; verify that another account
   cannot read them.
3. Restart the API and confirm the data survives. Check that retired social routes return 404.
   Verify an iPhone can reach the API while the developer's Mac is off. Delete the temporary
   accounts after these checks.
4. Review deploy logs, database backup status, and the Railway usage dashboard after release.
   Test restoration to a separate database before relying on backups for real user data.

To return to an earlier API release, redeploy a known-good image or commit. Database migrations
are managed separately and may be destructive; take a backup before any future migration that
drops or rewrites production data. The initial `remove_social_data` migration only drops
development-era tables in a fresh production database.
