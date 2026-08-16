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

* **Frontend Dashboard:** http://localhost:5173
* **Backend API Health Check:** http://localhost:3000

---

### Option B: Local Native Development

If you prefer running the stack natively on your machine:

#### 1. Configure Environment Variables
```bash
# Navigate to backend and copy the template
cd backend
cp .env.example .env
```
*Update `.env` with your local PostgreSQL credentials.*

#### 2. Install Dependencies & Setup Database
```bash
# Install backend gems and prepare DB
cd backend
bundle install
bin/rails db:create db:migrate
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

## 🔒 Security & Architecture Notes

* **CORS & APIs:** The Rails backend acts strictly as a headless API. The root path (`/`) serves a JSON health check.
* **Secrets:** Environment-specific database credentials are isolated in `backend/.env` (ignored by git).
* **Environment Parity:** `.env.example` provides template configurations for all required environment variables without exposing sensitive values.

---

## 📄 Design Document
For a comprehensive breakdown of the upcoming deterministic hashing, scale characteristics, fail-open mechanisms, and LLM placement trade-offs, see the `DESIGN.md` *(coming soon)*.
