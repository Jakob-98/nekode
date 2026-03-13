# VS Code Copilot Agent Integration

## Background

VS Code Copilot agent mode has a hooks system nearly identical to Claude Code hooks: same event names, same JSON-over-stdin/stdout protocol. Our existing `nekode hook` subcommand already speaks this protocol.

## Goal

Copilot agent sessions appear in Nekode alongside Claude Code and opencode sessions, with no new binary needed.

## How it works

```
VS Code Copilot agent
  -> hook fires (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, SubagentStart, SubagentStop, Stop)
  -> hooks.json points to run-hook.sh
  -> run-hook.sh invokes nekode hook --source copilot <event>
  -> nekode hook writes ~/.nekode/sessions/{pid}.json
  -> Nekode picks it up via file watcher
```

## Architecture

### Hook files location

Hook files live at `~/.nekode/plugins/copilot/hooks/`:
- `hooks.json` — flat array of hook commands (VS Code format, no matcher wrappers)
- `run-hook.sh` — shim script that locates and invokes `nekode hook`

VS Code discovers these via the `chat.hookFilesLocations` setting in `~/Library/Application Support/Code/User/settings.json`:

```jsonc
{
  "chat.hookFilesLocations": {
    "~/.nekode/plugins/copilot/hooks": true
  }
}
```

**Important:** VS Code does NOT use `github.copilot.chat.agent.hooks` in settings.json for hook commands. That key doesn't load hook files. The only way to register external hooks is through `chat.hookFilesLocations` (or placing files in `.github/hooks/` within a workspace).

### hooks.json format

VS Code uses a **flat format** — an array of command objects, no `matcher` wrapper:

```json
[
  { "type": "command", "command": "/path/to/run-hook.sh SessionStart" },
  { "type": "command", "command": "/path/to/run-hook.sh Stop" }
]
```

This differs from Claude Code's nested format (`{ "matcher": "...", "hooks": [...] }`).

### JSON field naming

VS Code Copilot sends **camelCase** fields (`sessionId`, `hookEventName`), while Claude Code sends **snake_case** (`session_id`, `hook_event_name`). `HookInput.swift` uses a flexible decoder (`FlexKey`) that tries camelCase first, then falls back to snake_case.

### Source tagging

`nekode hook` accepts a `--source <value>` flag before the hook event name:

```
nekode hook --source copilot SessionStart
```

This sets `"source": "copilot"` on the session JSON. The UI displays it as "CP" via `Session.sourceLabel`.

## Implementation details

### Files

| File | Purpose |
|------|---------|
| `plugins/copilot/hooks/hooks.json` | Hook definitions (flat format, all 7 events) |
| `plugins/copilot/hooks/run-hook.sh` | Shim that finds nekode and invokes it with `hook --source copilot` |
| `menubar/Nekode/Hook/HookMain.swift` | `--source` flag parsing |
| `menubar/Nekode/Hook/HookHandler.swift` | Source propagation to session |
| `menubar/Nekode/Hook/HookInput.swift` | Flexible camelCase/snake_case decoder |
| `menubar/Nekode/Models/Session.swift` | `"copilot"` -> `"CP"` source label |
| `menubar/Nekode/Services/PluginManager.swift` | Install/remove/detect using `chat.hookFilesLocations` |
| `menubar/Nekode/Views/SettingsSection.swift` | Copilot row in MonitoredToolsView |
| `menubar/Nekode/Views/EmptyStateView.swift` | Copilot row in empty state views |
| `Makefile` | Bundles copilot hooks into Debug app Resources |
| `scripts/bundle-macos.sh` | Bundles copilot hooks into release app Resources |

### Install flow (PluginManager)

1. Copy `hooks.json` and `run-hook.sh` from app bundle Resources to `~/.nekode/plugins/copilot/hooks/`
2. Read VS Code `settings.json` (JSONC — strip comments and trailing commas before parsing)
3. Add `"~/.nekode/plugins/copilot/hooks": true` to `chat.hookFilesLocations`
4. Clean up legacy `github.copilot.chat.agent.hooks` key if present
5. Write back to settings.json

### Detection

- VS Code installed: check `~/Library/Application Support/Code/User/` exists
- Plugin installed: check `chat.hookFilesLocations` contains `~/.nekode/plugins/copilot/hooks`

### Events handled

`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `SubagentStart`, `SubagentStop`, `Stop`

## Testing

### Manual pipeline test

```bash
echo '{"sessionId":"test-123","cwd":"/tmp","hookEventName":"SessionStart"}' | ~/.nekode/plugins/copilot/hooks/run-hook.sh SessionStart
```

Check `~/.nekode/log/nekode.log` for SHIM and HOOK entries.

### End-to-end test

1. Restart VS Code after install
2. Start a Copilot agent chat session
3. Verify session appears in Nekode menubar
4. Check VS Code Output panel -> "GitHub Copilot Chat Hooks" for diagnostics

## Open questions

- Should Copilot sessions get a distinct pet sprite or just a label?
- Do we need special handling for `SubagentStart`/`SubagentStop` beyond basic session tracking?
