# Store Submission Legal Compliance Checklist

**DANTE TERMINAL**
**Created: March 25, 2026**

This checklist maps each legal document to the specific fields in App Store Connect and Google Play Console where URLs or content must be entered before submission.

---

## Pre-Submission Requirements

Before filling in store fields, complete these hosting steps:

- [ ] **Host Privacy Policy** at a publicly accessible URL (e.g., `https://danteterminal.com/privacy` or GitHub Pages at `https://[username].github.io/dante-terminal/privacy`)
- [ ] **Host Terms of Service** at a publicly accessible URL (e.g., `https://danteterminal.com/terms` or GitHub Pages at `https://[username].github.io/dante-terminal/terms`)
- [ ] **Replace placeholder values** in both documents:
  - `[Physical address to be provided before store submission]` — add a valid mailing address
  - `[Jurisdiction to be specified before store submission]` — specify governing law jurisdiction
  - `[Arbitration body to be specified]` — specify arbitration provider or remove arbitration clause
- [ ] **Set up email forwarding** for `privacy@danteterminal.com` and `legal@danteterminal.com` (or update documents with actual contact emails)
- [ ] **Verify URLs are accessible** from a mobile browser before entering them in store consoles

---

## Apple App Store Connect

### App Information (App Store Connect > General > App Information)

| Field | Value | Document |
|---|---|---|
| **Privacy Policy URL** | `https://danteterminal.com/privacy` | Privacy Policy |
| **License Agreement** | Use default Apple EULA *or* paste custom ToS | Terms of Service |

> **Location:** App Store Connect > Your App > General > App Information > scroll to "Privacy Policy URL"

### App Privacy (App Store Connect > General > App Privacy)

Apple requires a Privacy Nutrition Label. Based on DANTE TERMINAL's privacy posture:

| App Privacy Question | Answer | Rationale |
|---|---|---|
| **"Do you or your third-party partners collect data from this app?"** | **No** | App collects zero user data; no analytics, no tracking, no third-party SDKs |

- [ ] Navigate to: App Store Connect > Your App > General > App Privacy
- [ ] Click "Get Started" or "Edit" on the privacy details
- [ ] Select **"No, we do not collect data from this app"**
- [ ] Save

> This will display the "Data Not Collected" privacy label on the App Store listing.

### Age Rating (App Store Connect > General > App Information > Age Rating)

| Question | Answer | Notes |
|---|---|---|
| Cartoon or Fantasy Violence | None | Text-only adventure; no graphic content |
| Realistic Violence | None | AI may describe fictional conflict |
| Sexual Content and Nudity | None | Not designed to generate such content |
| Profanity or Crude Humor | Infrequent | AI text is unpredictable; conservative answer |
| Alcohol, Tobacco, or Drug Use | Infrequent | May appear in fictional narrative |
| Simulated Gambling | None | Not a game mechanic |
| Horror/Fear Themes | Mild | Dungeon setting, atmospheric tension |
| Mature/Suggestive Themes | None | Not designed for mature themes |
| Medical/Treatment Information | None | Not applicable |
| Unrestricted Web Access | No | No web browser or external links during gameplay |

- [ ] Navigate to: App Store Connect > Your App > General > Age Rating
- [ ] Fill in questionnaire per table above
- [ ] Expected result: **12+** rating (due to "Infrequent" profanity and mild horror)

### Review Notes (App Store Connect > Version > Review Information)

- [ ] Add a **review note** explaining: "This app downloads an AI model (~1.5 GB) on first launch, then runs entirely offline. All AI text generation occurs on-device with no server communication during gameplay."
- [ ] Provide **contact information** for the review team in the Review Information section

---

## Google Play Console

### Store Listing (Google Play Console > Store presence > Main store listing)

| Field | Value | Document |
|---|---|---|
| **Privacy policy URL** | `https://danteterminal.com/privacy` | Privacy Policy |

> **Location:** Google Play Console > Your App > Store presence > Main store listing > scroll to "Privacy policy"
> This is a **required field** — the listing cannot be published without it.

### App Content (Google Play Console > Policy and programs > App content)

This section contains multiple required declarations. Complete each:

#### Privacy Policy

- [ ] Navigate to: App content > Privacy policy
- [ ] Enter the Privacy Policy URL
- [ ] Save

#### Data Safety

Google requires a Data Safety section. Based on DANTE TERMINAL's privacy posture:

| Data Safety Question | Answer | Rationale |
|---|---|---|
| **Does your app collect or share any of the required user data types?** | **No** | No data collection of any type |
| **Is all of the user data collected by your app encrypted in transit?** | **N/A** (no data collected) | Only network activity is model download over HTTPS |
| **Do you provide a way for users to request that their data is deleted?** | **N/A** (no data collected) | Nothing to delete |

- [ ] Navigate to: App content > Data safety
- [ ] Start the Data safety form
- [ ] For each data type category (Location, Personal info, Financial info, Health and fitness, Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts, App activity, Web browsing, App info and performance, Device or other IDs): select **"No, we do not collect this data type"**
- [ ] Confirm: "Does your app share any user data with third parties?" — **No**
- [ ] Save and submit

#### Ads Declaration

- [ ] Navigate to: App content > Ads
- [ ] Select: **"No, my app does not contain ads"**
- [ ] Save

#### Target Audience and Content

- [ ] Navigate to: App content > Target audience and content
- [ ] Target age group: **13 and above** (not designed for children under 13)
- [ ] "Is this app specifically designed for children?": **No**
- [ ] Save

> Setting target audience to 13+ means the app is NOT subject to Google's Families Policy, which would impose additional requirements. This is appropriate because the AI-generated content cannot be guaranteed child-safe.

#### Content Rating (IARC Questionnaire)

- [ ] Navigate to: App content > Content rating
- [ ] Start the IARC questionnaire
- [ ] Key answers:
  - Violence: **Mild** (text descriptions of fictional dungeon scenarios)
  - Sexuality: **None**
  - Language: **Mild** (AI may generate occasional mild language)
  - Controlled substances: **Mild** (may appear in fictional context)
  - User interaction: **None** (fully offline single-player)
  - Users can share personal information: **No**
  - Users can purchase digital goods: **No**
  - "Does the app contain user-generated content?": **Yes — AI-generated** (select this if available; otherwise answer contextually about AI content)
- [ ] Expected rating: **Teen (T)** or equivalent PEGI 12

#### Government Apps and Financial Features

- [ ] Navigate to: App content > Financial features (if shown)
- [ ] Confirm: App does not include financial features
- [ ] Navigate to: App content > Government apps (if shown)
- [ ] Confirm: App is not a government app

### App Access (Google Play Console > Policy and programs > App content > App access)

- [ ] Select: **"All functionality is available without special access"**
- [ ] Note: The model download requires internet, but no login, account, or special credentials are needed

---

## Post-Submission Monitoring

After both store listings are submitted:

- [ ] Verify Privacy Policy URL loads correctly on mobile Safari (Apple review team's browser)
- [ ] Verify Privacy Policy URL loads correctly on mobile Chrome (Google review team's browser)
- [ ] Verify Terms of Service URL loads correctly on both browsers
- [ ] Monitor for review rejection feedback related to legal compliance
- [ ] If either store requests changes, update both documents simultaneously to maintain consistency

---

## Document Hosting Options

| Option | Pros | Cons | Recommended |
|---|---|---|---|
| **GitHub Pages** (existing docs/ directory) | Free, already set up per BL-066, version-controlled | Tied to GitHub repo visibility | Yes — for launch |
| **Custom domain** (danteterminal.com) | Professional, portable | Requires domain purchase ($12/yr) and DNS setup | Yes — post-launch |
| **Notion/Google Docs** | Quick to set up, easy to edit | Unprofessional appearance, less control | No |

**Recommended approach:** Add privacy.html and terms.html to the existing `docs/` directory (created by BL-066) and serve via GitHub Pages. Update to a custom domain post-launch if desired.

---

## Quick Reference: Minimum Fields Required for Store Submission

### Apple App Store — Minimum Legal Requirements
1. Privacy Policy URL in App Information (**BLOCKING — cannot submit without**)
2. App Privacy nutrition label completed (**BLOCKING — cannot submit without**)
3. Age Rating questionnaire completed (**BLOCKING — cannot submit without**)

### Google Play — Minimum Legal Requirements
1. Privacy Policy URL in Main store listing (**BLOCKING — cannot publish without**)
2. Data Safety form completed (**BLOCKING — cannot publish without**)
3. Content Rating (IARC) questionnaire completed (**BLOCKING — cannot publish without**)
4. Target Audience declaration completed (**BLOCKING — cannot publish without**)
5. Ads declaration completed (**BLOCKING — cannot publish without**)
