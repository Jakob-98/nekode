# catwait — Pipe-based session monitoring for CatAssistant

## Install

```bash
# Build and install catwait + cathook to ~/.cat/bin/
make install

# Add to your shell profile (~/.zshrc)
export PATH="$HOME/.cat/bin:$PATH"
```

Restart your shell (or `source ~/.zshrc`), then `which catwait` should point to `~/.cat/bin/catwait`.

## Overview

`catwait` is a CLI tool that integrates arbitrary long-running commands into CatAssistant's session monitoring. Pipe any command's output through `catwait` and it appears as a live session in the menubar (and as a desktop pet if enabled). When the command finishes, the session transitions to an attention state — the pet walks toward your cursor, the menubar shows it as needing attention — so you get notified without watching the terminal.

## Usage

```bash
# Basic usage — pipe any command
cargo build --release 2>&1 | catwait

# With a custom display name
npm run build | catwait --name "npm build"

# With explicit project directory
terraform apply | catwait --project ~/infra/prod

# Long-running test suite
make test 2>&1 | catwait --name "test suite"
```

## How it works

1. **Start:** `catwait` creates a session file at `~/.cat/sessions/{pid}.json` with status `working`
2. **Running:** Reads stdin and passes it through to stdout (transparent in the pipeline). Periodically updates `last_activity` in the session file
3. **Done:** When stdin reaches EOF (the upstream command finished), transitions to `waiting_input`. The pet enters alerting mode and approaches your cursor
4. **Dismiss:** `catwait` blocks, waiting for Enter or Ctrl+C. On dismiss, the process exits and the PID liveness check cleans up the session

## CLI interface

```
USAGE: catwait [--name <name>] [--project <path>]

OPTIONS:
  --name <name>       Display name for the session (default: auto-detected
                      from parent process command line)
  --project <path>    Project directory (default: current working directory)
  -h, --help          Print this help message
  -V, --version       Print version
```

## Session JSON

catwait writes standard CatAssistant session JSON with `"source": "cli"`:

```json
{
  "session_id": "catwait-12345",
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
Sessions from catwait appear alongside Claude Code and opencode sessions with a "CLI" source badge (teal). No configuration needed — the SessionManager file watcher picks up any valid session JSON automatically.

### Desktop Pets
If Desktop Pets is enabled, catwait sessions get their own pet. The pet:
- **While running:** sits attentively (same as `working` status)
- **When done:** enters alerting mode with 4-stage attention escalation (perk up → approach → insistent → urgent), walking toward your cursor with a "?" speech bubble
- **On dismiss:** despawns when catwait exits

### Raycast Extension
catwait sessions appear in the Raycast extension with a "CLI" source tag.

## Architecture

`catwait` is a Swift CLI target in the CatAssistant Xcode project, sharing the `Models/` group (Session, SessionStatus, Config) with the menubar app and cathook. It ships inside the `.app` bundle at `Contents/MacOS/catwait`.

### Files

| File | Purpose |
|------|---------|
| `menubar/CatAssistant/CatWait/CatWaitMain.swift` | CLI entry point, argument parsing, session lifecycle |
| `menubar/CatAssistant/CatWait/PipeMonitor.swift` | stdin→stdout passthrough, EOF detection, activity timer |

### Limitations

- **No exit code detection** from the piped command. In a shell pipeline (`cmd | catwait`), catwait cannot see cmd's exit code — that's a fundamental shell limitation. The session always transitions to `waiting_input` on EOF. Users see the command output (passthrough) and judge success themselves.
- **catwait must stay alive** for the session to remain visible. If you Ctrl+C catwait before the upstream command finishes, the session disappears immediately (PID liveness check).
- **No progress tracking.** catwait cannot infer how far along a build is. The pet shows "working" the entire time.

## Future ideas

- `--timeout <seconds>` — auto-dismiss after N seconds instead of blocking forever
- `--notify` — send a macOS notification on completion in addition to the pet behavior
- `--fail-status` — use a wrapper to detect exit codes: `cmd; echo "EXIT:$?" | catwait --fail-status`
- Exit code detection via `$PIPESTATUS` integration or a subcommand mode: `catwait -- cargo build`
