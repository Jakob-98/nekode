#!/bin/bash
set -euo pipefail

# bundle-macos.sh - Build and bundle Nekode.app (Swift-only)
#
# Usage:
#   ./scripts/bundle-macos.sh                  # Build and bundle (release)
#   ./scripts/bundle-macos.sh --skip-build     # Bundle from existing release binaries
#   ./scripts/bundle-macos.sh --arch arm64     # Build for specific architecture
#
# Output: dist/Nekode.app, dist/nekode-macOS.zip

SKIP_BUILD=false
ARCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
        --arch) ARCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/dist"

XCODE_ARCHS="${ARCH:-$(uname -m)}"

if [ "$SKIP_BUILD" = false ]; then
    echo "==> Building Nekode app..."
    xcodebuild build \
        -project "$REPO_ROOT/menubar/Nekode.xcodeproj" \
        -scheme Nekode \
        -configuration Release \
        -derivedDataPath "$REPO_ROOT/menubar/build/" \
        CODE_SIGN_IDENTITY="-" \
        ARCHS="$XCODE_ARCHS" \
        ONLY_ACTIVE_ARCH=NO

    echo "==> Building nekode CLI..."
    xcodebuild build \
        -project "$REPO_ROOT/menubar/Nekode.xcodeproj" \
        -scheme nekode \
        -configuration Release \
        -derivedDataPath "$REPO_ROOT/menubar/build/" \
        CODE_SIGN_IDENTITY="-" \
        ARCHS="$XCODE_ARCHS" \
        ONLY_ACTIVE_ARCH=NO
fi

echo "==> Assembling .app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

APP="$BUILD_DIR/Nekode.app"
cp -R "$REPO_ROOT/menubar/build/Build/Products/Release/Nekode.app" "$APP"

# Copy nekode CLI into the app bundle (named nekode-cli to avoid
# case-insensitive collision with the Nekode GUI binary)
cp "$REPO_ROOT/menubar/build/Build/Products/Release/nekode-cli" "$APP/Contents/MacOS/nekode-cli"

# Copy opencode plugin into Resources
mkdir -p "$APP/Contents/Resources"
cp "$REPO_ROOT/plugins/opencode/plugin.js" "$APP/Contents/Resources/opencode-plugin.js"

# Copy copilot hooks into Resources
cp "$REPO_ROOT/plugins/copilot/hooks/hooks.json" "$APP/Contents/Resources/copilot-hooks.json"
cp "$REPO_ROOT/plugins/copilot/hooks/run-hook.sh" "$APP/Contents/Resources/copilot-run-hook.sh"

# Copy copilot-cli hooks into Resources
cp "$REPO_ROOT/plugins/copilot-cli/hooks/hooks.json" "$APP/Contents/Resources/copilot-cli-hooks.json"
cp "$REPO_ROOT/plugins/copilot-cli/hooks/run-hook.sh" "$APP/Contents/Resources/copilot-cli-run-hook.sh"

# Copy Claude Code hook script into Resources
cp "$REPO_ROOT/plugins/nekode/hooks/run-hook.sh" "$APP/Contents/Resources/cc-run-hook.sh"

# Ad-hoc sign (innermost first — no --deep)
echo "==> Signing app bundle..."

# Sign nested bundles/frameworks first (includes Sparkle's XPC services and helper apps)
while IFS= read -r -d '' nested; do
    echo "  Signing $(basename "$nested")..."
    codesign --force --sign - "$nested"
done < <(find "$APP/Contents" -depth \( -name "*.bundle" -o -name "*.framework" -o -name "*.xpc" -o -name "*.app" -o -name "*.appex" -o -name "*.dylib" \) -print0)

# Sign nekode CLI
echo "  Signing nekode-cli..."
codesign --force --sign - "$APP/Contents/MacOS/nekode-cli"

# Sign main executable
echo "  Signing Nekode..."
codesign --force --sign - "$APP/Contents/MacOS/Nekode"

# Sign the overall bundle
echo "  Signing app bundle..."
codesign --force --sign - "$APP"

echo "==> Packaging..."
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent Nekode.app nekode-macOS.zip

SIZE=$(du -sh Nekode.app | cut -f1)
echo "==> Done! App size: $SIZE"
echo "   App:  $APP"
echo "   Zip:  $BUILD_DIR/nekode-macOS.zip"
