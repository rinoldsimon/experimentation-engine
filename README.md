# Experimentation Engine Core

A lightweight, low-latency, deterministic A/B testing and experimentation platform designed for the critical page-rendering path.

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

* **Frontend Dashboard:** http://localhost:4000
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

**Local Development:** `docker compose up` runs this automatically on the *first* boot only. The backend's `docker-entrypoint` calls `bin/rails db:prepare`, and Rails' `db:prepare` task only loads `db/seeds.rb` when it also had to create the database from scratch — on every subsequent boot the database already exists, so `db:prepare` just runs pending migrations and leaves your data alone. To reseed intentionally, run `docker compose exec backend bin/rails db:seed` (or `bin/rails db:seed` natively).

> ⚠️ **Production Deployment (Render): never automate `db:seed`.** Run it manually, exactly once, via the Render Shell (`bin/rails db:seed`) — for example right after the very first deploy, or deliberately when you want to reset demo data. **Do not** add `db:seed` to Render's build command or any deploy hook: since it calls `Experiment.destroy_all`, running it on every deploy would silently delete every real experiment (and its historical events) each time you ship a change.

---

## 🔒 Security & Architecture Notes

* **CORS & APIs:** The Rails backend acts strictly as a headless API. The root path (`/`) serves a JSON health check.
* **Secrets:** Environment-specific database credentials are isolated in `backend/.env` (ignored by git).
* **Environment Parity:** `.env.example` files (in both `backend/` and `frontend/`) provide template configurations for all required environment variables without exposing sensitive values.
* **Frontend API URL:** The SPA reads its backend base URL from `VITE_API_URL` (see `frontend/src/services/api.ts`), which throws a clear startup error if it's unset rather than silently falling back to a default. Local development and Docker Compose provide it via `.env`/`compose.yaml`; in production (e.g. Render), it's set via the platform's dashboard env vars rather than a committed `.env` file.

---

## 📄 Design Document
For a comprehensive breakdown of the upcoming deterministic hashing, scale characteristics, fail-open mechanisms, and LLM placement trade-offs, see the `DESIGN.md` *(coming soon)*.
