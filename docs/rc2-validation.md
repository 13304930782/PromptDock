# RC2 validation — 2026-10-23

Environment: Intel MacBook Pro, macOS 15.8.1, Xcode 16.4. All data tests use synthetic records and temporary directories or in-memory stores. No paid API requests.

## Automated checks

- Build 11 Debug suite: **103 passed, 0 failed** (`rc2-final.xcresult`, after search tuning).
- Real-disk safety-backup failure: no persistence attempt and no library changes.
- Real-disk replacement and recovery: prompt IDs/content/favorites, tags, variable definitions, history, smart collections and Trash preserved. Fixtures use fixed timestamps to avoid sub-microsecond JSON Date rounding affecting exact equality checks.
- V1/V2 JSON import to disk, V1 store opening and V2 migration metadata checked.
- Automatic backup reads the committed state before the pending edit and creates only one daily backup.
- 100k search cancellation does not publish stale results. Mocked AI request/stream tests remain in the full suite.
- Scheme inspection: `PROMPTDOCK_TESTING=1` remains enabled. Xcode rewrites BuildableName display metadata; actual product names and bundle IDs are controlled by build settings and package checks. Existing formatting changes are not committed.

## Search evidence

10,000 synthetic prompts, three warm-ups followed by 20 measured queries per mode. Timing includes snapshot generation, debounce (baseline 120 ms; candidate 40 ms), search and ID mapping; **does not include SwiftUI rendering**.

| Configuration | Library (all results) P95 | Quick Search (12 results) P95 |
| --- | ---: | ---: |
| Debug, baseline 120 ms delay | 579.0 ms | 582.5 ms |
| Release, baseline 120 ms delay | 370.9 ms | 356.9 ms |
| Release, candidate 40 ms delay | 282.3 ms | 279.5 ms |

The optimized candidate run also passed superseded-query and 100k cancellation tests. Measurements ran before packaging began to avoid concurrent build load. Debug figures are not a Release acceptance result. Do not infer the ≤300 ms end-to-end UI target has passed. The result attachments contain no user library content or credentials.

## Remaining gates

Actual system permission refusal, signed Widget interaction, other-Mac/isolated-account installation and upgrades, keyboard/VoiceOver and layout review, full UI latency and large import responsiveness, seven-day use regression, Developer ID/notarization/Gatekeeper remain pending. Native app UI automation is unavailable in the current tool connection; compilation/unit tests do not substitute for these checks.

The candidate must remain a development build and Release draft until distribution prerequisites and manual gates are explicitly satisfied.
