# nekode wait — Pipe-based session monitoring for Nekode

## Install

```bash
# Build and install nekode to ~/.nekode/bin/
make install

# Add to your shell profile (~/.zshrc)
export PATH="$HOME/.nekode/bin:$PATH"
```

Restart your shell (or `source ~/.zshrc`), then `which nekode` should point to `~/.nekode/bin/nekode`.

## Overview

`nekode wait` is a CLI mode that integrates arbitrary long-running commands into Nekode's session monitoring. Pipe any command's output through `nekode` and it appears as a live session in the menubar (and as a desktop pet if enabled). When the command finishes, the session transitions to an attention state — the pet walks toward your cursor, the menubar shows it as needing attention — so you get notified without watching the terminal.

## Usage

```bash
# Basic usage — pipe any command
cargo build --release 2>&1 | nekode

# With a custom display name
npm run build | nekode wait --name "npm build"

# With explicit project directory
terraform apply | nekode wait --project ~/infra/prod

# Long-running test suite
make test 2>&1 | nekode wait --name "test suite"
```

## How it works

1. **Start:** `nekode wait` creates a session file at `~/.nekode/sessions/{pid}.json` with status `working`
2. **Running:** Reads stdin and passes it through to stdout (transparent in the pipeline). Periodically updates `last_activity` in the session file
3. **Done:** When stdin reaches EOF (the upstream command finished), transitions to `waiting_input`. The pet enters alerting mode and approaches your cursor
4. **Dismiss:** `nekode wait` blocks, waiting for Enter or Ctrl+C. On dismiss, the process exits and the PID liveness check cleans up the session

## CLI interface

```
USAGE: nekode wait [--name <name>] [--project <path>]

OPTIONS:
  --name <name>       Display name for the session (default: auto-detected
                      from parent process command line)
  --project <path>    Project directory (default: current working directory)
  -h, --help          Print this help message
  -V, --version       Print version
```

## Session JSON

`nekode wait` writes standard Nekode session JSON with `"source": "cli"`:

```json
{
  "session_id": "nekode-wait-12345",
  "project_path": "/Users/you/myapp",
  "project_name": "myapp",
  "branch": "main",
  "status": "working",
  "last_activity": "2026-03-05T10:00:00.000Z",
  "started_at": "2026-03-05T10:00:00.000Z",
  "pid": 12345,
  "pid_start_time": 1741176000.0,
  "source": "cli",
  "session_name": "cargo build",
  "last_tool": "pipe",
  "last_tool_detail": "reading stdin..."
}
```

## Integration

### Menubar
Sessions from `nekode wait` appear alongside Claude Code and opencode sessions with a "CLI" source badge (teal). No configuration needed — the SessionManager file watcher picks up any valid session JSON automatically.

### Desktop Pets
If Desktop Pets is enabled, `nekode wait` sessions get their own pet. The pet:
- **While running:** sits attentively (same as `working` status)
- **When done:** enters alerting mode with 4-stage attention escalation (perk up → approach → insistent → urgent), walking toward your cursor with a "?" speech bubble
- **On dismiss:** despawns when `nekode wait` exits

### Raycast Extension
`nekode wait` sessions appear in the Raycast extension with a "CLI" source tag.

## Architecture

`nekode wait` is a subcommand of the `nekode` Swift CLI target in the Nekode Xcode project, sharing the `Models/` group (Session, SessionStatus, Config) with the menubar app and `nekode hook`. It ships inside the `.app` bundle at `Contents/MacOS/nekode`.

### Files

| File | Purpose |
|------|---------|
| `menubar/Nekode/CLI/CatWaitMain.swift` | CLI entry point, argument parsing, session lifecycle |
| `menubar/Nekode/CLI/PipeMonitor.swift` | stdin→stdout passthrough, EOF detection, activity timer |

### Limitations

- **No exit code detection** from the piped command. In a shell pipeline (`cmd | nekode`), `nekode wait` cannot see cmd's exit code — that's a fundamental shell limitation. The session always transitions to `waiting_input` on EOF. Users see the command output (passthrough) and judge success themselves.
- **`nekode wait` must stay alive** for the session to remain visible. If you Ctrl+C before the upstream command finishes, the session disappears immediately (PID liveness check).
- **No progress tracking.** `nekode wait` cannot infer how far along a build is. The pet shows "working" the entire time.

## Future ideas

- `--timeout <seconds>` — auto-dismiss after N seconds instead of blocking forever
- `--notify` — send a macOS notification on completion in addition to the pet behavior
- `--fail-status` — use a wrapper to detect exit codes: `cmd; echo "EXIT:$?" | nekode wait --fail-status`
- Exit code detection via `$PIPESTATUS` integration or a subcommand mode: `nekode wait -- cargo build`
