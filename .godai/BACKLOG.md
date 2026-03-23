# Backlog

## Ready

### BL-009: Add measurable acceptance criteria to all backlog items that lack them
- **Description:** The only execution attempt (BL-001) was rejected at pre-flight because it had no acceptance criteria. Inspection shows BL-001 through BL-005 all lack acceptance_criteria fields, while BL-006 and BL-007 have them. For each of the 5 items missing criteria, write 2-4 concrete, objectively testable 'done when' conditions following the pattern established by BL-006/BL-007 and the learning about research tasks. For BL-001 specifically, include quantitative thresholds (e.g., 'comparison table includes tokens/sec and peak memory MB columns', 'at least one candidate achieves >5 tokens/sec on mid-range device specs'). Update BACKLOG.md directly.
- **Impact:** 7 | **Effort:** 2 | **Priority Score:** 63
- **Goal:** Immediate — Validate on-device AI feasibility (unblocks BL-001 execution by removing the pre-flight rejection cause)
- **Domain:** operations
- **Acceptance Criteria:**
  - BL-001 through BL-005 in BACKLOG.md each contain an acceptance_criteria section with 2-4 testable conditions
  - BL-001 acceptance criteria include at least one quantitative performance threshold
  - No acceptance criterion uses vague terms like 'works well', 'is improved', or 'looks good'
  - BACKLOG.md parses correctly with no formatting errors after edits
- **Status:** ready
- **Updated:** 2026-03-23

### BL-022: DANTE TERMINAL retro UI design spec with typewriter effect interaction patterns
- **Description:** Create a UI design specification document for the DANTE TERMINAL retro terminal interface. This is the only short-term goal ('implement the DANTE TERMINAL retro UI with typewriter streaming effect') with zero backlog coverage — no existing backlog item addresses it. Purpose: define visual design decisions and interaction patterns before coding begins, so implementation can proceed without design iteration loops. Audience: founding team and front-end implementation. Key sections: (1) Visual design system — exact color palette (green-on-black variants), font selection (monospace candidates with licensing for mobile), CRT/scanline effect parameters, screen edge treatment, (2) Typewriter streaming effect spec — characters-per-second rate, cursor blink timing, sound effect triggers (if any), behavior during fast-scroll/skip, (3) Input interaction patterns — text input field styling, command history navigation, suggestion chip layout and tap targets for mobile, keyboard behavior (auto-show, dismiss), (4) Screen-by-screen wireframes — title/menu screen, active game screen, settings screen, model download/first-run screen (referencing BL-019's first-run UX states). This document ensures the UI implementation has a clear, opinionated design target rather than ad-hoc decisions during coding.
- **Impact:** 7 | **Effort:** 3 | **Priority Score:** 56
- **Goal:** Short-term — Implement the DANTE TERMINAL retro UI with typewriter streaming effect
- **Domain:** design
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - Visual design section specifies exact hex color codes for at least primary, secondary, and background colors plus a named monospace font with license type
  - Typewriter effect section defines numeric characters-per-second rate and cursor blink interval in milliseconds
  - Screen wireframes section includes at least 4 distinct screens with labeled UI element descriptions
- **Status:** ready
- **Updated:** 2026-03-23

### BL-002: Set up cross-platform project scaffold
- **Description:** Initialize a Flutter or React Native project with working iOS and Android build targets, CI basics, and a minimal "hello world" screen. Decision on framework should follow from BL-001 (which runtime integrates best).
- **Impact:** 8 | **Effort:** 4 | **Priority Score:** 56
- **Goal:** Immediate — Set up cross-platform project scaffold with basic build pipeline for iOS and Android
- **Acceptance Criteria:**
  - Project directory initialized with chosen framework (Flutter or React Native) including platform-specific configs for both iOS and Android
  - Build commands complete without errors producing deployable artifacts for both platforms (e.g., `flutter build ios --no-codesign` and `flutter build apk`)
  - A minimal screen renders text on both an iOS simulator and an Android emulator without crashes
  - CI configuration file exists (e.g., GitHub Actions workflow) that runs build verification on push
- **Status:** ready
- **Updated:** 2026-03-23

### BL-013: DANTE TERMINAL game design one-pager defining adventure structure and fun loops
- **Description:** Write a focused game design document that defines what playing DANTE TERMINAL actually feels like — decisions that BL-005 (game loop implementation) needs but that no current backlog item produces. Purpose: establish shared game design vision before coding the game loop. Audience: founding team and the AI Game Master prompt design. Key sections: (1) Core loop anatomy — what happens each turn, pacing targets (words per response, turns per session, sessions per adventure), (2) Adventure structure — how an adventure begins, progresses, and ends; win/fail conditions; branching vs. linear narrative philosophy, (3) Genre/theme menu — 3-5 launch adventure themes with one-paragraph pitches (e.g., 'dungeon crawl', 'sci-fi escape', 'noir mystery'), (4) Replayability mechanics — what makes a player start a new adventure after finishing one (procedural variation, unlockable themes, difficulty modes). This document directly feeds into prompt engineering for BL-005 and content planning for the medium-term 'explore content variety' goal.
- **Impact:** 6 | **Effort:** 2 | **Priority Score:** 54
- **Goal:** Short-term — Build the core game loop: AI generates scene → player types command → AI responds → 3 suggestions shown
- **Domain:** design
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - Core loop anatomy includes specific numeric targets for words-per-response and turns-per-session
  - Genre/theme menu contains at least 3 distinct adventure themes each with a one-paragraph pitch
  - Replayability section describes at least 2 concrete mechanics with explanation of how each drives repeat play
- **Status:** ready
- **Updated:** 2026-03-23

### BL-010: Research AI Game Master prompt patterns from existing interactive fiction products
- **Description:** Survey how existing AI-powered interactive fiction products (AI Dungeon, NovelAI, KoboldAI, LitRPG Adventures) structure their prompts to produce engaging game experiences with small models. Purpose: build a reference of proven patterns before implementing BL-005's Game Master prompt. Audience: founding team for prompt design decisions. Key sections: (1) System prompt anatomy — common structural elements across products (world state block, character memory, tone instructions, output format constraints), (2) Context window management strategies — how products handle long adventures that exceed context limits (summarization, sliding window, importance scoring), (3) Suggestion generation techniques — how products produce contextual action suggestions without a separate model call, (4) Small-model adaptation — techniques for getting quality fiction output from sub-4B parameter models (few-shot examples in prompt, constrained generation, genre-specific fine-tune availability).
- **Impact:** 6 | **Effort:** 3 | **Priority Score:** 48
- **Goal:** Short-term — Build the core game loop: AI generates scene → player types command → AI responds → 3 suggestions shown
- **Domain:** research
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - At least 3 existing AI interactive fiction products analyzed with named prompt techniques
  - Context window management section describes at least 2 distinct strategies with trade-offs
  - Small-model section lists specific models under 4B parameters with links to weights or fine-tunes suitable for interactive fiction
- **Status:** ready
- **Updated:** 2026-03-23

### BL-001: Benchmark on-device LLM candidates
- **Description:** Evaluate llama.cpp, MLC LLM, and MediaPipe LLM Inference on iOS and Android simulators/devices. Test small models (Phi-3-mini, Gemma 2B, TinyLlama) for response quality, latency, and memory footprint in an interactive fiction context.
- **Impact:** 9 | **Effort:** 6 | **Priority Score:** 45
- **Goal:** Immediate — Validate on-device AI feasibility: select model, framework, and runtime that can generate quality interactive fiction responses on mid-range mobile devices
- **Acceptance Criteria:**
  - Comparison table exists with columns: model name, SDK, tokens/sec, peak memory MB, TTFT seconds, and interactive fiction quality score (1-5)
  - At least 3 model+SDK combinations benchmarked on at least one physical device or simulator per platform (iOS and Android)
  - At least one candidate achieves ≥4 tokens/sec decode speed and ≤1,500 MB peak memory on the iOS floor device spec (per BL-014 budget)
  - Each candidate's interactive fiction quality assessed with a standardized 5-turn test adventure, with numeric score and written rationale
- **Status:** ready
- **Updated:** 2026-03-23

### BL-003: Build proof-of-concept: on-device model generates a response
- **Description:** Integrate the chosen model + runtime into the app scaffold. User types a prompt, model generates a streamed text response on-device. No UI polish needed — just prove the pipeline works end-to-end.
- **Impact:** 9 | **Effort:** 6 | **Priority Score:** 45
- **Goal:** Immediate — Get a 'hello world' proof-of-concept: model loaded on-device, generating a text response to a user prompt
- **Acceptance Criteria:**
  - Chosen LLM model loads successfully within the mobile app on at least one device or simulator per platform
  - User can type a text prompt and receive a streamed text response generated entirely on-device with no network requests
  - Time-to-first-token is ≤3.0 seconds and decode speed is ≥4 tokens/sec on the target floor device (per BL-014 budget)
  - App does not crash or exceed platform memory limits during a 5-prompt test session
- **Status:** ready
- **Updated:** 2026-03-23

### BL-005: Implement core game loop with Game Master prompt engineering
- **Description:** Craft the system prompt that turns the LLM into an interactive fiction Game Master. Implement the loop: AI generates opening scene → player types command → AI responds with narrative + state tracking → 3 contextual suggestions generated. Include basic context window management.
- **Impact:** 9 | **Effort:** 6 | **Priority Score:** 45
- **Goal:** Short-term — Build the core game loop: AI generates scene → player types command → AI responds → 3 suggestions shown
- **Acceptance Criteria:**
  - System prompt exists that instructs the LLM to act as an interactive fiction Game Master, generating narrative responses and exactly 3 contextual action suggestions per turn
  - Game loop implements the full cycle: AI generates opening scene → player types freeform command → AI responds with narrative continuation → 3 suggestions displayed
  - Context window management prevents prompt overflow for at least 15 consecutive turns without crashing or producing incoherent output
  - A 10-turn test adventure demonstrates coherent narrative with no factual self-contradictions and all 10 responses include exactly 3 action suggestions
- **Status:** ready
- **Updated:** 2026-03-23

### BL-018: Build genre-specific Game Master prompt templates and test on CLI prototype
- **Description:** Create 4 distinct Game Master system prompt templates — one per genre (classic dungeon crawl, sci-fi escape, noir mystery, survival horror) — and run each through the working CLI prototype with a standardized 5-turn test conversation. Record results in a structured findings file showing: which genre produces the most coherent multi-turn narrative, which prompt structures best elicit the 3-suggestion format, and where small models break down (e.g., losing character names, contradicting earlier scene details). This is different from BL-010 (desk research about existing products' prompts) and BL-005 (full mobile game loop implementation) — this is hands-on prompt engineering using the working CLI to produce tested, reusable templates. Before this, there's one generic Game Master prompt from BL-012. After this, there are 4 genre-tested templates with empirical quality notes ready for BL-005 and BL-013.
- **Impact:** 6 | **Effort:** 4 | **Priority Score:** 42
- **Goal:** Short-term — Build the core game loop: AI generates scene → player types command → AI responds → 3 suggestions shown
- **Domain:** development
- **Acceptance Criteria:**
  - 4 genre-specific system prompt template files exist (dungeon, sci-fi, noir, horror) each with complete Game Master instructions
  - Each template has been run through at least 5 turns on the CLI prototype with conversation logs saved
  - Findings file documents per-genre scores for narrative coherence, suggestion quality, and character/detail consistency
  - At least one template identified as 'recommended default' with written rationale based on test results
- **Status:** ready
- **Updated:** 2026-03-23

### BL-019: Model delivery pipeline and first-run experience strategy for mobile app
- **Description:** Design and document how the 1.5-2GB LLM model file reaches the user's device after app installation, synthesizing constraints from BL-008 (SDK findings) and BL-014 (device specs). The iOS App Store imposes a 200MB cellular download limit, making model bundling impossible — the model MUST be a post-install download. This has cascading implications for UX, storage, and error handling that no current backlog item addresses. BL-001 benchmarks models and BL-003 assumes a model is on-device, but neither designs the delivery mechanism between them. Purpose: provide architecture-level decisions needed before BL-003 (on-device PoC) can be implemented without a placeholder hack. Audience: founding team for technical architecture decisions. Key sections: (1) Model format and quantization level selection (GGUF Q4_K_M vs Q4_0 vs Q5_K_M) with size/quality trade-off analysis referencing BL-014's memory budget, (2) Download mechanism — background download with resume support, progress UI, storage location (app sandbox vs shared), CDN options at zero cost (GitHub Releases, Hugging Face Hub), (3) First-run experience flow — wireframe-level UX from install → download → first game prompt, including error states (network failure, insufficient storage), (4) Model update strategy — how to ship improved models without forcing full re-download.
- **Impact:** 5 | **Effort:** 3 | **Priority Score:** 40
- **Goal:** Short-term — Ship playable prototype to both App Store and Google Play
- **Domain:** operations
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - Model format section names specific quantization levels with file sizes in MB and references BL-014 memory budget numbers
  - Download mechanism section identifies at least 2 zero-cost CDN/hosting options with URLs and documented file size limits
  - First-run experience section includes at least 3 distinct UX states (downloading, error/retry, ready-to-play) with user-facing copy for each
- **Status:** ready
- **Updated:** 2026-03-23

### BL-011: Pre-launch waitlist landing page and social campaign brief
- **Description:** Create a campaign brief for building an audience before DANTE TERMINAL ships. Purpose: define the pre-launch user acquisition strategy across channels that cost $0 (landing page with email capture, Reddit/Discord/Twitter presence, text adventure community outreach). Audience: founding team for execution prioritization. Key sections: (1) One-page landing page spec — headline, value prop, email signup CTA, and recommended free hosting (GitHub Pages, Netlify), (2) Social channel strategy — which 2-3 platforms to prioritize with posting cadence and content themes, (3) Text adventure community outreach plan — specific subreddits, Discord servers, and forums to engage with suggested intro posts, (4) Waitlist milestone targets — subscriber goals for pre-launch, soft launch, and public launch phases. This is a distinct channel from BL-006's app store optimization — it captures interest before the app exists.
- **Impact:** 4 | **Effort:** 2 | **Priority Score:** 36
- **Goal:** Short-term — Establish initial user acquisition channel (app store optimization, landing page, social, or similar)
- **Domain:** growth
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - Landing page spec includes exact headline text, CTA copy, and at least 2 free hosting options with URLs
  - Social channel strategy names at least 3 specific platforms/communities with rationale for prioritization
  - Waitlist milestone targets include numeric subscriber goals for at least 3 launch phases
- **Status:** ready
- **Updated:** 2026-03-23

### BL-020: Implement sliding-window context management in CLI prototype and measure quality degradation
- **Description:** The CLI prototype (BL-012) currently passes raw conversation history to the LLM, which will overflow the context window after ~10-15 turns on small models with 2K-4K context. Implement a configurable sliding-window strategy: keep the system prompt + last N turns verbatim, and compress older turns into a structured summary block (location, inventory, recent events) via an LLM summarization call. Run a 30-turn test adventure with window sizes of 5, 10, and 15 turns, and record: (a) whether the AI references events from before the window correctly, (b) whether it contradicts earlier established facts, (c) tokens/sec impact of different context sizes. This directly produces reusable context management code and empirical data that informs BL-005's mobile implementation. This is distinct from BL-010 (desk research on how others solve this) and BL-005 (full mobile game loop) — this is a hands-on CLI implementation that validates the approach before mobile investment. Before: CLI prototype degrades or errors after ~15 turns. After: CLI maintains coherent adventures for 30+ turns with measured quality trade-offs per window size.
- **Impact:** 5 | **Effort:** 5 | **Priority Score:** 30
- **Goal:** Medium-term — Improve AI response quality, speed, and memory/context management
- **Domain:** development
- **Acceptance Criteria:**
  - CLI prototype supports a --context-window flag that limits the number of raw turns kept in context
  - Turns older than the window are compressed into a structured summary block injected after the system prompt
  - Test results file documents narrative coherence scores for window sizes 5, 10, and 15 over a 30-turn conversation
  - At least one window size configuration maintains coherent adventure for 30 turns without factual contradictions in test log
- **Status:** ready
- **Updated:** 2026-03-23

### BL-021: Design game state JSON schema and validate state-only context reconstruction in CLI prototype
- **Description:** Define a structured JSON schema that captures DANTE TERMINAL adventure state independently of conversation history: current_scene (location, atmosphere), inventory (items with properties), visited_locations (explored areas set), active_npcs (name, disposition, last interaction), quest_flags (key-value progress markers), and narrative_summary (compressed story-so-far text). Implement a lightweight state extractor in the CLI prototype that parses each LLM response to update the state object using a secondary structured extraction prompt. Validate by running a 10-turn test adventure, then reconstructing game context from the state schema alone (zero conversation history) and verifying the AI produces a coherent continuation. This schema is foundational for: context window management (BL-020 could use it instead of freeform summaries), save/load game sessions, and context-aware suggestion generation. It de-risks BL-005's state tracking requirement by validating the approach in CLI first. Before: game state exists only as raw chat history. After: game state is a structured, serializable object proven to reconstruct viable game context without history.
- **Impact:** 5 | **Effort:** 5 | **Priority Score:** 30
- **Goal:** Short-term — Build the core game loop: AI generates scene → player types command → AI responds → 3 suggestions shown
- **Domain:** development
- **Acceptance Criteria:**
  - JSON schema file defines at least 6 state fields (scene, inventory, locations, NPCs, quest_flags, narrative_summary) with typed properties
  - CLI prototype extracts and updates state object after each LLM response turn without manual intervention
  - State reconstruction test demonstrates AI producing coherent continuation from schema-only context (no raw conversation history) after a 10-turn adventure
  - State object round-trips through JSON serialization and deserialization without data loss
- **Status:** ready
- **Updated:** 2026-03-23

### BL-007: Create app store submission runbook covering signing, provisioning, and release steps
- **Description:** Document the complete end-to-end process for submitting a Flutter/React Native app to both Apple App Store and Google Play Store. Sections: (1) Apple Developer Program enrollment and provisioning profile setup, (2) iOS code signing with certificates and entitlements, (3) TestFlight internal testing configuration, (4) App Store Connect metadata requirements and review guidelines checklist, (5) Google Play Console setup and AAB signing, (6) Google Play internal testing track configuration, (7) Pre-submission checklist (privacy policy URL, age rating, content declarations, app icons at required sizes). This runbook ensures the team can go from 'build passes' to 'submitted for review' in under 2 hours when the prototype is ready, directly unblocking the 'ship playable prototype' goal.
- **Impact:** 3 | **Effort:** 2 | **Priority Score:** 27
- **Goal:** Short-term — Ship playable prototype to both App Store and Google Play
- **Domain:** operations
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 7 sections populated
  - Apple section includes exact steps for provisioning profile creation and code signing
  - Google section includes exact steps for AAB upload and internal test track setup
  - Pre-submission checklist contains at least 10 verifiable items with links to platform documentation
- **Status:** ready
- **Updated:** 2026-03-23

### BL-017: Community validation campaign brief for CLI prototype on text adventure forums
- **Description:** Create a campaign brief for sharing the working CLI prototype with text adventure communities to validate AI-generated fiction quality before investing in mobile development. This is distinct from BL-011 (pre-launch waitlist for the mobile app) — this is about getting qualitative gameplay feedback from hardcore text adventure fans using the existing desktop CLI, right now. Purpose: validate that AI Game Master output meets the quality bar of text adventure enthusiasts before committing to mobile architecture. Audience: founding team for immediate execution. Key sections: (1) Target communities — specific subreddits (r/textadventures, r/interactivefiction, r/MUD), forums (intfiction.org, IFDB), and Discord servers with subscriber/member counts and posting norms, (2) Prototype packaging — how to distribute the CLI prototype for testers (pre-built binary via PyInstaller vs. pip install, bundled model download instructions, platform support), (3) Feedback collection plan — specific questions to ask testers (fiction quality rating 1-5, immersion breaks, suggestion usefulness, session length before boredom) and collection method (Google Form, GitHub Discussions, or Reddit thread), (4) Success criteria — minimum number of testers and quality score threshold that would validate proceeding to mobile.
- **Impact:** 3 | **Effort:** 2 | **Priority Score:** 27
- **Goal:** Medium-term — Iterate on game quality based on early user feedback
- **Domain:** growth
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ with all 4 key sections populated
  - At least 5 specific communities listed with subscriber/member counts and links
  - Feedback collection plan includes at least 4 specific questions with defined response scales
  - Success criteria section defines a numeric minimum tester count and minimum average quality score to proceed
- **Status:** ready
- **Updated:** 2026-03-23

### BL-006: Draft App Store listing copy and ASO keyword strategy
- **Description:** Research top-performing text adventure and AI game listings on App Store and Google Play. Produce a strategy document with: (1) Target keyword list with estimated competition levels for both platforms, (2) App title and subtitle variations optimized for discovery (e.g., 'Dante Terminal: AI Text Adventure'), (3) Full store listing copy — short description and long description — for both iOS and Android, (4) Screenshot and preview content plan describing 5 frames that tell the game's story. Purpose: ensure day-one organic discoverability when the prototype ships. Audience: founding team for review before store submission. This directly unblocks the 'establish initial user acquisition channel' goal with zero spend.
- **Impact:** 3 | **Effort:** 3 | **Priority Score:** 24
- **Goal:** Short-term — Establish initial user acquisition channel (app store optimization, landing page, social, or similar)
- **Domain:** growth
- **Acceptance Criteria:**
  - Artifact file exists in .godai/artifacts/ containing all 4 key sections
  - At least 15 target keywords listed with platform and competition rating
  - Complete short description (≤80 chars) and long description (≤4000 chars) drafted for both App Store and Google Play
  - Screenshot plan describes exactly 5 frames with visual content and caption text
- **Status:** ready
- **Updated:** 2026-03-23

## In Progress
_None._

## Done
_None._

## Blocked
_None._

## Rejected
_None._
