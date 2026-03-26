# DANTE TERMINAL: Human Handoff Checklist

> **BL-195** | Created: 2026-03-26 | Status: **ACTIVE**
>
> Everything below **requires your hands** — credentials, physical devices, or payment the AI cannot provide. Each task lists exactly what to do, what the AI already prepared, and what the AI will do once you're done.

---

## Quick Reference

| # | Task | Time | Cost | Depends On |
|---|------|------|------|------------|
| H1 | Push 29 commits to origin | 2 min | $0 | Nothing |
| H2 | Verify GitHub Pages deployment | 5 min | $0 | H1 |
| H3 | Run app on physical Android device | 30 min | $0 | H1 |
| H4 | Run app on physical iOS device | 30 min | $0 | H1 |
| H5 | Generate Android release keystore | 10 min | $0 | Nothing |
| H6 | Enroll in Apple Developer Program | 15 min | $99/year | Nothing |
| H7 | Create Google Play Developer account | 15 min | $25 one-time | Nothing |
| H8 | Run quality gate evaluation on device | 90 min | $0 | H3 or H4 |
| **Total** | | **~3.5 hrs** | **$124** | |

---

## Dependency Graph

```
           H1 (git push)
          / |         \
         /  |          \
       H2   H3         H4
       |   (Android)   (iOS)
       |     \         /
       |      \       /
       |       H8 (quality gate)
       |       |
       v       v
  [AI resumes: CI triage, store builds, quality analysis]

  H5, H6, H7 are independent — do them in any order, anytime.
  All must be done before store submission.

  H5 (keystore) ──┐
  H6 (Apple Dev) ──┼──> Store Submission (AI-driven after all complete)
  H7 (Google Dev) ─┘
```

---

## H1: Push 26 Commits to Origin

**Why:** 29 commits (BL-069 through BL-217) are sitting on local `main` but have never been pushed. CI hasn't run on them, GitHub Pages hasn't deployed, and the remote repo is 2+ weeks stale. Nothing the AI builds is "real" until this happens.

**AI already prepared:** All 29 commits are clean, tests pass locally (196 tests), `flutter analyze` is clean. See **[Build Baseline Report](./../BL-216/build-baseline-report.md)** for full verification output (analysis, tests, Android .aab, iOS .app builds all passing).

**Steps:**
1. Open terminal in project root (`/Users/jakubtakac/workspace/dante/goadi`)
2. Verify what's pending:
   ```bash
   git log --oneline origin/main..HEAD
   ```
   You should see 29 commits from `808abd0` (BL-069) to the latest HEAD.
3. Push:
   ```bash
   git push origin main
   ```
4. Go to https://github.com/bakua/dante/actions and confirm the CI workflow triggers.

**Estimated time:** 2 minutes

**After you're done, the AI will:**
- Triage CI results (BL-215 playbook exists)
- If CI fails: diagnose and fix, then ask you to push again
- If CI passes: green-light store submission pipeline

---

## H2: Verify GitHub Pages Deployment

**Why:** The privacy policy and terms of service must be live at public URLs before Apple/Google will accept the app submission. The AI placed the HTML files in `docs/` and configured the URLs in the app code, but can't trigger the deployment.

**AI already prepared:**
- `docs/privacy-policy.html` — complete, all TODOs resolved (BL-204)
- `docs/terms-of-service.html` — complete, jurisdiction set to Slovak Republic (BL-204)
- `docs/index.html` — landing page with PRIVACY and TERMS footer links
- `dante_terminal/lib/config/legal_urls.dart` — URL constants pointing to GitHub Pages
- `.github/workflows/deploy-pages.yml` — auto-deployment workflow

**Steps:**
1. After H1 (push), go to https://github.com/bakua/dante → Settings → Pages
2. Ensure Source is set to: **Deploy from a branch**, Branch: `main`, Folder: `/docs`
   - If Pages isn't enabled yet, enable it with these settings
3. Wait 1-2 minutes for deployment
4. Verify these URLs return HTTP 200 (not 404):
   - https://bakua.github.io/dante/privacy-policy.html
   - https://bakua.github.io/dante/terms-of-service.html
   - https://bakua.github.io/dante/ (landing page)
5. Spot-check: each page should have the "Quick Summary" table at the bottom and "Contact" section with the GitHub Issues link

**Estimated time:** 5 minutes

**After you're done, the AI will:**
- Mark legal hosting requirement as MET in the MVP checklist (BL-144 criteria SS-07, SS-08, CL-04)
- No further AI work needed on legal docs

---

## H3: Run App on Physical Android Device

**Why:** The entire app — 16 source files, 196 tests, full install-download-play pipeline — has NEVER been run on a physical device. Every test uses mocks or desktop simulators. This is the single highest-risk item: the app may crash on model load, hit memory limits, produce gibberish, or drain battery. We cannot submit to stores without knowing.

**AI already prepared:**
- Full app with mock backend for desktop/CI and real inference path for mobile
- `dante_terminal/lib/main.dart` — auto-routes: desktop uses mock, mobile uses real inference
- Model download screen with progress, resume, and SHA-256 integrity verification
- Qwen2-1.5B-Instruct Q4_K_M configured as default model (986 MB download)

**Steps:**
1. Connect Android device via USB (enable Developer Options + USB Debugging)
   - Target: Android 10+ with 4+ GB RAM (mid-range is fine)
2. Navigate to the Flutter project:
   ```bash
   cd /Users/jakubtakac/workspace/dante/goadi/dante_terminal
   ```
3. Run the app:
   ```bash
   flutter run --release
   ```
   (Use `--release` to test real performance, not debug overhead)
4. **First launch flow:** The app should show a model download screen. It will download ~986 MB of model data. Wait for it to complete.
   - If download fails: check internet connection, try again (resume is supported)
   - Note the download speed and any errors
5. **After download:** The app should transition to the terminal game screen with green-on-black retro UI
6. **Test the game loop:**
   - You should see an opening narrative about The Sunken Archive
   - Type a command (e.g., "look around") and press send
   - Observe: Does the AI respond? How long does it take? Is the response coherent?
   - Try 3-4 more commands (e.g., "examine the desk", "go north", "pick up the key")
   - Check: Do suggestion chips appear below each response?
7. **Record these metrics:**
   - Cold start time (app launch to first screen): ___ seconds
   - Model load time (after download, first inference): ___ seconds
   - Response generation time (per command): ___ seconds
   - Response quality (coherent/gibberish/crashes): ___
   - Memory usage (check Android Studio profiler if available): ___ MB
   - Any crashes, errors, or visual glitches: ___
   - Battery drain during 10 min play session: ___%

**Estimated time:** 30 minutes (including download time)

**After you report results, the AI will:**
- If it works: proceed to store submission prep
- If it crashes on model load: investigate memory limits, possibly switch to smaller quantization
- If responses are gibberish: tune system prompt, adjust temperature/sampling params
- If it's too slow: reduce context window, try Q3_K_S quantization
- Generate new backlog items from whatever breaks

---

## H4: Run App on Physical iOS Device

**Why:** Same as H3 but for iOS. iOS has stricter memory limits (jetsam kills apps using >1.4 GB), different file system behavior, and different Metal vs Vulkan GPU paths. An app that works on Android may still fail on iOS.

**AI already prepared:** Same as H3, plus iOS-specific build configuration in `ios/` directory.

**Steps:**
1. Connect iOS device via USB (iPhone 11 or newer recommended, iOS 16+)
2. Open Xcode, ensure your Apple ID is added (Xcode > Settings > Accounts)
   - For development testing, a free Apple ID works (no $99 enrollment needed yet)
3. Navigate to Flutter project:
   ```bash
   cd /Users/jakubtakac/workspace/dante/goadi/dante_terminal
   ```
4. Run:
   ```bash
   flutter run --release
   ```
   - Xcode may prompt you to trust the developer certificate on the device
   - Go to: Settings > General > VPN & Device Management > trust the certificate
5. Follow the same test flow as H3 (steps 4-7)
6. **iOS-specific things to watch for:**
   - Does the app get killed by jetsam (sudden termination with no crash log)? This means memory is too high.
   - Does the keyboard properly push the input field up?
   - Does the CRT shader effect render correctly?
   - Check Settings > Battery to see energy impact

**Estimated time:** 30 minutes (including download and Xcode signing)

**After you report results, the AI will:**
- Same as H3, plus:
- If jetsam kills the app: reduce context window to 1K tokens, evaluate Q3_K_S quantization
- If Xcode signing fails: provide specific signing config instructions

---

## H5: Generate Android Release Keystore

**Why:** Google Play requires all APKs/AABs to be signed with a release keystore. The current build falls back to debug signing when no release keystore is configured. Without a release keystore, the build produces a debug-signed AAB that Google Play will reject.

**AI already prepared (BL-198):**
- `scripts/generate_keystore.sh` — wraps keytool with configurable alias/output/validity, validates inputs, prints next-step instructions
- `android/key.properties.template` — template with placeholder values, copy and fill in
- `android/app/build.gradle.kts` — reads `key.properties` at build time; uses release signing config when present, falls back to debug when absent
- `.gitignore` — already configured to exclude `key.properties`, `*.keystore`, and `*.jks` files
- Application ID: `com.danteterminal.dante_terminal`

**Steps:**
1. Run the keystore generator script:
   ```bash
   cd /Users/jakubtakac/workspace/dante/goadi
   ./scripts/generate_keystore.sh
   ```
   (Or customize: `./scripts/generate_keystore.sh --output ~/my-keystore.jks --alias my-alias`)
2. When prompted, enter:
   - **Keystore password:** (choose a strong password, write it down securely)
   - **Key password:** (can be same as keystore password)
   - **First and last name:** Your name
   - **Organization:** DANTE TERMINAL
   - **City/State/Country:** Your location / SK
3. Store the keystore file securely (NOT in the repo — it's gitignored)
4. Create key.properties from the template:
   ```bash
   cp dante_terminal/android/key.properties.template dante_terminal/android/key.properties
   ```
5. Edit `dante_terminal/android/key.properties` with your real values:
   ```properties
   storePassword=YOUR_KEYSTORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=dante-release
   storeFile=/Users/YOUR_USERNAME/dante-release-key.jks
   ```
6. Verify the signed build works:
   ```bash
   cd dante_terminal && flutter build appbundle --release
   ```
7. **IMPORTANT:** Back up `dante-release-key.jks` and passwords somewhere safe. If you lose the keystore, you can NEVER update the app on Google Play.

**Estimated time:** 10 minutes

**After you're done, the AI will:**
- `build.gradle.kts` already reads `key.properties` — no further AI changes needed (BL-198 completed this)
- Update CI workflow to support release signing (via GitHub Secrets)
- Build a signed AAB for Play Store upload

---

## H6: Enroll in Apple Developer Program

**Why:** To submit to the App Store, you need an Apple Developer Program membership ($99/year). Free Apple IDs can only sideload to personal devices — they cannot publish to the store.

**AI already prepared:**
- Bundle ID: `com.danteterminal.danteTerminal`
- App Store listing copy (BL-156): title, subtitle, description, keywords — all ready to paste
- Privacy policy URL: `https://bakua.github.io/dante/privacy-policy.html` (live after H2)
- Store compliance notes (BL-150): pre-filled content rating answers, screenshot specs

**Steps:**
1. Go to https://developer.apple.com/programs/enroll/
2. Sign in with your Apple ID (or create one)
3. Follow enrollment steps — you'll need:
   - Apple ID with two-factor authentication enabled
   - Payment method for $99/year
   - Legal name and address
4. Enrollment may take up to 48 hours for Apple to process
5. Once approved, go to App Store Connect (https://appstoreconnect.apple.com)
6. Register the bundle ID:
   - Go to Certificates, Identifiers & Profiles > Identifiers
   - Click "+" > App IDs > App
   - Bundle ID: `com.danteterminal.danteTerminal`
   - Description: "DANTE TERMINAL"
   - Enable capabilities: (none required beyond default)
7. Create the app record:
   - Go to My Apps > "+" > New App
   - Platform: iOS
   - Name: "DANTE TERMINAL: Text Adventure"
   - Bundle ID: select the one you just registered
   - SKU: `dante-terminal-001`
   - Primary language: English (U.S.)

**Estimated time:** 15 minutes (+ up to 48 hours for Apple approval)

**Cost:** $99/year

**After you're done, the AI will:**
- Generate iOS distribution certificate and provisioning profile instructions
- Configure Xcode signing in the Flutter project
- Build a signed IPA using `scripts/archive_ios.sh` (BL-205) — run it with your Team ID and provisioning profile:
  ```bash
  ./scripts/archive_ios.sh --team-id YOUR_TEAM_ID --profile "Your Distribution Profile"
  ```
  The script wraps `flutter build ios`, `xcodebuild archive`, and `xcodebuild -exportArchive` with full error handling. It reads from `ios/ExportOptions.plist` (already configured with bundle ID `com.danteterminal.danteTerminal`).
- Upload the resulting `.ipa` to TestFlight via `xcrun altool --upload-app` or Xcode Organizer
- Fill in App Store Connect metadata using BL-156 listing copy

---

## H7: Create Google Play Developer Account

**Why:** To submit to Google Play, you need a Google Play Developer account ($25 one-time fee).

**AI already prepared:**
- Application ID: `com.danteterminal.dante_terminal`
- Google Play listing copy (BL-156): title, short description, full description — all ready to paste
- Privacy policy URL: `https://bakua.github.io/dante/privacy-policy.html` (live after H2)
- Content rating answers (BL-150): pre-filled for IARC questionnaire
- Data Safety form answers (BL-150): "No data collected" — simplest possible form

**Steps:**
1. Go to https://play.google.com/console/signup
2. Sign in with your Google account
3. Pay the $25 one-time registration fee
4. Complete developer profile:
   - Developer name: "DANTE TERMINAL" (or your name/company)
   - Contact email: (your email)
   - Website: `https://bakua.github.io/dante/`
   - Phone number: (required by Google)
5. Create a new app:
   - App name: "DANTE TERMINAL: Offline AI Text Adventure RPG"
   - Default language: English (United States)
   - App or game: Game
   - Free or paid: Free
6. In the app dashboard, go to Store presence > Main store listing:
   - Paste the short description and full description from BL-156
   - You'll need screenshots later (AI will generate specs after H3/H4)

**Estimated time:** 15 minutes

**Cost:** $25 one-time

**After you're done, the AI will:**
- Prepare the Data Safety form answers (copy-paste ready)
- Prepare the content rating questionnaire answers (copy-paste ready)
- Build a signed AAB (after H5) and provide upload instructions
- Fill in remaining store listing fields

---

## H8: Run Quality Gate Evaluation on Device

**Why:** The AI built a 6-dimension scoring rubric (BL-171) and demonstrated it works on mock responses (BL-210, composite: 3.40). But mock responses are NOT real Qwen2-1.5B output. We need to know if the actual on-device model produces fiction good enough to ship. This is a SHIP/NO-SHIP decision gate.

**AI already prepared:**
- Full rubric with anchored 1-5 scales: `.godai/artifacts/BL-171/research.md`
- 10 test scenarios with exact prompts to type
- Pass/fail thresholds:
  - >= 3.5 composite: **SHIP**
  - 3.0-3.49: **SHIP WITH CAVEATS** (AI will add guardrails)
  - 2.5-2.99: **CONDITIONAL NO-SHIP** (AI will re-tune prompts, re-test)
  - < 2.5: **NO-SHIP** (AI will evaluate fallback model Gemma 2 2B)
- Score sheet template below

**Steps:**
1. With the app running on a physical device (after H3 or H4), play through these 10 scenarios from BL-171:

| # | Scenario | What to type |
|---|----------|-------------|
| 1 | Opening scene | (Just observe the opening narrative — no input needed) |
| 2 | Basic exploration | `look around` |
| 3 | Object interaction | `examine the desk` or `pick up the brass key` |
| 4 | NPC conversation | `talk to Maren` |
| 5 | Combat/danger | `attack the warden` or `fight` |
| 6 | Inventory check | `check inventory` or `what am I carrying` |
| 7 | Nonsensical input | `asdfghjkl` or `fly to the moon` |
| 8 | Ambiguous command | `use it` or `go there` |
| 9 | Multi-step puzzle | `turn the cipher wheel to match the constellation` |
| 10 | Atmosphere request | `listen carefully` or `what do I hear` |

2. For each response, score these 6 dimensions (1-5 scale, use the anchors in BL-171):

| Dimension | What you're rating |
|-----------|-------------------|
| D1: Narrative Coherence | Does it make sense? Is it internally consistent? |
| D2: Command Parsing | Did it understand what you typed? |
| D3: Suggestion Relevance | Are the 3 suggestion chips sensible next actions? |
| D4: Tone Consistency | Does it sound like a text adventure, not a chatbot? |
| D5: World State Tracking | Does it remember what happened earlier? |
| D6: Response Length | Not too short (< 20 words) or too long (> 150 words)? |

3. Record scores in this format (copy-paste into a text file or message):

```
Scenario 1: D1=_ D2=_ D3=_ D4=_ D5=_ D6=_
Scenario 2: D1=_ D2=_ D3=_ D4=_ D5=_ D6=_
... (all 10)
```

4. Also note:
   - Any response that breaks the fourth wall (mentions being an AI, asks "how can I help you")
   - Any response that loops/repeats itself
   - Any empty or malformed response
   - Any response that takes > 30 seconds

**Estimated time:** 60-90 minutes

**After you report scores, the AI will:**
- Compute composite scores and compare against thresholds
- If SHIP: proceed directly to store submission
- If SHIP WITH CAVEATS: add response-length guardrails, suggestion-quality filters
- If NO-SHIP: re-tune system prompt, adjust sampling parameters, re-test; if still failing, evaluate Gemma 2 2B fallback model
- Document results in quality gate artifact for App Store review defense

---

## After All Human Tasks: What Happens Next

Once you complete these tasks, the AI pipeline resumes automatically:

```
H1 done → AI triages CI (BL-215)
H2 done → AI marks legal hosting MET
H3/H4 done → AI triages device results, generates fix backlog
H5 done → AI configures release signing in build.gradle.kts
H6 done → AI prepares App Store Connect submission package
H7 done → AI prepares Google Play Console submission package
H8 done → AI makes SHIP/NO-SHIP decision, adjusts if needed

All done → AI builds signed release artifacts
         → AI prepares store metadata (screenshots, descriptions)
         → AI submits to stores OR hands back final upload step
```

---

## Priority Order (Recommended)

**Do these FIRST (unblock everything else):**
1. **H1** — Push commits (2 min). Everything depends on this.
2. **H2** — Check GitHub Pages (5 min). Closes legal blocker.
3. **H3** — Android device test (30 min). The make-or-break moment.

**Do these WHEN CONVENIENT (parallel with above):**
4. **H6** — Apple Developer enrollment (15 min + 48hr wait). Start early because of Apple's review delay.
5. **H7** — Google Play account (15 min). Quick, do it while waiting.
6. **H5** — Android keystore (10 min). Needed before Play Store upload.

**Do this LAST (needs working app):**
7. **H8** — Quality gate (90 min). Needs H3 or H4 completed first.

---

## How to Report Results

After each task, just tell the AI what happened. Examples:
- "H1 done, push succeeded, CI is running"
- "H3 done, app launches, model downloads, but inference is slow (~45 seconds per response)"
- "H4 failed, app crashes after model download with memory error"
- "H8 scores: Scenario 1: D1=4 D2=3 D3=4 D4=4 D5=3 D6=4 ..."

The AI will take it from there.
