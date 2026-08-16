# Experimentation Engine Core

![CI](../../actions/workflows/ci.yml/badge.svg)

A lightweight, low-latency, deterministic A/B testing and experimentation platform designed for the critical page-rendering path.

🌐 **Live deployment:** [Dashboard & Demo pages](https://experimentation-engine-1.onrender.com/) · [API](https://experimentation-engine.onrender.com/) — hosted on Render's free tier, so the first request after a period of inactivity may take ~30-60s to wake up.

📄 **Read [`DESIGN.md`](./DESIGN.md) first** — it covers the architecture, determinism, scale, reliability/failure-mode, correctness, and LLM-placement reasoning behind everything below, plus an honest account of what was deliberately left unbuilt.

---

## 🏗 System Architecture & Overview

This repository is structured as a unified monorepo containing:

* **Backend (`/backend`):** Ruby on Rails (v7.2+) API-only service configured for PostgreSQL. Configured with strict CORS policies and JSON health checks.
* **Frontend (`/frontend`):** React Single-Page Application (SPA) built with Vite, TypeScript, and Tailwind CSS for experiment configuration and metrics.
* **Orchestration:** Multi-environment Docker Compose configurations alongside a root-level `./bin/dev` script for native local development.

---

## 📋 Prerequisites

If running natively without Docker, ensure you have the following installed:

* **Ruby:** `3.3.5` (managed via `.ruby-version`)
* **Node.js:** `24.18.0` (managed via `.node-version`)
* **PostgreSQL:** `16+`

*(Note: Foreman is managed via the backend Gemfile, no global installation required).*

---

## 🚀 Getting Started

### Option A: Docker Compose (Recommended)

To spin up the entire system (Postgres database, Rails API, and Vite SPA) in isolated containers:

```bash
# 1. Build and start all services
docker compose up --build

# 2. In a separate terminal, run initial database setup
docker compose exec backend bin/rails db:create db:migrate
```

* **Frontend Dashboard:** http://localhost:4000 — polls `GET /api/v1/experiments` every 5 seconds, so exposures/conversions tracked from a demo page (even in another tab) show up without a manual reload.
* **Backend API Health Check:** http://localhost:3000

---

### Option B: Local Native Development

If you prefer running the stack natively on your machine:

#### 1. Configure Environment Variables
```bash
# Backend: navigate to backend and copy the template
cd backend
cp .env.example .env
cd ..

# Frontend: navigate to frontend and copy the template
cd frontend
cp .env.example .env
cd ..
```
*Update `backend/.env` with your local PostgreSQL credentials. The frontend
requires `VITE_API_URL` to be set — the template points it at
`http://localhost:3000`, and you only need to change it if your API isn't
running on the default host/port.*

#### 2. Install Dependencies & Setup Database
```bash
# Install backend gems and prepare DB
cd backend
bundle install
bin/rails db:create db:migrate db:seed
cd ..

# Install frontend dependencies
cd frontend
npm install
cd ..
```

#### 3. Boot the System
From the project root directory, run the executable dev script. This will boot both the Rails server and Vite frontend concurrently.
```bash
./bin/dev
```

---

## 🌱 Database Seeding

`backend/db/seeds.rb` resets local experiment data to two realistic demo experiments: `pricing_plan_default` (two variants, split 50/50) and `checkout_upsell_placement` (three variants — `header_banner`, `cart_inline`, `sticky_footer` — split 34/33/33, to demonstrate that variant weights don't need to be an even split as long as they sum to 100). It is **destructive**: it starts with `Experiment.destroy_all`, wiping every experiment, variant, and event. It intentionally creates zero `Event` records so exposures/conversions read as 0 on the Dashboard until you generate real traffic through the Demo pages (`/demo/pricing`, `/demo/checkout`) — that's how you manually confirm tracking is actually wired up end to end, rather than seeing pre-populated numbers.

The seed script creates experiments through `ExperimentCreationService` — the same Configuration API path exercised by `POST /api/v1/experiments` — rather than raw ActiveRecord calls, so it doubles as a smoke test for that service. Every seeded variant's `content` is plain hardcoded copy (`content_source: "manual"`, no LLM call) — seed data intentionally doesn't look AI-generated, so the Dashboard's 🤖 badge stays a reliable signal that a variant's copy was actually written by Gemini rather than always showing on a fresh install. Use "✨ Generate AI copy" on the Dashboard against any seeded variant to see the LLM feature live instead.

**Local Development:** `docker compose up` runs this automatically on the *first* boot only. The backend's `docker-entrypoint` calls `bin/rails db:prepare`, and Rails' `db:prepare` task only loads `db/seeds.rb` when it also had to create the database from scratch — on every subsequent boot the database already exists, so `db:prepare` just runs pending migrations and leaves your data alone. To reseed intentionally, run `docker compose exec backend bin/rails db:seed` (or `bin/rails db:seed` natively).

> ⚠️ **Production Deployment (Render): never automate `db:seed`.** Run it manually, exactly once, via the Render Shell (`bin/rails db:seed`) — for example right after the very first deploy, or deliberately when you want to reset demo data. **Do not** add `db:seed` to Render's build command or any deploy hook: since it calls `Experiment.destroy_all`, running it on every deploy would silently delete every real experiment (and its historical events) each time you ship a change.

---

## 🔌 API Overview

All endpoints are namespaced under `/api/v1` and return JSON. No authentication is required (there's no multi-tenant/user concept in this project — see `DESIGN.md`'s "Trade-offs" for why that's out of scope).

| Method & Path | Purpose |
|---|---|
| `GET /api/v1/assignments?experiment_name=&visitor_id=` | The critical-path endpoint: returns the variant this visitor is deterministically assigned to, and logs an exposure (unless the experiment is paused). |
| `POST /api/v1/events` | Records an `exposure` or `conversion` event. Idempotent — a duplicate `(experiment, visitor, event_type)` returns `200` with the existing row rather than erroring or double-counting. |
| `GET /api/v1/experiments` | Results: every experiment with its variants, each variant's exposures/conversions/conversion rate, and experiment-level totals. This is what the Dashboard renders. |
| `POST /api/v1/experiments` | Configuration: define a new experiment, its variants, and their traffic allocation (weights must sum to 100) in one call. A variant may request LLM-generated content via `content_source: "llm"` — see `DESIGN.md`'s "The LLM decision". |
| `PATCH /api/v1/experiments/:id/toggle_status` | The kill switch: flips an experiment between `running` and `paused`. |
| `DELETE /api/v1/experiments/:id` | Deletes an experiment along with its variants and tracked events. Restricted to experiments with `source: "ai_draft"` (`422` otherwise) — the seeded showcase experiments can't be deleted through this endpoint. Used by the Dashboard's "Delete" button, which only appears on 🤖 AI-drafted experiments. |
| `PATCH /api/v1/variants/:id/generate_content` | On-demand LLM copy generation for an existing variant, given a `content_prompt`. This is what the Dashboard's "✨ Generate AI copy" button calls — see below. |
| `POST /api/v1/experiment_drafts` | Drafts a full experiment (name + variants + weights + copy) from a plain-English `topic`, via Gemini's structured JSON output. **Never persists anything** — see below. |

Try it against the live deployment with `curl`, e.g.:

```bash
API_URL="https://experimentation-engine.onrender.com"

curl "$API_URL/api/v1/assignments?experiment_name=pricing_plan_default&visitor_id=demo-visitor-1"
curl "$API_URL/api/v1/experiments"

# Exercise the LLM-content feature (no API key needed on your end -- it's
# configured server-side only, see "Security" below):
curl -X POST "$API_URL/api/v1/experiments" -H "Content-Type: application/json" -d '{
  "experiment": {
    "name": "llm_demo_'"$(date +%s)"'",
    "variants": [
      { "name": "control", "weight": 50 },
      {
        "name": "ai_headline",
        "weight": 50,
        "content_source": "llm",
        "content_prompt": "Write one short e-commerce banner headline (under 8 words) announcing a 20% off sale.",
        "fallback_content": "20% off, today only!"
      }
    ]
  }
}'
```

The response's `variants[1].content` is the live Gemini-generated headline, and `content_source` will be `"llm"` on success or `"llm_fallback"` if generation failed for any reason — either way the request still succeeds.

**Easiest way to see the LLM working, with zero `curl`:** open the [live Dashboard](https://experimentation-engine-1.onrender.com/) and try either of these:

* **"✨ Generate AI copy"** under any existing variant — type any prompt (e.g. "a headline for a 20% off sale") and hit Generate. Updates that one variant's copy live, straight from Gemini.
* **"✨ Draft a new experiment with AI"** at the top of the page — describe what you want to test in plain English (e.g. "increase newsletter signups on the blog homepage"), pick a variant count, and Gemini drafts a whole experiment: a name, that many variants, weights that sum to 100, and copy for each. You get an editable preview — tweak anything — then a separate "Create Experiment" click sends it through the exact same validated path as `POST /api/v1/experiments` above. The LLM only ever *drafts*; nothing goes live until you explicitly click Create.

The React frontend ([Dashboard](https://experimentation-engine-1.onrender.com/), plus `/demo/pricing` and `/demo/checkout` for the visitor-facing demo pages) doubles as a live demo of the whole flow — assignment, tracking, results, and now on-demand LLM content — without needing `curl` at all. Every experiment on the Dashboard also has a "Try it →" link: the two seeded experiments open their bespoke demo page, and anything else (e.g. an experiment drafted with AI) opens `/demo/:experimentName`, a generic page that shows whichever variant this visitor was assigned and its content, so a freshly-drafted experiment is testable end-to-end immediately, with no bespoke page required.

---

## 🧪 Testing & CI

Every push runs both suites via [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) (backend RSpec + RuboCop, frontend Vitest + type-check + lint + build). To run them locally:

```bash
# Backend: request specs + service specs (assignment logic, kill switch, idempotency,
# the Configuration API, the LLM content generator), plus RuboCop
cd backend
bundle exec rspec
bundle exec rubocop

# Frontend: the useExperiment hook's fetch/localStorage behavior (including the
# fail-open "degraded" case) and the AI drafting flow, plus type-checking, lint, and a production build
cd frontend
npm test
npx tsc -b
npm run lint
npm run build
```

---

## 🔒 Security & Architecture Notes

* **CORS & APIs:** The Rails backend acts strictly as a headless API. The root path (`/`) serves a JSON health check.
* **Secrets:** Environment-specific database credentials are isolated in `backend/.env` (ignored by git).
* **Environment Parity:** `.env.example` files (in both `backend/` and `frontend/`) provide template configurations for all required environment variables without exposing sensitive values.
* **Frontend API URL:** The SPA reads its backend base URL from `VITE_API_URL` (see `frontend/src/services/api.ts`), which throws a clear startup error if it's unset rather than silently falling back to a default. Local development and Docker Compose provide it via `.env`/`compose.yaml`; in production (e.g. Render), it's set via the platform's dashboard env vars rather than a committed `.env` file.
* **LLM key (`GEMINI_API_KEY`):** Optional, backend-only, and **never committed to this repo or exposed by any API response.** It's set directly as an environment variable — in `backend/.env` locally (gitignored), and in the hosting platform's dashboard (e.g. Render's *Environment* tab) for the live deployment. Testers don't need this key at all: `VariantContentGenerator` is the only thing that reads it, and it's only called from the backend at experiment-*configuration* time (see `DESIGN.md`'s "The LLM decision") — exercise the feature via the API Overview's `curl` example above and the live service handles the LLM call itself. If the key is ever unset or invalid, requests still succeed; the variant just falls back to its supplied default text (`content_source: "llm_fallback"`). Get a free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) if you want to set your own.

---

## 📄 Design Document
For a comprehensive breakdown of the deterministic hashing, scale characteristics, fail-open mechanisms, statistical correctness caveats, and LLM placement trade-offs, see [`DESIGN.md`](./DESIGN.md).
