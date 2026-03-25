# Store Compliance Notes — DANTE TERMINAL

> All required metadata fields for Apple App Store and Google Play, pre-filled for submission.
> Created: 2026-03-25 | Backlog Item: BL-150

---

## Table of Contents

1. [Pre-Submission Checklist](#1-pre-submission-checklist)
2. [Apple App Store Connect — All Required Fields](#2-apple-app-store-connect)
3. [Google Play Console — All Required Fields](#3-google-play-console)
4. [Content Rating Questionnaires](#4-content-rating-questionnaires)
5. [Screenshot Dimension Requirements](#5-screenshot-dimension-requirements)

---

## 1. Pre-Submission Checklist

Complete these before touching either store console:

- [ ] Host `privacy-policy.html` at a public URL (GitHub Pages recommended: `https://<username>.github.io/dante-terminal/privacy-policy.html`)
- [ ] Host `terms-of-service.html` at a public URL (same host: `https://<username>.github.io/dante-terminal/terms-of-service.html`)
- [ ] Replace `[Physical address to be provided before store submission]` in both HTML files
- [ ] Replace `[Jurisdiction to be specified before store submission]` in terms-of-service.html
- [ ] Set up email forwarding for `privacy@danteterminal.com` and `legal@danteterminal.com` (or update HTML files with actual contact emails)
- [ ] Verify both URLs load correctly in mobile Safari and mobile Chrome
- [ ] Prepare app signing (Apple: distribution certificate + provisioning profile; Android: upload keystore)
- [ ] Capture screenshots from a real device running the app (see Section 5 for dimensions)

---

## 2. Apple App Store Connect

### 2.1 App Information (General > App Information)

| Field | Value | Notes |
|---|---|---|
| **App Name** | `DANTE TERMINAL: Text Adventure` | 30 chars max |
| **Subtitle** | `Offline AI Game Master` | 30 chars max |
| **Primary Language** | English (U.S.) | |
| **Bundle ID** | `com.danteterminal.app` | Must match Xcode project |
| **SKU** | `DANTE_TERMINAL_001` | Internal reference, not visible to users |
| **Privacy Policy URL** | `https://<host>/privacy-policy.html` | **REQUIRED — submission blocked without this** |
| **License Agreement** | Use default Apple EULA | Custom ToS available if needed |
| **Primary Category** | Role Playing | Games > Role Playing |
| **Secondary Category** | Adventure | Games > Adventure |
| **Content Rights** | "This app does not contain, show, or access third-party content" | AI model is self-contained |

### 2.2 App Privacy (General > App Privacy)

Apple's "Privacy Nutrition Label":

| Question | Answer | Rationale |
|---|---|---|
| **"Do you or your third-party partners collect data from this app?"** | **No** | Zero data collection, zero third-party SDKs |

Result: App Store displays **"Data Not Collected"** label.

Steps:
1. Navigate to: App Store Connect > Your App > General > App Privacy
2. Click "Get Started" or "Edit"
3. Select **"No, we do not collect data from this app"**
4. Save

### 2.3 App Review Information (Version > Review Information)

| Field | Value |
|---|---|
| **Contact First Name** | [Your first name] |
| **Contact Last Name** | [Your last name] |
| **Contact Phone** | [Your phone number] |
| **Contact Email** | [Your email] |
| **Review Notes** | "This app downloads an AI model (~1.5 GB) on first launch over Wi-Fi, then runs entirely offline. All AI text generation occurs on-device with no server communication during gameplay. No account or login required." |
| **Demo Account** | Not required (no login) |
| **Attachment** | None needed |

### 2.4 Pricing and Availability

| Field | Value |
|---|---|
| **Price** | Free |
| **In-App Purchases** | None |
| **Availability** | All territories |
| **Pre-Order** | No |

### 2.5 Version Information

| Field | Value |
|---|---|
| **Version Number** | 1.0.0 |
| **Build** | (uploaded from Xcode/CI) |
| **What's New** | "Initial release. Welcome to The Sunken Archive." |
| **Promotional Text** | "The Sunken Archive awaits. Type anything -- the AI understands. No internet needed, no subscriptions. Classic text adventure meets on-device AI. Free to play, forever." |
| **Description** | (See BL-090 app-store-listing-package.md, Section 2, Apple App Store description) |
| **Keywords** | `text adventure,ai game,offline rpg,interactive fiction,zork,game master,dungeon crawler,retro game,ai dungeon,story game,choose adventure,no wifi game` |
| **Support URL** | `https://<host>/` or GitHub Issues URL |
| **Marketing URL** | `https://<host>/` |

### 2.6 Age Rating Questionnaire (Apple)

See Section 4.1 below.

---

## 3. Google Play Console

### 3.1 Store Listing (Store Presence > Main Store Listing)

| Field | Value | Notes |
|---|---|---|
| **App Name** | `DANTE TERMINAL: Offline AI Text Adventure RPG` | 50 chars max |
| **Short Description** | `Classic text adventure with an AI Game Master. Runs offline. Type anything.` | 80 chars max |
| **Full Description** | (See BL-090 app-store-listing-package.md, Section 2, Google Play description) | 4000 chars max |
| **App Icon** | 512 x 512 PNG, 32-bit, no alpha | Generated by BL-141 |
| **Feature Graphic** | 1024 x 500 PNG or JPEG | Dark bg, green title, amber subtitle |
| **Privacy Policy URL** | `https://<host>/privacy-policy.html` | **REQUIRED — cannot publish without** |
| **App Category** | Game > Role Playing | |
| **Tags** | Text adventure, RPG, Offline, AI | Up to 5 tags |
| **Contact Email** | [Developer email — required] | |
| **Contact Website** | `https://<host>/` | Optional but recommended |

### 3.2 App Content Declarations (Policy and Programs > App Content)

#### Privacy Policy
- Enter the Privacy Policy URL
- Save

#### Data Safety

| Question | Answer | Rationale |
|---|---|---|
| **Does your app collect or share any user data types?** | **No** | Zero data collection |
| **Is all user data encrypted in transit?** | **N/A** | Only network activity is model download over HTTPS |
| **Do you provide a way to request data deletion?** | **N/A** | Nothing to delete |

For each data type category (Location, Personal info, Financial info, Health and fitness, Messages, Photos and videos, Audio files, Files and docs, Calendar, Contacts, App activity, Web browsing, App info and performance, Device or other IDs):
- Select **"No, we do not collect this data type"**

Confirm: "Does your app share any user data with third parties?" — **No**

#### Ads Declaration
- Select: **"No, my app does not contain ads"**

#### Target Audience and Content
- Target age group: **13 and above**
- "Is this app specifically designed for children?": **No**
- Not subject to Google's Families Policy

#### App Access
- Select: **"All functionality is available without special access"**
- Note: Model download requires internet but no login or credentials

#### Government Apps
- Confirm: App is not a government app

#### Financial Features
- Confirm: App does not include financial features

### 3.3 Content Rating (IARC Questionnaire)

See Section 4.2 below.

### 3.4 Pricing

| Field | Value |
|---|---|
| **Price** | Free |
| **In-App Products** | None |
| **Countries** | All available countries |

---

## 4. Content Rating Questionnaires

### 4.1 Apple Age Rating (App Store Connect)

Navigate to: App Store Connect > Your App > General > Age Rating

| Question | Answer | Justification |
|---|---|---|
| Cartoon or Fantasy Violence | **None** | Text-only; no graphic content |
| Realistic Violence | **None** | AI may describe fictional conflict but no visual depiction |
| Sexual Content and Nudity | **None** | Not designed to generate such content |
| Profanity or Crude Humor | **Infrequent** | AI text is unpredictable; conservative answer |
| Alcohol, Tobacco, or Drug Use | **Infrequent** | May appear in fictional narrative context |
| Simulated Gambling | **None** | Not a game mechanic |
| Horror/Fear Themes | **Mild** | Dungeon setting, atmospheric tension |
| Mature/Suggestive Themes | **None** | Not designed for mature themes |
| Medical/Treatment Information | **None** | N/A |
| Unrestricted Web Access | **No** | No browser or external links during gameplay |

**Expected result: 12+ rating** (driven by "Infrequent" profanity and "Mild" horror themes).

### 4.2 Google Play Content Rating (IARC Questionnaire)

Navigate to: Google Play Console > App content > Content rating > Start questionnaire

| Question | Answer | Justification |
|---|---|---|
| **Category** | Game | |
| **Violence** | **Mild** | Text descriptions of fictional dungeon scenarios; no graphic imagery |
| **Violence — Detailed** | "Fictional text-based adventure set in a dungeon. Conflicts are described through text. No graphic depictions, no blood, no weapons targeting real people." | Free-text field |
| **Fear** | **Mild** | Atmospheric tension in underground setting |
| **Sexuality** | **None** | |
| **Language** | **Mild** | AI may generate occasional mild language |
| **Controlled Substances** | **Mild** | May appear in fictional medieval/fantasy context (e.g., tavern scenes) |
| **Discrimination** | **None** | |
| **User Interaction** | **None** | Fully offline single-player |
| **Users can share personal information** | **No** | No input leaves device |
| **Users can purchase digital goods** | **No** | No IAP |
| **Users can share their location** | **No** | No location access |
| **Does the app share user location with other users?** | **No** | |
| **Does the app allow users to interact or exchange info?** | **No** | Single-player offline |
| **Does the app contain user-generated content?** | **Yes — AI-generated content** | On-device AI generates fiction text; flag this if "AI-generated" option is available |
| **Is the app a web browser or search engine?** | **No** | |
| **Is this app primarily news/educational?** | **No** | Entertainment game |

**Expected ESRB rating: Teen (T)**
- ESRB: Teen — Fantasy Violence, Mild Language
- PEGI: 12 — Mild violence, infrequent mild language
- USK: 12
- ClassInd: 12

**Expected IARC descriptor tags:** Fantasy Violence, Mild Language

### 4.3 Rating Comparison Across Regions

| Rating System | Expected Rating | Equivalent |
|---|---|---|
| Apple | 12+ | Ages 12 and up |
| ESRB (North America) | Teen (T) | Ages 13+ |
| PEGI (Europe) | PEGI 12 | Ages 12+ |
| USK (Germany) | USK 12 | Ages 12+ |
| ClassInd (Brazil) | 12 | Ages 12+ |
| ACB (Australia) | PG | Parental guidance |
| GRAC (South Korea) | 12 | Ages 12+ |

---

## 5. Screenshot Dimension Requirements

### 5.1 Apple App Store — Required Screenshot Sizes

App Store Connect requires screenshots for each device class you support. Minimum 1 screenshot per size class; maximum 10.

#### iPhone Screenshots (REQUIRED — at least one size)

| Device Class | Display Size | Screenshot Dimensions (portrait) | Screenshot Dimensions (landscape) | Required? |
|---|---|---|---|---|
| **iPhone 6.7"** (iPhone 15 Pro Max, 15 Plus, 14 Pro Max) | 6.7 inch | **1290 x 2796 px** | 2796 x 1290 px | **Yes — primary** |
| iPhone 6.5" (iPhone 14 Plus, 13 Pro Max, 12 Pro Max, 11 Pro Max, XS Max) | 6.5 inch | **1284 x 2778 px** or **1242 x 2688 px** | 2778 x 1284 px or 2688 x 1242 px | Yes if supporting these devices |
| iPhone 6.1" (iPhone 15, 15 Pro, 14, 14 Pro, 13, 13 Pro, 12, 12 Pro) | 6.1 inch | **1179 x 2556 px** (Pro) or **1170 x 2532 px** | 2556 x 1179 px or 2532 x 1170 px | Optional (can auto-scale from 6.7") |
| iPhone 5.5" (iPhone 8 Plus, 7 Plus, 6s Plus) | 5.5 inch | **1242 x 2208 px** | 2208 x 1242 px | Required if supporting iOS 15 on these devices |

**Recommendation:** Capture at **6.7"** (1290 x 2796) as the primary set. App Store Connect can auto-generate 6.5" from 6.7". Provide 5.5" separately if targeting older phones.

#### iPad Screenshots (REQUIRED if app runs on iPad)

| Device Class | Display Size | Screenshot Dimensions (portrait) | Screenshot Dimensions (landscape) | Required? |
|---|---|---|---|---|
| **iPad Pro 12.9" (6th gen)** | 12.9 inch | **2048 x 2732 px** | **2732 x 2048 px** | **Yes — primary iPad** |
| iPad Pro 12.9" (2nd gen) | 12.9 inch | **2048 x 2732 px** | 2732 x 2048 px | Same dimensions, accepted |
| iPad Pro 11" | 11 inch | **1668 x 2388 px** | 2388 x 1668 px | Optional (auto-scaled from 12.9") |
| iPad 10.5" | 10.5 inch | **1668 x 2224 px** | 2224 x 1668 px | Optional |
| iPad 9.7" | 9.7 inch | **1536 x 2048 px** | 2048 x 1536 px | Optional (for older iPad support) |

**Recommendation:** Capture at **12.9"** (2048 x 2732) as the primary iPad set.

#### File Requirements (Apple)

| Property | Requirement |
|---|---|
| Format | PNG or JPEG |
| Color space | sRGB or Display P3 |
| File size | Max ~10 MB per screenshot |
| Status bar | Include (captures must show real status bar or none) |
| Count | 1-10 per device size, per localization |

### 5.2 Google Play — Required Screenshot Sizes

#### Phone Screenshots (REQUIRED)

| Property | Requirement |
|---|---|
| **Minimum dimensions** | 320 px on shortest side |
| **Maximum dimensions** | 3840 px on longest side |
| **Aspect ratio** | Max 2:1 (or 1:2 for landscape) |
| **Recommended** | **1080 x 1920 px** (portrait, Full HD) or **1440 x 2560 px** (portrait, QHD) |
| **Format** | PNG or JPEG, no alpha channel |
| **Count** | 2-8 screenshots |
| **File size** | Max 8 MB per screenshot |

#### Tablet Screenshots (RECOMMENDED for wider reach)

| Property | Requirement |
|---|---|
| **Recommended 7"** | **1200 x 1920 px** (portrait) or **1920 x 1200 px** (landscape) |
| **Recommended 10"** | **1600 x 2560 px** (portrait) or **2560 x 1600 px** (landscape) |
| **Aspect ratio** | Max 2:1 |
| **Count** | 0-8 screenshots (0 = not tablet-optimized listing) |

#### Feature Graphic (REQUIRED)

| Property | Requirement |
|---|---|
| **Dimensions** | **1024 x 500 px** exactly |
| **Format** | PNG or JPEG, no alpha |
| **Content** | Brand graphic; no device frames; text must be legible at small sizes |

### 5.3 Screenshot Capture Matrix

Minimum set for submission covering all 4 required device classes per the acceptance criteria:

| # | Device Class | Dimensions | Platform | Priority |
|---|---|---|---|---|
| 1 | **iPhone 6.7"** | 1290 x 2796 px | Apple | P0 — required |
| 2 | **iPad 12.9"** | 2048 x 2732 px | Apple | P0 — required if iPad supported |
| 3 | **Android Phone** | 1080 x 1920 px (or 1440 x 2560) | Google Play | P0 — required (min 2 screenshots) |
| 4 | **Android Tablet** | 1600 x 2560 px | Google Play | P1 — recommended |
| 5 | Feature Graphic | 1024 x 500 px | Google Play | P0 — required |

**Content per screenshot:** Use the 6-frame storyboard defined in BL-090 (opening scene, terminal aesthetic, freeform commands, NPC dialogue, puzzle solving, offline/privacy CTA).

### 5.4 Screenshot Production Workflow

1. Build release APK/IPA
2. Install on target device (or closest available)
3. Set up game to reach each storyboard scene
4. Capture via device screenshot (Power + Volume on iOS; Power + Volume Down on Android)
5. Trim/crop to exact required dimensions if needed
6. For iPad: either capture on actual iPad or scale up iPhone capture (but real captures preferred)
7. For Feature Graphic: design in Figma/Canva using the spec from BL-090 Appendix A

---

## 6. Quick Reference — Submission Blockers

Fields that will **prevent submission** if missing:

### Apple App Store — Hard Blockers
| # | Field | Status |
|---|---|---|
| 1 | Privacy Policy URL | Requires hosted HTML file |
| 2 | App Privacy nutrition label completed | Select "No data collected" |
| 3 | Age Rating questionnaire completed | See Section 4.1 |
| 4 | At least 1 screenshot per required device size | See Section 5.1 |
| 5 | App binary uploaded (signed .ipa) | From Xcode/CI |
| 6 | App description | See BL-090 |
| 7 | Support URL | Landing page or email |
| 8 | Contact info for review team | See Section 2.3 |

### Google Play — Hard Blockers
| # | Field | Status |
|---|---|---|
| 1 | Privacy Policy URL | Requires hosted HTML file |
| 2 | Data Safety form completed | See Section 3.2 |
| 3 | Content Rating (IARC) completed | See Section 4.2 |
| 4 | Target Audience declaration | 13+, not for children |
| 5 | Ads declaration | No ads |
| 6 | At least 2 phone screenshots | See Section 5.2 |
| 7 | Feature Graphic (1024x500) | See Section 5.2 |
| 8 | App binary uploaded (signed .aab) | From CI |
| 9 | Short description | See Section 3.1 |
| 10 | Contact email | Developer account email |
