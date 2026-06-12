# Auto Company Consensus

## Last Updated
2026-06-12 - Cycle #8 complete - Wave 1 simulation done, paid tiers defined, positioning reframed

## Current Phase
Building / Pre-Launch

## What We Did This Cycle
- hn-user ran Wave 1 (4 comments: skeptic / curious / minimalist / tech-inquisitor)
- 5 signals surfaced: P1 no webhook/non-email alerts; P2 no run history; P2 slug security model; P2 free tier weaker than Healthchecks.io; P2 no retry logic docs
- ops-pg drafted inline founder replies to all 4 comments, tagged each, wrote synthesis doc
- cfo-campbell defined 3-tier pricing: Free ($0 / 5 monitors / email), Pro ($29/mo / 50 monitors / Slack+webhook+API), Business ($79/mo / 500 monitors / all channels)
- marketing-godin reframed positioning from "simpler" to "runs in your Cloudflare account — you own the monitoring layer"
- sales-ross defined upgrade trigger (inline Slack prompt, not monitor limit), pricing page headline, first dollar path (network outreach to 5 devs)
- Filed 2 new P2 known issues: no webhook alerts, no ping run history

## Key Decisions Made
- **First paid differentiator is Slack/webhook alerts, not more monitors** - the upgrade moment fires when a user tries to add a Slack channel and hits the gate; monitor limit is a weaker trigger
- **Keep free tier at 5 monitors** - raising to 20 removes the natural expansion trigger; at Pro level ($29) CronGuard wins on value-per-monitor vs Healthchecks.io ($20 for 100 monitors)
- **Positioning reframe: ownership** - "CronGuard runs in your Cloudflare account" is a category claim Healthchecks.io cannot copy; drop the "dead-simple / simpler" framing
- **HN launch held** - Wave 2 and Wave 3 simulations still to run; Slack/webhook should be shipped before or immediately after real launch to enable Pro conversions

## Active Projects
- **cronguard**: Pre-launch - simulation Wave 1 complete, paid tier defined; build Slack/webhook alert before HN launch to unlock Pro conversions

## Known Issues
- [P2] [20260612-no-webhook-alert-channels.md](../projects/cronguard/known-issues/20260612-no-webhook-alert-channels.md) - No Slack/webhook alert channels; blocks Pro tier conversions
- [P2] [20260612-no-ping-run-history.md](../projects/cronguard/known-issues/20260612-no-ping-run-history.md) - No ping run history per monitor; users see only up/down, no audit trail

## Simulation Mode
Active: mock HN simulation
Thread file: `projects/cronguard/product-docs/mock-hn-thread.md`
Agent: `hn-user` (`.claude/agents/hn-user.md`)
Wave: 1 (complete)
Purpose: test response quality and surface product gaps before real HN launch

## Next Action
Cycle 9: Build Slack/webhook alert + run Wave 2 simulation.
1. `fullstack-dhh` implements webhook alert on monitors: add `webhook_url` field to the `monitors` D1 table, populate it in the dashboard form, fire a JSON POST to it on missed-heartbeat events. A single `fetch()` call in the check worker is enough for v1 - no retry, no queue.
2. `devops-hightower` deploys the updated worker and runs smoke test (create monitor with webhook_url, miss a ping, confirm POST fires).
3. `hn-user` runs Wave 2 (2-3 comments; some personas react to Wave 1 replies; introduce one new persona not seen in Wave 1).
4. `operations-pg` + `marketing-godin` draft Wave 2 replies inline, tag, and append synthesis notes to `docs/operations/mock-hn-wave1-synthesis.md`.
5. Update consensus: wave count, any new signals, next action set to Wave 3 or real launch prep if simulation is clean.

## Human Overrides
These directives are set by the human founder and supersede any agent decision or Next Action. Do not remove or overwrite them. Only the human can add or clear entries here.

- **Domain purchase:** do not buy `cronguard.dev` or any paid domain until explicitly requested. Skip domain-related steps and proceed to the next highest-priority item.
- you may draft the email. you may send it only to me omergeiger@gmail.com.
- No automatic publish to HN. only generate instruction recomendations for human to act on.
- Generally never reach out to other humans on any platform.

- lets mock HN announcement and have hn-user agent provide feedback after mock launch
- proceed to define paid tier based on mock

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

## Critic Conditions (must hold throughout build)
1. Free tier strictly limited (5 monitors max, email only - no Slack on free) - **NOW ENFORCED**
2. CF-native features are product-level (npm SDK, CF Cron auto-detection), not just marketing copy
3. Market validation proxy: researcher confirmed live entrants + displacement window; no build block required

## Open Questions
- Ship Slack/webhook before or immediately after HN launch? Building pre-launch means Pro tier is live and sellable on day 1 of the spike.
- Should ping run history be v1 scope or post-launch? P2 but erodes trust on false alerts.
- Wave 2 and Wave 3 still to run; after Wave 3, critic-munger reviews full thread for product gaps before real launch (per CLAUDE.md simulation workflow).
- Pricing page not yet built - needed before or shortly after HN launch for conversions.
