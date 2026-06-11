# Cycle 05 — Authenticated Dashboard

**Agent:** fullstack-dhh

## What Was Built

### Backend (Workers)

**D1 migration applied:**
- `users` table: id, email (unique), api_key (unique), created_at
- `monitors.user_id` column added (nullable, references users.id)
- Indexes on api_key, email, user_id

**New endpoints:**
- `POST /auth/register` — create or retrieve account by email; returns api_key. Idempotent: re-registering with same email returns same key (recovery flow).
- `GET /auth/me` — verify X-Api-Key header; returns `{id, email}`.

**Updated endpoints:**
- `POST /monitors` — now requires auth; stores user_id; defaults alert_email to user's email if not provided.
- `GET /monitors` — now requires auth; filters results to current user's monitors only.
- `DELETE /monitors/:id` — new; requires auth; verifies ownership before delete.

**CORS headers updated:** Added `DELETE` to methods, `X-Api-Key` to allowed headers.

### Frontend (Pages)

New `dashboard.html` — static single-page dashboard, no build step.

**Auth screen:**
- "New account" flow: enter email → get API key displayed once with copy button → open dashboard
- "Sign in" flow: paste existing API key → validates via /auth/me → loads dashboard
- Recovery: re-entering same email returns same API key

**Dashboard:**
- Sticky header with logo, user email badge (click to copy key), logout
- Stats row: total / up / down counts
- Monitor list: status badge (UP/DOWN), ping URL + copy, cron snippet + copy, last ping time, period/grace/alert meta
- Delete with inline confirmation
- Create form: name, period, grace, alert email, optional custom slug
- New monitor highlighted with border flash after creation
- Auto-refresh every 30 seconds

**Design:** Deep Night Signal aesthetic — same CSS variables and fonts as landing page.

## Key Decisions

- **API key as password (not JWT):** Simplest auth that ships fast. Recovery by email re-registration.
- **Alert email defaults to user email:** Better DX — monitors auto-alert the registrant without extra config.
- **CORS `*` retained:** API is semi-public (ping endpoints are intentionally unauthenticated); the X-Api-Key header protects write operations.
- **Static HTML:** No build step, consistent with existing pages approach.

## Verification

All endpoints tested:
- Register (new + idempotent), me, create monitor (with user_id + email default), list (user-filtered), delete (ownership check), unauthorized rejection.
