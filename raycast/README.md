# Nekode

Monitor your AI coding sessions from Raycast. See which sessions need attention, what each one is doing, and jump to the right terminal or editor in one action.

## Prerequisites

This extension requires the **Nekode macOS menubar app** to be installed. The app monitors your AI coding sessions and writes status data that this extension reads.

Install via Homebrew:

```bash
brew tap Jakob-98/nekode
brew install --cask nekode
```

Or [download the latest release](https://github.com/Jakob-98/nekode/releases/latest).

After installing, follow the app's instructions to connect your tools (Claude Code and/or opencode).

## Features

- **Session list** with live status: idle, working, waiting for input, waiting for permission, compacting
- **Status filtering** via dropdown: show all sessions, only those needing attention, active, or idle
- **Detail pane** with full session metadata: project, branch, terminal, last tool, last prompt
- **Jump to session**: open the terminal or editor (VS Code, Cursor, iTerm2, etc.) for any session
- **Reset to idle**: manually reset a stuck session's status

## How It Works

The Nekode menubar app writes session files to `~/.nekode/sessions/` via plugins for Claude Code and opencode. This Raycast extension reads those files and displays live session status, polling every 2 seconds. No network access is involved — all data stays on your machine.
