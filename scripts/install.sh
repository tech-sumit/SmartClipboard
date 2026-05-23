#!/usr/bin/env bash
# Smart Clipboard — one-line installer.
#
# Downloads the latest DMG from GitHub Releases, copies the .app into
# /Applications, removes the macOS Gatekeeper quarantine attribute (so the
# app launches without the "Apple could not verify…" dialog), and starts it.
#
# Use:
#   curl -fsSL https://raw.githubusercontent.com/tech-sumit/SmartClipboard/main/scripts/install.sh | bash
#
# Why this is needed: the DMG is ad-hoc signed (not Apple-Developer-ID-notarized).
# Removing the quarantine flag is the equivalent of right-clicking → Open and
# saying "yes I really mean it", except we do it from the shell.

set -euo pipefail

REPO="tech-sumit/SmartClipboard"
APP_NAME="SmartClipboard.app"
APP_PATH="/Applications/$APP_NAME"

err() { printf "\033[31m✘\033[0m %s\n" "$*" >&2; exit 1; }
info() { printf "\033[36m▸\033[0m %s\n" "$*"; }
ok() { printf "\033[32m✔\033[0m %s\n" "$*"; }

[[ "$(uname)" == "Darwin" ]] || err "This installer is for macOS only."

TMP=$(mktemp -d)
MOUNT=""
trap 'rm -rf "$TMP"; [[ -n "${MOUNT:-}" ]] && hdiutil detach "$MOUNT" -quiet 2>/dev/null || true' EXIT

info "Resolving latest release of ${REPO}..."
ASSET_URL=$(
    curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -E '"browser_download_url".*\.dmg"' \
        | head -1 \
        | sed -E 's/.*"([^"]+\.dmg)".*/\1/'
)
[[ -n "$ASSET_URL" ]] || err "No DMG asset found in latest release."
info "Found: $ASSET_URL"

DMG="$TMP/SmartClipboard.dmg"
info "Downloading…"
curl -fL --progress-bar "$ASSET_URL" -o "$DMG"

info "Mounting DMG"
MOUNT=$(hdiutil attach "$DMG" -nobrowse -quiet \
    | tail -1 | awk '{ for (i=3; i<=NF; i++) printf "%s%s", $i, (i==NF ? ORS : OFS) }' \
    | sed 's/[[:space:]]*$//')
[[ -d "$MOUNT/$APP_NAME" ]] || err "Mounted DMG does not contain $APP_NAME (mount: $MOUNT)"

if [[ -d "$APP_PATH" ]]; then
    info "Removing previous installation"
    rm -rf "$APP_PATH"
fi

info "Copying to /Applications"
cp -R "$MOUNT/$APP_NAME" /Applications/

info "Removing Gatekeeper quarantine flag"
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
# Re-apply ad-hoc signature (xattr removal can invalidate it on some systems)
codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true

info "Unmounting DMG"
hdiutil detach "$MOUNT" -quiet 2>/dev/null || true

info "Launching"
open "$APP_PATH"

ok "Installed at $APP_PATH"
ok "Look for the clipboard icon in your menu bar."
echo
echo "First time you press ⌘⇧V, macOS will ask for Input Monitoring."
echo "To enable paste-on-Enter, open Settings → Permissions and grant Accessibility."
