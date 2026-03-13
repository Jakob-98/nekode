# Rename Plan: CatAssistant → Nekode

## Decisions

- **App name:** Nekode
- **Bundle ID:** `dev.nekode.Nekode`
- **CLI:** Single `nekode` binary with subcommands (`nekode hook`, `nekode wait`, or just piping `... | nekode`)
- **Data directory:** `~/.nekode/` (sessions, config, bin)
- **Mascot:** Pochi stays (the cat character). Nekode is the product, Pochi is the pet.
- **Xcode project:** Full rename (xcodeproj, targets, products, directories)

## Naming Map

| Old | New |
|---|---|
| CatAssistant | Nekode |
| CatAssistant.app | Nekode.app |
| CatAssistantApp (Swift) | NekodeApp |
| CatAssistantTests | NekodeTests |
| cathook | `nekode hook` (subcommand) |
| catwait | `nekode wait` / pipe mode |
| `~/.cat/` | `~/.nekode/` |
| `~/.cat/sessions/` | `~/.nekode/sessions/` |
| `~/.cat/bin/` | `~/.nekode/bin/` |
| `com.jakobserlier.CatAssistant` | `dev.nekode.Nekode` |
| CatAssistant.xcodeproj | Nekode.xcodeproj |
| `menubar/CatAssistant/` | `menubar/Nekode/` |
| `menubar/CatAssistantTests/` | `menubar/NekodeTests/` |
| `plugins/catassistant/` | `plugins/nekode/` |
| `catassistant-macOS.zip` | `nekode-macOS.zip` |
| `jakobserlier/catassistant` (repo) | `jakobserlier/nekode` (do later) |
| `jakobserlier/homebrew-catassistant` | `jakobserlier/homebrew-nekode` (do later) |
| `brew install --cask catassistant` | `brew install --cask nekode` |

## CLI Refactor: cathook + catwait → nekode

Currently two separate Xcode targets with separate main files. Merge into one `nekode` binary.

**New entry point:** `NekodeMain.swift`

```
nekode hook <hookName> [--source <source>]    # reads JSON from stdin (replaces cathook)
nekode wait [--name <n>] [--project <p>]      # pipe mode (replaces catwait)
nekode --version
nekode --help
```

When stdin is a pipe and no subcommand is given, default to `wait` mode:
```bash
cargo build 2>&1 | nekode              # implicit wait
cargo build 2>&1 | nekode --name build # implicit wait with name
```

**Implementation:**
1. Create `menubar/Nekode/CLI/NekodeMain.swift` — new entry point that dispatches to hook or wait
2. Move `HookMain.swift` logic into a function `runHook(args:)` 
3. Move `CatWaitMain.swift` logic into a function `runWait(args:)`
4. Single Xcode target `nekode` (command-line tool) replaces both `cathook` and `catwait`
5. Keep using manual argument parsing (no need for ArgumentParser dependency)

## Execution Order

### Phase 1: Filesystem renames (directories, files)

These must happen first because all subsequent edits reference the new paths.

1. `menubar/CatAssistant.xcodeproj/` → `menubar/Nekode.xcodeproj/`
2. `menubar/CatAssistant/` → `menubar/Nekode/`
3. `menubar/CatAssistantTests/` → `menubar/NekodeTests/`
4. `menubar/CatAssistant/CatAssistantApp.swift` → `menubar/Nekode/NekodeApp.swift`
5. `menubar/CatAssistant/CatWait/CatWaitMain.swift` → (merge into CLI/NekodeMain.swift)
6. `menubar/CatAssistant/CatWait/PipeMonitor.swift` → `menubar/Nekode/CLI/PipeMonitor.swift`
7. `menubar/CatAssistant/Hook/HookMain.swift` → (merge into CLI/NekodeMain.swift)
8. `menubar/CatAssistant/Hook/` → `menubar/Nekode/Hook/` (keep handler/input/logger)
9. `menubar/CatAssistant/CatAssistant.entitlements` → `menubar/Nekode/Nekode.entitlements`
10. `plugins/catassistant/` → `plugins/nekode/`
11. `plugins/catassistant/skills/catassistant-setup/` → `plugins/nekode/skills/nekode-setup/`

### Phase 2: Xcode project file (project.pbxproj)

The big one. This is a ~700-line structured text file. Changes needed:

- All `name = CatAssistant` → `name = Nekode`
- All `name = cathook` and `name = catwait` → `name = nekode` (single target)
- `productName = CatAssistant` → `productName = Nekode`
- `productName = cathook` / `productName = catwait` → `productName = nekode`
- `PRODUCT_BUNDLE_IDENTIFIER = com.jakobserlier.CatAssistant` → `dev.nekode.Nekode`
- `PRODUCT_NAME = CatAssistant` → `Nekode`
- `INFOPLIST_FILE` paths updated
- File references updated to new directory names
- Remove one of the two CLI targets, rename the other to `nekode`
- Update all source file membership references

**Note:** This is the riskiest step. If the pbxproj is corrupted, Xcode won't open. Approach: do careful string replacements, then verify with `make build`.

### Phase 3: Swift source edits

Files with "CatAssistant" or "cat" references in code:

- `NekodeApp.swift` (was CatAssistantApp.swift): class name, @main struct
- `AppDelegate.swift`: any references to app name
- `Config.swift`: `~/.cat/` path constant
- `Session.swift`: session file paths
- `SessionManager.swift`: file watcher paths
- `HookHandler.swift`: session directory paths
- `HookMain.swift` → merged into NekodeMain.swift
- `CatWaitMain.swift` → merged into NekodeMain.swift
- `PipeMonitor.swift`: session paths
- `PluginManager.swift`: plugin paths, app bundle references
- `HookLogger.swift`: log file paths
- `Info.plist`: app name, Sparkle feed URL
- `*.entitlements`: (probably no CatAssistant-specific content but verify)
- `SettingsSection.swift`: any UI strings mentioning CatAssistant
- `AboutView.swift`: app name in about window
- `LicenseBanner.swift`: "Support CatAssistant" text
- `HeaderView.swift`: app title
- `PopupView.swift`: any title references
- Tests: class names, references

### Phase 4: Plugins

- `plugins/nekode/.claude-plugin/plugin.json`: name, description, paths
- `plugins/nekode/hooks/hooks.json`: cathook path → nekode path
- `plugins/nekode/hooks/run-hook.sh`: binary path
- `plugins/nekode/skills/nekode-setup/SKILL.md`: all references
- `plugins/copilot/hooks/hooks.json`: cathook path → nekode path
- `plugins/copilot/hooks/run-hook.sh`: binary path
- `plugins/opencode/plugin.js`: `~/.cat/` → `~/.nekode/`
- `plugins/opencode/package.json`: name, description
- `.claude-plugin/marketplace.json`: name, description

### Phase 5: Scripts

- `scripts/bundle-macos.sh`: CatAssistant → Nekode, cathook/catwait → nekode, artifact names
- `scripts/sign-and-notarize.sh`: bundle paths, app name
- `scripts/create-dmg.sh`: app name, DMG name
- `scripts/bump-version.sh`: all path references to files that moved
- `scripts/generate-appcast.sh`: URLs, file names
- `scripts/download-stats.sh`: repo reference

### Phase 6: CI workflows

- `.github/workflows/ci.yml`: scheme names, artifact names
- `.github/workflows/release.yml`: scheme names, artifact names, tap repo name, cask name
- `.github/release.yml`: (may not need changes, it's changelog config)

### Phase 7: Config & packaging

- `Makefile`: scheme names, paths, install target
- `packaging/homebrew-cask.rb`: cask name, URLs, binary path, zap path
- `appcast.xml`: download URLs, app name
- `.swiftlint.yml`: (verify if any path exclusions reference old names)

### Phase 8: Docs

- `README.md`: all references
- `docs/distribution.md`: all references
- `docs/release-checklist.md`: all references
- `docs/naming-and-brand.md`: update "current identity" section
- `docs/product-page.md`: all references
- `docs/monetization-plan.md`: all references
- `docs/desktop-pets-*.md`: references (less critical, historical docs)
- `docs/petwait.md`: catwait → nekode
- `docs/sprite-art-requirements.md`: (may not need changes)
- `docs/copilot-integration.md`: cathook paths
- `CONTRIBUTING.md`: all references
- `AGENTS.md`: already partially updated
- `CLAUDE.md`: check for references
- `deployment.md`: check for references

### Phase 9: Verify

1. `make build` — all targets compile
2. `make test` — tests pass
3. `make lint` — no lint errors
4. Manual smoke test: `make run`, verify app launches, menubar works, pets spawn
5. Verify `nekode hook --help` and `nekode wait --help` work
6. Verify `echo '{}' | nekode hook test` doesn't crash

## What NOT to rename yet

- **GitHub repo** (`jakobserlier/catassistant` → `jakobserlier/nekode`): do after the code rename is verified, since it changes all clone/remote URLs
- **Homebrew tap repo**: doesn't exist yet, create as `homebrew-nekode` directly
- **Domain**: secure independently
- **Appcast feed URL**: update when repo is renamed (it uses raw.githubusercontent.com)
- **Sparkle EdDSA keys**: unchanged, they're content-based not name-based

## Risk Mitigation

- **pbxproj corruption**: The Xcode project file is fragile. After editing, verify with `xcodebuild -list -project menubar/Nekode.xcodeproj` before attempting a build.
- **Broken file references**: After directory renames, Xcode file references in pbxproj must point to new paths. Missing one = red files in Xcode.
- **Git rename tracking**: Use `git mv` for directory renames so git tracks them as renames, not delete+create. This preserves blame history.
- **Existing user data**: Users with `~/.cat/` from development builds will need to move to `~/.nekode/`. Consider adding a migration check in the app on first launch (out of scope for this rename, do as follow-up).
