# Auto Company — Framework TODO

Items deferred from the initial framework development session.

## Visibility and Control

### 2. Cycle visibility - auto logic transparency
Surface what the loop is doing inside each cycle in a human-readable way:
- Structured per-cycle summary written to `logs/last-cycle-summary.md` after each cycle
- What the agents decided, what actions were taken, what was skipped and why
- Makes it possible to review a cycle without reading raw logs

### 3. Pause/resume gate
A finer-grained intervention point than SINGLE_CYCLE:
- After each cycle, loop drops into a wait state (writes `.auto-loop-paused`)
- A `resume-loop.sh` command (or `touch .auto-loop-resume`) signals the next cycle to start
- Allows mid-run inspection and instruction injection without restarting the process
- Different from SINGLE_CYCLE: process stays alive, does not need to be relaunched

### Gap 3. Cloudflare Pages requires manual redeployment
CF Pages is deployed via direct upload (`wrangler pages deploy`), not connected to GitHub auto-deploy:
- Pushing frontend changes to GitHub does NOT redeploy the Pages site
- After any change to a `pages/` component, run: `cd projects/<name>/pages && wrangler pages deploy .`
- This is a Cloudflare configuration gap, not a framework constraint
- Tracked in `CLAUDE.md` under Tooling as a standing reminder

### 4. Token usage tracking
Track API spend per cycle and cumulatively:
- Parse `total_cost_usd`, input tokens, output tokens from Claude JSON output (already available in `RESULT_MESSAGE`)
- Append per-cycle entry to `logs/token-ledger.json`
- Show running session total in the startup banner and in each cycle log line
- Surface "expected vs actual" budget awareness
