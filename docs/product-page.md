# Product Page Draft

## The Pitch

**Your AI agents are working. You shouldn't have to watch them.**

You're running three Claude Code sessions and an opencode instance across different projects. One is building, one is waiting for approval, one finished five minutes ago and you didn't notice. You've been tab-cycling between terminals trying to figure out which one needs you.

CatAssistant fixes this. A menubar app that shows you the state of every AI coding session at a glance. Color-coded badges. Current tool in use. One click to jump to the right terminal. And if you want — pixel-art desktop pets that chase your cursor when a session needs attention.

---

## What It Does

### Menubar Dashboard
Every active AI coding session in one floating panel. Each card shows the project name, current status (idle / working / waiting for input / waiting for permission / compacting), and what the agent is doing right now ("Editing auth.ts", "Running tests"). Color-coded so you can scan in under a second.

### Jump to Any Session
Click a card to raise the right VS Code, Cursor, or iTerm2 window — the exact tab and pane, not just the app. Keyboard-native: arrow keys to browse, Enter to jump. Refocus mode overlays numbered badges (1-9) so you can jump by number with a global hotkey.

### Desktop Pets
Optional pixel-art animals (dog, cat, hamster) that live on your desktop, one per session. They sit calmly while the agent works. They sleep when idle. And when a session needs you — they get up, walk toward your cursor, and escalate from a polite "?" to an insistent "!!" over 60 seconds. Drag them to dismiss. Double-click to jump to the session. They have dust particles, breathing animations, squash-and-stretch physics, speech bubbles showing what the agent is doing, and a 4-tier idle system inspired by Clippy (without the unsolicited advice).

### catwait — Monitor Anything
Not just for AI agents. Pipe any long-running command through `catwait` and it becomes a live session:

```bash
cargo build --release 2>&1 | catwait
npm run build | catwait --name "frontend build"
make test 2>&1 | catwait --name "test suite"
```

The pet sits while it runs. When it finishes, the pet walks to your cursor. Press Enter to dismiss. You never have to stare at a terminal waiting for a build again.

### Raycast Extension
All sessions also show up in Raycast with live status, filtering, and jump-to-session.

---

## How It Works

No server. No network. No analytics. No telemetry. All local.

Plugins for Claude Code and opencode write tiny JSON files to `~/.cat/sessions/`. The menubar app watches that directory. That's the entire architecture. `catwait` writes the same JSON format. Any tool that writes a conforming JSON file gets a session card and a pet for free.

---

## Supports

- **Claude Code** — via shell hook (`cathook`), tracks every lifecycle event
- **opencode** — via JS plugin running in Bun, zero dependencies
- **Any CLI command** — via `catwait` pipe

Works with VS Code, Cursor, iTerm2, Kitty, Warp, and any macOS terminal.

---

## Install

```bash
brew tap jakobserlier/catassistant
brew install --cask catassistant
```

Signed and notarized by Apple. Follow the in-app instructions to connect Claude Code and/or opencode. Two minutes to set up.

---

## Privacy

No network access. No accounts. No cloud. Session data is plain JSON files on your disk. You can `cat` them. You can delete them. They contain only: project name, status, last tool, timestamps.

---

## Name

The project was originally called **cctop** (from "Claude Code top", like `htop` for AI sessions). It was renamed to **CatAssistant** — agent-agnostic, leans into the desktop pets angle (the most distinctive feature), and more brandable for a product page or Product Hunt launch.

---

## Should You Sell It?

### The case for selling

1. **The market exists and is growing fast.** Anyone running multiple AI coding sessions has this problem. That's an increasing number of developers every month as Claude Code, opencode, Cursor agent mode, and similar tools proliferate. This isn't a shrinking niche.

2. **There is no real competition.** There is no other tool that monitors multiple AI coding agent sessions from a single dashboard. The closest thing is checking terminal tabs manually. The desktop pets feature has zero competition — nobody else is doing this.

3. **The price point is impulse-buy territory.** At $9.99, anyone who tries it and finds it useful will pay to remove a nag banner. The Sublime Text model is proven: full functionality, gentle nag, one-time payment. No subscriptions to manage or justify.

4. **You've already built the hard parts.** The pet system alone is ~2,500 lines of polished Swift with physics, animations, speech bubbles, multi-pet collision, and a 4-stage attention escalation system. The hook infrastructure for Claude Code and opencode is done. Raycast extension is done. The marginal effort to add Paddle licensing is 2-3 days per your own estimate.

5. **Desktop pets are a marketing gift.** A 15-second screen recording of a pixel-art dog chasing your cursor when your build finishes is the kind of thing that goes viral on dev Twitter. The product markets itself visually in a way that most dev tools can't.

### The case against selling

1. **Small addressable market (today).** The intersection of "runs multiple AI coding sessions simultaneously" and "uses macOS" and "would pay for a monitoring tool" is narrow right now. It's growing, but it's not huge yet.

2. **Platform risk.** If Claude Code or opencode add their own session management UI, the core monitoring value proposition weakens. The pets become the moat, not the dashboard.

3. **Open source goodwill.** The tool is MIT-licensed with community contributions. Going paid (even with source-available) could alienate early adopters. The Raycast extension must stay MIT anyway.

4. **Support burden.** macOS app updates, notarization, Homebrew cask maintenance, terminal compatibility issues, Paddle integration — it's ongoing work for what may be modest revenue.

5. **The real value might be the brand, not the revenue.** Being the person who built "the desktop pets for AI agents" has career/reputation value that may exceed the $9.99 x N revenue. Keeping it free and open maximizes adoption and visibility.

### My take

**Sell it, but don't optimize for revenue.** The product is good enough to charge for and the Sublime Text model is low-friction. But the bigger play is adoption and brand. Here's a concrete path:

1. **Keep the core open source** (option 3 from your monetization doc — MIT source, sell the signed binary). Anyone technical enough to build from source will do so; that's fine. The 90% who install via Homebrew will see the nag banner.
2. **Price at $9.99 one-time.** Don't overthink it.
3. **Invest in the marketing angle.** The desktop pets are the hook. Make a 30-second demo video. Post it on X/Twitter, Hacker News, r/programming. The visual is inherently shareable.
4. **Don't gate features.** No "pro" tier. No locked pets. Full functionality for everyone. The nag banner is the only difference.
5. **Add more agent support.** Cursor agent mode, Windsurf, Aider, Codex CLI — each new integration expands the market. The JSON-file architecture makes this trivial.

The worst outcome is spending weeks on Paddle integration and selling 50 licenses. The best outcome is that the desktop pets go mildly viral, thousands of developers install it, and the $9.99 converts at 5-10% — meaningful side income from a product you'd maintain anyway. The expected outcome is somewhere in between, and worth the 2-3 days.

**One more thing:** the `catwait` angle is underexplored. "Pipe any command, get a desktop pet that tells you when it's done" is a standalone product pitch that appeals to every developer, not just AI agent users. Consider leading with that in marketing, even if the AI session monitoring is the deeper feature.
