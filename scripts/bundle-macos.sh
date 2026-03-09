#!/bin/bash
set -euo pipefail

# bundle-macos.sh - Build and bundle CatAssistant.app (Swift-only)
#
# Usage:
#   ./scripts/bundle-macos.sh                  # Build and bundle (release)
#   ./scripts/bundle-macos.sh --skip-build     # Bundle from existing release binaries
#   ./scripts/bundle-macos.sh --arch arm64     # Build for specific architecture
#
# Output: dist/CatAssistant.app, dist/catassistant-macOS.zip

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
    echo "==> Building CatAssistant app..."
    xcodebuild build \
        -project "$REPO_ROOT/menubar/CatAssistant.xcodeproj" \
        -scheme CatAssistant \
        -configuration Release \
        -derivedDataPath "$REPO_ROOT/menubar/build/" \
        CODE_SIGN_IDENTITY="-" \
        ARCHS="$XCODE_ARCHS" \
        ONLY_ACTIVE_ARCH=NO

    echo "==> Building cathook CLI..."
    xcodebuild build \
        -project "$REPO_ROOT/menubar/CatAssistant.xcodeproj" \
        -scheme cathook \
        -configuration Release \
        -derivedDataPath "$REPO_ROOT/menubar/build/" \
        CODE_SIGN_IDENTITY="-" \
        ARCHS="$XCODE_ARCHS" \
        ONLY_ACTIVE_ARCH=NO

    echo "==> Building catwait CLI..."
    xcodebuild build \
        -project "$REPO_ROOT/menubar/CatAssistant.xcodeproj" \
        -scheme catwait \
        -configuration Release \
        -derivedDataPath "$REPO_ROOT/menubar/build/" \
        CODE_SIGN_IDENTITY="-" \
        ARCHS="$XCODE_ARCHS" \
        ONLY_ACTIVE_ARCH=NO
fi

echo "==> Assembling .app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

APP="$BUILD_DIR/CatAssistant.app"
cp -R "$REPO_ROOT/menubar/build/Build/Products/Release/CatAssistant.app" "$APP"

# Copy cathook into the app bundle
cp "$REPO_ROOT/menubar/build/Build/Products/Release/cathook" "$APP/Contents/MacOS/cathook"

# Copy catwait into the app bundle
cp "$REPO_ROOT/menubar/build/Build/Products/Release/catwait" "$APP/Contents/MacOS/catwait"

# Copy opencode plugin into Resources
mkdir -p "$APP/Contents/Resources"
cp "$REPO_ROOT/plugins/opencode/plugin.js" "$APP/Contents/Resources/opencode-plugin.js"

# Ad-hoc sign (innermost first — no --deep)
echo "==> Signing app bundle..."

# Sign nested bundles/frameworks first (includes Sparkle's XPC services and helper apps)
while IFS= read -r -d '' nested; do
    echo "  Signing $(basename "$nested")..."
    codesign --force --sign - "$nested"
done < <(find "$APP/Contents" -depth \( -name "*.bundle" -o -name "*.framework" -o -name "*.xpc" -o -name "*.app" -o -name "*.appex" -o -name "*.dylib" \) -print0)

# Sign cathook
echo "  Signing cathook..."
codesign --force --sign - "$APP/Contents/MacOS/cathook"

# Sign catwait
echo "  Signing catwait..."
codesign --force --sign - "$APP/Contents/MacOS/catwait"

# Sign main executable
echo "  Signing CatAssistant..."
codesign --force --sign - "$APP/Contents/MacOS/CatAssistant"

# Sign the overall bundle
echo "  Signing app bundle..."
codesign --force --sign - "$APP"

echo "==> Packaging..."
cd "$BUILD_DIR"
ditto -c -k --sequesterRsrc --keepParent CatAssistant.app catassistant-macOS.zip

SIZE=$(du -sh CatAssistant.app | cut -f1)
echo "==> Done! App size: $SIZE"
echo "   App:  $APP"
echo "   Zip:  $BUILD_DIR/catassistant-macOS.zip"
