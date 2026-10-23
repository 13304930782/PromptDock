#!/bin/bash
# Build a universal candidate. Public mode requires a real Developer ID and notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-internal}"
OUTPUT="${2:-$PWD/dist}"
case "$MODE" in internal|public) ;; *) echo 'Usage: package-macos.sh internal|public [output-directory]' >&2; exit 2;; esac
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/promptdock-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
if [[ "$MODE" == public ]]; then
  : "${PROMPTDOCK_DEVELOPER_ID:?Set the Developer ID Application signing identity}"
  : "${PROMPTDOCK_NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
  [[ "$PROMPTDOCK_DEVELOPER_ID" == 'Developer ID Application:'* ]] || { echo 'Public builds require Developer ID Application, not Apple Development.' >&2; exit 2; }
  SCHEME=PromptDock
  CONFIG=Release
  PRODUCT=PromptDock
  LABEL=PromptDock-1.3.0-rc.2
  SIGNING=("CODE_SIGN_IDENTITY=$PROMPTDOCK_DEVELOPER_ID" CODE_SIGN_STYLE=Manual)
else
  SCHEME='PromptDock Dev'
  CONFIG=Debug
  PRODUCT='PromptDock Dev'
  LABEL=PromptDock-1.3.0-rc.2-INTERNAL-DEV
  SIGNING=('CODE_SIGN_IDENTITY=Apple Development')
fi
xcodebuild -project PromptDock.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' -derivedDataPath "$WORK/build" \
  ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO "${SIGNING[@]}" build > "$OUTPUT/$LABEL-build.log" 2>&1
APP="$WORK/build/Build/Products/$CONFIG/$PRODUCT.app"
codesign --verify --deep --strict --verbose=2 "$APP"
# Validate the actual signed app and extension, not only source entitlements.
APP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :PromptDockAppGroupIdentifier' "$APP/Contents/Info.plist")"
if [[ "$MODE" == internal ]]; then
  EXPECTED_ID=com.promptdock.PromptDock.Dev
  [[ "$APP_GROUP" == *.PromptDock.Dev ]] || { echo 'Internal app must use the Dev group.' >&2; exit 1; }
else
  EXPECTED_ID=com.promptdock.PromptDock
  [[ "$APP_GROUP" != *.Dev ]] || { echo 'Public app must not use the Dev group.' >&2; exit 1; }
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" == "$EXPECTED_ID" ]]
WIDGET="$APP/Contents/PlugIns/PromptDockWidget.appex"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WIDGET/Contents/Info.plist")" == "$EXPECTED_ID.Widget" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :PromptDockAppGroupIdentifier' "$WIDGET/Contents/Info.plist")" == "$APP_GROUP" ]]
for BUNDLE in "$APP" "$WIDGET"; do
  codesign -d --entitlements :- "$BUNDLE" > "$WORK/entitlements.plist" 2>/dev/null
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$WORK/entitlements.plist")" == true ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$WORK/entitlements.plist")" == "$APP_GROUP" ]]
  EXTRA_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:1' "$WORK/entitlements.plist" 2>/dev/null || true)"
  [[ -z "$EXTRA_GROUP" ]] || { echo 'Unexpected additional App Group.' >&2; exit 1; }
  if [[ "$MODE" == public ]]; then
    DEBUGGABLE="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$WORK/entitlements.plist" 2>/dev/null || true)"
    [[ "$DEBUGGABLE" != true ]] || { echo 'Refusing a debuggable public build.' >&2; exit 1; }
    codesign -dv --verbose=4 "$BUNDLE" 2>&1 | grep -q 'flags=.*runtime' || { echo 'Hardened Runtime is required.' >&2; exit 1; }
  fi
done
lipo "$APP/Contents/MacOS/$PRODUCT" -verify_arch x86_64 arm64
lipo "$APP/Contents/PlugIns/PromptDockWidget.appex/Contents/MacOS/PromptDockWidget" -verify_arch x86_64 arm64
mkdir "$WORK/image"
ditto "$APP" "$WORK/image/$PRODUCT.app"
ln -s /Applications "$WORK/image/Applications"
if [[ "$MODE" == internal ]]; then
  printf '%s\n' 'INTERNAL DEVELOPMENT BUILD — not notarized, not approved for public distribution.' 'Independent Dev library. Do not rename this app to replace the production app.' > "$WORK/image/READ-ME.txt"
fi
hdiutil create -volname "$LABEL" -srcfolder "$WORK/image" -ov -format UDZO "$OUTPUT/$LABEL.dmg"
if [[ "$MODE" == public ]]; then
  codesign --force --sign "$PROMPTDOCK_DEVELOPER_ID" --timestamp "$OUTPUT/$LABEL.dmg"
  xcrun notarytool submit "$OUTPUT/$LABEL.dmg" --keychain-profile "$PROMPTDOCK_NOTARY_PROFILE" --wait --output-format json > "$OUTPUT/$LABEL-notarization.json"
  /usr/bin/plutil -extract status raw "$OUTPUT/$LABEL-notarization.json" | /usr/bin/grep -qx Accepted
  xcrun stapler staple "$OUTPUT/$LABEL.dmg"
  xcrun stapler validate "$OUTPUT/$LABEL.dmg"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$OUTPUT/$LABEL.dmg"
fi
(cd "$OUTPUT" && shasum -a 256 "$LABEL.dmg" > "$LABEL.dmg.sha256")
printf 'Created %s/%s.dmg\n' "$OUTPUT" "$LABEL"
