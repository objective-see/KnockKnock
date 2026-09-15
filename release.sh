#!/bin/bash
#
# release.sh - build, sign, notarize, and staple a KnockKnock release
# run from the KnockKnock directory (the one containing KnockKnock.xcodeproj)
#
# usage: ./release.sh [notarytool keychain profile]   (default: objective-see)
#
# output: Releases/KnockKnock_<version>.zip (notarized & stapled)
#

set -euo pipefail

# --- config ---------------------------------------------------------------

# Xcode 26 (last Xcode that can target macOS 10.15)
export DEVELOPER_DIR=/Applications/Xcode_26.app/Contents/Developer

SCHEME="KnockKnock"
CONFIGURATION="Release"

# Developer ID Application: Objective-See, LLC (VBG97UB4TA)
SIGNING_IDENTITY="7C252D0F28F7D452C3647A78A9781EDD8EDB08E8"
TEAM_ID="VBG97UB4TA"

# notarytool credentials (create once with: xcrun notarytool store-credentials objective-see --apple-id <id> --team-id VBG97UB4TA)
KEYCHAIN_PROFILE="${1:-objective-see}"

# where the final zip lands
OUTPUT_DIR="$PWD/Releases"

# --- setup ----------------------------------------------------------------

log()  { printf '\n[+] %s\n' "$*"; }
fail() { printf '\n[!] %s\n' "$*" >&2; exit 1; }

[[ -d "$DEVELOPER_DIR" ]] || fail "Xcode 26 not found at $DEVELOPER_DIR"
[[ -d "$SCHEME.xcodeproj" ]] || fail "run this from the KnockKnock directory (no $SCHEME.xcodeproj here)"

# temp build dir, removed on exit (success or failure)
TMP_DIR="$(mktemp -d -t knockknock-release)"
trap 'log "cleaning up $TMP_DIR"; rm -rf "$TMP_DIR"' EXIT

ARCHIVE_PATH="$TMP_DIR/$SCHEME.xcarchive"
DERIVED_DATA="$TMP_DIR/DerivedData"
APP_PATH="$ARCHIVE_PATH/Products/Applications/$SCHEME.app"

# --- preflight ------------------------------------------------------------

log "checking signing identity"
security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY" \
    || fail "signing identity $SIGNING_IDENTITY not found in keychain"

log "checking notarytool profile '$KEYCHAIN_PROFILE'"
xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
    || fail "notarytool profile '$KEYCHAIN_PROFILE' not found (run: xcrun notarytool store-credentials $KEYCHAIN_PROFILE --apple-id <id> --team-id $TEAM_ID)"

if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    printf '\n[?] working tree has uncommitted changes:\n'
    git status --short
    read -r -p "    continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || fail "aborted"
fi

# --- build ----------------------------------------------------------------

log "archiving $SCHEME ($CONFIGURATION) with $(xcodebuild -version | head -1)"
xcodebuild -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -derivedDataPath "$DERIVED_DATA" \
           -archivePath "$ARCHIVE_PATH" \
           CODE_SIGN_STYLE=Manual \
           CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
           DEVELOPMENT_TEAM="$TEAM_ID" \
           OTHER_CODE_SIGN_FLAGS="--timestamp" \
           archive | grep -E "error:|warning:|ARCHIVE (SUCCEEDED|FAILED)" || true

[[ -d "$APP_PATH" ]] || fail "archive failed, no app at $APP_PATH"

VERSION="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)"
MIN_OS="$(defaults read "$APP_PATH/Contents/Info.plist" LSMinimumSystemVersion)"
ZIP_NAME="${SCHEME}_${VERSION}.zip"
SUBMIT_ZIP="$TMP_DIR/$ZIP_NAME"
FINAL_ZIP="$OUTPUT_DIR/$ZIP_NAME"

log "built $SCHEME $VERSION (min macOS $MIN_OS)"
lipo -info "$APP_PATH/Contents/MacOS/$SCHEME"

# fail early, before notarizing, if this version was already packaged
[[ -e "$FINAL_ZIP" ]] && fail "$FINAL_ZIP already exists, move it first"

# --- verify signature -----------------------------------------------------

log "verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvv "$APP_PATH" 2>&1 | grep -q "TeamIdentifier=$TEAM_ID" \
    || fail "app is not signed by team $TEAM_ID"
codesign -dvv "$APP_PATH" 2>&1 | grep -q "flags=.*runtime" \
    || fail "hardened runtime not enabled"

# --- notarize -------------------------------------------------------------

log "zipping for submission"
ditto -c -k --keepParent "$APP_PATH" "$SUBMIT_ZIP"

log "submitting to notary service (this can take a few minutes)"
SUBMIT_OUTPUT="$(xcrun notarytool submit "$SUBMIT_ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1 | tee /dev/stderr)"

SUBMISSION_ID="$(printf '%s' "$SUBMIT_OUTPUT" | awk '/^ *id:/ {print $2; exit}')"
STATUS="$(printf '%s' "$SUBMIT_OUTPUT" | awk '/^ *status:/ {print $2}' | tail -1)"

if [[ "$STATUS" != "Accepted" ]]; then
    log "notarization failed (status: ${STATUS:-unknown}), fetching log"
    [[ -n "$SUBMISSION_ID" ]] && xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$KEYCHAIN_PROFILE"
    fail "notarization was not accepted"
fi

# --- staple & package -----------------------------------------------------

log "stapling ticket"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

log "verifying with Gatekeeper"
spctl -a -vv -t exec "$APP_PATH" 2>&1 | grep -q "source=Notarized Developer ID" \
    || fail "Gatekeeper does not report app as notarized"

log "packaging final zip"
mkdir -p "$OUTPUT_DIR"
ditto -c -k --keepParent "$APP_PATH" "$FINAL_ZIP"

log "done: $FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP"
