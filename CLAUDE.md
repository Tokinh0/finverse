# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Finverse

Finverse is a personal finance app built and used by a single person (the repo owner). It is not a
multi-user product: there is no authentication, tenancy or public deployment to design for.

The goal is one place for the owner's whole financial life ("financial universe"):

**Today**
- **Spending:** import Sicredi bank statements (checking account and credit card, PDF/CSV), categorize
  every transaction automatically by keyword, and build monthly reports showing where the money goes.
  The reports are also used to spot unexpected or mistaken charges.
- **Portfolio:** track investment holdings by asset type and see the allocation.

**Planned (not built yet)**
- **Investing strategy:** help decide where to invest so savings grow safely, beyond just tracking holdings.
- **Tax control:** track taxes paid as *pessoa física* (individual) and *pessoa jurídica* (the owner's company).

Data is the owner's real banking data, in BRL and Portuguese. Never commit statements or other personal
financial data, and keep test fixtures synthetic.

Finverse API: a Rails 7.1 API-only app (Ruby 3.2.0, Postgres 14) that imports Brazilian bank statements (Sicredi PDF/CSV), auto-categorizes transactions by keyword, and serves monthly reports and an investment portfolio. Amounts are in BRL, and bank data, seed names and some identifiers are in Portuguese. The React client lives in a separate repo (`../finverse-front`) and calls `http://localhost:3000/api/v1`.

## Commands

Everything runs through Docker Compose (`api` on :3000, `db`, `redis`):
```bash
docker compose up -d
docker compose up -d --build api                  # after changing the Gemfile
docker compose exec api bin/rails db:prepare
docker compose exec api bin/rails db:seed         # categories/subcategories/keywords/assets from db/seed_data
docker compose exec api bin/rails db:rebuild      # custom: drop + create + migrate + seed
docker compose exec api bin/rails c

docker compose exec api bundle exec rspec                                   # full suite
docker compose exec api bundle exec rspec spec/services/categorization_spec.rb:12   # one example
```
`spec/rails_helper.rb` always rewrites `DATABASE_URL` to the `finverse_test` database, and it aborts unless the database name ends in `_test`. Create the test DB once with `docker compose exec -e RAILS_ENV=test api bin/rails db:create db:schema:load`. Compose's `DATABASE_URL` has no database name, so `config/database.yml` chooses one per environment. Don't add a database name to it, because then `RAILS_ENV=test` tasks would hit the development DB.

## Architecture

Controllers in `app/controllers/api/v1/` stay thin. They permit params, call a model or service, and render a presenter from `app/presenters/`. Business logic lives in `app/services/`, and models hold only associations, validations, enums and scopes.

**Statement import** (`POST /monthly_statements` → `MonthlyStatements::Import`):
1. `Import` picks the parser by the file's content type (`PARSERS`: `Parsers::CsvParser` or `Parsers::PdfParser`) and runs it inside a DB transaction. If the parser raises, everything rolls back, the statement is marked `failed`, the error goes into `errors[:file]`, and the controller responds 422.
2. `PdfParser` finds the first entry in `LAYOUT_PARSERS` whose `.matches?(first_page_text)` is true (`SicrediAccountStatementPdf`, `SicrediCreditCardPdf`). Those classes rebuild table rows from positioned text runs through `Parsers::PdfTable`. If nothing matches, it falls back to a legacy line-regex layout. To support a new bank layout, add a class with `.matches?` and `#call` and register it in `LAYOUT_PARSERS`.
3. Every entry goes through `BaseParser#create_transaction` → `Categorization.call(entry)`. `Matchers::DefaultMatcher` scores each `Keyword#parsed_name` (exact 4 > whole word 3 > substring 2 > reverse substring 1), and the best keyword's subcategory wins. With no match, the entry falls back to `Subcategory.other_subcategory` ("Outros"/"Outros", which must exist, and seeding creates it). When the parser gives no transaction type, `Keywords::TypeInference` infers it from the keyword lists in the seed file. Ties, including no match at all, resolve to debit.
4. Each input line produces a `SummaryLine` (`processed`/`failed`/`skipped`). The statement ends up `failed` if any line failed.
5. `Import` rejects duplicates: the same file again (blob checksum), or a file where at least 90% of the transactions (day, name, amount) already exist in other statements. Each parser sets `statement_kind` (`checking_account`/`credit_card`); `bin/rails statements:backfill_kind` fills it for old statements.

**Categorization source:** every transaction records how it got its subcategory in `categorization_source` (`keyword` with `keyword_id`, `ai_accepted`, `manual`, or `uncategorized` = still in the Outros fallback). `Transactions::Recategorize` marks moves `manual` and writes a `CategorizationEvent` (from/to subcategory and source, the overridden keyword, `merchant_key`); keyword re-application marks the moved transactions `keyword`. Keep these fields in sync in any new code that changes a transaction's subcategory.

**Name normalization:** models that include `Normalizer` (Category, Subcategory, Keyword, Transaction) derive `parsed_name` from every `name=` assignment via `StringUtils.default_string_parse` (stripped, upcased, whitespace replaced by `_`). Uniqueness validations, matching and seeding all compare `parsed_name`. `StringUtils` is not mixed in globally, so call `StringUtils.default_string_parse` from service and class-level code.

**Transaction review:** `Transactions::Search` backs `GET /transactions` (filters: `month`, `category_id`, `subcategory_id`, `transaction_type`, `q`; paginated; `meta.months` lists the months that have data). `Transactions::Recategorize` backs `PATCH /transactions/:id`. It changes the subcategory or type, can create a keyword for the new subcategory, and with `apply_to_matching` moves other transactions for which that keyword is now the best match.

**Financial health report:** `Reports::FinancialHealth` (`GET /reports/financial_health?period=1|3|6|12&as_of=YYYY-MM&year=YYYY`) returns everything the one-screen report needs: period summary vs the previous period, categories ranked by spending, 12-month category trends, and a calendar-year summary vs the previous year. Income = credits in `gain` subcategories. Spending = debits minus refunds in `expense` subcategories. Invested = net debits in `investment` subcategories. Transfers count as neither. `Transactions::Merchant.key` is the shared merchant identity, used by this report and by alerts.

**Charge alerts:** `Alerts::Detector` (`GET /alerts?month=YYYY-MM`, which defaults to the latest month) flags debits that are possible duplicates (same merchant, amount and day), uncategorized merchants new in the last 6 months, recurring monthly charges whose amount changed, and amounts at least 3× the median of their *expense* subcategory. Merchants are compared with `merchant_key` (the `parsed_name` without digits). `POST /alerts/dismiss` records an `AlertDismissal`, and `DELETE` brings the alert back. The thresholds are constants at the top of the detector, tuned on real statements to keep the monthly list short enough to review. Re-measure against the dev data if you change them, and don't quote the real counts in PRs or commits, because the repo is public.

**Deletes keep transactions:** deleting a subcategory, or a category through its subcategories, moves the transactions to the Outros fallback (`before_destroy`). The fallback category and subcategory can't be deleted, and the API responds 422.

**Other services:** `Reports::MonthlyByCategory` / `Reports::MonthlyBySubcategory` (the report endpoints), `Portfolio::Dashboard` (assets plus allocation by `asset_type`; it passes per-type totals into `AssetPresenter` to avoid N+1 queries), and `Assets::CryptoPriceUpdater` + `CriptomoedasPriceService` (crypto prices from CoinGecko, with CoinCap as a fallback; not wired to an endpoint yet).

**Asset types:** `Asset::ASSET_TYPES` maps enum keys to the Portuguese labels stored in the DB (`enum asset_type: ASSET_TYPES`). The API sends the keys, and `portfolio_dashboard` also returns the map so the client can show the labels.

**Seed data:** `db/seeds.rb` and `Keywords::TypeInference` read `db/seed_data/$DEFAULT_DATA_FILE_PATHNAME` (JSONC with `//` line comments; the real file is gitignored, so copy `default_data.jsonc.example`). Specs use `spec/fixtures/seed_data/default_data.jsonc` instead.

## Tests

RSpec + FactoryBot (all factories live in `spec/factories/factories.rb`) + shoulda-matchers + WebMock (real HTTP is blocked). Every model, service, presenter and endpoint has a spec under the matching `spec/` folder, and new features need one too. Parser specs never use real bank statements. PDFs are built from `[x, y, text]` runs with `fake_pdf_reader` (`spec/support/fake_pdf.rb`), and Sicredi CSVs come from `sicredi_csv(*rows)` (`spec/support/statement_helpers.rb`). Use those helpers rather than committing statement files.
