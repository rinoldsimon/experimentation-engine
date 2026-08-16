# Design Document

Short by design — this covers every point asked for, straight to the point. Setup/run
instructions are in `README.md`.

## At a glance

| Capability | Status |
|---|---|
| Deterministic, sticky, weighted assignment | Built |
| Exposure/conversion tracking, idempotent | Built |
| Per-variant results (exposures/conversions/rate) | Built |
| Kill switch (pause an experiment mid-flight) | Built |
| Configuration API (create experiments/variants) | Built |
| LLM-generated variant content | Built, config-time only |
| Caching + fail-open on DB outage during assignment | Built |
| Statistical rigor (SRM, confidence intervals) | Not built — see Trade-offs |
| Admin UI, SSR, adaptive allocation, real auth | Not built — see Trade-offs |

24 hours isn't enough to build everything, so the list above is deliberate: a small,
correct core, with the rest reasoned about here instead of half-built.

---

## Architecture

```
visitor's browser ──► GET /api/v1/assignments ──► cached experiment lookup ──► hash ──► variant
                                                          │
                                                          ▼ (best-effort, never blocks the response)
                                                    exposure event

admin ──► POST /api/v1/experiments  (may call the LLM once, synchronously)
      ──► GET  /api/v1/experiments  (results: per-variant exposures/conversions/rate)
      ──► PATCH .../toggle_status   (kill switch)
```

Rails API + Postgres + a React SPA that's both the "customer site" demo and the results
dashboard. No queue, no Redis — deliberately (see Scale).

**Core decision:** the read path (assignment) and the write/config path (tracking,
experiment setup) have different latency budgets even though they share one database.
Assignment is fast and side-effect-free (computed from a hash, no write required to answer
it). Tracking and configuration can afford a normal DB round-trip, or even an LLM call.

**Data model:** `Experiment` (name, running/paused) → `Variant` (name, weight, optional
`content`) → `Event` (exposure/conversion, unique per `[experiment, visitor, event_type]`).
UUID primary keys throughout.

**Configuration API:** `POST /api/v1/experiments` creates an experiment and all its
variants atomically. Weights must sum to 100 (`422` otherwise, not `500`). A variant can
request `content_source: "llm"` + a prompt to get LLM-generated copy — see below.

---

## Determinism

```ruby
bucket = Digest::MD5.hexdigest("#{experiment.id}-#{visitor_id}").to_i(16) % 100
```

- **No `rand()`, no stored assignment table.** The variant is a pure function of
  `(experiment_id, visitor_id)`. Nothing is written before a visitor gets an answer, and the
  same inputs always hash to the same bucket — sticky across requests and restarts for free,
  with nothing to cache-invalidate or replicate.
- **Why this respects traffic allocation:** hashing spreads output close to uniformly, so
  walking a cumulative-weight table over a large population converges to the configured
  split (50/50, 34/33/33, etc.) even though each individual visitor's result is fixed.
- **Why MD5 specifically:** not for security — just cheap and well-distributed. A one-line
  swap to SHA-256 wouldn't change any of the above.
- **Known limit:** changing a variant's weight mid-experiment reshuffles buckets for
  *existing* visitors too, not just new ones. Don't change live weights; freezing them once
  an experiment starts is the simple, current answer to this.

---

## Scale

- Today: one indexed lookup + in-memory hashing per assignment call — already O(1), no
  N+1, no scan.
- At millions of calls, the bottleneck is the DB round-trip on every request, not the hash
  math. Fixed by caching the experiment→variants config (`ExperimentLookup`, 30s freshness
  window) — most requests never touch Postgres.
- Reads (assignment) vastly outnumber writes (tracking), which in turn outnumber config
  changes. That skew is exactly what caching targets: cache the rarely-changing config,
  let Postgres handle the comparatively small write volume.
- Not built, named honestly: the cache above is per-process (`Rails.cache`, in-memory). At
  real scale it'd move to a shared Redis so one server's cache warms all of them. At
  "millions of calls," raw event writes would also eventually want to move off the primary
  OLTP DB (batched writes, or a separate analytics store) — Postgres stays source of truth
  for config, which is small.

---

## Reliability and failure modes

This is the critical-path guarantee: **a broken page is never an acceptable outcome.**

- Exposure logging is best-effort and wrapped in a rescue — a logging failure can never
  fail the actual assignment response.
- Duplicate/retried events never double-count or 500 (unique DB index + idempotent
  handling in `EventsController`).
- A paused experiment always serves Control, bypassing the hash — instant kill switch, no
  cache to invalidate.
- **`ExperimentLookup`** caches experiment config and fails open: a DB error during lookup
  serves the last cached snapshot (even stale) instead of raising. Only when there's truly
  nothing cached does `AssignmentsController` return a fixed placeholder
  (`{ name: "control", degraded: true }`, HTTP `200`) instead of a `5xx`.
- A genuine "no experiment with this name" is never confused with an outage — it 404s
  immediately, it's never cached, and it never triggers the fallback path above.

---

## Correctness & edge cases handled

- **Tied conversion rates → no winner shown.** If two or more variants share the top
  conversion rate, the dashboard's 🏆 badge is suppressed for all of them rather than
  arbitrarily picking one. Also suppressed below 1 conversion (0% vs 0% isn't a winner).
- **No `rand()` anywhere in assignment** — see Determinism. This is what makes results
  reproducible and auditable: replaying the same visitor/experiment always explains the
  same outcome.
- **The LLM is only ever called when a variant is configured, never on a page load** — see
  below. This is as much a correctness point as a performance one: assignment latency
  can't depend on a third-party API's uptime.
- **Idempotent tracking**: a retried/duplicated request can't inflate conversion counts,
  so `conversion_rate = conversions / exposures` isn't silently biased.
- **Paused ⇒ no exposure *and* no conversion.** Fixed a real bug during development where a
  paused experiment could still record a conversion with no matching exposure, which would
  have permanently skewed that variant's rate even after resuming.
- **Not built, named honestly:** no Sample Ratio Mismatch detection, no confidence
  intervals, no protection against "peeking" at results and stopping early. The dashboard
  reports a raw point estimate, not a significance test — worth knowing before trusting a
  small-sample "winner."

---

## The LLM decision

- **Where:** exactly once per variant, synchronously, inside `POST /api/v1/experiments`
  (config time). Never on the assignment path.
- **Why:** assignment is the highest-QPS, most latency-sensitive path in the system. LLM
  calls take seconds and can fail; configuration is a rare, human-paced action that can
  absorb that latency once. Cost is naturally bounded too — spend scales with experiments
  configured, not with visitor traffic.
- **How it's implemented:** `VariantContentGenerator` makes one HTTP call to Gemini's
  `generateContent` endpoint with a hard timeout. Any failure (timeout, network error, bad
  response) is caught and falls back to the caller-supplied default text — an LLM having a
  bad day can never block an experiment from being created. The generated (or fallback)
  text is stored as a plain column on `variants`, so reading it later is a normal DB read,
  zero extra latency, zero external dependency.
- **Key handling:** `GEMINI_API_KEY` is a backend-only env var, read once inside the
  service, never returned in any API response. If unset, LLM-flavored variants just use
  their fallback text — the core service works fully without this key.
- **How to see it working, live:** every variant row on the Dashboard has a "✨ Generate AI
  copy" control — type any prompt and it calls `PATCH /api/v1/variants/:id/generate_content`
  in real time, which makes the same synchronous, fallback-safe Gemini call and updates the
  variant on success. This is the same config-time code path as `POST /api/v1/experiments`,
  just re-triggerable on demand. Seed data is deliberately plain hardcoded copy
  (`content_source: "manual"`) rather than LLM-generated, so the Dashboard's 🤖 badge stays a
  meaningful signal — it only appears once a variant's copy was actually generated this way.
- **Going further — drafting a whole experiment from a topic:** the Dashboard's "✨ Draft a
  new experiment with AI" panel takes a plain-English topic and returns a full suggested
  experiment (name, variants, weights, copy) via `POST /api/v1/experiment_drafts`, using
  Gemini's structured JSON output (`responseSchema`) instead of a free-text prompt. Two
  things keep this safe: (1) `ExperimentDraftGenerator` never persists anything — it only
  returns a suggestion, normalized (weights rebalanced to sum to 100, names slugified and
  de-duplicated) into the exact shape `POST /api/v1/experiments` already accepts; (2) the
  Dashboard shows that suggestion in an editable review step, and nothing is created until
  a human explicitly clicks "Create," which goes through the same, already-validated
  `ExperimentCreationService` as any manually-typed experiment. An LLM never gets to launch
  something live unreviewed. Every experiment records `source: manual | ai_draft`; the
  Dashboard shows a 🤖 badge on the latter and only lets you delete that kind — enforced
  server-side too (`DELETE` 422s on a manual experiment), so the seeded showcase
  experiments can't be wiped out through this path.

---

## Trade-offs and what I'd do with more time

Deliberately not built in this window, roughly in the order I'd tackle them next:

- **Higher write throughput** — Redis/Sidekiq for async event processing, and batched
  writes (`update_all`) instead of one row per event, once traffic is high enough that
  per-request inserts become the bottleneck.
- **Statistical rigor on the dashboard** — SRM detection, confidence intervals, peeking
  protection (see Correctness). A dashboard that can mislead is worse than no dashboard.
- **Real visitor identity / auth** — right now a visitor is just a `localStorage` UUID, so
  clearing cache or switching browsers looks like a brand-new visitor. A real login system
  would fix this but is a fundamentally different (and much bigger) feature.
- **An admin UI with real analytics/visualization** — today's dashboard is a flat table;
  it's fine for a handful of experiments but wouldn't scale visually to dozens.
- **Mobile-responsive polish** — the current Tailwind layout is desktop-first.
- **Server-side rendering** — evaluated and skipped: this is an SPA with no SEO
  requirement and no evidence it's needed; would add real complexity for no clear benefit
  today.
- **Git workflow for a larger team** — branch protection, required reviews, a
  documented PR/merge process. Not needed for a solo 24-hour build, but the first thing
  I'd set up before a team touched this codebase.
- **Multi-experiment batched assignment** — the spec allows "one or more" experiments per
  call; this only handles one at a time. Additive fix, not built now.
- **Adaptive allocation / cross-site learning** — genuinely different, harder problems
  (multi-armed bandits, cross-tenant data model) that deserve their own design, not a
  bolt-on to a fixed-split A/B system.
