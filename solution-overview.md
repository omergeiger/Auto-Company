# Auto Company - Solution Overview

## What It Is

A fully autonomous AI company loop. A shell script invokes Claude headlessly on a recurring cycle. Claude reads the current company state, decides what to do, assembles a team of sub-agents, executes work, and writes the updated state back to disk. No human involvement required between cycles.

---

## Input Layer (the files that drive behavior)

| File / Dir | Role |
|---|---|
| `Makefile` | Entry point. Exposes `start`, `start-single`, `install` (daemon), `monitor`, `dashboard`, `flush-run`, and others. Most targets are thin wrappers around `scripts/core/`. |
| `PROMPT.md` | Orchestrator constitution. Defines the cycle structure, convergence rules, artifact conventions, and known-issues lifecycle. Stable across cycles - not modified by agents. |
| `scripts/core/auto-loop.sh` | Loop engine. Handles config loading, PID management, prompt assembly, subprocess execution, watchdog timeout, consensus validation, backup/restore, log rotation, artifact sync, GitHub commit/push, circuit breaker, and usage-limit detection. |
| `config/auto-company.env` | Committed shared defaults (e.g. `ENGINE=claude`). |
| `config/auto-company.local.env` | Gitignored local overrides. Primary use: set `ACTIVE_PROJECT=<name>`. Also accepts `GITHUB_USER`, `MODEL`, `LOOP_INTERVAL`, etc. Changing `ACTIVE_PROJECT` here changes the active project context for the loop. |
| `CLAUDE.md` (project root) | Auto-injected by Claude Code into every session including headless subprocesses. Defines team roster, safety guardrails, project structure rules, documentation map, collaboration workflows, and known-issues lifecycle. Does not need to be referenced in the prompt - it is always present. |
| `~/.claude/CLAUDE.md` | Global user-level directives (Python venv rules, git hygiene, style rules). Also auto-injected. |
| `memories/consensus.md` | The relay baton. The only state that persists between cycles. Every cycle reads it at the start and rewrites it at the end. If this file is wrong, the company goes in the wrong direction. |
| `.claude/agents/*.md` | One file per persona (Bezos, Munger, DHH, etc.). Defines decision style and domain focus. The orchestrator reads these when deciding which sub-agents to spawn. |
| `.claude/skills/*.md` | Reusable work protocols. Any agent can invoke any skill when the task matches. Agent definitions may recommend certain skills but do not restrict access. |
| `.claude/skills/team/SKILL.md` | Team assembly protocol. Called out explicitly in `PROMPT.md` - the orchestrator is instructed to read it at the start of every cycle before picking agents. |
| `scripts/core/stop-loop.sh` | Graceful shutdown via `.auto-loop-stop` sentinel file. |
| `scripts/core/monitor.sh` | Human observation tooling: loop status, last-cycle output, cycle history. |
| `.auto-loop-state` | Persists `LOOP_COUNT`, `ERROR_COUNT`, `LAST_RUN`, `STATUS`, `MODEL`, `ENGINE` across runs. Keeps cycle numbering continuous across `make start-single` invocations. |
| `.auto-loop.pid` | Live PID of the loop process. Used by `stop-loop.sh` to find and kill the process. |

---

## Output Layer

| Output | Location | Description |
|---|---|---|
| Updated consensus | `memories/consensus.md` | Rewritten every cycle. The company's current state, decisions, next action, known issues, and human overrides. |
| Consensus snapshots | `memories/consensus-step-NNNN.md` | Immutable per-cycle record. Written on success, never overwritten. |
| Agent analysis outputs | `docs/<role>/cycle-NN-<description>.md` | Internal agent thinking: research, pre-mortems, unit economics, architecture decisions. Zero-padded cycle prefix required. |
| Project-facing documents | `projects/<name>/product-docs/<name>.md` | Human-readable deliverables: PRDs, runbooks, launch plans, demo scripts. No cycle prefix. |
| Artifact sync | `projects/<name>/auto-company-tracking/` | Mirror of `docs/`, `memories/`, and `logs/` synced into the project repo each cycle via `rsync`. |
| Known issues | `projects/<name>/known-issues/` | Bug and issue tracker. Filed by agents or humans. Resolved files move to `known-issues/resolved/`. |

---

## How a Cycle Runs

1. `auto-loop.sh` sources config files, restores loop count from `.auto-loop-state`.
2. Backs up `consensus.md` to `consensus.md.bak` and snapshots `.gitignore`.
3. Assembles `FULL_PROMPT` by concatenating: `PROMPT.md` + runtime guardrail block (hardcoded in the shell script) + current `consensus.md` + project context line + cycle number.
4. Spawns a headless Claude subprocess: `claude -p "$FULL_PROMPT" --output-format json --permission-mode bypassPermissions`. A parallel watchdog subprocess kills it after `CYCLE_TIMEOUT_SECONDS` (default 1800s) if it hasn't exited.
5. Claude runs as the orchestrator: reads the consensus, picks 3-5 agents, executes work, writes docs, updates consensus.
6. After exit: validates consensus, handles timeout/error/circuit-breaker cases, saves snapshot, syncs artifacts, commits and pushes the project repo.
7. In `SINGLE_CYCLE=1` mode (the default via `make start`): exits. In continuous mode: sleeps `LOOP_INTERVAL` seconds and repeats.

---

## Prompt Assembly - Why Split Across Two Files

`PROMPT.md` contains what the company does (strategy, cycle workflow, agent rules). The runtime guardrail block is injected by the shell script and contains how the loop operates safely (no heredocs, no direct redirect operators, protect gitignore, honor human overrides).

These are separated by ownership: `PROMPT.md` is edited by the founder to change business direction. The guardrails are maintained by whoever maintains the loop infrastructure. They change for different reasons and should not be coupled. Keeping guardrails in the shell script also protects them from being accidentally weakened by strategic edits to the prompt.

The guardrails also exist because of observed runtime failures - the heredoc rule exists because malformed shell redirects were producing `=*` artifact files in the repo root. The shell script has a `cleanup_accidental_root_artifacts()` function that deletes these after every cycle.

---

## Sub-Agent Communication

Sub-agents do not communicate directly. The orchestrator is the hub.

**Mechanism 1 - Orchestrator as relay:** The orchestrator spawns Agent A, reads the result, synthesizes it, and includes relevant findings in the prompt it writes for Agent B. Agent B only knows what the orchestrator chose to pass along.

**Mechanism 2 - Filesystem as shared memory:** Agent A writes to `docs/<role>/cycle-N.md`. The orchestrator tells Agent B to read that file. The shared filesystem is the communication medium - but the orchestrator must explicitly route Agent B to Agent A's output.

**Parallel vs sequential:** Entirely orchestrator-decided at runtime. No external parameter controls this. CLAUDE.md recommends sequences for specific workflows (e.g. `research-thompson -> ceo-bezos -> critic-munger`) but these are prompt-level suggestions, not enforced. When agents run in parallel, they are fully isolated - each receives only what the orchestrator put in their individual prompt.

---

## Key Mechanics and Edge Cases

**Cycle timeout is invisible to the orchestrator.** `CYCLE_TIMEOUT_SECONDS` is a shell watchdog only. Claude has no knowledge of the timeout value and cannot pace itself against it. The loop handles timeout outcomes post-hoc: if consensus was updated despite timeout, it counts as a soft success.

**`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** is a legacy backwards-compatibility flag kept in the loop. It was the opt-in gate for sub-agent spawning in headless mode when Claude Code's multi-agent feature was experimental. It may be a no-op in current versions but is kept to avoid breaking anything if some toolchain version still checks for it.

**`bypassPermissions` mode** means the headless Claude subprocess can read/write files, run shell commands, and deploy via wrangler without prompting for approval. This is what makes full autonomy possible.

**Circuit breaker:** After `MAX_CONSECUTIVE_ERRORS` (default 5) consecutive failed cycles, the loop pauses for `COOLDOWN_SECONDS` (default 300s) before resuming. Separate from usage-limit detection, which waits `LIMIT_WAIT_SECONDS` (default 3600s).

**Human override mechanism:** The `## Human Overrides` section in `consensus.md` is the only channel for human direction. The orchestrator is instructed (in `PROMPT.md` and in the runtime guardrails) to read it before acting on `## Next Action`, to never remove it, and to preserve it verbatim on every consensus update. Overrides supersede any agent decision.
