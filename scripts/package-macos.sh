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
  LABEL=PromptDock-1.3.0-rc.1
  SIGNING=("CODE_SIGN_IDENTITY=$PROMPTDOCK_DEVELOPER_ID" CODE_SIGN_STYLE=Manual)
else
  SCHEME='PromptDock Dev'
  CONFIG=Debug
  PRODUCT='PromptDock Dev'
  LABEL=PromptDock-1.3.0-rc.1-INTERNAL-DEV
  SIGNING=('CODE_SIGN_IDENTITY=Apple Development')
fi
xcodebuild -project PromptDock.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' -derivedDataPath "$WORK/build" \
  ARCHS='x86_64 arm64' ONLY_ACTIVE_ARCH=NO "${SIGNING[@]}" build > "$OUTPUT/$LABEL-build.log" 2>&1
APP="$WORK/build/Build/Products/$CONFIG/$PRODUCT.app"
codesign --verify --deep --strict --verbose=2 "$APP"
if [[ "$MODE" == public ]]; then
  for BUNDLE in "$APP" "$APP/Contents/PlugIns/PromptDockWidget.appex"; do
    codesign -d --entitlements :- "$BUNDLE" > "$WORK/entitlements.plist" 2>/dev/null
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$WORK/entitlements.plist")" == true ]]
    DEBUGGABLE="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$WORK/entitlements.plist" 2>/dev/null || true)"
    [[ "$DEBUGGABLE" != true ]] || { echo 'Refusing a debuggable public build.' >&2; exit 1; }
  done
fi
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
