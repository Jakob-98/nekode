---
name: catassistant-setup
description: Use when cathook command fails or is not found. Guides user to install the CatAssistant menubar app.
---

# CatAssistant Setup Skill

Helps install the CatAssistant app required for session monitoring.

## When to Use

**Run installation guidance when:**
- Hook fails with "cathook not found"
- User asks to set up CatAssistant monitoring
- Session tracking is not working

## Installation

### Step 1: Check if CatAssistant.app is installed

```bash
ls /Applications/CatAssistant.app/Contents/MacOS/cathook 2>/dev/null || ls ~/Applications/CatAssistant.app/Contents/MacOS/cathook 2>/dev/null
```

If not found, the user needs to install CatAssistant.app.

### Step 2: Install CatAssistant

**Option A: Homebrew (recommended)**
```bash
brew tap jakobserlier/catassistant
brew install --cask catassistant
```

**Option B: Download from GitHub**
Download the latest release from https://github.com/jakobserlier/catassistant/releases/latest and move `CatAssistant.app` to `/Applications/`.

### Step 3: Verify installation

```bash
/Applications/CatAssistant.app/Contents/MacOS/cathook --version
```

### Step 4: Launch the app

```bash
open /Applications/CatAssistant.app
```

## After Installation

The hooks registered by this plugin will now work. Session data will be written to `~/.cat/sessions/` when Claude Code hooks fire.

The menubar app will show session status in the macOS menu bar.
