# Auto Company Consensus

## Last Updated
2026-06-12 — Cycle #6 complete — P1 auth bug fixed, outreach email drafted

## Current Phase
Building / Early Growth

## What We Did This Cycle
- Fixed P1 bug: registration flow was broken — `show()` sets `style.display = ''` which fell back to CSS `display:none` rules for `#dashboard` and `.key-reveal`; fixed by removing the CSS rules and using inline `style="display:none"` on the elements instead
- Moved resolved P1 issue to `known-issues/resolved/`
- Replaced bare empty state with a 3-step getting-started guide (create monitor, copy ping URL, add crontab line) — makes first-use onboarding obvious
- Drafted and saved Show HN post to `product-docs/show-hn-draft.md`
- Created Gmail draft to omergeiger@gmail.com with dashboard link and 2-sentence pitch (per Human Override: send to founder only)
- Deployed all changes to CF Pages, pushed to GitHub

## Key Decisions Made
- **P1 first** — auth was broken before any real user could register; fixed before outreach
- **Inline style over CSS rule** for elements toggled by show()/hide() — the `show()` pattern requires no competing CSS rule to work correctly
- **Email is a draft** — Human Override restricts sending to omergeiger@gmail.com only; draft created in Gmail for review and send

## Active Projects
- **cronguard**: Building — auth fixed, dashboard live with getting-started guide; next focus is first real user registration and HN launch

## Known Issues
- (none)

## Next Action
Cycle 7: Launch CronGuard publicly and get the first real non-test user.
1. Review and send the Gmail draft (id: r-763030244258226664) to self first — confirm the auth + monitor creation flow works end-to-end.
2. Enforce the 5-monitor free tier cap in the API (P2 scope control: return 403 with a clear message when user has 5+ monitors).
3. Post the Show HN draft from `product-docs/show-hn-draft.md` — schedule for a weekday morning ET.

## Human Overrides
These directives are set by the human founder and supersede any agent decision or Next Action. Do not remove or overwrite them. Only the human can add or clear entries here.

- **Domain purchase:** do not buy `cronguard.dev` or any paid domain until explicitly requested. Skip domain-related steps and proceed to the next highest-priority item.
- you may draft the email. you may send it only to me omergeiger@gmail.com.

## Company State
- Product: CronGuard — heartbeat/cron job monitoring SaaS
- Tech Stack: Cloudflare Workers / D1 / CF Pages / Resend (pending domain)
- Revenue: $0
- Users: 0 (auth was broken until Cycle 6; should be functional now)
- Workers API: https://cronguard-workers.omergeiger.workers.dev
- Landing page: https://cronguard-pages.pages.dev
- Dashboard: https://cronguard-pages.pages.dev/dashboard.html
- Repo: https://github.com/omergeiger/cronguard

## Critic Conditions (must hold throughout build)
1. Free tier strictly limited (5 monitors max, email only — no Slack on free)
2. CF-native features are product-level (npm SDK, CF Cron auto-detection), not just marketing copy
3. Market validation proxy: researcher confirmed live entrants + displacement window; no build block required

## Open Questions
- 5-monitor cap not yet enforced in API — add in Cycle 7
- HN post timing: weekday morning ET, ideally after confirming auth flow works
- Should paid tier be defined before HN launch to capture upgrade intent?
