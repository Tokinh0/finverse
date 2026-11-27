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

Everything runs through Docker Compose (`api` on :3000, `sidekiq` for background jobs, `db`, `redis`):
```bash
docker compose up -d
docker compose up -d --build api sidekiq          # after changing the Gemfile (both use the same image)
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
3. Every entry goes through `BaseParser#create_transaction` → `Categorization.call(entry)`. `Matchers::DefaultMatcher` scores each `Keyword#parsed_name` (exact 4 > whole word 3 > substring 2 > reverse substring 1), and the best keyword's subcategory wins. A keyword can have an amount range (`min_amount`/`max_amount`, inclusive, absolute BRL): it only applies to transactions inside it (pass `amount:` to `find_best_keyword_match`; without one, ranged rules don't apply), and on equal scores a ranged rule beats a plain one. So one keyword can map to different subcategories by value (AMAZON up to R$ 99,99 → Assinatura, from R$ 100 → Compras). Rule suggestions carry the range too (`Rules::Change`; for an update, `Rules::Change::KEEP` keeps the current bounds), and the fingerprint only includes it for ranged rules so older rejections still match. With no match, the entry falls back to `Subcategory.other_subcategory` ("Outros"/"Outros", which must exist, and seeding creates it). When the parser gives no transaction type, `Keywords::TypeInference` infers it from the keyword lists in the seed file. Ties, including no match at all, resolve to debit.
4. Each input line produces a `SummaryLine` (`processed`/`failed`/`skipped`). The statement ends up `failed` if any line failed.
5. `Import` rejects duplicates: the same file again (blob checksum), or a file where at least 90% of the transactions (day, name, amount) already exist in other statements. Each parser sets `statement_kind` (`checking_account`/`credit_card`); `bin/rails statements:backfill_kind` fills it for old statements.

**Categorization source:** every transaction records how it got its subcategory in `categorization_source` (`keyword` with `keyword_id`, `ai_accepted`, `manual`, or `uncategorized` = still in the Outros fallback). `Transactions::Recategorize` marks moves `manual` and writes a `CategorizationEvent` (from/to subcategory and source, the overridden keyword, `merchant_key`, and the owner's optional `reason` as `note`, which is sent to Claude as context and quoted in history suggestions); keyword re-application marks the moved transactions `keyword`. Keep these fields in sync in any new code that changes a transaction's subcategory.

**Settings and the Claude API key:** `AppSetting.current` is the single settings row. `claude_api_key` is encrypted with Active Record Encryption (keys under `active_record_encryption` in `config/credentials.yml.enc`; `config/environments/test.rb` sets fixed test keys so specs and CI need no credentials). The key never leaves the API: `ClaudeSettingPresenter` sends only `masked_key`. `GET/PUT/DELETE /settings/claude` manage it, and `PUT` checks a new key with one `models.list` call (a rejected key isn't saved; an unreachable API saves it with a `warning`). The model is `claude_model`, else `ENV["CLAUDE_MODEL"]`, else `AppSetting::DEFAULT_CLAUDE_MODEL` (`claude-haiku-5-5`, chosen to keep token spend low). `Ai::Client` wraps the `anthropic` gem and maps SDK errors to `Ai::Client::Error#code` (`invalid_key`, `billing`, `rate_limited`, `timeout`, `unavailable`, `bad_request`, `api_error`) with messages safe to show in the UI. Jobs run on Sidekiq (`config.active_job.queue_adapter`; `:test` in specs).

**Categorization suggestions** (suggest, never decide): after a successful import, `Suggestions::Enqueue` creates a `SuggestionRun` and `GenerateSuggestionsJob` runs `Suggestions::Generate` on Sidekiq. Keyword rules already ran at import, so it only looks at `uncategorized` transactions without a pending suggestion, grouped by merchant key (`Suggestions::Candidates`; one decision per merchant, applied to each of its transactions). Order: (1) `Suggestions::HistoryMatcher` suggests what the owner already chose for that merchant (manual or accepted), no API call; (2) the rest go to Claude only if a key is saved, in one request per `MAX_GROUPS_PER_REQUEST` merchants (one per import in practice). `Ai::PayloadBuilder` sends only subcategories (never the Outros fallback), keyword rules, a few similar past examples and per merchant the name scrubbed by `Suggestions::Privacy` (long numbers such as CPFs become `#`), count, average amount, type and statement kind. `Ai::Suggester` asks, in the same single request, for category and keyword-rule suggestions as structured JSON (`output_config.format`, effort `low`), and `Ai::ResponseValidator` drops bad items one by one. Results are `CategorySuggestion`s (`origin` history/ai, `confidence`, `reason`, `status` pending/accepted/rejected/superseded). `Suggestions::Decide` accepts (source `ai_accepted`), accepts with another subcategory (source `manual`, and the suggestion counts as rejected) or rejects; rejected subcategories are never suggested again for that merchant (`Suggestions::Rejections`). Retryable Claude errors (`Ai::Client::RetryableError`) are retried by the job, other errors mark the run `failed` with a message for the UI. Endpoints: `GET /suggestions/summary`, `GET/POST /suggestion_runs`, `GET /category_suggestions`, `POST /category_suggestions/:id/accept|reject`, `POST /category_suggestions/bulk_accept` (`min_confidence` and/or `merchant_key`).

**"No idea":** `Transactions::MarkUnknown` (`POST`/`DELETE /transactions/:id/unknown`, or `POST /category_suggestions/:id/dont_know`) sets `transactions.unknown_marked_at` on an uncategorized transaction the owner can't remember. It has no categorization effect: the transaction stays in Outros and `uncategorized`, its pending suggestion becomes `dismissed` (not `rejected`, so nothing is remembered against the merchant), and nothing about it goes to Claude. Marked transactions are skipped by `Suggestions::Candidates`/`Enqueue` and never moved by `Rules::Apply` (previews show them as kept). Re-categorizing by hand clears the mark. `GET /transactions?unknown=true` lists them.

**Rule suggestions:** a `RuleSuggestion` proposes a `Rules::Change` (`create` a keyword, `update` one's text and/or subcategory, `delete` one). They come from Claude (same request as the category suggestions; the payload adds `rule_issues` for overridden/overlapping rules, repeated `corrections`, the owner's `notes` and `rejected_rules`) and from `Rules::LocalSuggester`, which needs no key: 3+ owner corrections of a merchant to the same subcategory with no covering rule → create; a rule flagged overridden whose overrides mostly go to one subcategory → update. Every suggestion goes through `Rules::SuggestionWriter` (no duplicates by `fingerprint`, no rule that matches nothing or more than 25% of transactions, no rejected change unless it now matches ≥50% and ≥5 more transactions; see `Rules::Rejections`). `Rules::Preview` dry-runs a change through `DefaultMatcher` (nothing saved). `Rules::Apply` performs it and re-matches: `reapply` is `none` (only the changed rule's own transactions), `uncategorized` or `all` (also transactions other rules matched). Owner decisions (`manual`, `ai_accepted`) are never moved by rules. `Rules::Health` reports per rule matches, overrides and flags (`overridden`, `unused`, `overlapping` = ties with a rule for another subcategory). Endpoints: `GET /rule_suggestions` (with live preview), `POST /rule_suggestions/:id/accept` (`name`, `subcategory_id`, `reapply`) and `/reject`, `GET /keywords/health`, `GET /reports/categorization_progress?months=6`. `PATCH /transactions/:id` returns a `rule_nudge` when a manual fix makes a merchant reach the correction threshold.

**Language (i18n):** the app speaks English or Brazilian Portuguese. The owner picks it in Settings; it's stored in `AppSetting#locale` (`GET/PUT /settings/preferences`). `ApplicationController` wraps every request in `I18n.with_locale(AppSetting.current.locale)` and `Suggestions::Generate` does the same for the background job, so API messages, alert texts (`Alerts::Detector`, dates via `I18n.l`), validation errors, `Ai::Client::Error` messages (looked up by key under `ai.errors`) and history/rule reasons come out in that language, and Claude is asked to write its `reason`s in it. Strings live in `config/locales/en.yml` and `pt-BR.yml` (with Portuguese Rails validation messages, since `rails-i18n` isn't installed); `spec/i18n_spec.rb` checks both files have the same keys and placeholders. Never translate the owner's data (transaction, category and keyword names, notes). Reasons are stored when generated, so they stay in the language of that run.

**Name normalization:** models that include `Normalizer` (Category, Subcategory, Keyword, Transaction) derive `parsed_name` from every `name=` assignment via `StringUtils.default_string_parse` (stripped, upcased, whitespace replaced by `_`). Uniqueness validations, matching and seeding all compare `parsed_name`. `StringUtils` is not mixed in globally, so call `StringUtils.default_string_parse` from service and class-level code.

**Transaction review:** `Transactions::Search` backs `GET /transactions` (filters: `month`, `category_id`, `subcategory_id`, `transaction_type`, `q`; paginated; `meta.months` lists the months that have data). `Transactions::Recategorize` backs `PATCH /transactions/:id`. It changes the subcategory or type, can create a keyword for the new subcategory, and with `apply_to_matching` moves other transactions for which that keyword is now the best match.

**Financial health report:** `Reports::FinancialHealth` (`GET /reports/financial_health?period=1|3|6|12&as_of=YYYY-MM&year=YYYY`) returns everything the one-screen report needs: period summary vs the previous period, categories ranked by spending, 12-month category trends, and a calendar-year summary vs the previous year. Income = credits in `gain` subcategories. Spending = debits minus refunds in `expense` subcategories. Invested = net debits in `investment` subcategories. Transfers count as neither. `Transactions::Merchant.key` is the shared merchant identity, used by this report and by alerts.

**Charge alerts:** `Alerts::Detector` (`GET /alerts?month=YYYY-MM`, which defaults to the latest month) flags debits that are possible duplicates (same merchant, amount and day), uncategorized merchants new in the last 6 months, recurring monthly charges whose amount changed, and amounts at least 3× the median of their *expense* subcategory. Merchants are compared with `merchant_key` (the `parsed_name` without digits). `POST /alerts/dismiss` records an `AlertDismissal`, and `DELETE` brings the alert back. The thresholds are constants at the top of the detector, tuned on real statements to keep the monthly list short enough to review. Re-measure against the dev data if you change them, and don't quote the real counts in PRs or commits, because the repo is public.

**Deletes keep transactions:** deleting a subcategory, or a category through its subcategories, moves the transactions to the Outros fallback (`before_destroy`). The fallback category and subcategory can't be deleted, and the API responds 422.

**Other services:** `Reports::MonthlyByCategory` / `Reports::MonthlyBySubcategory` (the report endpoints), `Portfolio::Dashboard` (assets plus allocation by `asset_type`; it passes per-type totals into `AssetPresenter` to avoid N+1 queries), and `Assets::CryptoPriceUpdater` + `CriptomoedasPriceService` (crypto prices from CoinGecko, with CoinCap as a fallback; not wired to an endpoint yet).

**Asset types:** `Asset::ASSET_TYPES` maps enum keys to the Portuguese labels stored in the DB (`enum asset_type: ASSET_TYPES`). The API sends the keys, and `portfolio_dashboard` also returns the map so the client can show the labels.

**Seed data:** `db/seeds.rb` and `Keywords::TypeInference` read `db/seed_data/$DEFAULT_DATA_FILE_PATHNAME` (JSONC with `//` line comments; the real file is gitignored, so copy `default_data.jsonc.example`). Specs use `spec/fixtures/seed_data/default_data.jsonc` instead.

## Tests

RSpec + FactoryBot (all factories live in `spec/factories/factories.rb`) + shoulda-matchers + WebMock (real HTTP is blocked). Stub the Claude API with the helpers in `spec/support/claude_api_helpers.rb`; specs never call it for real. Every model, service, presenter and endpoint has a spec under the matching `spec/` folder, and new features need one too. Parser specs never use real bank statements. PDFs are built from `[x, y, text]` runs with `fake_pdf_reader` (`spec/support/fake_pdf.rb`), and Sicredi CSVs come from `sicredi_csv(*rows)` (`spec/support/statement_helpers.rb`). Use those helpers rather than committing statement files.
