# DANTE TERMINAL is code-complete. 5 actions only you can do before it ships.

**Total time: ~2 hrs | Total cost: $124 | Full details: `.godai/artifacts/BL-195/human-handoff-checklist.md`**

| # | Action | Time | Cost | What to do |
|---|--------|------|------|------------|
| 1 | **Push code** | 2 min | $0 | Run `git push origin main` (33+ commits pending). Unblocks CI + GitHub Pages. |
| 2 | **Test on phone** | 30 min | $0 | `cd dante_terminal && flutter run --release` on Android or iOS. Note: downloads ~1GB model on first launch. Record response time, crashes, quality. |
| 3 | **Create developer accounts** | 30 min | $124 | Apple Developer ($99/yr): developer.apple.com/programs/enroll. Google Play ($25): play.google.com/console/signup. Start Apple early — approval takes up to 48 hrs. |
| 4 | **Generate Android keystore** | 10 min | $0 | Run `keytool -genkey -v -keystore ~/dante-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dante-release`. Back up the file + password — losing it = can never update on Play Store. |
| 5 | **Score AI quality** | 60 min | $0 | Play 10 test scenarios (listed in `.godai/artifacts/BL-171/research.md`) and score each on 6 dimensions (1-5). Report scores; the AI decides SHIP or NO-SHIP. |

**Pre-built artifacts ready for you:**
- Store listing copy (title, description, keywords): `.godai/artifacts/BL-156/app-store-listing-package.md`
- Privacy policy + ToS (live after step 1): `docs/privacy-policy.html`, `docs/terms-of-service.html`
- Quality rubric with 10 test prompts + scoring sheet: `.godai/artifacts/BL-171/research.md`

**After each step, just tell me what happened** (e.g., "step 1 done, CI running" or "step 2: app crashes after model download"). I'll handle everything else — CI triage, signing config, store submission packages, quality analysis.
