# Auto Company Index

## Purpose

This file provides a quick reference for the repository's directory structure, script responsibilities, and call chains - for maintenance and troubleshooting.

## Directory Structure (current)

### Implementation Directories (canonical script entry points)

- `scripts/windows/`: Windows control, keep-alive, and autostart script implementations
- `scripts/core/`: Main loop and core control script implementations
- `scripts/wsl/`: WSL `systemd --user` daemon script implementations
- `scripts/macos/`: macOS `launchd` daemon script implementations

Note: the root directory no longer holds script wrapper shims - all execution and maintenance goes through `scripts/`.

### Other Key Directories

- `docs/`: Documentation
- `logs/`: Runtime logs
- `memories/`: Consensus files
- `projects/`: Projects produced by the autonomous company

## Core Execution Logic (Win + WSL)

Default call chain:

`scripts/windows/start-win.ps1` -> WSL `systemd --user auto-company.service` -> `scripts/core/auto-loop.sh`

Notes:
- Default engine is `ENGINE=claude`
- Switch to Codex via `.auto-loop.env` or `start-win.ps1 -Engine codex`
- No automatic engine fallback - missing engine fails immediately

Stop chain:

`scripts/windows/stop-win.ps1` -> stops `auto-company.service` + stops `awake guardian` + stops `wsl anchor`

## Script Responsibility Table (entry / daemon / autostart / diagnostics)

| Category | Script Path | Primary Responsibility |
|---|---|---|
| Entry | `scripts/windows/start-win.ps1` | Starts WSL daemon, writes `.auto-loop.env` (supports `ENGINE/CLAUDE_PERMISSION_MODE/CODEX_SANDBOX_MODE`), starts sleep prevention and WSL keepalive |
| Entry | `scripts/windows/stop-win.ps1` | Stops daemon and reclaims sleep prevention and WSL keepalive |
| Entry | `scripts/windows/status-win.ps1` | Summarizes status across all five layers: guardian / keepalive / autostart / daemon / loop |
| Diagnostics | `scripts/windows/monitor-win.ps1` | Real-time log streaming |
| Diagnostics | `scripts/windows/last-win.ps1` | Most recent full cycle output |
| Diagnostics | `scripts/windows/cycles-win.ps1` | Cycle summary |
| Diagnostics | `scripts/windows/dashboard-win.ps1` | Launches local web visualization dashboard |
| Keep-alive | `scripts/windows/awake-guardian-win.ps1` | Prevents system sleep at runtime (`start/stop/status/run`) |
| Keep-alive | `scripts/windows/wsl-anchor-win.ps1` | Keeps WSL session resident (`start/stop/status/run`) |
| Autostart | `scripts/windows/enable-autostart-win.ps1` | Creates login autostart task |
| Autostart | `scripts/windows/disable-autostart-win.ps1` | Removes login autostart task |
| Autostart | `scripts/windows/autostart-status-win.ps1` | Queries autostart task status |
| Daemon | `scripts/wsl/install-wsl-daemon.sh` | Installs and enables `auto-company.service` |
| Daemon | `scripts/wsl/uninstall-wsl-daemon.sh` | Uninstalls WSL daemon |
| Daemon | `scripts/wsl/wsl-daemon-status.sh` | Queries WSL daemon status |
| Daemon | `scripts/macos/install-daemon.sh` | macOS launchd install/uninstall |
| Core | `scripts/core/auto-loop.sh` | Main loop execution, circuit breaking, logging, consensus updates |
| Core | `scripts/core/monitor.sh` | Core status/log output |
| Core | `scripts/core/stop-loop.sh` | Core stop/pause/resume control |

## Quick Troubleshooting Path

1. Start with `scripts/windows/status-win.ps1`
2. Then check `scripts/windows/dashboard-win.ps1` or `scripts/windows/monitor-win.ps1`
3. For daemon issues, check `scripts/wsl/wsl-daemon-status.sh`
4. For autostart issues, check `scripts/windows/autostart-status-win.ps1` (permission problems - try admin PowerShell first)

## Maintenance Rules

1. New features go into the implementation scripts under `scripts/` first.
2. Documentation changes must be synced across:
   - `README.md`
   - `README-ZH.md`
   - `docs/windows-setup.md`
   - This index file `INDEX.md`
