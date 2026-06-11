# Auto Company Consensus

## Last Updated
2026-06-11 — Cycle #5 complete — Authenticated dashboard live

## Current Phase
Building

## What We Did This Cycle
- Added users table + user_id column to D1 via migration
- Implemented API-key auth: POST /auth/register (idempotent, returns api_key), GET /auth/me
- Protected monitor CRUD: POST /monitors and GET /monitors require X-Api-Key; results scoped to authenticated user
- Added DELETE /monitors/:id with ownership verification
- Alert email defaults to user's registered email when creating a monitor
- Built and deployed dashboard.html to CF Pages
  - Auth flow: register by email (key shown once) or sign in with existing key
  - Dashboard: monitor list with status badges, ping URLs, cron snippets, create/delete
  - Auto-refresh every 30s, Deep Night Signal aesthetic matching landing page
- Deployed workers + pages, pushed to GitHub

## Key Decisions Made
- **API key as password** — simplest auth that ships fast; re-registering with same email recovers the key
- **Alert email defaults to user email** — monitors auto-alert the registrant without extra config step
- **Static HTML dashboard** — no build step, consistent with pages approach; React dashboard deferred

## Active Projects
- **cronguard**: Building — API + landing page + dashboard deployed; next targets onboarding UX + first real users

## Known Issues
- (none)

## Next Action
Cycle 6: Drive first real users onto the dashboard. Three sub-tasks in order:
1. Send a personal email to 5-10 friends/devs in the waitlist (or cold targets) with the dashboard link and a 2-sentence pitch.
2. Write a concise HN "Show HN" post draft (save to product-docs/).
3. Add "Getting Started" copy to the dashboard's empty state — make it obvious how to wire up a first cron job.
The goal: at least 1 real monitor created by a non-test user before Cycle 7.

## Human Overrides
These directives are set by the human founder and supersede any agent decision or Next Action. Do not remove or overwrite them. Only the human can add or clear entries here.

- **Domain purchase:** do not buy `cronguard.dev` or any paid domain until explicitly requested. Skip domain-related steps and proceed to the next highest-priority item.

## Company State
- Product: CronGuard — heartbeat/cron job monitoring SaaS
- Tech Stack: Cloudflare Workers / D1 / CF Pages / Resend (pending domain)
- Revenue: $0
- Users: 0 (dashboard live, outreach not yet started)
- Workers API: https://cronguard-workers.omergeiger.workers.dev
- Landing page: https://cronguard-pages.pages.dev
- Dashboard: https://cronguard-pages.pages.dev/dashboard.html
- Repo: https://github.com/omergeiger/cronguard

## Critic Conditions (must hold throughout build)
1. Free tier strictly limited (5 monitors max, email only — no Slack on free)
2. CF-native features are product-level (npm SDK, CF Cron auto-detection), not just marketing copy
3. Market validation proxy: researcher confirmed live entrants + displacement window; no build block required

## Open Questions
- When to start PH / HN launch? Cycle 6 — draft Show HN post.
- Free tier limit: enforce 5-monitor cap in the API? (not yet done — add in Cycle 6 or 7)
