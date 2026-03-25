# MVP Release Readiness Checklist — DANTE TERMINAL v1.0.0

**Purpose:** Binary ship-or-no-ship decision framework for the founding team.
**Rule:** Every criterion is PASS or FAIL. No subjective judgment. If any P0 criterion is FAIL, the recommendation is NO-SHIP.

---

## How to Use This Checklist

1. Work through each criterion in order.
2. Run the listed verification command or inspect the listed file path.
3. Mark PASS or FAIL — nothing else.
4. Tally results in the Summary section at the bottom.
5. Apply the ship decision rule stated in the Summary.

All file paths are relative to the project root: `dante_terminal/`
All commands assume the working directory is `dante_terminal/`.

---

## Section 1: Store Submission Requirements

These criteria verify that the app can be accepted by Apple App Store and Google Play review.

### SS-01 [P0] iOS app icon set contains all required sizes

**Verify:** `ls ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png | wc -l`
**Pass condition:** Output is >= 13 (covering 20pt through 1024pt at 1x/2x/3x)
**File:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`

### SS-02 [P0] Android adaptive icon resources exist in all 5 density buckets

**Verify:** `for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do test -f android/app/src/main/res/mipmap-$d/ic_launcher.png && echo "$d PASS" || echo "$d FAIL"; done`
**Pass condition:** All 5 densities print PASS.

### SS-03 [P0] Android application ID is set and does not contain default placeholder

**Verify:** `grep 'applicationId' android/app/build.gradle.kts`
**Pass condition:** Value is `"com.danteterminal.dante_terminal"` (not `com.example.*`).
**File:** `android/app/build.gradle.kts`

### SS-04 [P0] iOS bundle identifier is set and does not contain default placeholder

**Verify:** `grep 'PRODUCT_BUNDLE_IDENTIFIER' ios/Runner.xcodeproj/project.pbxproj | head -1`
**Pass condition:** Value is `com.danteterminal.danteTerminal` (not `com.example.*`).

### SS-05 [P0] iOS release signing identity is configured or obtainable

**Verify:** On a Mac with Xcode installed, run `security find-identity -v -p codesigning | grep -c "Apple Distribution"`
**Pass condition:** Output >= 1, OR the team confirms an Apple Developer Program membership with active distribution certificate.
**Note:** CI currently uses `--no-codesign`. A signing identity is required before actual App Store submission.

### SS-06 [P0] Android release signing keystore exists or generation steps are documented

**Verify:** `grep -c 'signingConfigs' android/app/build.gradle.kts`
**Pass condition:** Output >= 1 with a release signingConfig block, OR the team has generated a keystore file and documented the path.
**Note:** Currently uses debug signing. A release keystore is required before Google Play submission.

### SS-07 [P0] Privacy policy document exists and contains no placeholder values

**Verify:** `grep -c 'PLACEHOLDER\|TODO\|TBD\|\[.*\]' ../.godai/artifacts/BL-093/privacy-policy.md`
**Pass condition:** Output is 0 (no unresolved placeholders).
**File:** `.godai/artifacts/BL-093/privacy-policy.md`

### SS-08 [P0] Privacy policy is hosted at a publicly accessible URL

**Verify:** `curl -s -o /dev/null -w "%{http_code}" <PRIVACY_POLICY_URL>`
**Pass condition:** HTTP status code is 200.
**Note:** URL must be entered in both App Store Connect and Google Play Console during submission.

### SS-09 [P0] App version and build number are set in pubspec.yaml

**Verify:** `grep '^version:' pubspec.yaml`
**Pass condition:** Output matches pattern `version: X.Y.Z+N` where X.Y.Z is the release version and N >= 1.
**File:** `pubspec.yaml` (currently `1.0.0+1`)

### SS-10 [P1] Age rating has been determined for both stores

**Verify:** Confirm the team has answers for Apple's age rating questionnaire and Google's content rating questionnaire.
**Pass condition:** Documented in `.godai/artifacts/BL-093/store-submission-checklist.md` Section 2.3 (Apple) and Section 3.4 (Google).
**File:** `.godai/artifacts/BL-093/store-submission-checklist.md`

---

## Section 2: Gameplay Completeness

These criteria verify that the core game loop functions end-to-end.

### GC-01 [P0] Model download completes successfully on a real device with WiFi

**Verify:** Install the app on a physical iOS or Android device connected to WiFi. Launch the app. Observe the download screen. Wait for completion.
**Pass condition:** The download screen shows 100% progress, transitions to "Verifying..." state, then advances to the game screen without error. File `model.gguf` exists in the app's documents directory.
**Config:** `lib/config/model_config.dart` — URL resolves to a downloadable GGUF file at `https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf`

### GC-02 [P0] SHA-256 checksum of downloaded model matches expected value

**Verify:** After GC-01 completes, check the app logs for verification result, or manually run `shasum -a 256 <path_to_model.gguf>` on the device filesystem.
**Pass condition:** Hash matches `f521a15453fd7f820e8467f4a307c99e44f5ab9cc24273d2fe67cd7cb1288f05`.
**File:** `lib/config/model_config.dart` (ModelConfig.sha256)

### GC-03 [P0] Adventure starts with an opening narrative when a new game begins

**Verify:** On a device with the model downloaded, tap "New Game" (or equivalent). Observe the terminal screen.
**Pass condition:** The AI generates a multi-sentence opening scene description that is contextually appropriate to "The Sunken Archive" adventure setting within 30 seconds.
**File:** `assets/adventures/sunken_archive.json` (adventure definition), `assets/game_master_prompt.txt` (system prompt)

### GC-04 [P0] Player text commands produce coherent AI responses

**Verify:** After GC-03, type "look around" and submit. Then type "go north" and submit.
**Pass condition:** Each command produces a narrative response that acknowledges the player's action and describes the environment or outcome. Responses do not contain raw JSON, error messages, or obviously unrelated text.

### GC-05 [P0] Three suggestion chips render below the AI response

**Verify:** After any AI response in GC-04, observe the area below the narrative text.
**Pass condition:** Exactly 3 tappable suggestion chips are visible, each containing a short action phrase (2-6 words).
**File:** `lib/main.dart` (TerminalScreen suggestion chip rendering)

### GC-06 [P0] Tapping a suggestion chip submits it as a player command

**Verify:** Tap any of the 3 suggestion chips from GC-05.
**Pass condition:** The tapped suggestion text appears as a player command in the terminal history, and the AI generates a new response.

### GC-07 [P0] Game state saves on app backgrounding and restores on relaunch

**Verify:** Play 3+ turns. Press the device home button (background the app). Force-quit the app. Relaunch.
**Pass condition:** The app presents a "Continue" option. Selecting it restores the game with previous turn history visible and the game continues from where it left off.
**File:** `lib/services/game_session.dart` (saveState, restoreFromSaveData), `lib/main.dart` (_checkForSavedGame)

---

## Section 3: Technical Stability

These criteria verify the app does not crash or fail ungracefully under expected conditions.

### TS-01 [P0] App launches to a usable screen on cold start without crashing

**Verify:** Force-quit the app. Launch it from the device home screen.
**Pass condition:** The app reaches either the model download screen (first run) or the game screen (model present) within 5 seconds without crashing.

### TS-02 [P0] Model download handles missing network gracefully

**Verify:** Enable airplane mode on the device. Launch the app (with no model downloaded).
**Pass condition:** The download screen shows a user-readable error message (not a stack trace or blank screen). The app does not crash. The user can retry after reconnecting.
**File:** `lib/screens/model_download_screen.dart` (error state handling)

### TS-03 [P0] Model download handles insufficient storage gracefully

**Verify:** Fill device storage to < 500 MB free. Attempt to download the model (~986 MB).
**Pass condition:** The app shows a user-readable error about insufficient storage. The app does not crash. No partial `.part` file is left consuming storage on failure.
**File:** `lib/services/model_download_service.dart` (cleanup on failure)

### TS-04 [P0] All unit tests pass

**Verify:** `flutter test`
**Pass condition:** Output shows "All tests passed!" with 0 failures. Current expected count: 146 tests across 10 test files.
**Directory:** `test/`

### TS-05 [P0] Static analysis produces zero errors and zero warnings

**Verify:** `flutter analyze --fatal-infos`
**Pass condition:** Output shows "No issues found!" with exit code 0.

### TS-06 [P0] CI pipeline completes the test job successfully

**Verify:** Push to main or open a PR. Check GitHub Actions.
**Pass condition:** The "Analyze & Test" job in `.github/workflows/mobile-ci.yml` shows a green checkmark.
**File:** `.github/workflows/mobile-ci.yml`

### TS-07 [P0] CI pipeline produces an Android AAB artifact

**Verify:** After TS-06 passes, check the "Build Android" job artifacts.
**Pass condition:** An `app-release.aab` artifact is downloadable from the GitHub Actions run.
**Build command:** `flutter build appbundle --release`

### TS-08 [P1] CI pipeline produces an iOS archive artifact

**Verify:** After TS-06 passes, check the "Build iOS" job artifacts.
**Pass condition:** An archive directory is present in the GitHub Actions run artifacts.
**Build command:** `flutter build ipa --no-codesign`
**Note:** Unsigned. Signing is a separate criterion (SS-05).

### TS-09 [P0] App does not crash when AI inference produces malformed output

**Verify:** Play 10+ turns issuing varied commands including nonsensical input ("asdfghjkl", empty string, very long string of 500+ characters).
**Pass condition:** The app never crashes. Malformed AI output is handled by showing a fallback response or retry prompt, not a stack trace.
**File:** `lib/services/game_session.dart` (response parsing)

---

## Section 4: Content and Legal Readiness

These criteria verify that store listing content and legal documents are complete and consistent.

### CL-01 [P0] App Store listing title fits within Apple character limit

**Verify:** Count characters in the Apple title.
**Pass condition:** Title is <= 30 characters. Current: "DANTE TERMINAL: Text Adventure" (30 chars).
**File:** `.godai/artifacts/BL-090/app-store-listing-package.md` (Section 1.1)

### CL-02 [P0] Google Play listing title fits within Google character limit

**Verify:** Count characters in the Google Play title.
**Pass condition:** Title is <= 50 characters. Current: "DANTE TERMINAL: Offline AI Text Adventure RPG" (47 chars).
**File:** `.godai/artifacts/BL-090/app-store-listing-package.md` (Section 2.1)

### CL-03 [P0] Privacy policy accurately reflects actual data collection

**Verify:** Read the privacy policy. Compare every claim against the app's actual behavior.
**Pass condition:** The policy states no data is collected, no analytics are used, no network calls are made except model download. This matches the codebase: no analytics SDK in `pubspec.yaml`, no tracking code in `lib/`, model download is the only HTTP call.
**Files:** `.godai/artifacts/BL-093/privacy-policy.md`, `pubspec.yaml`, `lib/services/model_download_service.dart`

### CL-04 [P0] Terms of Service document exists and contains no placeholder values

**Verify:** `grep -c 'PLACEHOLDER\|TODO\|TBD\|\[.*\]' ../.godai/artifacts/BL-093/terms-of-service.md`
**Pass condition:** Output is 0.
**File:** `.godai/artifacts/BL-093/terms-of-service.md`

### CL-05 [P0] Google Play Data Safety form declarations match app behavior

**Verify:** Review the data safety answers documented in the store submission checklist. Compare against actual app behavior.
**Pass condition:** All answers declare "no data collected, no data shared" which matches the codebase (no analytics, no tracking, no user accounts).
**File:** `.godai/artifacts/BL-093/store-submission-checklist.md` (Section 3.3)

### CL-06 [P1] Apple App Store privacy nutrition labels match app behavior

**Verify:** Review the App Store Connect privacy declarations in the store submission checklist.
**Pass condition:** All categories marked as "Data Not Collected" which matches the codebase.
**File:** `.godai/artifacts/BL-093/store-submission-checklist.md` (Section 2.2)

### CL-07 [P1] Store listing descriptions exist for both platforms

**Verify:** `test -f ../.godai/artifacts/BL-090/app-store-listing-package.md && echo PASS || echo FAIL`
**Pass condition:** File exists and contains non-empty full description text for both Apple App Store and Google Play.
**File:** `.godai/artifacts/BL-090/app-store-listing-package.md`

---

## Summary

### Tally Instructions

Count PASS and FAIL for each section, then compute totals.

| Section | Total Criteria | P0 Criteria | P0 Pass | P0 Fail | P1 Pass | P1 Fail |
|---------|---------------|-------------|---------|---------|---------|---------|
| 1. Store Submission | 10 | 9 | ___ | ___ | ___ | ___ |
| 2. Gameplay Completeness | 7 | 7 | ___ | ___ | ___ | ___ |
| 3. Technical Stability | 9 | 8 | ___ | ___ | ___ | ___ |
| 4. Content and Legal | 7 | 5 | ___ | ___ | ___ | ___ |
| **TOTAL** | **33** | **29** | ___ | ___ | ___ | ___ |

### Ship Decision Rule

```
IF P0 Fail count == 0:
    RECOMMENDATION: SHIP
    Proceed with store submission. P1 failures do not block v1.0.0
    and should be tracked as follow-up items.

IF P0 Fail count >= 1 AND P0 Fail count <= 3:
    RECOMMENDATION: NO-SHIP (fix and re-evaluate)
    List the failing P0 criteria. Estimate fix effort. Re-run this
    checklist after fixes are applied.

IF P0 Fail count > 3:
    RECOMMENDATION: NO-SHIP (significant gaps remain)
    The prototype is not release-ready. Prioritize P0 failures by
    section order (Store Submission > Gameplay > Stability > Legal).
```

### Known Pre-Submission Blockers (as of checklist creation)

Based on the current codebase state, the following P0 criteria are expected to FAIL and require action before a ship decision:

1. **SS-05** — No iOS release signing identity configured (CI uses `--no-codesign`)
2. **SS-06** — No Android release keystore configured (uses debug signing)
3. **SS-07** — Privacy policy contains placeholder values (mailing address, jurisdiction)
4. **SS-08** — Privacy policy not yet hosted at a public URL
5. **CL-04** — Terms of Service contains placeholder values (jurisdiction, arbitration body, mailing address)

All 5 are addressable without code changes to the app itself.

### Criteria Index

| ID | Priority | Section | Short Description |
|----|----------|---------|-------------------|
| SS-01 | P0 | Store Submission | iOS icon set complete |
| SS-02 | P0 | Store Submission | Android adaptive icons in 5 densities |
| SS-03 | P0 | Store Submission | Android application ID set |
| SS-04 | P0 | Store Submission | iOS bundle identifier set |
| SS-05 | P0 | Store Submission | iOS signing identity available |
| SS-06 | P0 | Store Submission | Android signing keystore available |
| SS-07 | P0 | Store Submission | Privacy policy has no placeholders |
| SS-08 | P0 | Store Submission | Privacy policy hosted at public URL |
| SS-09 | P0 | Store Submission | App version set in pubspec.yaml |
| SS-10 | P1 | Store Submission | Age rating determined |
| GC-01 | P0 | Gameplay | Model download completes on device |
| GC-02 | P0 | Gameplay | SHA-256 checksum matches |
| GC-03 | P0 | Gameplay | Opening narrative generates |
| GC-04 | P0 | Gameplay | Player commands produce coherent responses |
| GC-05 | P0 | Gameplay | Three suggestion chips render |
| GC-06 | P0 | Gameplay | Suggestion chips are tappable |
| GC-07 | P0 | Gameplay | Save on exit, restore on launch |
| TS-01 | P0 | Technical Stability | No crash on cold start |
| TS-02 | P0 | Technical Stability | Handles missing network |
| TS-03 | P0 | Technical Stability | Handles insufficient storage |
| TS-04 | P0 | Technical Stability | All unit tests pass |
| TS-05 | P0 | Technical Stability | Zero analysis warnings |
| TS-06 | P0 | Technical Stability | CI test job green |
| TS-07 | P0 | Technical Stability | CI produces Android AAB |
| TS-08 | P1 | Technical Stability | CI produces iOS archive |
| TS-09 | P0 | Technical Stability | No crash on malformed AI output |
| CL-01 | P0 | Content and Legal | Apple title within limit |
| CL-02 | P0 | Content and Legal | Google title within limit |
| CL-03 | P0 | Content and Legal | Privacy policy matches behavior |
| CL-04 | P0 | Content and Legal | ToS has no placeholders |
| CL-05 | P0 | Content and Legal | Google Data Safety matches app |
| CL-06 | P1 | Content and Legal | Apple nutrition labels match app |
| CL-07 | P1 | Content and Legal | Store descriptions exist |
