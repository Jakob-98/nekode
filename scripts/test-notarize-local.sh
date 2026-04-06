#!/bin/bash
set -euo pipefail

# test-notarize-local.sh — Build, sign, and notarize locally to test
# whether Apple accepts the binary. Bypasses slow GH Actions upload.
#
# Prerequisites:
#   - Signing certificate installed in local Keychain
#   - .env file with APPLE_IDENTITY, APPLE_TEAM_ID, APPLE_ID, APPLE_APP_PASSWORD
#
# Usage:
#   ./scripts/test-notarize-local.sh              # Full: build + sign + notarize
#   ./scripts/test-notarize-local.sh --sign-only  # Build + sign, skip notarize
#   ./scripts/test-notarize-local.sh --notarize-only  # Notarize existing dist/Nekode.app

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env
if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
else
    echo "Error: .env file not found. Copy .env.example to .env and fill in credentials."
    exit 1
fi

SIGN_ONLY=false
NOTARIZE_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign-only) SIGN_ONLY=true; shift ;;
        --notarize-only) NOTARIZE_ONLY=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Validate credentials
for var in APPLE_IDENTITY APPLE_TEAM_ID APPLE_ID APPLE_APP_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: $var not set in .env"
        exit 1
    fi
done

APP_PATH="$REPO_ROOT/dist/Nekode.app"

# Step 1: Build (unless --notarize-only)
if [[ "$NOTARIZE_ONLY" = false ]]; then
    echo ""
    echo "=== Step 1: Building ==="
    "$REPO_ROOT/scripts/bundle-macos.sh"
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run without --notarize-only first."
    exit 1
fi

# Step 2: Sign
if [[ "$NOTARIZE_ONLY" = false ]]; then
    echo ""
    echo "=== Step 2: Signing ==="
    if [[ "$SIGN_ONLY" = true ]]; then
        "$REPO_ROOT/scripts/sign-and-notarize.sh" --sign-only "$APP_PATH"
    else
        "$REPO_ROOT/scripts/sign-and-notarize.sh" --sign-only "$APP_PATH"
    fi
fi

# Step 3: Notarize
if [[ "$SIGN_ONLY" = true ]]; then
    echo ""
    echo "=== Done (sign only) ==="
    echo "Signed app: $APP_PATH"
    echo "To notarize later: $0 --notarize-only"
    exit 0
fi

echo ""
echo "=== Step 3: Notarizing ==="
echo "Creating zip for notarization..."
NOTARIZE_ZIP="$REPO_ROOT/dist/nekode-notarize.zip"
rm -f "$NOTARIZE_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

ZIP_SIZE=$(du -h "$NOTARIZE_ZIP" | cut -f1)
echo "Zip size: $ZIP_SIZE"
echo "Submitting to Apple (this should take <1 min locally)..."
echo ""

time xcrun notarytool submit "$NOTARIZE_ZIP" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait --timeout 15m

RESULT=$?
rm -f "$NOTARIZE_ZIP"

if [[ $RESULT -ne 0 ]]; then
    echo ""
    echo "=== Notarization may have failed or timed out ==="
    echo "Check submission status with:"
    echo "  xcrun notarytool history --apple-id $APPLE_ID --password <pw> --team-id $APPLE_TEAM_ID"
    exit 1
fi

echo ""
echo "=== Step 4: Stapling ==="
xcrun stapler staple "$APP_PATH"

echo ""
echo "=== Step 5: Verifying ==="
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo ""
echo "=== SUCCESS ==="
echo "App is signed, notarized, and stapled: $APP_PATH"
echo ""
echo "You can now:"
echo "  1. Open $APP_PATH directly to test"
echo "  2. Copy to spare MacBook to test Gatekeeper"
echo "  3. Create DMG: ./scripts/create-dmg.sh"
