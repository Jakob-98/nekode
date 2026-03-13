#!/bin/bash
# Nekode installer — curl -fsSL https://nekode.dev/install.sh | bash
#
# Installs the latest Nekode release:
#   1. Downloads the correct zip for your architecture (arm64 or x86_64)
#   2. Extracts Nekode.app to /Applications
#   3. Symlinks the nekode CLI into /usr/local/bin
#
# Options:
#   NEKODE_VERSION=v0.9.0  Pin a specific version (default: latest)
#   NEKODE_NO_CLI=1        Skip CLI symlink
#   NEKODE_INSTALL_DIR     Override app install directory (default: /Applications)

set -euo pipefail

REPO="Jakob-98/nekode"
INSTALL_DIR="${NEKODE_INSTALL_DIR:-/Applications}"
BIN_DIR="/usr/local/bin"
APP_NAME="Nekode.app"
CLI_NAME="nekode"

# ─── Colors ───

bold='\033[1m'
dim='\033[2m'
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
reset='\033[0m'

info()  { printf "${bold}==>${reset} %s\n" "$1"; }
ok()    { printf "${green}==>${reset} %s\n" "$1"; }
warn()  { printf "${yellow}==> Warning:${reset} %s\n" "$1"; }
err()   { printf "${red}==> Error:${reset} %s\n" "$1" >&2; }

# ─── Preflight ───

if [ "$(uname -s)" != "Darwin" ]; then
  err "Nekode is a macOS app. This installer only works on macOS."
  exit 1
fi

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  arm64)  ASSET_ARCH="arm64" ;;
  x86_64) ASSET_ARCH="x86_64" ;;
  *)
    err "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

info "Detected architecture: $ASSET_ARCH"

# ─── Resolve version ───

if [ -n "${NEKODE_VERSION:-}" ]; then
  VERSION="$NEKODE_VERSION"
  # Ensure v prefix
  case "$VERSION" in
    v*) ;;
    *)  VERSION="v$VERSION" ;;
  esac
  info "Installing pinned version: $VERSION"
else
  info "Fetching latest release..."
  VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | head -1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"

  if [ -z "$VERSION" ]; then
    err "Could not determine latest version. Check https://github.com/${REPO}/releases"
    exit 1
  fi
  info "Latest version: $VERSION"
fi

# ─── Download ───

ASSET_NAME="nekode-macOS-${ASSET_ARCH}.zip"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"

TMPDIR_INSTALL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_INSTALL"' EXIT

info "Downloading ${ASSET_NAME}..."
HTTP_CODE="$(curl -fSL -w '%{http_code}' -o "${TMPDIR_INSTALL}/${ASSET_NAME}" "$DOWNLOAD_URL" 2>/dev/null)" || true

if [ ! -f "${TMPDIR_INSTALL}/${ASSET_NAME}" ] || [ "$HTTP_CODE" != "200" ]; then
  err "Download failed (HTTP $HTTP_CODE)."
  err "URL: $DOWNLOAD_URL"
  err "Check that version $VERSION exists at https://github.com/${REPO}/releases"
  exit 1
fi

# ─── Extract ───

info "Extracting to ${INSTALL_DIR}..."
cd "$TMPDIR_INSTALL"
unzip -qo "${ASSET_NAME}"

if [ ! -d "$APP_NAME" ]; then
  err "Archive did not contain ${APP_NAME}. Contents:"
  ls -la "$TMPDIR_INSTALL"
  exit 1
fi

# Remove existing install
if [ -d "${INSTALL_DIR}/${APP_NAME}" ]; then
  warn "Replacing existing ${APP_NAME} in ${INSTALL_DIR}"
  rm -rf "${INSTALL_DIR}/${APP_NAME}"
fi

mv "$APP_NAME" "${INSTALL_DIR}/"
ok "Installed ${APP_NAME} to ${INSTALL_DIR}"

# ─── Clear quarantine ───

if xattr -l "${INSTALL_DIR}/${APP_NAME}" 2>/dev/null | grep -q "com.apple.quarantine"; then
  info "Removing quarantine attribute..."
  xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}" 2>/dev/null || true
fi

# ─── CLI symlink ───

if [ "${NEKODE_NO_CLI:-}" != "1" ]; then
  CLI_PATH="${INSTALL_DIR}/${APP_NAME}/Contents/MacOS/${CLI_NAME}"
  if [ -f "$CLI_PATH" ]; then
    info "Symlinking ${CLI_NAME} CLI to ${BIN_DIR}..."

    # Create bin dir if needed (shouldn't be needed on macOS, but just in case)
    if [ ! -d "$BIN_DIR" ]; then
      sudo mkdir -p "$BIN_DIR"
    fi

    # Remove existing symlink/binary
    if [ -L "${BIN_DIR}/${CLI_NAME}" ] || [ -f "${BIN_DIR}/${CLI_NAME}" ]; then
      sudo rm -f "${BIN_DIR}/${CLI_NAME}"
    fi

    sudo ln -s "$CLI_PATH" "${BIN_DIR}/${CLI_NAME}"
    ok "CLI available: ${CLI_NAME}"
  else
    warn "CLI binary not found at ${CLI_PATH} — skipping symlink"
  fi
fi

# ─── Done ───

printf "\n"
ok "Nekode ${VERSION} installed successfully!"
printf "\n"
printf "  ${dim}App:${reset}  ${INSTALL_DIR}/${APP_NAME}\n"
if [ "${NEKODE_NO_CLI:-}" != "1" ]; then
  printf "  ${dim}CLI:${reset}  ${BIN_DIR}/${CLI_NAME}\n"
fi
printf "\n"
printf "  Open the app:   ${bold}open ${INSTALL_DIR}/${APP_NAME}${reset}\n"
printf "  Set up hooks:   ${bold}nekode hook install${reset}\n"
printf "\n"
