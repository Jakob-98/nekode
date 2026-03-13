# Contributing to Nekode

Thanks for your interest in contributing to Nekode! The project has three main components:

- **Nekode** - macOS menubar app (SwiftUI)
- **nekode** - CLI binary with subcommands (`nekode hook`, `nekode wait`)
- **opencode plugin** - JS plugin for opencode (`plugins/opencode/plugin.js`)

The two Swift targets share model code in `Models/`. The opencode plugin is a standalone JS file with zero dependencies.

## Getting Started

### Prerequisites

- Xcode 16+ (for Swift 6.1 tools)
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

### Building

```bash
# Menubar app
xcodebuild build \
  -project menubar/Nekode.xcodeproj \
  -scheme Nekode \
  -configuration Debug \
  -derivedDataPath menubar/build/ \
  CODE_SIGN_IDENTITY="-"

# nekode CLI
xcodebuild build \
  -project menubar/Nekode.xcodeproj \
  -scheme nekode \
  -configuration Debug \
  -derivedDataPath menubar/build/ \
  CODE_SIGN_IDENTITY="-"
```

### Running Tests

```bash
# Swift tests
xcodebuild test \
  -project menubar/Nekode.xcodeproj \
  -scheme Nekode \
  -configuration Debug \
  -derivedDataPath menubar/build/

# Lint checks
swiftlint lint --strict
```

## Making Changes

1. Fork the repository and create a branch from `main`.
2. Make your changes. Add tests if applicable.
3. Run the full test and lint suite (see above).
4. Open a pull request against `main`.

### Code Organization

**Swift** (in `menubar/Nekode/`). Use Xcode or SwiftUI Previews for visual feedback -- all views have `#Preview` blocks with mock data.

- `Models/` — Shared between both Swift targets (Session, SessionStatus, HookEvent, Config)
- `Views/` — Menubar app only (SwiftUI views)
- `Services/` — Menubar app only (SessionManager, FocusTerminal)
- `Hook/` — nekode CLI only (HookMain, HookHandler, HookInput, HookLogger)

**opencode plugin** (in `plugins/opencode/`). A single JS file that runs in-process in Bun.

- `plugin.js` — Event handler that writes session JSON to `~/.nekode/sessions/`
- `package.json` — Plugin manifest (name, version)
- Auto-installed by the menubar app on launch when `~/.config/opencode/` exists
- No build step needed — edit `plugin.js` directly and use the manual copy below to test changes

### Testing the opencode Plugin Locally

The plugin is auto-installed by the menubar app on launch. For local development, manually copy your modified version to override it:

```bash
# Copy your modified plugin into the opencode plugins directory
cp plugins/opencode/plugin.js ~/.config/opencode/plugins/nekode.js

# Restart opencode to pick up changes
# (opencode loads plugins at startup — there's no hot reload)

# Verify session files are written
ls ~/.nekode/sessions/

# Check the session JSON contents
cat ~/.nekode/sessions/*.json | python3 -m json.tool
```

Note: Launching the menubar app will overwrite your local changes if the bundled plugin differs. Either quit the app while iterating, or use `make run` to build and launch with your latest changes bundled.

The plugin runs inside opencode's Bun runtime — no separate Node.js or Bun install is needed. You can check syntax without opencode by running `node -c plugins/opencode/plugin.js`.

### Version Bumping

When releasing a new version, use the bump script to update all version references at once:

```bash
./scripts/bump-version.sh 0.3.0
```

This updates `packaging/homebrew-cask.rb`, both plugin manifests (Claude Code and opencode), and the Xcode project.

## Reporting Issues

Open an issue on [GitHub](https://github.com/Jakob-98/nekode/issues). Include:

- What you expected vs. what happened
- Steps to reproduce
- Your OS version and architecture

## License

By contributing, you agree that your contributions will be licensed under the project's [source-available license](LICENSE).
