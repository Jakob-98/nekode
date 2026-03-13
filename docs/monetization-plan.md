# Nekode Monetization Plan

## Model

Paid app with a one-time lifetime license, sold via **Paddle**. Fully functional unlimited trial with a subtle nag banner (the Sublime Text model).

**Price:** ~$9.99 USD one-time.

## Why Not the App Store?

Nekode's architecture is incompatible with App Sandbox (required for the Mac App Store). The app reads/writes `~/.nekode/`, controls terminals via AppleScript, spawns processes, and exposes a CLI binary (`nekode`) that external tools call into. Porting to the App Store would require a ground-up redesign and degrade the product.

## How It Works

- **Distribution stays the same:** Homebrew cask, GitHub Releases, Sparkle auto-update, `.dmg` download. Nothing changes for users.
- **Everyone gets the full app.** No features are locked. Licensed and unlicensed users are identical except for a small banner.
- **Nag banner:** A non-intrusive message at the bottom of the popup: *"Support Nekode development -- [Purchase a license]"*. Clicking it opens the Paddle checkout. Once purchased, the banner disappears.
- **License key stored in Keychain.** Validated against Paddle's API periodically (cached, works offline).

## Payment & Tax

Paddle handles checkout, payment processing, tax/VAT compliance, receipts, and refunds. They take ~5% + $0.50 per transaction. You need a legal entity (sole proprietorship is fine to start).

## License Change

The project is currently MIT. Options:

1. **Go proprietary** -- remove public source or make repo private. Simplest for a paid product.
2. **Source-available** (e.g., BSL 1.1) -- code is readable on GitHub but can't be redistributed or used commercially. Good for trust and contributions.
3. **Keep MIT, sell the binary** -- anyone can build from source, but the signed/notarized/auto-updating binary is the paid product. Least friction, but some people will just build it themselves (that's fine).

The **Raycast extension** should stay MIT regardless -- it's published to the Raycast Store (which requires open source) and serves as free marketing for the menubar app.

## What to Build

1. `LicenseManager` service (Keychain storage, Paddle API validation, caching)
2. Nag banner in `PopupView` (subtle, non-blocking)
3. "Purchase" / "Enter License Key" option in settings
4. A simple landing page with download + purchase buttons

Roughly 2-3 days of work.

## Pricing Notes

- $8.99 is the floor -- low friction, impulse-buy territory
- $9.99-$12.99 is the sweet spot for a niche dev tool
- $19.99 is viable later with a "Pro" framing
- Start at $9.99 and adjust based on conversion data
