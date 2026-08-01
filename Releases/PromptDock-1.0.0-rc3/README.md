# PromptDock 1.0.0 RC3 Early Access

## Release information

- App version: `1.0.0`
- Build: `2`
- Minimum system: macOS 14
- Architectures: Apple Silicon (`arm64`) and Intel (`x86_64`)
- Distribution: Personal Team development signature, not Apple notarized
- Package: `PromptDock-1.0.0-rc3.dmg`

The DMG and its SHA-256 file are generated from the tested Release build. Do not
replace an existing RC3 artifact after it has been shared. A changed binary must
use a new build number and release-candidate name.

## What changed

- Added fill-before-copy template variables with live preview.
- Added repeatable `{{name[]}}` variables with up to 100 values.
- Added an in-app template syntax guide.
- Added an optional AI template assistant for DeepSeek and OpenAI-compatible
  endpoints.
- Stored AI credentials in macOS Keychain.
- Added explicit confirmation before an AI request is sent.
- Improved AI cancellation and error handling.
- Updated the in-app and repository privacy explanations.

## Install

1. Download and open `PromptDock-1.0.0-rc3.dmg`.
2. Drag PromptDock into the Applications folder.
3. Because this Early Access build is not notarized, the first launch may be
   blocked by Gatekeeper. Control-click PromptDock in Applications, choose
   **Open**, then confirm **Open**.
4. Do not disable Gatekeeper or change global macOS security settings.

## Upgrade from an earlier build

1. In the old PromptDock, open **Settings → Privacy → Export Backup…** and save
   a JSON backup.
2. Quit PromptDock completely, including its menu-bar process.
3. Open the RC3 DMG and drag PromptDock into Applications.
4. Choose **Replace** when Finder asks.
5. Start PromptDock and check prompts, categories, settings, Widget, and the
   stored AI credential.

PromptDock keeps the same Bundle Identifier, App Group, SwiftData V1 schema,
preferences, and Keychain service, so replacing the app should preserve data.
The exported backup remains the recovery copy.

## AI privacy and BYOK

- Online AI generation is disabled until the user enables and configures it.
- Early Access users provide their own DeepSeek or compatible API credential.
- Credentials are stored in macOS Keychain and are not written to JSON backups.
- Only after explicit confirmation are the current requirement and template
  syntax guide sent to the selected provider.
- Saved prompts, categories, and local images are not included in the request.
- The selected provider's privacy terms and account billing apply.

## Known limitations

- The build is not notarized and can show a Gatekeeper warning on another Mac.
- Updates are manual Finder replacements; there is no silent auto-updater.
- AI availability, billing, retention, and regional access depend on the
  provider chosen by the user.
- RC3 does not provide accounts, cloud sync, collaboration, iPhone, iPad, or
  Windows clients.

## Release smoke test

Complete this checklist with the packaged app, not only an Xcode build:

- [ ] Clean install and first launch
- [ ] Main window and Settings open normally
- [ ] Create, edit, favorite, delete, categorize, and reorder a prompt
- [ ] Main search highlighting, result count, and next/previous navigation
- [ ] Menu-bar Quick Search, arrow navigation, Return copy, and Esc close
- [ ] Global shortcut and shortcut conflict behavior
- [ ] Widget add, refresh, copy, restart, and persistence
- [ ] JSON export, merge import, replace import, and rollback on failure
- [ ] Standard variables, repeatable variables, 100-item limit, and live preview
- [ ] AI disabled state, missing key, invalid key, cancellation, and timeout
- [ ] One real DeepSeek request with `deepseek-v4-flash`
- [ ] One configured OpenAI-compatible endpoint, if available
- [ ] RC2-to-RC3 replacement preserves data, preferences, and Keychain entry
- [x] DMG layout, Applications link, version, architectures, and signatures

### CueGrove delivery flow

- [ ] Confirm the deployed privacy and security pages describe optional online AI accurately
- [ ] Confirm the Early Access approval flow uses the fixed RC3 HTTPS download URL
- [ ] Complete one test application, administrator notification, review, approval, and download email
- [ ] Verify Chinese and English email content, buttons, download URL, and rejection behavior
- [ ] Remove or clearly mark test applications before using production application counts

Automated release verification completed on 2026-07-31:

- 50 unit tests passed.
- Debug test build passed.
- Unsigned universal Release build passed.
- Personal Team signed universal Release build passed.
- The mounted DMG reports version `1.0.0` (build `2`) and macOS 14 minimum.
- Main app and Widget both contain `arm64` and `x86_64` slices.
- Deep signature verification and DMG checksum verification passed.
- Gatekeeper rejection is expected because this Personal Team build is not
  Developer ID signed or notarized.

The remaining unchecked items require a real installed-app session or a real
provider credential and must be completed before distribution expands beyond
the first five testers.

Stop distribution for any data loss, startup blocker, failed backup recovery,
Widget-related database damage, request sent without confirmation, or credential
appearing in logs, preferences, or backup files.

## Tester feedback template

Please do not include private prompt text unless it is essential and safe to
share.

```text
Device:
Chip: Apple Silicon / Intel
macOS version:
PromptDock version and build: 1.0.0 (2)

Steps to reproduce:
1.
2.
3.

Expected result:
Actual result:
How often it happens:
Screenshot or screen recording (optional):
```

## Early Access gate

Start with five testers. Expand to at most ten only after the first week has no
release-blocking issue. Promote beyond RC only after two consecutive weeks with
no known data loss, startup blocker, or backup-recovery failure.
