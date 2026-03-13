# Distribution & Installation

How Nekode gets to users, what's set up, what's not, and what to do next.

## Current State

The build pipeline is complete: CI builds both architectures (arm64 + x86_64), creates zips and DMGs, and uploads them to GitHub Releases. A Homebrew cask template and an auto-update job exist but **the tap repo hasn't been created yet**, and **builds are not signed/notarized**.

## Installation Methods

### 1. Homebrew Cask (primary — not yet live)

```bash
brew tap jakobserlier/nekode
brew install --cask nekode
```

**Why this matters:** Homebrew is the standard macOS package manager. Most developers already have it. One command to install, one to update, one to uninstall. The cask also symlinks `nekode` into the user's PATH automatically.

**Status:** Template exists at `packaging/homebrew-cask.rb`. CI job to push it exists in `.github/workflows/release.yml`. Needs the tap repo created and a signed release.

### 2. GitHub Releases (direct download)

Users download `nekode-macOS-arm64.zip` or `nekode-macOS-x86_64.zip` from the releases page, unzip, and drag to `/Applications`.

**Status:** CI creates zips and DMGs and uploads them. Works today for unsigned builds (users must right-click → Open).

### 3. DMG installer

A standard drag-to-Applications DMG. Created by `scripts/create-dmg.sh`. Uploaded alongside zips in GitHub Releases.

**Status:** Works. Same signing caveat as direct download.

### 4. Build from source

```bash
git clone https://github.com/jakobserlier/nekode.git
cd nekode
./scripts/bundle-macos.sh
cp -R dist/Nekode.app /Applications/
```

**Status:** Works. Requires Xcode 16+.

### 5. Sparkle auto-updates (in-app)

Once installed, the app checks `appcast.xml` in this repo for new versions and offers in-app updates via Sparkle. This is independent of Homebrew — the cask has `auto_updates true` so `brew upgrade` defers to Sparkle.

**Status:** Integrated. Needs signed builds to work properly (Sparkle verifies EdDSA signatures).

### 5. Shell one-liner

```bash
curl -fsSL https://nekode.dev/install.sh | bash
```

Downloads the latest release zip for the user's architecture, extracts `Nekode.app` to `/Applications`, and symlinks the `nekode` CLI to `/usr/local/bin`.

**Options (environment variables):**

| Variable | Default | Description |
|---|---|---|
| `NEKODE_VERSION` | latest | Pin a specific version (e.g. `v0.9.0`) |
| `NEKODE_NO_CLI` | — | Set to `1` to skip CLI symlink |
| `NEKODE_INSTALL_DIR` | `/Applications` | Override app install directory |

**Status:** Script at `scripts/install.sh`. Needs to be hosted at `nekode.dev/install.sh` (copy to website public dir or serve via redirect). Same signing caveat as direct download.

### Other options to consider later

| Method | Effort | Audience | Notes |
|---|---|---|---|
| **Homebrew core** | High | Broad | Requires upstream PR to `homebrew-cask`. Only worth it at significant adoption. They have strict review. |
| **Mac App Store** | High | Non-technical | Requires App Sandbox (currently disabled), paid Apple Developer account, App Store review. Nekode uses filesystem watching and terminal automation — sandbox restrictions would require significant refactoring. Not worth it now. |
| **Nix / nixpkgs** | Medium | Nix users | Niche but loyal audience. Can add later if there's demand. |
| **MacPorts** | Medium | MacPorts users | Very small audience compared to Homebrew. Skip unless requested. |

## Apple Developer Program & Code Signing

### What it gives you

- **Developer ID certificate** — signs the app so macOS Gatekeeper trusts it
- **Notarization** — Apple scans the binary and issues a ticket; macOS verifies it on first launch
- Without these, users see "Nekode can't be opened because Apple cannot check it for malicious software" and must right-click → Open

### Cost

$99/year (Apple Developer Program). Required for Developer ID signing and notarization. Not required for TestFlight or App Store (those need it too, but different reasons).

### Can you skip it for now?

**Yes.** Everything else works without it:

- Homebrew installs the app fine — users just get the Gatekeeper warning on first launch
- The CI pipeline builds, packages, and publishes without signing (it ad-hoc signs with `CODE_SIGN_IDENTITY="-"`)
- Sparkle auto-updates work for EdDSA-signed zips (EdDSA is independent of Apple signing)

**What changes when you add it later:**

1. Generate a Developer ID Application certificate in Apple Developer portal
2. Export it as .p12 and add to GitHub secrets (`APPLE_CERTIFICATE_P12`, `APPLE_CERTIFICATE_PASSWORD`)
3. Add `APPLE_IDENTITY`, `APPLE_TEAM_ID`, `APPLE_ID`, `APPLE_APP_PASSWORD` secrets
4. The release CI already has the signing/notarization step — it's just gated on these secrets existing

No code changes needed. The signing script (`scripts/sign-and-notarize.sh`) and CI workflow are already written.

### Recommendation

Ship unsigned first via Homebrew to validate the distribution pipeline end-to-end. Add signing when you're ready to pay for the Developer Program or when the Gatekeeper friction becomes a real barrier for users.

## Setup Steps (Homebrew tap)

### Step 1: Create the tap repo

Create a **public** GitHub repo named `jakobserlier/homebrew-nekode`.

```bash
gh repo create jakobserlier/homebrew-nekode --public --clone
cd homebrew-nekode
mkdir Casks
cp /path/to/agent-hud/packaging/homebrew-cask.rb Casks/nekode.rb
git add . && git commit -m "Initial cask formula" && git push
```

The naming convention `homebrew-<name>` is required — it's how `brew tap jakobserlier/nekode` resolves to the correct repo.

### Step 2: Create a GitHub PAT for CI

1. Go to https://github.com/settings/tokens?type=beta (fine-grained tokens)
2. Create token:
   - Name: `nekode-tap-updater`
   - Repository access: Only `jakobserlier/homebrew-nekode`
   - Permissions: Contents → Read and write
3. Add it as a secret named `TAP_GITHUB_TOKEN` on the `nekode` (source) repo

### Step 3: Tag a release

```bash
# Make sure version is correct (currently 0.8.2)
git tag v0.8.2
git push origin v0.8.2
```

The CI will:
1. Build arm64 + x86_64 zips and DMGs
2. Create a GitHub Release with all artifacts
3. Compute SHA256 hashes and push the updated cask to the tap repo
4. Update the Sparkle appcast

### Step 4: Verify

```bash
brew tap jakobserlier/nekode
brew install --cask nekode
open /Applications/Nekode.app
which nekode  # should be symlinked
```

## Architecture

```
jakobserlier/nekode                (source repo)
  ├── CI builds + signs + notarizes
  ├── Uploads zips/DMGs to GitHub Releases
  ├── Computes SHA256 → pushes cask to tap repo
  └── Updates appcast.xml for Sparkle

jakobserlier/homebrew-nekode       (tap repo)
  └── Casks/nekode.rb              (single file, auto-updated by CI)

User:
  brew tap jakobserlier/nekode
  brew install --cask nekode
  → downloads zip from GitHub Releases
  → extracts Nekode.app to /Applications
  → symlinks nekode to /usr/local/bin (or /opt/homebrew/bin)
```

## Files in this repo

| File | Purpose |
|---|---|
| `packaging/homebrew-cask.rb` | Cask template (version + SHA256 placeholders) |
| `scripts/bundle-macos.sh` | Builds .app bundle + zip |
| `scripts/install.sh` | curl one-liner installer (downloads release + installs) |
| `scripts/sign-and-notarize.sh` | Signs + notarizes (needs Apple Developer secrets) |
| `scripts/create-dmg.sh` | Creates DMG installer |
| `scripts/bump-version.sh` | Updates version in cask + all other locations |
| `scripts/generate-appcast.sh` | Updates Sparkle appcast XML |
| `.github/workflows/release.yml` | Full release pipeline (build → sign → publish → update tap → update appcast) |
| `docs/release-checklist.md` | Step-by-step release guide |
