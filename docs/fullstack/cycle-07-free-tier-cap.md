# Cycle 07 - Free Tier Monitor Cap

## What Changed

Added a 5-monitor hard cap to `handleMonitorCreate` in `workers/src/index.ts`.

Before inserting a new monitor, the API now queries:

```sql
SELECT COUNT(*) as count FROM monitors WHERE user_id = ?
```

If `count >= 5`, returns `403` with:

```json
{ "error": "Free tier limit reached (5 monitors max). Upgrade to add more." }
```

The constant `FREE_TIER_MONITOR_LIMIT = 5` is defined at module scope so it's easy to change when paid tiers ship.

## Why This Matters for Launch

Without the cap, a single user could create unlimited monitors, which would stress the D1 database and scheduler at CF free tier limits. More importantly, the cap is advertised in the Show HN post — it must be enforced or the pitch is misleading.

## Deployment

Deployed to `cronguard-workers.omergeiger.workers.dev` — Version ID `57685ab6-389e-4f6e-a452-60750db9672a`.
