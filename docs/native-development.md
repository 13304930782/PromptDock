# Native development isolation

This branch starts from the native 1.2.0 Build 7 sources on
`codex/promptdock-1.2-local-workflow`, retaining the current main website and server.

## Build identities

| Setting | Debug / PromptDock Dev scheme | Release / PromptDock archive |
| --- | --- | --- |
| Product | PromptDock Dev.app | PromptDock.app |
| Bundle ID | com.promptdock.PromptDock.Dev | com.promptdock.PromptDock |
| Widget ID | com.promptdock.PromptDock.Dev.Widget | com.promptdock.PromptDock.Widget |
| App Group | L96B6KHL5Y.PromptDock.Dev | L96B6KHL5Y.PromptDock |
| Keychain service | com.promptdock.PromptDock.Dev.ai-api-key | com.promptdock.PromptDock.ai-api-key |

UserDefaults follows the application's separate bundle identity. The development
app never copies or opens the production library. Import an explicitly exported
backup to use real content. Register the development App Group for the signing
team before testing signed builds; do not change production entitlements.

The Dev scheme uses Debug for launch, profile and archive. Production archives use
the original PromptDock scheme and Release. Both remain sandboxed.

## Tests and permission denial

The test scheme sets PROMPTDOCK_TESTING=1. XCTest environment markers provide an
additional fallback. The hosted app does not bootstrap its UI, store or runtime.
Default test stores are in-memory; persistence tests pass their own temporary URL.
Shared container resolution, widget snapshots, login items and Keychain operations
are disabled in tests. Explicit keychain writes fail rather than silently persist.

The startup error view resolves the data directory only when Show Data Folder is
clicked. It does not query the container while rendering. Widget synchronization
pauses after its first error until Retry Widget Sync in Settings is clicked (or
the app restarts). Startup retry is also an explicit user action.

## Validation

Run on a Mac with Xcode installed:

```sh
xcodebuild -project PromptDock.xcodeproj -scheme 'PromptDock Dev' -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project PromptDock.xcodeproj -scheme PromptDock -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

CI tests the Debug host and checks both app/extension identities before building
Release. Unsigned CI cannot validate TCC or signed entitlements. Before release,
inspect `codesign -d --entitlements :-` for both signed bundles, deny access once,
verify no repeated dialogs without user retry, and confirm the installed Release
app and Widget still read their original library. Do not reset privacy permissions
or enable Full Disk Access for this test.

## Remaining milestones

Data protection (Schema V3, trash, drafts and automatic backups), transactional
multiformat import/export, and search/template performance are separate follow-up
milestones. These features are not claimed complete by the isolation PR. Each
requires its own tests and PR; merging to main requires explicit approval. A
release candidate also needs one week of real-use regression testing.

## Follow-up implementation branches

- `codex/promptdock-data-protection`: V3 tombstones, 30-day retention, selected
  restore/permanent delete, local editor drafts with revision checking, and seven
  automatic pre-save backups. V1/V2 backup decoding accepts absent newer arrays.
- `codex/promptdock-batch-transfer`: multi-file preview, keep/update/copy policy,
  explicit valid-only consent, stale-preview checks, JSON content packages,
  Markdown metadata/ZIP and RFC-style quoted CSV with UTF-8 templates.
- `codex/promptdock-search-workflow`: common snapshot ranking with tags, cancellable
  delayed search, quick-search variable metadata, multiline list paste and tests.

These stacked PRs are implementation candidates, not a release acceptance claim.
The earlier Remaining milestones list describes the original sequencing.

## Release acceptance checklist

CI runs memory/temp-store tests, V1/V2 migrations, restore and backup tests,
CSV/Markdown round trips, conflict/stale-preview checks, and snapshot-search
stress tests (10k and 100k records). CI timing is logged, not used as a substitute
for the fixed-machine P95 target. On the release test Mac record hardware, OS,
configuration and dataset, run at least 20 warmed queries, and verify P95 <=300ms
for 10k normal prompts. Include snapshot generation and UI presentation in the
manual measurement, not just worker execution.

Before promoting the candidate, manually validate:
- signed Dev/Release app and Widget identities and entitlements;
- refusal of container access, explicit retry, and existing production data;
- crash/relaunch draft recovery, simultaneous edits and deleted-record conflicts;
- backup failure/retry and a failed replacement save with rollback;
- large batch progress, malformed/oversized inputs and ZIP extraction;
- VoiceOver, keyboard-only operation, and English/Simplified Chinese layouts;
- at least seven days of actual use, recording defects and retesting fixes.

Do not install a candidate over the production app or merge any PR automatically.
