#!/bin/bash
# Synthetic pipeline benchmark; does not measure SwiftUI rendering.
set -euo pipefail
cd "$(dirname "$0")/.."
OUTPUT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/promptdock-search.XXXXXX")}"
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
RESULT="$OUTPUT/Search-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project PromptDock.xcodeproj -scheme 'PromptDock Dev' \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$OUTPUT/build" -resultBundlePath "$RESULT" \
  -only-testing:PromptDockTests/PromptDockTests/testSearchPipelineIncludesSnapshotDebounceAndResultApplication \
  ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO test > "$OUTPUT/build.log" 2>&1
xcrun xcresulttool get test-results summary --path "$RESULT" > "$OUTPUT/summary.json"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUTPUT/attachments"
printf 'Results: %s\nIncludes synthetic snapshots, debounce and mapping; excludes SwiftUI rendering.\n' "$OUTPUT"
