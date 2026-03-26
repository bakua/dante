# Post-Push CI Failure Playbook

> **BL-215** | HEAD: `77d0d11` | Date: 2026-03-26 | 32 unpushed commits
>
> Use this playbook after running `git push origin main` (BL-195 task H1).
> The CI pipeline (`.github/workflows/mobile-ci.yml`) has not run on any commit since ~cycle 70. Expect some failures. This document tells you which are expected, which need action, and exactly what to do.

---

## CI Pipeline Overview

Three jobs run in sequence:

```
test (ubuntu-latest)
├── flutter analyze --fatal-infos
└── flutter test --coverage
        │
        ├── build-android (ubuntu-latest) → flutter build appbundle --release
        └── build-ios (macos-latest)      → flutter build ipa --no-codesign
```

Additionally, a separate workflow `.github/workflows/deploy-pages.yml` deploys `docs/` to GitHub Pages when files under `docs/` change.

---

## Local Baseline (verified at HEAD `77d0d11`)

| Check | Result | Notes |
|-------|--------|-------|
| `flutter analyze` | **CLEAN** — 0 issues | Ran 2026-03-26, 1.4s |
| `flutter test` | **196/196 PASS** | 14 test files, ~13s, 0 failures, 0 skips |
| `flutter build appbundle --release` | **SUCCESS** — 92.0 MB AAB | Debug-signed (no key.properties on CI) |
| `flutter build ios --release --no-codesign` | **SUCCESS** — 21.3 MB .app | Unsigned, local macOS only |

**Bottom line:** If CI fails, it is NOT because the code is broken. It is because the CI environment differs from local (signing, platform, flags). See the 5 failure modes below.

---

## Failure Mode 1: Dart Analysis Warnings

### Likelihood: LOW

### What you'd see
```
   Running flutter analyze...
   error • ... • lib/some_file.dart:42:5 • some_lint_rule
   Error: 1 issue found. (1 error)
```

### Root cause
The CI workflow runs `flutter analyze --fatal-infos` which treats `info`-level hints as errors. Locally, `flutter analyze` (without `--fatal-infos`) also reports these but doesn't fail. However, **the current codebase produces zero issues on local `flutter analyze`** — including infos, warnings, and errors. So this failure mode is unlikely unless the CI Flutter version differs from local (3.38.9 stable).

### Fix
1. Check the GitHub Actions log for the exact lint rule that triggered
2. Open the file and line shown in the error
3. Fix the lint violation (usually a missing type annotation, unused import, or deprecated API)
4. If it's a false positive or stylistic disagreement:
   ```dart
   // ignore: the_lint_rule
   ```
5. Commit and push

### Quick diagnostic command (run locally)
```bash
cd dante_terminal && flutter analyze --fatal-infos
```

---

## Failure Mode 2: Tests Pass Locally but Fail on CI

### Likelihood: LOW

### What you'd see
```
   00:XX +195 -1: Some test name
   FAILED: Expected: ...
           Actual: ...
```

### Root cause
The test suite (196 tests, 14 files) uses no platform-dependent assertions, no `dart:io` filesystem access in tests, no network calls, and no platform detection (`Platform.isX` only in production code, never in test code). All external dependencies are mocked. This makes CI-vs-local divergence unlikely.

Possible causes if it does happen:
- **Flutter version mismatch**: CI uses `channel: stable` (latest). Local is 3.38.9. If CI's stable channel has advanced, a breaking change in Flutter's test framework could cause failures.
- **Timing-dependent tests**: No `sleep` or `Future.delayed` in tests currently, but if added, CI's slower VMs could cause timeout.
- **Font/asset issues**: Tests using `WidgetTester` call `tester.pumpAndSettle()` which depends on fonts being loaded. CI may behave differently.

### Fix
1. Read the failing test name and assertion from the GitHub Actions log
2. Run the exact failing test locally:
   ```bash
   cd dante_terminal && flutter test test/the_failing_test.dart
   ```
3. If it passes locally, pin the Flutter version in CI to match local:
   ```yaml
   # In .github/workflows/mobile-ci.yml
   - uses: subosito/flutter-action@v2
     with:
       flutter-version: '3.38.9'  # Pin to match local
       channel: stable
   ```
4. Commit the version pin and push

### Quick diagnostic command (run locally)
```bash
cd dante_terminal && flutter test --reporter expanded
```

---

## Failure Mode 3: iOS Build Failure (Code Signing)

### Likelihood: MEDIUM — EXPECTED, DO NOT PANIC

### What you'd see
```
   Build iOS (no codesign)
   ...
   error: No signing certificate "iOS Distribution" found
   ** BUILD FAILED **
```

Or:
```
   error: Signing for "Runner" requires a development team.
```

Or, more likely with `--no-codesign`:
```
   flutter build ipa --no-codesign
   ...
   error: exportArchive: No applicable devices found.
```

### Root cause
The CI workflow (mobile-ci.yml, line 106) runs `flutter build ipa --no-codesign`. This command tries to create an `.ipa` archive, which internally calls `xcodebuild archive` and then `xcodebuild -exportArchive`. The export step can fail even with `--no-codesign` because `flutter build ipa` is designed to produce a distributable `.ipa`, not just compile the code.

Note: The older CI workflow (`dante_terminal/.github/workflows/ci.yml`) uses `flutter build ios --no-codesign` (no `ipa`), which just compiles without archiving — this succeeds reliably.

**This is a known, expected failure.** No signing credentials are configured on CI, and they won't be until the human completes BL-195 task H6 (Apple Developer enrollment).

### Fix (short-term: make CI green)
Change the iOS build command in `.github/workflows/mobile-ci.yml` from:
```yaml
- name: Build iOS (unsigned)
  run: flutter build ipa --no-codesign
```
to:
```yaml
- name: Build iOS (unsigned)
  run: flutter build ios --no-codesign
```

This compiles the iOS app without attempting to create an archive. The build verifies that the code compiles for iOS, which is what CI should validate.

### Fix (long-term: after Apple Developer enrollment)
After the human completes H6 and provides signing credentials:
1. Add Apple signing secrets to GitHub repo (Settings > Secrets):
   - `APPLE_CERTIFICATE_BASE64`
   - `APPLE_CERTIFICATE_PASSWORD`
   - `APPLE_PROVISIONING_PROFILE_BASE64`
   - `APPLE_TEAM_ID`
2. Update CI to decode and install the certificate/profile before building
3. Change command back to `flutter build ipa` (without `--no-codesign`)

### Linked items
- **BL-205**: iOS archive script (`scripts/archive_ios.sh`) and `ExportOptions.plist` — for local archive builds
- **BL-195 H6**: Apple Developer enrollment

---

## Failure Mode 4: Android Build Failure (Keystore / Signing)

### Likelihood: LOW — but possible

### What you'd see
```
   Build Android
   ...
   FAILURE: Build failed with an exception.
   * What went wrong:
   Execution failed for task ':app:validateSigningRelease'.
   > Keystore file '/path/to/keystore.jks' not found
```

### Root cause
The CI workflow runs `flutter build appbundle --release`. The `build.gradle.kts` has been configured (BL-198) to:
1. Check if `key.properties` exists
2. If yes: use the release keystore specified in that file
3. If no: **fall back to debug signing**

Since `key.properties` is gitignored and won't exist on CI, the build should fall back to debug signing and **succeed**. This failure mode should NOT trigger unless:
- The `key.properties` file accidentally gets committed (check `.gitignore`)
- The Gradle fallback logic has a bug (verified working locally — 92.0 MB AAB built)

### Fix (if it does fail)
1. Verify `.gitignore` excludes `key.properties`:
   ```bash
   grep "key.properties" dante_terminal/android/.gitignore
   ```
2. If `key.properties` was committed accidentally:
   ```bash
   git rm --cached dante_terminal/android/key.properties
   git commit -m "BL-215: Remove accidentally committed key.properties"
   git push
   ```
3. If the Gradle fallback fails, simplify `build.gradle.kts` to remove the conditional signing entirely for CI, then re-add after keystore is configured

### Fix (long-term: after keystore generation)
After the human completes H5:
1. Add keystore secrets to GitHub repo (Settings > Secrets):
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `ANDROID_STORE_PASSWORD`
2. Add CI steps to decode keystore and write `key.properties` from secrets
3. The build will then produce a release-signed AAB

### Linked items
- **BL-198**: Keystore generation script (`scripts/generate_keystore.sh`) and `key.properties.template`
- **BL-195 H5**: Android release keystore generation

---

## Failure Mode 5: GitHub Pages Deployment Failure

### Likelihood: LOW-MEDIUM

### What you'd see
In the GitHub Actions tab, the "Deploy to GitHub Pages" workflow either:
- Doesn't trigger at all
- Shows error: `Error: Get Pages site failed` or `HttpError: Not Found`
- Deploys but pages return 404

### Root cause
The `deploy-pages.yml` workflow uses GitHub's official Pages actions (`actions/configure-pages@v5`, `actions/upload-pages-artifact@v3`, `actions/deploy-pages@v4`). It triggers on pushes to `main` that change files under `docs/`. For it to work, GitHub Pages must be **enabled** in the repository settings with the **GitHub Actions** source (not "Deploy from a branch").

The workflow uses the newer Actions-based deployment, NOT the legacy branch-based deployment. This means:
- Repository Settings > Pages > Source must be set to **"GitHub Actions"** (not "Deploy from a branch")
- The workflow requires `pages: write` and `id-token: write` permissions (already configured in the YAML)

The `docs/` directory contains 5 files: `index.html`, `privacy-policy.html`, `terms-of-service.html`, `style.css`, `script.js`.

### Fix
1. Go to https://github.com/bakua/dante → Settings → Pages
2. Under "Build and deployment" > Source, select **"GitHub Actions"**
   - If it shows "Deploy from a branch", change it to "GitHub Actions"
3. If the workflow ran but failed before Pages was enabled:
   - Go to Actions tab
   - Find the failed "Deploy to GitHub Pages" run
   - Click "Re-run all jobs"
4. After deployment, verify:
   ```
   curl -s -o /dev/null -w "%{http_code}" https://bakua.github.io/dante/privacy-policy.html
   curl -s -o /dev/null -w "%{http_code}" https://bakua.github.io/dante/terms-of-service.html
   curl -s -o /dev/null -w "%{http_code}" https://bakua.github.io/dante/
   ```
   All should return `200`.

5. If Pages was previously set to "Deploy from a branch" with `/docs` folder:
   - The BL-195 handoff (H2) instructs `Branch: main, Folder: /docs` which is the legacy mode
   - The `deploy-pages.yml` workflow uses the modern Actions-based mode
   - **Choose one**: Either use the workflow (set source to "GitHub Actions") OR delete the workflow and use branch-based deployment (source: "Deploy from a branch", branch: `main`, folder: `/docs`)
   - Recommendation: Use the workflow (GitHub Actions source) — it's already configured and more reliable

### Linked items
- **BL-195 H2**: Verify GitHub Pages deployment
- **BL-204**: Privacy policy and ToS TODO placeholders (already fixed)

---

## Triage Decision Tree

After `git push origin main`, go to https://github.com/bakua/dante/actions and check each workflow:

```
Mobile CI workflow:
│
├── test job
│   ├── flutter analyze failed? → Failure Mode 1
│   └── flutter test failed?    → Failure Mode 2
│
├── build-android job
│   └── Build failed?           → Failure Mode 4 (unlikely)
│
└── build-ios job
    └── Build failed?           → Failure Mode 3 (EXPECTED)

Deploy to GitHub Pages workflow:
└── Deploy failed?              → Failure Mode 5
```

### Expected CI State After Push

| Job | Expected Result | Action if Different |
|-----|----------------|---------------------|
| test (analyze) | PASS | See FM1 — likely Flutter version mismatch |
| test (tests) | PASS | See FM2 — likely Flutter version mismatch |
| build-android | PASS | See FM4 — check key.properties isn't committed |
| build-ios | **LIKELY FAIL** | See FM3 — **EXPECTED.** Fix: change `ipa` to `ios` in workflow |
| deploy-pages | PASS (if Pages source = "GitHub Actions") | See FM5 — enable Pages in repo settings |

### Quick Fix Script

If iOS build is the only failure (most likely scenario), run this one-liner locally:

```bash
cd /Users/jakubtakac/workspace/dante/goadi
sed -i '' 's/flutter build ipa --no-codesign/flutter build ios --no-codesign/' .github/workflows/mobile-ci.yml
git add .github/workflows/mobile-ci.yml
git commit -m "BL-215: Fix iOS CI build — use flutter build ios instead of ipa (no signing on CI)"
git push origin main
```

---

## After CI is Green

Once all jobs pass (or only the iOS build fails as expected):
1. Check the **Artifacts** tab on the successful Android build — download `android-release-aab` to verify it's a valid AAB
2. Proceed to BL-195 task H3 (device testing) — CI green means the code is safe to run on a device
3. Report results to the AI: "H1 done, CI status: [pass/fail details]"

---

## Note on Duplicate CI Workflows

There are TWO CI workflow files:
1. `.github/workflows/mobile-ci.yml` — the primary workflow (3 jobs: test, build-android, build-ios)
2. `dante_terminal/.github/workflows/ci.yml` — an older workflow inside the Flutter project directory

The second workflow (`ci.yml`) has path filters (`dante_terminal/**`) and uses `dart analyze` instead of `flutter analyze`, and builds a debug APK instead of a release AAB. It may or may not trigger depending on GitHub's workflow discovery (workflows must be in the repo root's `.github/workflows/`). If it's nested inside `dante_terminal/`, GitHub will ignore it. No action needed — just be aware it exists.
