#!/bin/bash
# ============================================================
# Auto Company — 24/7 Autonomous Loop
# ============================================================
# Keeps selected CLI engine (Claude/Codex) running continuously.
# Uses fresh sessions with consensus.md as the relay baton.
#
# Usage:
#   ./auto-loop.sh              # Run in foreground
#   ./auto-loop.sh --daemon     # Run via launchd (macOS only)
#
# Stop:
#   ./stop-loop.sh              # Graceful stop
#   kill $(cat .auto-loop.pid)  # Force stop
#
# Config (env vars):
#   ENGINE=claude               # Engine selection: claude|codex (default: claude)
#   MODEL=...                   # Optional model override (empty = engine default)
#   CLAUDE_BIN=...              # Optional Claude executable override
#   CLAUDE_PERMISSION_MODE=bypassPermissions
#                               # Claude permission mode (default: bypassPermissions)
#   CODEX_BIN=...               # Optional Codex executable override
#   CODEX_SANDBOX_MODE=danger-full-access
#                               # Codex sandbox mode (only for ENGINE=codex)
#   LOOP_INTERVAL=30            # Seconds between cycles (default: 30)
#   CYCLE_TIMEOUT_SECONDS=1800  # Max seconds per cycle before force-kill
#   MAX_CONSECUTIVE_ERRORS=5    # Circuit breaker threshold
#   COOLDOWN_SECONDS=300        # Cooldown after circuit break
#   LIMIT_WAIT_SECONDS=3600     # Wait on usage limit
#   MAX_LOGS=200                # Max cycle logs to keep
#   AUTO_LOOP_PROTECT_GITIGNORE=1
#                               # Restore .gitignore if a cycle mutates it
#   SINGLE_CYCLE=1              # Run exactly one cycle then exit cleanly
#   GITHUB_USER=omergeiger      # GitHub account owner for project repos
#   ACTIVE_PROJECT=             # Active project name (empty on main; set on run branches)
# ============================================================

set -euo pipefail

# === Resolve project root (always relative to this script) ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source project-level config (sets GITHUB_USER and other vars)
if [ -f "$PROJECT_DIR/config/auto-company.env" ]; then
    # shellcheck source=/dev/null
    . "$PROJECT_DIR/config/auto-company.env"
fi

LOG_DIR="$PROJECT_DIR/logs"
CONSENSUS_FILE="$PROJECT_DIR/memories/consensus.md"
PROMPT_FILE="$PROJECT_DIR/PROMPT.md"
PID_FILE="$PROJECT_DIR/.auto-loop.pid"
STATE_FILE="$PROJECT_DIR/.auto-loop-state"

# Loop settings (all overridable via env vars)
ENGINE="${ENGINE:-claude}"
ENGINE="$(echo "$ENGINE" | tr '[:upper:]' '[:lower:]')"
MODEL="${MODEL:-}"
MODEL_LABEL="${MODEL:-config-default}"
CLAUDE_BIN="${CLAUDE_BIN:-}"
CLAUDE_PERMISSION_MODE="${CLAUDE_PERMISSION_MODE:-bypassPermissions}"
CODEX_BIN="${CODEX_BIN:-}"
CODEX_SANDBOX_MODE="${CODEX_SANDBOX_MODE:-danger-full-access}"
LOOP_INTERVAL="${LOOP_INTERVAL:-30}"
CYCLE_TIMEOUT_SECONDS="${CYCLE_TIMEOUT_SECONDS:-1800}"
MAX_CONSECUTIVE_ERRORS="${MAX_CONSECUTIVE_ERRORS:-5}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"
LIMIT_WAIT_SECONDS="${LIMIT_WAIT_SECONDS:-3600}"
MAX_LOGS="${MAX_LOGS:-200}"
AUTO_LOOP_PROTECT_GITIGNORE="${AUTO_LOOP_PROTECT_GITIGNORE:-1}"
SINGLE_CYCLE="${SINGLE_CYCLE:-1}"
ACTIVE_PROJECT="${ACTIVE_PROJECT:-}"
PROJECTS_DIR="$PROJECT_DIR/projects"
GITHUB_USER="${GITHUB_USER:-}"
RESOLVED_ENGINE_BIN=""

if [ "$ENGINE" != "claude" ] && [ "$ENGINE" != "codex" ]; then
    echo "Error: ENGINE must be 'claude' or 'codex' (received: '$ENGINE')."
    exit 1
fi

# Keep Agent Teams compatibility for legacy prompts/config.
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# === Functions ===

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[$timestamp] $1"
    echo "$msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "$msg"
    fi
}

log_cycle() {
    local cycle_num=$1
    local status=$2
    local msg=$3
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Cycle #$cycle_num [$status] $msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "[$timestamp] Cycle #$cycle_num [$status] $msg"
    fi
}

check_usage_limit() {
    local output="$1"
    if echo "$output" | grep -qi "usage limit\|rate limit\|too many requests\|resource_exhausted\|overloaded\|quota\|429\|billing\|insufficient credits"; then
        return 0
    fi
    return 1
}

check_stop_requested() {
    if [ -f "$PROJECT_DIR/.auto-loop-stop" ]; then
        rm -f "$PROJECT_DIR/.auto-loop-stop"
        return 0
    fi
    return 1
}

save_state() {
    cat > "$STATE_FILE" << EOF
LOOP_COUNT=$loop_count
ERROR_COUNT=$error_count
LAST_RUN=$(date '+%Y-%m-%d %H:%M:%S')
STATUS=$1
MODEL=$MODEL_LABEL
ENGINE=$ENGINE
EOF
}

cleanup() {
    log "=== Auto Loop Shutting Down (PID $$) ==="
    rm -f "$PID_FILE"
    save_state "stopped"
    exit 0
}

snapshot_gitignore() {
    if [ "$AUTO_LOOP_PROTECT_GITIGNORE" = "0" ]; then
        echo ""
        return
    fi

    local gitignore_file="$PROJECT_DIR/.gitignore"
    local snapshot_file=""
    if [ -f "$gitignore_file" ]; then
        snapshot_file=$(mktemp)
        cp "$gitignore_file" "$snapshot_file"
    fi
    echo "$snapshot_file"
}

restore_gitignore_if_changed() {
    local snapshot_file="$1"
    if [ "$AUTO_LOOP_PROTECT_GITIGNORE" = "0" ]; then
        [ -n "$snapshot_file" ] && rm -f "$snapshot_file"
        return
    fi

    local gitignore_file="$PROJECT_DIR/.gitignore"
    local changed=0

    if [ -f "$gitignore_file" ]; then
        if [ -z "$snapshot_file" ] || [ ! -f "$snapshot_file" ]; then
            changed=1
        elif ! cmp -s "$gitignore_file" "$snapshot_file"; then
            changed=1
        fi
    else
        if [ -n "$snapshot_file" ] && [ -f "$snapshot_file" ]; then
            changed=1
        fi
    fi

    if [ "$changed" -eq 1 ]; then
        if [ -n "$snapshot_file" ] && [ -f "$snapshot_file" ]; then
            cp "$snapshot_file" "$gitignore_file"
            log_cycle "$loop_count" "GUARD" "Blocked cycle mutation of .gitignore and restored baseline"
        else
            rm -f "$gitignore_file"
            log_cycle "$loop_count" "GUARD" "Blocked cycle-created .gitignore and removed it"
        fi
    fi

    [ -n "$snapshot_file" ] && rm -f "$snapshot_file"
}

get_file_size_bytes() {
    local target_file="$1"
    if [ ! -f "$target_file" ]; then
        echo 0
        return
    fi

    if stat -c%s "$target_file" >/dev/null 2>&1; then
        stat -c%s "$target_file"
        return
    fi

    if stat -f%z "$target_file" >/dev/null 2>&1; then
        stat -f%z "$target_file"
        return
    fi

    wc -c < "$target_file" | tr -d ' '
}

rotate_logs() {
    # Keep only the latest N cycle logs
    local count
    count=$(find "$LOG_DIR" -name "cycle-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt "$MAX_LOGS" ]; then
        local to_delete=$((count - MAX_LOGS))
        find "$LOG_DIR" -name "cycle-*.log" -type f | sort | head -n "$to_delete" | xargs rm -f 2>/dev/null || true
        log "Log rotation: removed $to_delete old cycle logs"
    fi

    # Rotate main log if over 10MB
    local log_size
    log_size=$(get_file_size_bytes "$LOG_DIR/auto-loop.log")
    if [ "$log_size" -gt 10485760 ]; then
        mv "$LOG_DIR/auto-loop.log" "$LOG_DIR/auto-loop.log.old"
        log "Main log rotated (was ${log_size} bytes)"
    fi
}

cleanup_accidental_root_artifacts() {
    local removed=0
    local removed_names=""
    local f base

    # Known accidental artifacts caused by malformed shell redirections in generated commands.
    for f in "$PROJECT_DIR"/=* "$PROJECT_DIR"/口径说明*; do
        [ -f "$f" ] || continue
        if [ ! -s "$f" ]; then
            rm -f "$f"
            removed=$((removed + 1))
            base=$(basename "$f")
            if [ -z "$removed_names" ]; then
                removed_names="$base"
            else
                removed_names="$removed_names, $base"
            fi
        fi
    done

    if [ "$removed" -gt 0 ]; then
        log_cycle "$loop_count" "GUARD" "Removed accidental root zero-byte artifact(s): $removed_names"
    fi
}

scan_projects() {
    find "$PROJECTS_DIR" -maxdepth 2 -name ".project.json" 2>/dev/null
}

setup_project_repos() {
    command -v jq >/dev/null 2>&1 || { log "WARN: jq not found, skipping project repo setup"; return; }
    command -v gh >/dev/null 2>&1 || { log "WARN: gh not found, skipping GitHub repo setup"; return; }

    local project_json project_dir project_name repo
    while IFS= read -r project_json; do
        [ -f "$project_json" ] || continue
        project_dir="$(dirname "$project_json")"
        project_name=$(jq -r '.name' "$project_json" 2>/dev/null) || continue
        repo=$(jq -r '.repo' "$project_json" 2>/dev/null) || continue

        # Derive full owner/repo from .project.json repo field
        case "$repo" in
            */*) full_repo="$repo" ;;
            *)
                if [ -z "$GITHUB_USER" ]; then
                    log "WARN PROJECT[$project_name]: GITHUB_USER not set; skipping repo $repo"
                    continue
                fi
                full_repo="${GITHUB_USER}/${repo}"
                ;;
        esac

        # Ensure GitHub repo exists
        if ! gh repo view "$full_repo" >/dev/null 2>&1; then
            log "PROJECT[$project_name]: Creating GitHub repo $full_repo"
            gh repo create "$full_repo" --private 2>/dev/null || true
        fi

        # Ensure git is initialized in project dir
        if [ ! -d "$project_dir/.git" ]; then
            git -C "$project_dir" init 2>/dev/null || true
        fi

        # Ensure remote is wired
        if ! git -C "$project_dir" remote get-url origin >/dev/null 2>&1; then
            git -C "$project_dir" remote add origin "https://github.com/${full_repo}.git" 2>/dev/null || true
            log "PROJECT[$project_name]: Wired git remote → $full_repo"
        fi
    done < <(scan_projects)
}

commit_project_changes() {
    local cycle_num="$1"
    local cycle_status="$2"
    command -v jq >/dev/null 2>&1 || return 0

    local project_json project_dir project_name repo full_repo changes
    while IFS= read -r project_json; do
        [ -f "$project_json" ] || continue
        project_dir="$(dirname "$project_json")"
        project_name=$(jq -r '.name' "$project_json" 2>/dev/null) || continue
        repo=$(jq -r '.repo' "$project_json" 2>/dev/null) || continue

        case "$repo" in
            */*) full_repo="$repo" ;;
            *) full_repo="${GITHUB_USER:+${GITHUB_USER}/}${repo}" ;;
        esac

        git -C "$project_dir" remote get-url origin >/dev/null 2>&1 || continue

        changes=$(git -C "$project_dir" status --porcelain 2>/dev/null)
        [ -n "$changes" ] || continue

        git -C "$project_dir" add -A 2>/dev/null || true
        git -C "$project_dir" diff --cached --quiet 2>/dev/null && continue
        git -C "$project_dir" commit -m "cycle #${cycle_num} [${cycle_status}] $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
        git -C "$project_dir" push origin HEAD 2>/dev/null || true
        log_cycle "$cycle_num" "PROJECT" "Committed changes to $project_name → $full_repo"
    done < <(scan_projects)
}

register_new_projects() {
    local cycle_num="$1"
    command -v jq >/dev/null 2>&1 || return 0

    local dir project_name
    while IFS= read -r -d '' dir; do
        [ -f "$dir/.project.json" ] && continue
        project_name="$(basename "$dir")"
        log "PROJECT: Auto-registering new project dir '$project_name'"
        jq -n \
            --arg name "$project_name" \
            --arg repo "$project_name" \
            '{"name": $name, "repo": $repo, "components": []}' \
            > "$dir/.project.json" 2>/dev/null || true
        log_cycle "$cycle_num" "PROJECT" "Created .project.json for $project_name"
    done < <(find "$PROJECTS_DIR" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
}

save_consensus_snapshot() {
    local cycle_num="$1"
    [ -f "$CONSENSUS_FILE" ] || return 0
    local snapshot_dir
    snapshot_dir="$(dirname "$CONSENSUS_FILE")"
    cp "$CONSENSUS_FILE" "$snapshot_dir/consensus-step-$(printf '%04d' "$cycle_num").md"
}

sync_artifacts() {
    local cycle_num="$1"
    local cycle_status="$2"
    [ -n "$ACTIVE_PROJECT" ] || return 0

    local tracking_dir="$PROJECTS_DIR/$ACTIVE_PROJECT/auto-company-tracking"
    mkdir -p "$tracking_dir/docs" "$tracking_dir/logs" "$tracking_dir/memories"

    rsync -a "$PROJECT_DIR/docs/" "$tracking_dir/docs/" 2>/dev/null || true
    rsync -a "$LOG_DIR/" "$tracking_dir/logs/" 2>/dev/null || true
    rsync -a "$(dirname "$CONSENSUS_FILE")/" "$tracking_dir/memories/" 2>/dev/null || true
    [ -f "$STATE_FILE" ] && cp "$STATE_FILE" "$tracking_dir/.auto-loop-state"

    log_cycle "$cycle_num" "SYNC" "Artifacts synced to $ACTIVE_PROJECT/auto-company-tracking"
}

backup_consensus() {
    if [ -f "$CONSENSUS_FILE" ]; then
        cp "$CONSENSUS_FILE" "$CONSENSUS_FILE.bak"
    fi
}

restore_consensus() {
    if [ -f "$CONSENSUS_FILE.bak" ]; then
        cp "$CONSENSUS_FILE.bak" "$CONSENSUS_FILE"
        log "Consensus restored from backup after failed cycle"
    fi
}

validate_consensus() {
    if [ ! -s "$CONSENSUS_FILE" ]; then
        return 1
    fi
    if ! grep -q "^# Auto Company Consensus" "$CONSENSUS_FILE"; then
        return 1
    fi
    if ! grep -q "^## Next Action" "$CONSENSUS_FILE"; then
        return 1
    fi
    if ! grep -q "^## Company State" "$CONSENSUS_FILE"; then
        return 1
    fi
    return 0
}

consensus_changed_since_backup() {
    if [ ! -f "$CONSENSUS_FILE" ]; then
        return 1
    fi

    if [ ! -f "$CONSENSUS_FILE.bak" ]; then
        return 0
    fi

    if cmp -s "$CONSENSUS_FILE" "$CONSENSUS_FILE.bak"; then
        return 1
    fi

    return 0
}

resolve_codex_bin() {
    if [ -n "$CODEX_BIN" ]; then
        if [ -x "$CODEX_BIN" ]; then
            echo "$CODEX_BIN"
            return 0
        fi
        if command -v "$CODEX_BIN" >/dev/null 2>&1; then
            command -v "$CODEX_BIN"
            return 0
        fi
    fi

    # Prefer WSL-local Codex installed via nvm.
    local nvm_candidate=""
    for candidate in "$HOME"/.nvm/versions/node/*/bin/codex; do
        if [ -x "$candidate" ]; then
            nvm_candidate="$candidate"
        fi
    done
    if [ -n "$nvm_candidate" ]; then
        echo "$nvm_candidate"
        return 0
    fi

    # Fallback: ask an interactive bash shell (loads user profile).
    local interactive_candidate
    interactive_candidate=$(bash -ic 'command -v codex' 2>/dev/null | tail -n1 | tr -d '\r' || true)
    if [ -n "$interactive_candidate" ] && [ -x "$interactive_candidate" ]; then
        echo "$interactive_candidate"
        return 0
    fi

    # Last fallback: current shell PATH.
    if command -v codex >/dev/null 2>&1; then
        command -v codex
        return 0
    fi

    return 1
}

resolve_claude_bin() {
    if [ -n "$CLAUDE_BIN" ]; then
        if [ -x "$CLAUDE_BIN" ]; then
            echo "$CLAUDE_BIN"
            return 0
        fi
        if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
            command -v "$CLAUDE_BIN"
            return 0
        fi
    fi

    # Prefer WSL-local Claude CLI installed via nvm.
    local nvm_candidate=""
    for candidate in "$HOME"/.nvm/versions/node/*/bin/claude; do
        if [ -x "$candidate" ]; then
            nvm_candidate="$candidate"
        fi
    done
    if [ -n "$nvm_candidate" ]; then
        echo "$nvm_candidate"
        return 0
    fi

    # Fallback: ask an interactive bash shell (loads user profile).
    local interactive_candidate
    interactive_candidate=$(bash -ic 'command -v claude' 2>/dev/null | tail -n1 | tr -d '\r' || true)
    if [ -n "$interactive_candidate" ] && [ -x "$interactive_candidate" ]; then
        echo "$interactive_candidate"
        return 0
    fi

    # Last fallback: current shell PATH.
    if command -v claude >/dev/null 2>&1; then
        command -v claude
        return 0
    fi

    return 1
}

resolve_engine_bin() {
    case "$ENGINE" in
        claude)
            resolve_claude_bin
            ;;
        codex)
            resolve_codex_bin
            ;;
        *)
            return 1
            ;;
    esac
}

run_codex_cycle() {
    local prompt="$1"
    local output_file timeout_flag message_file

    output_file=$(mktemp)
    timeout_flag=$(mktemp)
    message_file=$(mktemp)

    set +e
    (
        cd "$PROJECT_DIR" || exit 1
        local codex_cmd=("$RESOLVED_ENGINE_BIN" "exec" "-c" "sandbox_mode=\"${CODEX_SANDBOX_MODE}\"" "-o" "$message_file")
        if [ -n "$MODEL" ]; then
            codex_cmd+=("-m" "$MODEL")
        fi
        codex_cmd+=("$prompt")
        "${codex_cmd[@]}"
    ) > "$output_file" 2>&1 &
    local codex_pid=$!

    (
        sleep "$CYCLE_TIMEOUT_SECONDS"
        if kill -0 "$codex_pid" 2>/dev/null; then
            echo "1" > "$timeout_flag"
            kill -TERM "$codex_pid" 2>/dev/null || true
            sleep 5
            kill -KILL "$codex_pid" 2>/dev/null || true
        fi
    ) &
    local watchdog_pid=$!

    wait "$codex_pid"
    EXIT_CODE=$?

    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    set -e

    OUTPUT=$(cat "$output_file")
    RESULT_MESSAGE=$(cat "$message_file" 2>/dev/null || true)
    rm -f "$output_file" "$message_file"

    if [ -s "$timeout_flag" ]; then
        CYCLE_TIMED_OUT=1
        EXIT_CODE=124
    else
        CYCLE_TIMED_OUT=0
    fi
    rm -f "$timeout_flag"
}

run_claude_cycle() {
    local prompt="$1"
    local output_file timeout_flag

    output_file=$(mktemp)
    timeout_flag=$(mktemp)

    set +e
    (
        cd "$PROJECT_DIR" || exit 1
        local claude_cmd=("$RESOLVED_ENGINE_BIN" "-p" "$prompt" "--output-format" "json")
        if [ -n "$MODEL" ]; then
            claude_cmd+=("--model" "$MODEL")
        fi
        if [ -n "$CLAUDE_PERMISSION_MODE" ]; then
            claude_cmd+=("--permission-mode" "$CLAUDE_PERMISSION_MODE")
        fi
        "${claude_cmd[@]}"
    ) > "$output_file" 2>&1 &
    local claude_pid=$!

    (
        sleep "$CYCLE_TIMEOUT_SECONDS"
        if kill -0 "$claude_pid" 2>/dev/null; then
            echo "1" > "$timeout_flag"
            kill -TERM "$claude_pid" 2>/dev/null || true
            sleep 5
            kill -KILL "$claude_pid" 2>/dev/null || true
        fi
    ) &
    local watchdog_pid=$!

    wait "$claude_pid"
    EXIT_CODE=$?

    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    set -e

    OUTPUT=$(cat "$output_file")
    RESULT_MESSAGE="$OUTPUT"
    rm -f "$output_file"

    if [ -s "$timeout_flag" ]; then
        CYCLE_TIMED_OUT=1
        EXIT_CODE=124
    else
        CYCLE_TIMED_OUT=0
    fi
    rm -f "$timeout_flag"
}

run_engine_cycle() {
    local prompt="$1"
    case "$ENGINE" in
        claude)
            run_claude_cycle "$prompt"
            ;;
        codex)
            run_codex_cycle "$prompt"
            ;;
        *)
            echo "Error: Unsupported ENGINE '$ENGINE'" >&2
            return 1
            ;;
    esac
}

extract_cycle_metadata() {
    RESULT_TEXT=""
    CYCLE_COST="N/A"
    CYCLE_SUBTYPE="unknown"
    CYCLE_TYPE="${ENGINE}_exec"

    if [ "$ENGINE" = "claude" ]; then
        if command -v jq >/dev/null 2>&1; then
            RESULT_TEXT=$(echo "$RESULT_MESSAGE" | jq -r '.result // .message // .output_text // empty' 2>/dev/null | head -c 2000 || true)
            if [ -z "$RESULT_TEXT" ]; then
                RESULT_TEXT=$(echo "$RESULT_MESSAGE" | jq -r '.. | .text? // empty' 2>/dev/null | head -c 2000 || true)
            fi

            parsed_cost=$(echo "$RESULT_MESSAGE" | jq -r '.total_cost_usd // .cost_usd // empty' 2>/dev/null || true)
            if [ -n "$parsed_cost" ]; then
                CYCLE_COST="$parsed_cost"
            fi

            parsed_subtype=$(echo "$RESULT_MESSAGE" | jq -r '.subtype // empty' 2>/dev/null || true)
            if [ -n "$parsed_subtype" ]; then
                CYCLE_SUBTYPE="$parsed_subtype"
            fi

            parsed_type=$(echo "$RESULT_MESSAGE" | jq -r '.type // empty' 2>/dev/null || true)
            if [ -n "$parsed_type" ]; then
                CYCLE_TYPE="$parsed_type"
            fi
        fi

        if [ -z "$RESULT_TEXT" ]; then
            RESULT_TEXT=$(echo "$OUTPUT" | head -c 2000 || true)
        fi

        if [ "$CYCLE_SUBTYPE" = "unknown" ]; then
            if [ "$EXIT_CODE" -eq 0 ]; then
                CYCLE_SUBTYPE="success"
            else
                CYCLE_SUBTYPE="error"
            fi
        fi
        return
    fi

    RESULT_TEXT=$(echo "$RESULT_MESSAGE" | head -c 2000 || true)
    if [ -z "$RESULT_TEXT" ]; then
        RESULT_TEXT=$(echo "$OUTPUT" | head -c 2000 || true)
    fi

    if [ "$EXIT_CODE" -eq 0 ]; then
        CYCLE_SUBTYPE="success"
    else
        CYCLE_SUBTYPE="error"
    fi
}

# === Setup ===

mkdir -p "$LOG_DIR" "$PROJECT_DIR/memories"

# Clean up stale stop file from previous run
rm -f "$PROJECT_DIR/.auto-loop-stop"

# Check for existing instance
if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "Auto loop already running (PID $existing_pid). Stop it first with ./stop-loop.sh"
        exit 1
    fi
fi

# Check dependencies
if ! RESOLVED_ENGINE_BIN="$(resolve_engine_bin)"; then
    if [ "$ENGINE" = "claude" ]; then
        echo "Error: Claude CLI not found. Install Claude Code in WSL and verify with 'claude --version'."
    else
        echo "Error: Codex CLI not found. Install Codex in WSL and verify with 'codex --version'."
    fi
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: PROMPT.md not found at $PROMPT_FILE"
    exit 1
fi

# Write PID file
echo $$ > "$PID_FILE"

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT SIGHUP

# Initialize counters
loop_count=0
error_count=0

log "=== Auto Company Loop Started (PID $$) ==="
log "Project: $PROJECT_DIR"
if [ "$ENGINE" = "codex" ]; then
    log "Engine: codex | Model: $MODEL_LABEL | Sandbox: $CODEX_SANDBOX_MODE"
else
    log "Engine: claude | Model: $MODEL_LABEL | PermissionMode: $CLAUDE_PERMISSION_MODE"
fi
log "Engine bin: $RESOLVED_ENGINE_BIN"
engine_version=$("$RESOLVED_ENGINE_BIN" --version 2>/dev/null | head -n1 || true)
case "$RESOLVED_ENGINE_BIN" in
    /mnt/c/*)
        if [ "$ENGINE" = "codex" ]; then
            log "Warning: Codex binary resolves to Windows-mounted path. Prefer WSL-local install for stability."
        else
            log "Warning: Claude binary resolves to Windows-mounted path. Prefer WSL-local install for stability."
        fi
        ;;
esac
if [ -n "$engine_version" ]; then
    if [ "$ENGINE" = "codex" ]; then
        log "Codex version: $engine_version"
    else
        log "Claude version: $engine_version"
    fi
fi
log "Interval: ${LOOP_INTERVAL}s | Timeout: ${CYCLE_TIMEOUT_SECONDS}s | Breaker: ${MAX_CONSECUTIVE_ERRORS} errors"
log "Single-cycle mode: $SINGLE_CYCLE"

# === Project Repo Setup ===
setup_project_repos

# === Active Project Guard ===
_project_count=$(scan_projects | wc -l | tr -d ' ')
if [ -z "$ACTIVE_PROJECT" ] && [ "$_project_count" -gt 1 ]; then
    log "Error: Multiple projects found but ACTIVE_PROJECT is not set."
    log "Set ACTIVE_PROJECT in config/auto-company.env and restart."
    exit 1
fi
if [ -z "$ACTIVE_PROJECT" ] && [ "$_project_count" -eq 1 ]; then
    ACTIVE_PROJECT=$(jq -r '.name' "$(scan_projects)" 2>/dev/null || true)
    log "ACTIVE_PROJECT auto-set to: $ACTIVE_PROJECT"
fi

# === Main Loop ===

while true; do
    # Check for stop request
    if check_stop_requested; then
        log "Stop requested. Shutting down gracefully."
        cleanup
    fi

    loop_count=$((loop_count + 1))
    cycle_log="$LOG_DIR/cycle-$(printf '%04d' "$loop_count")-$(date '+%Y%m%d-%H%M%S').log"

    log_cycle "$loop_count" "START" "Beginning work cycle"
    save_state "running"

    # Log rotation
    rotate_logs

    # Backup consensus before cycle
    backup_consensus
    gitignore_snapshot=$(snapshot_gitignore)

    # Build prompt with consensus pre-injected
    PROMPT=$(cat "$PROMPT_FILE")
    CONSENSUS=$(cat "$CONSENSUS_FILE" 2>/dev/null || echo "No consensus file found. This is the very first cycle.")
    FULL_PROMPT="$PROMPT

---

## Runtime Guardrails (must follow)

1. Early in the cycle, create or update \`memories/consensus.md\` with the required section skeleton.
2. If work scope is large, persist partial decisions to \`memories/consensus.md\` before deep dives.
3. Prefer shipping one completed milestone over broad parallel exploration.
4. Never write files via shell heredoc (\`cat <<EOF\`). Use \`apply_patch\` for file creates/edits.
5. Never execute shell lines that begin with \`>\` or \`>=\`; treat them as text and keep them inside markdown/files.

---

## Current Consensus (pre-loaded, do NOT re-read this file)

$CONSENSUS

---

This is Cycle #$loop_count. Act decisively."

    # Run selected engine in headless mode with per-cycle timeout
    run_engine_cycle "$FULL_PROMPT"

    # Save full output to cycle log
    echo "$OUTPUT" > "$cycle_log"

    # Clean up known malformed-redirection artifacts created by bad generated shell commands.
    cleanup_accidental_root_artifacts
    restore_gitignore_if_changed "$gitignore_snapshot"

    # Extract result fields for status classification
    extract_cycle_metadata

    cycle_failed_reason=""
    cycle_soft_timeout=0
    if [ "$CYCLE_TIMED_OUT" -eq 1 ]; then
        if validate_consensus && consensus_changed_since_backup; then
            cycle_soft_timeout=1
        else
            cycle_failed_reason="Timed out after ${CYCLE_TIMEOUT_SECONDS}s"
        fi
    elif [ "$EXIT_CODE" -ne 0 ]; then
        cycle_failed_reason="Exit code $EXIT_CODE"
    elif ! validate_consensus; then
        cycle_failed_reason="consensus.md validation failed after cycle"
    fi

    if [ "$cycle_soft_timeout" -eq 1 ]; then
        log_cycle "$loop_count" "OK" "Timed out after ${CYCLE_TIMEOUT_SECONDS}s but consensus was updated; keeping progress (cost: ${CYCLE_COST}, subtype: ${CYCLE_SUBTYPE})"
        if [ -n "$RESULT_TEXT" ]; then
            log_cycle "$loop_count" "SUMMARY" "$(echo "$RESULT_TEXT" | head -c 300)"
        fi
        error_count=0
    elif [ -z "$cycle_failed_reason" ]; then
        log_cycle "$loop_count" "OK" "Completed (cost: ${CYCLE_COST}, subtype: ${CYCLE_SUBTYPE})"
        if [ -n "$RESULT_TEXT" ]; then
            log_cycle "$loop_count" "SUMMARY" "$(echo "$RESULT_TEXT" | head -c 300)"
        fi
        error_count=0
    else
        error_count=$((error_count + 1))
        log_cycle "$loop_count" "FAIL" "$cycle_failed_reason (cost: ${CYCLE_COST}, subtype: ${CYCLE_SUBTYPE}, errors: $error_count/$MAX_CONSECUTIVE_ERRORS)"

        # Restore consensus on hard failure
        restore_consensus

        # Check for usage limit
        if check_usage_limit "$OUTPUT"; then
            log_cycle "$loop_count" "LIMIT" "API usage limit detected. Waiting ${LIMIT_WAIT_SECONDS}s..."
            save_state "waiting_limit"
            sleep "$LIMIT_WAIT_SECONDS"
            error_count=0
            continue
        fi

        # Circuit breaker
        if [ "$error_count" -ge "$MAX_CONSECUTIVE_ERRORS" ]; then
            log_cycle "$loop_count" "BREAKER" "Circuit breaker tripped! Cooling down ${COOLDOWN_SECONDS}s..."
            save_state "circuit_break"
            sleep "$COOLDOWN_SECONDS"
            error_count=0
            log "Circuit breaker reset. Resuming..."
        fi
    fi

    if [ "$cycle_soft_timeout" -eq 1 ]; then
        _artifact_status="ok:timeout"
    elif [ -z "$cycle_failed_reason" ]; then
        _artifact_status="ok"
    else
        _artifact_status="fail"
    fi
    if [ "$_artifact_status" != "fail" ]; then
        save_consensus_snapshot "$loop_count"
    fi
    register_new_projects "$loop_count"
    sync_artifacts "$loop_count" "$_artifact_status"
    commit_project_changes "$loop_count" "$_artifact_status"

    save_state "idle"

    if [ "$SINGLE_CYCLE" = "1" ]; then
        log_cycle "$loop_count" "DONE" "Single-cycle mode: exiting. Edit consensus.md then rerun to continue."
        cleanup
    fi

    log_cycle "$loop_count" "WAIT" "Sleeping ${LOOP_INTERVAL}s before next cycle..."
    sleep "$LOOP_INTERVAL"
done
