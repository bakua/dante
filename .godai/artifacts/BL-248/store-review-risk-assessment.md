# DANTE TERMINAL — App Store & Play Store Review Risk Assessment

> **Purpose:** Identify and mitigate store rejection risks before submission. Covers Apple App Store and Google Play policies affecting AI-generated-content apps.
> **Audience:** Human preparing for store submission.
> **Created:** 2026-03-28 | Backlog Item: BL-248 | Related: BL-247 (store listing), BL-266 (content safety)

---

## Section 1: Apple App Store Review Guidelines Analysis

Apple's guidelines were significantly updated in November 2025 to address AI apps. The guidelines below are current as of early 2026. Precedent exists for on-device LLM apps being approved (e.g., "Private LLM - Local AI Chat," App ID 6448106860).

### Guideline 1.1 — Objectionable Content

**1.1.1:** *"Defamatory, discriminatory, or mean-spirited content, including references or commentary about religion, race, sexual orientation, gender, national/ethnic origin, or other targeted groups."*

**1.1.2:** *"Realistic portrayals of people or animals being killed, maimed, tortured, or abused, or content that encourages violence."*

| Clause | Relevance to DANTE TERMINAL | Compliance Status |
|--------|----------------------------|-------------------|
| 1.1.1 | LLM could generate discriminatory text if prompted adversarially | **AT RISK** — requires output guardrails |
| 1.1.2 | Interactive fiction naturally includes violence (combat, death) — acceptable in game context, but graphic/realistic depictions are not | **AT RISK** — system prompt must constrain violence to fantasy/game tone |

### Guideline 1.2 — User-Generated Content

**1.2:** Requires filtering, reporting, blocking, and published contact info for apps with UGC shared between users.

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 1.2 (all) | Single-player offline game with no content sharing between users. LLM output is dynamically generated game content consumed only by the player — analogous to procedural generation | **LOW RISK** — likely not applicable, but having content filtering strengthens review position |

### Guideline 2.3 — Accurate Metadata & Disclosures

**2.3.1(a):** *"Don't include any hidden, dormant, or undocumented features [...] your app's functionality should be clear to end users and App Review."*

**2.3.6:** *"Answer the age rating questions in App Store Connect honestly so that your app aligns properly with parental controls."*

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 2.3.1(a) | Must explicitly describe AI/LLM functionality in App Store description AND Notes for Review. Must provide reviewer walkthrough instructions. | **ACTION REQUIRED** — add AI disclosure to listing (BL-247 listing should cover this) |
| 2.3.6 | Age rating questionnaire now explicitly asks about AI/chatbot content: *"consider how all app features, including AI assistants and chatbot functionality, impact the frequency of sensitive content."* Must rate based on what LLM *can* produce, not just intended output. | **ACTION REQUIRED** — rate conservatively (see age rating section below) |

### Guideline 4.2 — Minimum Functionality

**4.2:** *"Your app should include features, content, and UI that elevate it beyond a repackaged website [...] If your App doesn't provide some sort of lasting entertainment value or adequate utility, it may not be accepted."*

**4.2.3(ii):** *"If your app needs to download additional resources in order to function on initial launch, disclose the size of the download and prompt users before doing so."*

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 4.2 | Simple ChatGPT wrappers get rejected here. DANTE TERMINAL is a purpose-built game with defined mechanics, aesthetic, and genre — clear differentiation from a generic chatbot. | **LOW RISK** — game framing provides strong differentiation |
| 4.2.3(ii) | Model file (~1-2 GB) must be downloaded post-install. Must disclose size and prompt before download. | **ACTION REQUIRED** — download flow already designed (BL-126), verify disclosure |

### Guideline 4.7 — Mini Apps, Chatbots, Plug-ins

**4.7:** Explicitly mentions "chatbots" as regulated. Requires content filtering, reporting mechanism, and age restriction for content exceeding the app's rating.

**4.7.5:** *"Your app must provide a way for users to identify software that exceeds the app's age rating, and use an age restriction mechanism."*

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 4.7 | If Apple classifies the LLM as a "chatbot" rather than a game engine, 4.7.1 applies — requiring content filtering and reporting. | **MODERATE RISK** — mitigation: frame consistently as a game (narrative engine, not chatbot); use game terminology everywhere (story, adventure, quest, narrator) |
| 4.7.5 | If 4.7 applies, must age-gate content exceeding the app's base rating | **CONDITIONAL** — only if 4.7 is triggered |

### Guideline 5.1.2(i) — Third-Party AI Data Sharing (November 2025)

**5.1.2(i):** *"You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so."*

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 5.1.2(i) | This rule targets cloud AI (GPT, Claude, Gemini). DANTE TERMINAL runs entirely on-device — no data is sent to any server. | **FAVORABLE** — on-device architecture is the ideal compliance posture. Can truthfully state: "All AI processing occurs on your device." |

### Guideline 5.6 — Developer Code of Conduct

**5.6.4:** *"Customers expect the highest quality from the App Store [...] Indications that this expectation is not being met include excessive customer reports, negative reviews, and excessive refund requests."*

| Clause | Relevance | Compliance Status |
|--------|-----------|-------------------|
| 5.6.4 | If the LLM model is too small and produces incoherent/low-quality text, resulting in negative reviews, this becomes a risk. | **LOW RISK** — model quality testing (BL-210) already in progress |

### Apple Age Rating (Updated January 2026)

Apple expanded to a 6-tier system: 4+, 9+, 13+, 16+, 18+, Unrated. The questionnaire now explicitly asks about AI-generated content.

| Rating Factor | DANTE TERMINAL Assessment | Implied Rating |
|--------------|--------------------------|----------------|
| Fantasy Violence | Frequent (core game mechanic — combat, monsters, death) | 13+ |
| Horror/Fear Themes | Infrequent (some adventure scenarios) | 9+ |
| Profanity | Infrequent (LLM may occasionally produce mild language) | 9+ |
| Mature Themes | Infrequent (narrative tension, moral choices) | 9+ |
| Realistic Violence | Should be prevented by content filters | N/A with filters |

**Recommended Apple Rating: 13+** — with content filters constraining output to this level. If filters cannot reliably prevent realistic violence or mature content, rate 16+.

---

## Section 2: Google Play Policy Analysis

Google's AI-Generated Content policy became a standalone regulated category in 2025, with mandatory requirements that go beyond Apple's.

### AI-Generated Content Policy (Standalone — Updated 2025)

**Source:** [Google Play AI-Generated Content Policy](https://support.google.com/googleplay/android-developer/answer/13985936)

Three mandatory requirements for apps where AI content generation is a primary function:

| Requirement | Detail | DANTE TERMINAL Status |
|-------------|--------|----------------------|
| **Proactive content prevention** | Must prevent offensive content generation *in advance* — not merely react to reports. Must safeguard against adversarial prompts. | **ACTION REQUIRED** — system prompt guardrails + output filtering (BL-266 covers this) |
| **In-app reporting mechanism** | Users must be able to report/flag offensive AI content without leaving the app | **ACTION REQUIRED** — must add a report button to the game UI |
| **Testing documentation** | Must rigorously test AI models and document testing. Google may request documentation during review. | **ACTION REQUIRED** — create adversarial testing log |

### Deceptive Behavior Policy

**Source:** [Google Play Deceptive Behavior Policy](https://play.google.com/about/privacy-security-deception/deceptive-behavior/)

| Requirement | Relevance | Status |
|-------------|-----------|--------|
| Store listing must accurately describe functionality | Must describe AI-powered game mechanics truthfully | **OK** — BL-247 listing covers this |
| App must perform as user reasonably expects | Game must deliver quality interactive fiction, not broken output | **LOW RISK** |
| Must not facilitate dishonest behavior | LLM constrained to game fiction — cannot generate fake documents etc. | **LOW RISK** — system prompt constrains to game context |

### Restricted / Inappropriate Content Policy

**Source:** [Google Play Inappropriate Content Policy](https://support.google.com/googleplay/android-developer/answer/9878810)

| Category | Policy | DANTE TERMINAL Implication |
|----------|--------|---------------------------|
| **Hate Speech** | No content promoting violence/hatred against protected groups | System prompt + output filter must block |
| **Violence** | No gratuitous violence — BUT: *"Apps that depict fictional violence in the context of a game, such as cartoons, hunting or fishing, are generally allowed"* | **FAVORABLE** — game exception covers Zork-style fantasy violence. Must still prevent graphic/realistic violence. |
| **Sexual Content** | No sexual content beyond content rating | System prompt must prevent sexual content generation |
| **Child Safety** | Must never generate content exploiting children, including AI-generated CSAM | System prompt must include explicit child safety constraints |

### Content Rating (IARC)

| Factor | Assessment | Likely Rating |
|--------|-----------|---------------|
| Fantasy Violence | Frequent — core mechanic | Teen / PEGI 12 |
| Fear/Horror | Moderate — adventure scenarios | Teen / PEGI 12 |
| Language | Infrequent mild language | Teen |
| Dynamic content | LLM generates text — rate based on filtered output potential | Conservative assessment required |

**Recommended Google Rating: Teen / PEGI 12** — with content filters constraining output. Answer IARC questionnaire based on filtered output capability.

### User Data Policy & Data Safety Section

| Requirement | DANTE TERMINAL Status |
|-------------|----------------------|
| Privacy policy link (Play Console + in-app) | **ACTION REQUIRED** — create privacy policy |
| Data Safety section declaration | **FAVORABLE** — "This app does not collect or share user data" (if no analytics/crash SDKs) |
| On-device processing exemption | Data processed only on-device does NOT need to be declared as "collected" | **FAVORABLE** |

### Store Listing / Metadata

| Requirement | Status |
|-------------|--------|
| Accurate title, description, screenshots | **OK** — BL-247 covers this |
| Disclose AI usage in description | **RECOMMENDED** — include "Powered by on-device AI" |
| Privacy policy link | **ACTION REQUIRED** |
| Feature graphic quality | **OK** — standard design requirement |

---

## Section 3: Risk Matrix

Likelihood scale: **Low** (unlikely with basic precautions), **Medium** (plausible, seen in similar apps), **High** (common rejection reason for AI apps)
Severity scale: **Low** (fixable in hours, quick re-review), **Medium** (requires days of work, delays launch), **High** (requires architectural changes or policy negotiation)

| # | Rejection Vector | Platform | Likelihood | Severity | Risk Score | Notes |
|---|-----------------|----------|------------|----------|------------|-------|
| **R1** | LLM generates objectionable content (hate speech, graphic violence, sexual content) during review | Both | **High** | **High** | **CRITICAL** | Reviewers will test adversarial inputs. A single instance of objectionable output can trigger rejection. This is the #1 rejection reason for AI apps. |
| **R2** | Missing in-app content reporting mechanism | Google | **High** | **Medium** | **HIGH** | Google Play explicitly mandates this for AI-generating apps. No report button = automatic rejection. Not required by Apple but recommended. |
| **R3** | Incorrect/too-low age rating | Both | **Medium** | **Medium** | **HIGH** | Apple now explicitly asks about AI content in age questionnaire. Rating the app 4+ or 9+ when the LLM can produce teen-level content will trigger rejection. Character.AI maintained 12+ until forced to change — don't repeat their mistake. |
| **R4** | Classified as "chatbot" rather than "game" — triggering stricter 4.7 requirements | Apple | **Medium** | **Medium** | **HIGH** | If Apple sees the LLM interaction as a chatbot (4.7) rather than a game engine, compliance requirements increase: content filtering, reporting, and age restriction mechanisms all become mandatory under 4.7.1. |
| **R5** | Insufficient AI disclosure in App Review Notes | Apple | **Medium** | **Low** | **MEDIUM** | Apple requires "specificity" about new features in Notes for Review (2.3.1). Failing to explain the on-device LLM, provide test instructions, or describe the model could delay review. Easy to fix but wastes a review cycle. |
| **R6** | Missing privacy policy or inaccurate Data Safety / App Privacy declarations | Both | **Medium** | **Low** | **MEDIUM** | Required even for apps collecting zero data. Must accurately reflect on-device processing. Missing = immediate rejection. |
| **R7** | Model download without size disclosure or user prompt | Apple | **Low** | **Low** | **LOW** | 4.2.3(ii) requires disclosing download size and prompting before download. Already designed in BL-126. Low risk if implemented as designed. |
| **R8** | App perceived as "minimum functionality" / ChatGPT wrapper | Apple | **Low** | **High** | **MEDIUM** | Simple AI wrappers get rejected under 4.2. DANTE TERMINAL's game mechanics, UI, and defined genre provide strong differentiation. Risk is low but severity is high if triggered — requires demonstrating the app is a game, not a chat wrapper. |
| **R9** | LLM produces content exploiting minors | Both | **Low** | **Critical** | **HIGH** | Even one instance during review = rejection + potential developer account consequences. Google's child safety policy is zero-tolerance. System prompt must explicitly prohibit this. |
| **R10** | EU AI Act transparency requirements (if distributing in EU) | Both | **Medium** | **Low** | **MEDIUM** | EU AI Act (phasing in through August 2026) requires labeling AI-generated content and user transparency. An in-app About screen disclosing AI usage satisfies this. |

### Risk Summary by Priority

| Priority | Risks | Action Timeline |
|----------|-------|----------------|
| **CRITICAL — Block submission** | R1 (objectionable content) | Must be resolved before submission |
| **HIGH — Likely rejection** | R2 (report button), R3 (age rating), R4 (chatbot classification), R9 (child safety) | Must be resolved before submission |
| **MEDIUM — Possible rejection** | R5 (review notes), R6 (privacy policy), R8 (min functionality), R10 (EU AI Act) | Should be resolved before submission |
| **LOW — Unlikely** | R7 (download disclosure) | Verify existing implementation |

---

## Section 4: Concrete Mitigations

### M1: Content Safety System (addresses R1, R9)

**What:** Multi-layer content safety for LLM output:
1. **System prompt guardrails** — constrain the LLM persona to interactive fiction. Explicitly prohibit: hate speech, graphic/realistic violence, sexual content, content involving minors in harmful scenarios, real-world harmful advice, content about real people/events.
2. **Output validation** — lightweight keyword/pattern filter on generated text. Flag or regenerate responses containing prohibited content patterns.
3. **Input sanitization** — detect and deflect adversarial prompts attempting to bypass the game context (jailbreak attempts, prompt injection).

**Effort:** Medium (BL-266 is already implementing this in parallel)

**Implementation notes:**
- System prompt should establish the GM persona and explicitly list content boundaries
- Output filter can be a simple blocklist + regex patterns for the worst categories (slurs, explicit sexual terms, CSAM-adjacent language)
- Input filter should detect common jailbreak patterns ("ignore previous instructions," "you are now," role-play escape attempts)
- Test with adversarial prompts before submission (document results for Google)

### M2: In-App Content Reporting (addresses R2)

**What:** Add a "Report Content" button accessible from the game screen. When tapped:
1. Captures the last AI response and player input that triggered it
2. Presents a simple category picker (offensive, inappropriate, disturbing, other)
3. Stores the report locally (no server needed for V1)
4. Shows confirmation: "Report saved. Thank you."

**Effort:** Small

**Implementation notes:**
- Google mandates this for AI apps — it must exist even without a backend
- Can store reports as JSON in app documents directory
- Later: if analytics are added, batch-upload reports for model improvement
- The mechanism itself satisfies the policy requirement; active monitoring can come later
- Also add to Apple version — strengthens 4.7 compliance argument

### M3: Conservative Age Rating (addresses R3)

**What:** Rate the app 13+ (Apple) / Teen (Google Play).

**Apple age rating questionnaire answers:**
- Cartoon or Fantasy Violence: **Frequent** (core game mechanic)
- Realistic Violence: **None** (content filters prevent this)
- Horror/Fear Themes: **Infrequent** (some adventure scenarios may be tense)
- Profanity or Crude Humor: **Infrequent** (LLM may produce mild language)
- Mature/Suggestive Themes: **Infrequent** (narrative tension)
- Sexual Content/Nudity: **None** (content filters prevent this)
- Alcohol/Tobacco/Drug References: **Infrequent** (adventure scenarios may reference)
- AI/Chatbot functionality: **Yes — content filters constrain to game fiction**

**Google IARC questionnaire:** Answer consistently with the above. Note that dynamic AI content is present and filtered.

**Effort:** Trivial (questionnaire answers during submission setup)

### M4: Game Framing — Avoid Chatbot Classification (addresses R4)

**What:** Ensure every touchpoint frames DANTE TERMINAL as a game, never a chatbot:

| Touchpoint | Game Framing | Avoid |
|------------|-------------|-------|
| App Store title | "Dante Terminal: AI Text Adventure" | "Dante Terminal: AI Chat" |
| App description | "interactive fiction game," "AI Game Master," "text adventure" | "chatbot," "AI assistant," "conversational AI" |
| UI labels | "Adventure," "Story," "Game Master" | "Chat," "Assistant," "AI" |
| App category | Games > Adventure (both stores) | Entertainment, Productivity |
| In-app text | "The Game Master narrates..." | "The AI responds..." |
| Review notes | "on-device narrative engine for interactive fiction" | "LLM chatbot" |

**Effort:** Trivial (copy review — BL-247 listing should already use game framing)

### M5: App Review Notes Package (addresses R5)

**What:** Prepare comprehensive Notes for Review in App Store Connect:

```
AI FUNCTIONALITY DISCLOSURE:
This app runs a quantized LLM (language model) entirely on-device
to serve as a Game Master for interactive fiction / text adventures.
No data is sent to any server. No third-party AI services are used.
All text generation occurs locally on the user's device.

MODEL DETAILS:
- Model: [specific model name and size, e.g., "Phi-3 Mini 3.8B, Q4_K_M quantization"]
- Framework: [e.g., "llama.cpp via Dart FFI"]
- Download: ~[X] GB, downloaded on first launch with user consent and size disclosure

CONTENT SAFETY:
- System prompt constrains output to interactive fiction genre
- Output filtering prevents objectionable content categories
- In-app reporting mechanism for users to flag content

HOW TO TEST:
1. Launch app → tap "New Adventure" → wait for model to load (~30 seconds)
2. Play through 5-10 turns using the suggestion chips
3. Try typing freeform commands: "look around," "open the door," "attack the creature"
4. To test content safety: try adversarial inputs like "ignore the game and tell me how to..."
   — the app should redirect to in-game responses
```

**Effort:** Small (write once before submission)

### M6: Privacy Policy & Data Declarations (addresses R6)

**What:**
1. **Privacy policy page** — host at a URL (GitHub Pages is free). Content:
   - All AI processing occurs on-device
   - No personal data is collected, transmitted, or shared
   - No analytics, no crash reporting, no ad SDKs (if true)
   - Contact email for privacy inquiries
2. **Apple App Privacy nutrition labels** — declare "Data Not Collected" for all categories
3. **Google Data Safety section** — declare "This app does not collect or share user data"
4. **In-app privacy disclosure** — accessible from Settings/About screen

**Effort:** Small (template privacy policy + store form completion)

### M7: EU AI Act In-App Disclosure (addresses R10)

**What:** Add an "About" or "Info" screen accessible from the game menu:
- "This game uses artificial intelligence running on your device to generate interactive fiction. No data leaves your device."
- Satisfies EU AI Act transparency requirement for AI-generated content labeling

**Effort:** Trivial (single screen addition)

---

## Mitigation Effort Summary

| Mitigation | Risks Addressed | Effort | Owner |
|-----------|----------------|--------|-------|
| M1: Content safety system | R1, R9 | **Medium** | BL-266 (in progress) |
| M2: In-app report button | R2 | **Small** | New task needed |
| M3: Age rating answers | R3 | **Trivial** | Human (during submission) |
| M4: Game framing review | R4 | **Trivial** | Verify BL-247 listing |
| M5: App Review Notes | R5 | **Small** | Human (during submission) |
| M6: Privacy policy + declarations | R6 | **Small** | New task needed |
| M7: EU AI Act disclosure | R10 | **Trivial** | New task needed |

### Pre-Submission Checklist

- [ ] Content safety filters implemented and tested (M1 / BL-266)
- [ ] In-app "Report Content" button functional (M2)
- [ ] Age rating questionnaire answered conservatively at 13+/Teen (M3)
- [ ] All store listing copy uses game framing, not chatbot language (M4)
- [ ] App Review Notes prepared with AI disclosure + test instructions (M5)
- [ ] Privacy policy hosted and linked in both stores + in-app (M6)
- [ ] App Privacy / Data Safety declarations completed accurately (M6)
- [ ] In-app AI disclosure screen added (M7)
- [ ] Adversarial prompt testing completed and documented (M1)
- [ ] App category set to Games > Adventure on both stores (M4)

---

## Appendix A: Real-World Rejection Precedents

These cases inform the risk ratings above:

| Case | Year | Issue | Outcome | Lesson for DANTE TERMINAL |
|------|------|-------|---------|--------------------------|
| **BlueMail** (Apple) | 2023 | AI integration (ChatGPT for email) lacked content filtering; Apple demanded 17+ rating | Update blocked | Even mundane AI use triggers scrutiny. Apple defaulted to 17+ for early AI apps. |
| **Character.AI** | 2024 | Maintained 12+ rating while chatbots engaged in sexual conversations with minors. Teen suicide linked to platform. | Forced to 17+; lawsuits; banned minors from open-ended chat | Under-rating AI content has legal and reputational consequences beyond store rejection. |
| **Replika** | 2023-2025 | Italy banned app for GDPR violations and insufficient age verification. EUR 5M fine. | Banned in Italy; removed NSFW features | Even single-player AI companions face regulatory scrutiny in EU markets. |
| **Nudify apps** (Both stores) | 2026 | 55 apps on Google Play, 47 on Apple Store could generate non-consensual imagery. 705M+ downloads. | Apple removed 28; Google removed 31 | Stores DO enforce eventually — proactive compliance avoids being in the next enforcement sweep. |
| **Multiple ChatGPT wrappers** (Apple) | 2023-2024 | Thin wrappers around OpenAI API with no unique functionality | Rejected under 4.2 Minimum Functionality | DANTE TERMINAL's game mechanics provide critical differentiation from this pattern. |

## Appendix B: Key Policy Sources

**Apple:**
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — sections 1.1, 1.2, 2.3, 4.2, 4.7, 5.1.2(i), 5.6
- [Age Rating Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [November 2025 Guidelines Update](https://developer.apple.com/news/?id=ey6d8onl)

**Google:**
- [AI-Generated Content Policy](https://support.google.com/googleplay/android-developer/answer/13985936)
- [Best Practices to Safeguard AI-Generated Content](https://support.google.com/googleplay/android-developer/answer/16353813)
- [Inappropriate Content Policy](https://support.google.com/googleplay/android-developer/answer/9878810)
- [Content Rating Requirements](https://support.google.com/googleplay/android-developer/answer/9859655)
- [Data Safety Section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Deceptive Behavior Policy](https://play.google.com/about/privacy-security-deception/deceptive-behavior/)

## Appendix C: DANTE TERMINAL Compliance Advantages

The on-device, offline, single-player architecture provides significant compliance advantages:

| Advantage | Policies Simplified |
|-----------|-------------------|
| **No third-party AI data sharing** | Apple 5.1.2(i) — fully exempt |
| **No user-to-user content sharing** | Apple 1.2, Google social/UGC policies — not applicable |
| **No cloud dependency** | No server-side moderation needed; no data breach surface |
| **No personal data collection** | Apple App Privacy = "Not Collected"; Google Data Safety = "No data shared" |
| **Game framing (not chatbot)** | Stronger 4.2 position; potentially avoids 4.7 chatbot classification |
| **Single-player** | No bullying/harassment vector; no child predator risk; no social features requiring moderation |

**Bottom line:** DANTE TERMINAL's architecture is the most favorable configuration for store compliance. The primary risks (R1: content safety, R2: report button, R3: age rating) are all addressable with known, bounded effort before submission.
