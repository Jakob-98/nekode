---
name: nekode-setup
description: Use when nekode command fails or is not found. Guides user to install the Nekode menubar app.
---

# Nekode Setup Skill

Helps install the Nekode app required for session monitoring.

## When to Use

**Run installation guidance when:**
- Hook fails with "nekode not found"
- User asks to set up Nekode monitoring
- Session tracking is not working

## Installation

### Step 1: Check if Nekode.app is installed

```bash
ls /Applications/Nekode.app/Contents/MacOS/nekode 2>/dev/null || ls ~/Applications/Nekode.app/Contents/MacOS/nekode 2>/dev/null
```

If not found, the user needs to install Nekode.app.

### Step 2: Install Nekode

**Option A: Homebrew (recommended)**
```bash
brew tap Jakob-98/nekode
brew install --cask nekode
```

**Option B: Download from GitHub**
Download the latest release from https://github.com/Jakob-98/nekode/releases/latest and move `Nekode.app` to `/Applications/`.

### Step 3: Verify installation

```bash
/Applications/Nekode.app/Contents/MacOS/nekode hook --version
```

### Step 4: Launch the app

```bash
open /Applications/Nekode.app
```

## After Installation

The hooks registered by this plugin will now work. Session data will be written to `~/.nekode/sessions/` when Claude Code hooks fire.

The menubar app will show session status in the macOS menu bar.
