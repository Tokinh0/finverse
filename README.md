# Finverse API

Rails 7.1 API that imports Sicredi bank statements (PDF/CSV), categorizes transactions by keyword and serves monthly reports and an investment portfolio to [finverse-front](https://github.com/Tokinh0/finverse-front).

## Setup

```bash
cp .env.example .env
cp db/seed_data/default_data.jsonc.example db/seed_data/default_data.jsonc   # fill in your own categories/keywords
docker compose up -d
docker compose exec api bin/rails db:prepare db:seed
```

The API listens on http://localhost:3000/api/v1.

## Tests

```bash
docker compose exec -e RAILS_ENV=test api bin/rails db:create db:schema:load   # once
docker compose exec api bundle exec rspec
```

See `CLAUDE.md` for an overview of the architecture.
