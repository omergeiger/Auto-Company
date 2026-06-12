# Auto Company Consensus

## Last Updated
2026-06-12 - Cycle #9 complete - Webhook shipped, Wave 2 simulation done, $29/mo conviction memo written

## Current Phase
Building / Pre-Launch

## What We Did This Cycle
- Addressed Human Override: cfo-campbell wrote $29/mo conviction memo — key finding: price holds on infra ownership + Slack incident response time + compliance isolation, NOT monitor count; only 87 paying customers needed for ramen profitability
- fullstack-dhh shipped webhook + Slack alert channels: `webhook_url` migration applied to D1, `sendWebhookAlert` added to alerts.ts, dashboard form updated with Slack + webhook URL fields (PRO badge), monitor cards show enabled state
- devops-hightower deployed: worker v1ba062ad, pages efd2ef47, smoke test passed (webhook_url + slack_webhook_url stored and returned via API)
- hn-user ran Wave 2 (3 comments: pm-at-startup, senior-sre, solo-indie-hacker); 3 new signals surfaced
- ops-pg drafted Wave 2 inline replies; synthesis appended to docs/operations/mock-hn-wave1-synthesis.md
- Resolved P2 known issue: no-webhook-alert-channels (moved to resolved/)
- Filed 2 new known issues: team/workspace model (P1), self-host deployment guide (P2)

## Key Decisions Made
- **$29/mo is defensible — sell it on the right axis**: ownership claim + Slack incident response speed + compliance isolation (no vendor review needed for CF-native deploy). Do NOT sell on monitor count — that's a comparison CronGuard loses against Healthchecks.io. See `docs/cfo/cycle-09-29-per-month-conviction.md`
- **Team/workspace model is now P1**: Wave 2 confirmed single-owner is a hard conversion blocker for even small teams; minimum viable fix is dashboard tooltip advising mailing list use; full workspace is v2 scope
- **Self-host deployment guide is pre-launch required**: The positioning claim "runs in your Cloudflare account" must be verifiably true; P2 known issue filed, must be resolved before HN launch for the compliance/enterprise messaging to hold
- **Webhook payload is already sufficient for SRE use**: Our shipped payload (monitor_id, name, slug, period_minutes, grace_minutes, last_ping_at) covers what senior-sre asked for; PagerDuty routing is possible via raw webhook today

## Active Projects
- **cronguard**: Pre-launch — simulation Wave 2 complete; webhook shipped; team/workspace P1 open; Wave 3 and post-Wave-3 critic-munger review still pending before real HN launch

## Known Issues
- [P1] [20260612-no-team-workspace-model.md](../projects/cronguard/known-issues/20260612-no-team-workspace-model.md) - No team/workspace model; single-owner blocks conversion for teams
- [P2] [20260612-no-ping-run-history.md](../projects/cronguard/known-issues/20260612-no-ping-run-history.md) - No ping run history per monitor; users see only up/down, no audit trail
- [P2] [20260612-no-self-host-deployment-guide.md](../projects/cronguard/known-issues/20260612-no-self-host-deployment-guide.md) - No verified self-host guide; wrangler.toml may have hardcoded values blocking clean fork-and-deploy

## Simulation Mode
Active: mock HN simulation
Thread file: `projects/cronguard/product-docs/mock-hn-thread.md`
Agent: `hn-user` (`.claude/agents/hn-user.md`)
Wave: 2 (complete)
Purpose: test response quality and surface product gaps before real HN launch

## Next Action
Cycle 10: Address P1 team issue (minimal fix) + run Wave 3 simulation.

1. `fullstack-dhh` adds a dashboard tooltip/helper text on the alert email field: "Tip: use a mailing list address (e.g. team-alerts@company.com) for shared team alerts." — 10-minute change, removes the P1 conversion blocker without building full workspace model.
2. `fullstack-dhh` audits `wrangler.toml` and project README for hardcoded account-specific values; writes a verified "Deploy to your own CF account" section in the repo README. Closes the self-host guide P2 before Wave 3 surfaces it again.
3. `hn-user` runs Wave 3 (2-3 comments; some personas react to Wave 2 replies; introduce pressure on the $29 price point and the free tier cap). After Wave 3, `critic-munger` reviews the full thread for remaining product gaps per CLAUDE.md simulation workflow.
4. `operations-pg` + `marketing-godin` draft Wave 3 replies inline and append synthesis to docs/operations/mock-hn-wave1-synthesis.md.
5. Update consensus: wave count, any new signals, set Next Action to real HN launch prep if critic-munger passes.

## Human Overrides
These directives are set by the human founder and supersede any agent decision or Next Action. Do not remove or overwrite them. Only the human can add or clear entries here.

**Persistent directives:**
- Domain purchase: do not buy `cronguard.dev` or any paid domain until explicitly requested. Skip domain-related steps and proceed to the next highest-priority item.
- You may draft the email. You may send only to me omergeiger@gmail.com.
- No automatic publish to HN. only generate instruction recomendations for human to act on.
- Generally never reach out to other humans on any platform.

- I want to see clear conviction of why a user would consider paying 29 usd/mo for this service. I find that hard to believe.

## Company State
- Product: CronGuard - heartbeat/cron job monitoring SaaS
- Tech Stack: Cloudflare Workers / D1 / CF Pages / Resend (pending domain)
- Revenue: $0
- Users: 0 (HN launch pending)
- Workers API: https://cronguard-workers.omergeiger.workers.dev
- Landing page: https://cronguard-pages.pages.dev
- Dashboard: https://cronguard-pages.pages.dev/dashboard.html
- Repo: https://github.com/omergeiger/cronguard
- Paid tiers: Free ($0), Pro ($29/mo), Business ($79/mo) - DEFINED, not yet live in product
- Alert channels: email (free), Slack webhook (Pro), generic webhook (Pro) - NOW SHIPPED

## Critic Conditions (must hold throughout build)
1. Free tier strictly limited (5 monitors max, email only - no Slack on free) - **NOW ENFORCED**
2. CF-native features are product-level (npm SDK, CF Cron auto-detection), not just marketing copy
3. Market validation proxy: researcher confirmed live entrants + displacement window; no build block required

## Open Questions
- Team/workspace model: build mailing-list tooltip first (10 min), then scope full workspace for v2?
- Self-host guide: audit wrangler.toml before or after Wave 3?
- Free tier cap at 5 vs 20 (Healthchecks.io): raise to 10 pre-launch to reduce friction?
- Wave 3 still to run; after Wave 3, critic-munger reviews full thread before real launch.
- $29/mo conviction memo is written — does the founder find it convincing? See docs/cfo/cycle-09-29-per-month-conviction.md.
