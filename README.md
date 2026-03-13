# Nekode

[![GitHub release](https://img.shields.io/github/v/release/jakobserlier/nekode?v=1)](https://github.com/jakobserlier/nekode/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Know which AI coding sessions need you in one place.**

A macOS menubar app that monitors your AI coding sessions at a glance — so you only switch when something actually needs you. Works with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [opencode](https://opencode.ai).

<p align="center">
  <img src="docs/menubar-light.png" alt="Nekode menubar popup (light mode)" width="340">
  &nbsp;&nbsp;
  <img src="docs/menubar-dark.png" alt="Nekode menubar popup (dark mode)" width="340">
</p>

<p align="center"><em>Monitoring Claude Code and opencode sessions side by side — light and dark mode.</em></p>

## Features

**At-a-glance status.** A floating menubar panel shows all active sessions with color-coded badges: idle, working, waiting for input, waiting for permission, compacting. See the current prompt or tool in use (e.g. "Editing auth.ts") without switching windows.

**Jump directly to any session.** Click a session card to raise its VS Code, Cursor, or iTerm2 window — or stay on the keyboard. Arrow keys to browse, Enter to jump, Tab to switch tabs.

**Refocus mode.** Hit a global hotkey to overlay numbered badges (1–9) on every session card, then press the number to jump instantly.

<p align="center">
  <img src="docs/menubar-refocus.png" alt="Nekode refocus mode with numbered badges" width="340">
</p>

**Recent Projects.** A second tab keeps session history so you can reopen past projects easily.

<p align="center">
  <img src="docs/menubar-recent.png" alt="Nekode recent projects tab" width="340">
</p>

**Compact mode.** Press Cmd+M to collapse the panel to a slim header bar showing just the status counts. Press Cmd+M again to switch back. Click the header or use the refocus shortcut to temporarily expand, or press Escape to return focus to your previous app.

<p align="center">
  <img src="docs/menubar-compact-light.png" alt="Nekode compact mode showing header-only view" width="340">
</p>

Works with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [opencode](https://opencode.ai).

## Installation

### Step 1: Install the app

**Homebrew:**

```bash
brew tap jakobserlier/nekode
brew install --cask nekode
```

Or [download the latest release](https://github.com/jakobserlier/nekode/releases/latest) — the app is signed and notarized by Apple.

### Step 2: Connect your tools

Follow the app's instructions to install Claude Code and/or opencode plugin.

## Privacy

**No network access. No analytics. No telemetry. All data stays on your machine.**

Nekode stores only:

- Session status (idle / working / waiting)
- Project directory name
- Last activity timestamp
- Current tool or prompt context

This data lives in `~/.nekode/sessions/` as plain JSON files. You can inspect it anytime:

```bash
ls ~/.nekode/sessions/
cat ~/.nekode/sessions/*.json | python3 -m json.tool
```

## FAQ

**Does Nekode slow down my coding tool?**
No. The plugin writes a small JSON file on each event and returns immediately. There is no measurable impact on performance.

**Do I need to configure anything per project?**
No. Once the plugin is installed, all sessions are automatically tracked. No per-project setup required.

**Does it work with VS Code and Cursor?**
Yes. Clicking a session card focuses the correct project window.

**Does it work with iTerm2?**
Yes. Clicking a session card raises the correct iTerm2 window, selects the tab, and focuses the pane — even with split panes or multiple windows.

> [!NOTE]
> Requires macOS Automation permission. You'll be prompted to grant it on first use.

**Does it work with Warp or other terminals?**
It activates the app but cannot target a specific terminal tab. You'll need to find the right tab manually.

**How does Nekode name sessions?**
By default, the project directory name (e.g. `/path/to/my-app` shows as "my-app"). In Claude Code, you can rename a session with `/rename` and Nekode picks that up.

**My panel shrank to just the header bar — how do I get it back?**
You activated compact mode (Cmd+M). Press Cmd+M again to return to the normal view. You can also click the header to temporarily expand and see your sessions. An amber underline under "Nekode" indicates compact mode is active.

**No sessions are showing up — what do I check?**
First, make sure you restarted sessions after installing the plugin. Then check if session files exist: `ls ~/.nekode/sessions/`. If the directory is empty, the plugin isn't writing data — verify it's installed correctly (see Step 2). If files exist but the menubar shows nothing, try restarting the Nekode app.

**What happens if opencode (or Claude Code) crashes?**
Nekode detects dead sessions automatically. It checks whether each session's process is still running and removes stale entries. No manual cleanup needed.

**Does the opencode plugin need Node.js or Bun installed separately?**
No. The plugin runs inside opencode's built-in Bun runtime. You don't need to install anything beyond the plugin file itself.

**Why does the app need to be in /Applications/?**
The Claude Code plugin looks for `nekode hook` inside `/Applications/Nekode.app`. Installing elsewhere breaks the hook path. (The opencode plugin writes session files directly and does not need the app in a specific location.)

## Uninstall

```bash
# Remove the menubar app
rm -rf /Applications/Nekode.app

# Remove the Claude Code plugin
claude plugin remove nekode
claude plugin marketplace remove nekode

# Remove the opencode plugin
rm ~/.config/opencode/plugins/nekode.js

# Remove session data and config
rm -rf ~/.nekode
```

If installed via Homebrew: `brew uninstall --cask nekode`

<details>
<summary>How it works</summary>

Both tools write to the same session store — the menubar app doesn't care where the data comes from.

```
┌─────────────┐    hook fires     ┌──────────────┐
│ Claude Code │ ────────────────> │ nekode hook  │ ──┐
│  (session)  │  SessionStart,    │   (Swift)    │   │  writes JSON
│             │  Stop, PreTool,   │              │   │  per-session
└─────────────┘  Notification,…   └──────────────┘   │
                                                   ▼
                                           ┌─────────────────────┐
                                           │ ~/.nekode/sessions  │
                                           │   ├── 123.json      │
                                           │   ├── 456.json      │
                                           │   └── 789.json      │
                                           └──────────┬──────────┘
┌─────────────┐   plugin event    ┌────────────┐  ▲   │
│  opencode   │ ────────────────> │ JS plugin  │ ─┘   │ file watcher
│  (session)  │  session.status,  │            │      ▼
│             │  tool.execute,…   │            │  ┌──────────────┐
└─────────────┘                   └────────────┘  │ Menubar app  │
                                                  │ (live status)│
                                                  └──────────────┘
```

1. Each tool has its own plugin that translates events into session state
2. **Claude Code**: hooks invoke `nekode hook` (a Swift CLI), which writes JSON session files
3. **opencode**: a JS plugin listens to events and writes the same JSON format directly
4. Both write to `~/.nekode/sessions/` — the menubar app watches this directory and displays live status

</details>

<details>
<summary>Build from source</summary>

Requires Xcode 16+ and macOS 13+.

```bash
git clone https://github.com/jakobserlier/nekode.git
cd nekode
./scripts/bundle-macos.sh
cp -R dist/Nekode.app /Applications/
open /Applications/Nekode.app
```

</details>

## License

MIT
