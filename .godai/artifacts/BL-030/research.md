# BL-030: Apple & Google App Store Policies for AI-Generated Content in Games

**Research Date:** 2026-03-25
**Audience:** Founding team (architecture & submission planning)
**Status:** Complete

---

## Summary

DANTE TERMINAL's core mechanic (on-device LLM generating all game content) is **shippable on both app stores**, but requires specific compliance measures built in from day one. Both Apple and Google have explicit policies governing AI-generated content in apps, with Apple being more prescriptive (at least 5 directly relevant guideline sections) and Google relying on broader "Inappropriate Content" policies cross-applied to AI apps. The critical finding is that **on-device inference is a major compliance advantage** — it eliminates the most onerous Apple requirement (Guideline 5.1.2(i) third-party AI data sharing disclosure) entirely. However, both platforms require content filtering/safety mechanisms for AI output, an in-app reporting mechanism, and honest age rating that accounts for worst-case AI outputs. Without content filtering, Apple will force a 17+/18+ age rating (BlueMail precedent, 2023), which severely limits the addressable audience. A content safety system with at least "Safe" and "Mature" tiers, combined with an output classifier, is the minimum viable compliance approach.

---

## 1. Apple App Store Review Guidelines

### 1.1 Directly Relevant Guidelines (with section numbers)

#### Guideline 1.1 — Objectionable Content
The umbrella prohibition on offensive content. Sub-sections define specific categories that an unconstrained LLM could violate:

| Sub-section | Prohibition | DANTE TERMINAL Risk |
|---|---|---|
| **1.1.1** | Discriminatory or defamatory content targeting race, religion, gender, sexual orientation | **Medium** — LLM could generate discriminatory NPC dialogue or descriptions if prompted adversarially |
| **1.1.2** | Realistic portrayals of violence — killing, maiming, torturing people/animals | **High** — text adventure combat scenarios could produce graphic violence descriptions |
| **1.1.4** | Overtly sexual or pornographic material | **Medium** — player could steer LLM toward sexual content via freeform text input |
| **1.1.6** | False information and trick features | **Low** — game fiction context mitigates, but "for entertainment purposes" disclaimer is explicitly stated to NOT override this |
| **1.1.7** | Content capitalizing on violent conflicts, terrorist attacks, epidemics | **Low** — unlikely in fantasy adventure context but possible if player forces contemporary themes |

**Compliance requirement:** Content filtering MUST prevent the LLM from generating content violating 1.1.1 through 1.1.7. System prompt constraints alone are insufficient — Apple reviews actual app behavior.

#### Guideline 1.2 — User-Generated Content
Apple treats AI-generated content in interactive apps as functionally equivalent to UGC. Apps must include:

1. **Method for filtering objectionable material** from being posted/generated
2. **Mechanism to report offensive content** and timely responses to concerns
3. **Ability to block abusive users** from the service (less relevant for single-player, but see below)
4. **Published contact information** for user support

**Key insight:** Even though DANTE TERMINAL is single-player with no sharing, Apple applies 1.2 to any app where content is generated dynamically and not pre-reviewed. The AI game master output IS the "user-generated content" from Apple's perspective, because it's not curated by the developer pre-submission. The "report" mechanism can be simplified to a "flag this response" button that logs the problematic output for developer review.

#### Guideline 4.7 — Mini Apps, Mini Games, Streaming Games, Chatbots, Plug-ins, and Game Emulators
This is the **most directly applicable** guideline. Section 4.7 was updated in 2024-2025 to explicitly include chatbots. DANTE TERMINAL's AI game master is functionally a chatbot within a game shell.

**4.7.1 — Software Requirements:**
- Must follow all privacy guidelines (5.1)
- **Must include filtering method for objectionable material**
- **Must include mechanism to report content** with timely responses
- **Must include ability to block abusive users**
- Must follow Guideline 3.1 for digital goods/services

**4.7.5 — Age Restriction:**
- Must provide a way for users to identify content exceeding the app's age rating
- **Must use age restriction mechanism based on verified or declared age** to limit underage access to content exceeding the rating

**Compliance requirement:** Implement content filtering, a report mechanism, and an age-gating flow. The age gate is mandatory under 4.7.5 — this means DANTE TERMINAL needs at minimum a declared-age check at first launch.

#### Guideline 2.3.6 — Age Rating Honesty
Developers must answer the age rating questionnaire honestly. Mis-rating can trigger government inquiries. For DANTE TERMINAL:

- **Violence:** The LLM will generate combat descriptions. Even with filtering, "infrequent mild realistic violence" is likely → minimum 13+ rating
- **Profanity:** Even filtered, occasional mild language is probable → pushes toward 9+ minimum
- **Horror/Fear:** Dungeon/adventure themes inherently involve horror elements → 9+ minimum
- **Sexual Content:** With robust filtering set to "none," can claim "none" → no rating impact
- **Unrestricted Web Access:** NOT applicable (offline app) → no rating impact

**Realistic minimum rating: 13+** (with content filtering active). Without filtering: **18+** (per BlueMail precedent and Apple's stated approach to unfiltered AI apps).

#### Guideline 5.1.2(i) — Data Sharing with Third-Party AI
> "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so."

**This is DANTE TERMINAL's biggest compliance advantage.** Because all inference runs on-device via llama.cpp/llamadart with NO cloud API calls:
- No personal data is shared with any third party
- No AI service provider receives user prompts
- Guideline 5.1.2(i) is satisfied by default — but should be explicitly stated in the privacy policy as a positive differentiator

### 1.2 Precedent Decisions on AI Apps

| App | Year | Decision | Relevance |
|---|---|---|---|
| **BlueMail** (ChatGPT integration) | 2023 | Apple required 17+ rating OR content filtering implementation | Established precedent: unfiltered AI text generation = automatic 17+ |
| **Bing Chat** | 2023 | Listed at 17+ on App Store (no such restriction on Google Play) | Shows Apple is more restrictive than Google for AI chat |
| **AI Dungeon** | 2021-present | Approved with content safety tiers (Safe/Moderate/Mature) + HiveAI filtering | **Closest precedent to DANTE TERMINAL** — AI text adventure approved with tiered safety system |
| **Character.AI** | 2023-present | Approved with content filtering, age verification, safety settings | Shows AI chat apps can ship with robust safety layer |

### 1.3 Required Disclosures (Apple)

1. **Privacy Policy:** Must explicitly state that all AI processing occurs on-device, no data leaves the device, no third-party AI services are used
2. **App Store Connect Privacy Nutrition Labels:** Must accurately declare data collection (likely "Data Not Collected" for DANTE TERMINAL — strong marketing advantage)
3. **Age Rating Questionnaire:** Must answer honestly accounting for worst-case filtered AI output (not just intended output)
4. **App Description:** Should clearly state the app uses on-device AI and does not require internet

---

## 2. Google Play Developer Policies

### 2.1 AI-Generated Content Policy
Google's dedicated AI-Generated Content policy (effective January 31, 2024) explicitly covers "text-to-text AI chatbot apps, in which the AI generated chatbot interaction is a central feature of the app." DANTE TERMINAL falls squarely within scope.

**Developer responsibilities:**
1. Ensure AI does not generate content prohibited under Google Play's Inappropriate Content policies
2. Prevent content that may exploit or abuse children
3. Prevent content that can deceive users or enable dishonest behaviors
4. **Implement in-app user reporting or flagging features** allowing users to report offensive content directly without leaving the app
5. Adopt content safeguards aligned with industry standards
6. **Rigorously test AI tools and models** to ensure user safety and privacy

**Key reference:** Google explicitly points developers to its [Secure AI Framework (SAIF)](https://safety.google/cybersecurity-advancements/saif/) and the OWASP Top 10 for LLM Applications as testing guidance.

### 2.2 Inappropriate Content Policy
The cross-referenced policy prohibits apps from generating:

| Category | Prohibition | DANTE TERMINAL Impact |
|---|---|---|
| **Sexual content** | No pornography, content meant for sexual gratification, solicitation | Must filter sexual content from LLM output |
| **Violence** | No content encouraging harmful behavior, self-harm, dangerous activities | Combat descriptions must stay within game-appropriate bounds |
| **Bullying/Harassment** | No content facilitating bullying | Low risk in single-player context |
| **Hate speech** | No content promoting hatred against protected groups | Must filter discriminatory output |
| **Child safety** | No content exploiting or endangering children | Mandatory — zero tolerance |
| **Deceptive content** | No AI-generated deepfakes, non-consensual recordings, election misinformation | Low risk for text adventure, but system prompt should prevent impersonation of real people |

### 2.3 IARC Age Rating (Google Play)
Google uses the International Age Rating Coalition (IARC) questionnaire. For DANTE TERMINAL with content filtering:

- **ESRB (North America):** Teen (T) — fantasy violence, mild language
- **PEGI (Europe):** PEGI 12 — non-realistic violence in a fantasy setting
- **USK (Germany):** 12 — fantasy violence
- **GRAC (South Korea):** 12+ — fantasy violence

Without content filtering, ratings would escalate to Mature 17+ (ESRB) / PEGI 16-18 across regions.

### 2.4 Google Play vs. Apple — Key Differences

| Dimension | Apple | Google Play |
|---|---|---|
| **AI-specific guideline** | Implicit via 4.7 (chatbots) + 1.2 (UGC) | Explicit AI-Generated Content policy |
| **Content filtering** | Required (BlueMail precedent: 17+ without it) | Required ("content safeguards" + testing) |
| **User reporting** | Required under 1.2 and 4.7 | **Explicitly required** (in-app flagging) |
| **Age gating** | Required under 4.7.5 (verified/declared age) | Via IARC questionnaire; no explicit age gate mandate |
| **Third-party AI disclosure** | 5.1.2(i) — explicit consent required | Covered by general privacy policy requirements |
| **On-device advantage** | Major — bypasses 5.1.2(i) entirely | Moderate — simplifies privacy but filtering still required |
| **Strictness** | More restrictive (higher age ratings for AI apps) | Somewhat more lenient |

---

## 3. Content Safety Requirements

### 3.1 Is Output Filtering Mandatory?

**Yes, on both platforms.**

- **Apple:** Guideline 1.2 requires "method for filtering objectionable material." Guideline 4.7.1 reiterates this for chatbots. The BlueMail precedent (2023) established that unfiltered AI text generation results in mandatory 17+ age rating. Without filtering, DANTE TERMINAL would be rated 18+ under the new system (2025+), excluding it from the vast majority of the gaming audience.

- **Google Play:** AI-Generated Content policy requires "content safeguards" and prohibits generation of "offensive content" per Inappropriate Content policies. The explicit requirement for "in-app user reporting" implies an expectation that some content will slip through automated filters and needs human-in-the-loop correction.

**Bottom line:** Content filtering is not optional. The question is minimum viable implementation complexity.

### 3.2 Implementation Approaches

#### Approach A: System Prompt Constraints + Keyword Blocklist (Low effort)
**Effort estimate:** 2-3 days
**Description:** Embed strict behavioral constraints in the system prompt instructing the LLM to never generate sexual, extremely violent, discriminatory, or otherwise prohibited content. Supplement with a post-generation keyword/phrase blocklist that catches the most egregious outputs.

**Implementation:**
1. System prompt with explicit content boundaries ("You are a game master for a fantasy text adventure rated Teen. Never generate sexual content, graphic gore, hate speech, real-world violence, or content involving harm to children.")
2. Static blocklist of ~500-1000 prohibited words/phrases checked against each LLM response
3. If blocklist triggers, regenerate response (up to 3 attempts) or return a generic safe fallback

**Pros:**
- Minimal latency overhead (~1ms for blocklist check)
- No additional model or API dependency
- Works fully offline
- Easy to maintain and extend

**Cons:**
- Keyword blocklists have high false-positive rates (e.g., blocking "kill" in a combat game)
- System prompt constraints can be bypassed via prompt injection ("ignore previous instructions")
- No semantic understanding — misses euphemisms, subtle inappropriate content
- May not satisfy Apple's review if reviewer can bypass with creative prompts

**App store compliance confidence:** 60% — sufficient for initial submission but may fail during review if Apple tests adversarial prompts.

#### Approach B: On-Device Output Classifier + Safety Tiers (Medium effort)
**Effort estimate:** 1-2 weeks
**Description:** Run a lightweight text classifier model alongside the main LLM to score each generated response for safety before displaying it. Implement configurable safety tiers (Safe/Moderate/Mature) similar to AI Dungeon's approach.

**Implementation:**
1. All of Approach A (system prompt + blocklist as first layer)
2. Lightweight on-device classifier (~50-100MB quantized model, e.g., distilled BERT or TinyBERT fine-tuned for content safety classification)
3. Classify each LLM response across categories: violence_level, sexual_content, hate_speech, self_harm, child_safety
4. Compare scores against current safety tier threshold
5. If score exceeds threshold: regenerate response (primary) or display content warning (fallback)
6. Safety tier selector in settings: "Adventure" (PG, default), "Gritty" (PG-13), "Uncensored" (18+, age-gated)
7. Age declaration at first launch gates access to tier selection

**Pros:**
- Semantic understanding catches content that keyword blocklists miss
- Configurable tiers satisfy both Apple's age-gating requirement (4.7.5) and Google's content safeguards
- Matches proven AI Dungeon approach (approved on both stores)
- Classifier runs locally — no privacy implications
- Enables honest age rating questionnaire answers (can rate for "Adventure" tier default)

**Cons:**
- Additional ~50-100MB model increases app download size
- Additional inference latency (~50-200ms per classification on mid-range device)
- Requires training/fine-tuning a classifier (or using an existing one like Meta's Llama Guard)
- More complex implementation and testing

**App store compliance confidence:** 90% — closely mirrors approved AI Dungeon / Character.AI approaches.

#### Approach C: Llama Guard / Safety Model Integration (Medium-high effort)
**Effort estimate:** 2-3 weeks
**Description:** Use Meta's Llama Guard (or similar purpose-built safety model) as an on-device content moderator. Llama Guard is specifically designed to classify LLM inputs AND outputs against configurable safety taxonomies.

**Implementation:**
1. All of Approach A
2. Llama Guard 3 1B (quantized to Q4: ~600MB) running as a second model via llama.cpp
3. Classify both player input (to detect prompt injection / adversarial steering) AND LLM output
4. 14-category safety taxonomy including violence, sexual content, hate speech, child safety, self-harm
5. Input classification enables proactive blocking — before the main LLM even generates a response

**Pros:**
- Most comprehensive safety coverage
- Catches prompt injection attacks (input classification)
- Purpose-built for LLM safety — better accuracy than general classifiers
- Configurable taxonomy per app store requirements

**Cons:**
- ~600MB additional model weight — may exceed mobile memory budget (see BL-014: 1,500MB iOS budget, main model already ~2GB)
- Significant additional inference time (dual-model pipeline)
- May be infeasible on 4GB iOS devices without aggressive optimization
- Overkill for a single-player text adventure

**App store compliance confidence:** 95% — gold standard, but may be impractical given mobile resource constraints.

### 3.3 Recommended Approach

**Start with Approach A for initial submission, build toward Approach B for v1.1.**

Rationale:
- Approach A is sufficient to demonstrate good-faith content safety to app reviewers and achieve a 13+ rating
- The system prompt + blocklist combination handles 80%+ of problematic outputs in a single-player text adventure context (no adversarial multi-user pressure)
- Approach B should be built before scaling to a larger audience, as it provides the configurable safety tiers that both platforms encourage
- Approach C is unnecessarily resource-intensive given the iOS memory constraints documented in BL-014

### 3.4 AI Dungeon Precedent (Key Reference)

AI Dungeon — the closest comparable product — has been approved on both stores with this approach:
- **3 safety tiers:** Safe (PG), Moderate (PG-13), Mature (R/18+)
- **External classifier:** HiveAI for content scoring (DANTE TERMINAL would need on-device equivalent)
- **Multi-response generation:** Generates multiple responses; if one fails the filter, serves another
- **Automatic rating of published content:** Everyone / Teen / Mature / Unrated
- Age-gated access to Mature tier

---

## 4. Action Items (Pre-Submission Requirements)

Ordered by implementation effort (lowest first):

### 4.1 Privacy Policy & Data Declarations (Effort: 1-2 hours)
**Priority: P0 — blocks submission**

Write a privacy policy that explicitly states:
- All AI processing occurs entirely on-device
- No user data, prompts, or game content is transmitted to any server or third party
- No third-party AI services are used (satisfies Apple 5.1.2(i) by elimination)
- No personal data is collected (enables Apple's "Data Not Collected" privacy label)
- Contact information for support (required by Apple 1.2)

Host at a public URL (e.g., GitHub Pages) and link from both App Store Connect and Google Play Console.

### 4.2 Content Report / Flag Mechanism (Effort: 2-4 hours)
**Priority: P0 — required by both platforms**

Add a "Flag this response" button/gesture on each AI-generated message in the game UI. On tap:
- Log the flagged message, preceding context (last 3 turns), timestamp, and device info to local storage
- Show user confirmation ("Thanks for the report — we'll review this to improve the game")
- Optionally prompt: "What was wrong?" with options: Offensive, Violent, Sexual, Other

This satisfies:
- Apple Guideline 1.2 ("mechanism to report offensive content")
- Apple Guideline 4.7.1 (same requirement for chatbots)
- Google Play AI-Generated Content policy ("in-app user reporting or flagging features")

Flagged content logs can be batch-uploaded (with user consent) to improve the system prompt and blocklist in future updates.

### 4.3 System Prompt Safety Constraints (Effort: 1-2 days)
**Priority: P0 — core content safety layer**

Design the game master system prompt to include explicit content boundaries:
- Prohibited categories: sexual content, graphic gore/torture, hate speech/slurs, real-world violence, child endangerment, self-harm/suicide, impersonation of real people
- Permitted violence: fantasy combat appropriate for Teen/13+ audience (swords, magic, monsters — no realistic firearms, no torture, no graphic injury descriptions)
- Behavioral constraint: "If the player attempts to steer the adventure toward prohibited content, redirect the narrative firmly but naturally"
- Include few-shot examples of appropriate boundary enforcement

### 4.4 Keyword/Phrase Blocklist (Effort: 1-2 days)
**Priority: P1 — supplements system prompt**

Implement a post-generation output check:
- Curate a blocklist of ~500-1000 terms/phrases across prohibited categories
- Context-aware exceptions (e.g., "kill" is allowed in combat context like "kill the dragon" but not "kill yourself")
- On match: regenerate response (up to 3 attempts), then fall back to generic safe response
- Log blocked outputs locally for blocklist refinement

### 4.5 Age Rating Questionnaire Preparation (Effort: 2-3 hours)
**Priority: P0 — blocks submission**

Pre-fill the Apple App Store Connect and IARC questionnaires based on expected filtered content:

**Apple (targeting 13+):**
- Violence: Infrequent/Mild Realistic Violence (fantasy combat) → 13+
- Profanity: Infrequent/Mild → 9+
- Horror/Fear: Frequent/Intense (dungeon themes) → 13+
- Sexual Content: None (filtered) → no impact
- Unrestricted Web Access: No → no impact
- User-Generated Content: Yes (AI-generated) → triggers 1.2 requirements

**Google Play IARC (targeting Teen/PEGI 12):**
- Violence: Fantasy/cartoon violence
- Language: Mild
- Sexual content: None
- User interaction: No (single-player, offline)

### 4.6 Age Declaration Gate (Effort: 3-5 days)
**Priority: P1 — required by Apple 4.7.5**

Implement a first-launch age declaration flow:
- Screen: "Please confirm your age" with date picker or age bracket selector
- Under 13: Lock to "Safe" content tier only (if tiers implemented), or display standard experience
- 13-17: Standard "Adventure" tier (default)
- 18+: Optionally unlock "Mature" tier (if implemented in v1.1+)
- Store declared age locally (not transmitted anywhere)
- Satisfies Apple Guideline 4.7.5: "age restriction mechanism based on verified or declared age"

**Note:** Apple's 2025 age rating update distinguishes between "declared age" (self-reported, acceptable) and "verified age" (government ID, not required for non-regulated content). Declared age is sufficient for DANTE TERMINAL.

### 4.7 App Store Listing Copy (Effort: 2-3 hours)
**Priority: P1 — needed before submission**

Draft App Store and Play Store descriptions that:
- Clearly state the app uses AI to generate game content
- Emphasize on-device processing and offline play
- Note content may vary and safety systems are in place
- Include appropriate content descriptors
- Avoid overclaiming ("unlimited adventures" could trigger Apple 2.3.1 for misleading if quality is inconsistent)

### 4.8 On-Device Output Classifier (Effort: 1-2 weeks)
**Priority: P2 — recommended for v1.1**

Implement Approach B from Section 3.2:
- Integrate a lightweight text safety classifier (~50-100MB)
- Add configurable safety tiers in Settings
- Score each LLM response before display
- This enables lower age rating (potentially 9+ with very strict "Safe" default) and satisfies the most rigorous interpretation of both platforms' content safety requirements

---

## Sources

### Apple
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — primary source for all section numbers
- [Age Ratings Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) — complete age rating system reference
- [Updated App Review Guidelines (Nov 2025)](https://developer.apple.com/news/?id=ey6d8onl) — Guideline 5.1.2(i) third-party AI update
- [Apple App Store Guidelines 2025: AI App Rules](https://openforge.io/app-store-review-guidelines-2025-essential-ai-app-rules/) — practical compliance guide
- [Apple Restricting Generative AI Apps to 17+](https://www.macrumors.com/2023/03/02/apple-restricting-generative-ai-apps/) — BlueMail/Bing precedent
- [Apple Broadens Age Rating System (Jul 2025)](https://techcrunch.com/2025/07/25/apple-broadens-app-stores-age-rating-system/) — new 13+/16+/18+ tiers
- [App Store Age Ratings Guide](https://capgo.app/blog/app-store-age-ratings-guide/) — cross-platform comparison

### Google Play
- [Understanding Google Play's AI-Generated Content Policy](https://support.google.com/googleplay/android-developer/answer/14094294?hl=en) — primary AI content policy
- [AI-Generated Content Policy Details](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en) — developer responsibilities
- [Best Practices to Safeguard AI-Generated Content](https://support.google.com/googleplay/android-developer/answer/16353813?hl=en) — implementation guidance
- [Google Play Inappropriate Content Policy](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en) — prohibited content categories
- [Google Play Policy Updates (Jul 2025)](https://support.google.com/googleplay/android-developer/answer/16296680?hl=en) — latest policy changes
- [Google Play Store Policy Updates: Generative AI Apps](https://asoworld.com/blog/google-play-store-policy-updates-generative-ai-apps-health-apps-user-data-privacy/) — AI policy summary

### Industry Precedent
- [AI Dungeon Content Safety System](https://help.aidungeon.com/faq/managing-content-safety-in-ai-dungeon) — 3-tier safety approach
- [AI Dungeon Content Moderation](https://help.aidungeon.com/faq/how-does-content-moderation-work) — HiveAI integration details
- [AI Dungeon Safety Settings](https://help.aidungeon.com/faq/what-are-the-ai-safety-settings) — Safe/Moderate/Mature tiers
- [Navigating AI Rejections in App Store Submissions](https://appitventures.com/blog/navigating-ai-rejections-app-store-play-store-submissions) — rejection patterns

### Content Safety
- [HAP Filtering Against Harmful Content (IBM)](https://www.ibm.com/think/insights/hap-filtering) — classifier approach
- [LLM Toxicity and Profanity Management](https://purplescape.com/profanity-in-llm/) — filtering strategies
- [Google Secure AI Framework (SAIF)](https://safety.google/cybersecurity-advancements/saif/) — Google-recommended testing framework
