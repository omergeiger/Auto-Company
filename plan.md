# Auto-Company Restructuring Plan

## Background

Auto-Company is an autonomous AI company framework. This plan restructures it to match the intended operating model. Read this document fully before starting any work.

---

## Intended Model

- **`main` branch** — clean framework template. No project-specific content. Anyone can fork and start fresh.
- **Each company run = a named branch** (e.g. `devfeed`). Branch carries the framework as configured for that run.
- **All project work lives in `projects/<name>/`** as a standalone GitHub repo. This includes both product code and auto-company tracking artifacts.
- **The project repo is self-contained** at the end — code + full build history in one place.
- **New project** — new branch from main (or fork for a separate company).
- **One project per branch** — enforced at runtime and documented.
- **Run branch is a snapshot** — once created, it diverges from main and is not kept in sync. It's a historical record of the framework as it was configured for that run.

---

## Tracking Folder Structure

Auto-company artifacts for a run are stored inside the project repo, not in the auto-company repo:

```
projects/<name>/
  <component>/              ← product code (workers/, pages/, etc.)
  auto-company-tracking/
    docs/                   ← agent outputs (mirrors auto-company docs/)
      ceo/
      cto/
      devops/
      fullstack/
      ...                   ← only populated roles
    memories/
      consensus.md          ← baton snapshot, updated each cycle
    logs/
      auto-loop.log         ← main loop log
      cycle-0001-YYYYMMDD-HHMMSS.log  ← full output, all cycles retained
      cycle-0002-YYYYMMDD-HHMMSS.log
      ...
    .auto-loop-state        ← loop counter, error count, last status
```

---

## Current State (as of plan creation)

**Repo location:** `/Users/omergeiger/Projects/Auto-Company`
**Current branch:** `main`
**GitHub remote:** `omergeiger/Auto-Company`

**Key files:**
- `scripts/core/auto-loop.sh` — main loop; contains worktree machinery to be removed
- `CLAUDE.md` — framework instructions; contains devfeed-specific content to be cleaned
- `PROMPT.md` — cycle prompt; needs one-project-per-branch reminder
- `config/auto-company.env` — currently has `GITHUB_USER=omergeiger`; needs `ACTIVE_PROJECT=` added
- `projects/devfeed/.project.json` — project registration; `"repo": "devfeed"`
- `.gitignore` — `projects/*` is gitignored (correct); `projects/devfeed/` contents are NOT tracked by this repo

**Active project:** `projects/devfeed/` on disk, tracked as standalone repo `omergeiger/devfeed` on GitHub

**Existing worktree:** `.worktrees/devfeed/` — a linked worktree pointing to the `devfeed` orphan branch. Must be removed before that branch can be renamed or deleted.

**Existing `devfeed` branch:** Orphan artifacts branch created by the old worktree model. This branch is superseded by the new model. It must be renamed (not deleted yet) in Step 2 to make room for the new `devfeed` run branch. It is deleted in Step 4 after confirmation.

**What `auto-loop.sh` currently contains that must be removed:**
- `ARTIFACTS_BRANCH="${ARTIFACTS_BRANCH:-devfeed}"` config var
- `ARTIFACTS_WORKTREE="$PROJECT_DIR/.worktrees/${ARTIFACTS_BRANCH}"` config var
- Worktree creation block inside `setup_project_repos()` (the `if [ ! -f "$worktree/.git" ]` block)
- `commit_artifacts()` function
- `commit_artifacts "$loop_count" "$_artifact_status"` call in the main loop
- `setup_project_repos` call at the end of `register_new_projects()`

**Safety guardrails (non-negotiable):**
- No `gh repo delete`
- No `wrangler delete`
- No `git push --force` to main/master
- No `git reset --hard` on shared branches
- Never commit secrets/credentials

---

## Required Changes

### 1. `config/auto-company.env`

- Add `ACTIVE_PROJECT=` (empty on main; set to project name on run branches)

### 2. `scripts/core/auto-loop.sh`

**Remove:**
- `ARTIFACTS_BRANCH` and `ARTIFACTS_WORKTREE` config vars
- Worktree creation block inside `setup_project_repos()`
- `commit_artifacts()` function entirely
- `commit_artifacts` call in the main loop
- `setup_project_repos` call at end of `register_new_projects()`

**Add:**
- `ACTIVE_PROJECT="${ACTIVE_PROJECT:-}"` config var (sourced from `config/auto-company.env`)
- Header comment documenting `ACTIVE_PROJECT`
- Startup guard: after `setup_project_repos`, count `.project.json` files via `scan_projects`. If count > 1 and `ACTIVE_PROJECT` is empty, log a clear error and exit. If count == 1 and `ACTIVE_PROJECT` is empty, auto-set it from the single project's name.
- End-of-cycle artifact sync function `sync_artifacts()`: rsync `docs/`, `logs/`, `memories/consensus.md`, `.auto-loop-state` into `$PROJECTS_DIR/$ACTIVE_PROJECT/auto-company-tracking/`. Call it before `commit_project_changes()` in the main loop.

**Modify:**
- `setup_project_repos()`: remove the entire worktree section (keep GitHub repo and git remote setup)
- `register_new_projects()`: remove the `setup_project_repos` call at the end

### 3. `CLAUDE.md`

**Add:**
- One-project-per-branch rule: "Each company run branch targets exactly one active project. Do not create a second `projects/` folder on an active branch. If running a second project, branch from main first."
- Tracking folder structure documentation (as shown above)
- Usage model: fork for a new company, branch for a new project run

**Remove:**
- Cloudflare Pages manual deploy note (devfeed-specific — belongs on the devfeed run branch, not main)
- Any other content specific to DevFeed

### 4. `PROMPT.md`

**Add to Cycle 3+:**
- "One project per branch. If a `projects/` folder already exists on this branch, build on it — do not create a second project. To start a new project, branch from main first."

---

## Migration Steps

---

### Step 1 — Implement framework changes on main

Apply all Required Changes above to the current `main` branch. Commit to main and push.

> **STOP — CHECKPOINT 1**
> User reviews all code and doc changes on main before any branch work.
> Confirm: auto-loop.sh logic is correct, CLAUDE.md is clean, PROMPT.md updated, no regressions.
> Do not proceed to Step 2 until user explicitly approves.

---

### Step 2 — Set up the `devfeed` run branch

**2a — Remove the existing worktree:**
```bash
git worktree remove .worktrees/devfeed --force
git worktree prune
```

**2b — Rename the old orphan artifacts branch** (do not delete yet — Step 4 handles that):
```bash
git branch -m devfeed devfeed-artifacts-legacy
git push origin devfeed-artifacts-legacy
git push origin --delete devfeed
```

**2c — Create the new `devfeed` run branch from current main:**
```bash
git checkout -b devfeed
git push -u origin devfeed
```

**2d — Configure the run branch:**
- Set `ACTIVE_PROJECT=devfeed` in `config/auto-company.env`
- Commit this change to the auto-company `devfeed` branch and push

**2e — Backfill tracking folder into the devfeed project repo:**
- Create `projects/devfeed/auto-company-tracking/` folder structure
- Copy current `docs/`, `logs/`, `memories/consensus.md` into the tracking folder
- Commit the tracking folder to `omergeiger/devfeed` (the project repo) and push

> **STOP — CHECKPOINT 2**
> User reviews the `devfeed` branch and the tracking folder in the devfeed repo.
> Confirm: branch structure is correct, artifacts are present and complete, devfeed run is fully captured.
> This is the last chance to catch anything before main is cleaned.
> Do not proceed to Step 3 until user explicitly approves.

---

### Step 3 — Clean `main` back to template

Switch back to main:
```bash
git checkout main
```

Verify main is clean:
- `config/auto-company.env`: `ACTIVE_PROJECT=` is empty (no project name), `GITHUB_USER` stays
- `CLAUDE.md`: no devfeed-specific content, CF Pages note removed
- `auto-loop.sh`: no hardcoded project names, no worktree references
- `PROMPT.md`: one-project-per-branch reminder is generic

Commit and push any cleanup edits needed.

> **STOP — CHECKPOINT 3**
> User reviews main in its clean template state.
> Confirm: a fresh fork of main gives a blank-slate Auto-Company with no DevFeed traces.
> Do not proceed to Step 4 until user explicitly approves.

---

### Step 4 — Delete the legacy artifacts branch

```bash
git branch -d devfeed-artifacts-legacy
git push origin --delete devfeed-artifacts-legacy
```

> **STOP — CHECKPOINT 4**
> Explicit user confirmation required — this deletion is irreversible.
> Confirm: new `devfeed` run branch and omergeiger/devfeed tracking folder have everything before deleting.
