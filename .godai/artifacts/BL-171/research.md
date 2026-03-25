# BL-171: Prompt Quality Evaluation Rubric for Qwen2-1.5B Interactive Fiction Validation

> **BL-171** | Created: 2026-03-25 | Status: **COMPLETE**
>
> Purpose: Structured hands-on evaluation plan to confirm or reject whether Qwen2-1.5B-Instruct Q4_K_M produces quality interactive fiction responses sufficient for App Store submission.
> Audience: Founding team (2-person) for device testing.
> Dependencies: BL-123 (model selection), BL-044 (Sunken Archive adventure), BL-010 (GM prompt), BL-049 (GBNF grammar).

---

## Summary

This document defines a complete evaluation protocol for validating Qwen2-1.5B-Instruct Q4_K_M's interactive fiction quality before committing to store submission. It provides a 6-dimension scoring rubric with anchored 1-5 scales, 10 canonical test scenarios with exact prompts drawn from the Sunken Archive adventure, numeric pass-fail thresholds, and a step-by-step execution procedure. The evaluation is designed to complete in under 90 minutes on a single device and produce a definitive SHIP or NO-SHIP recommendation.

---

## 1. Evaluation Rubric: 6 Quality Dimensions

Each dimension is scored on a 1-5 integer scale. Scores 1, 3, and 5 have concrete anchor descriptions. Scores 2 and 4 represent intermediate quality between adjacent anchors.

### D1: Narrative Coherence

*Does the response form a logically consistent, readable passage that advances the game state?*

| Score | Anchor Description |
|---|---|
| **1** | Incoherent or contradictory. Sentences don't connect. Contains hallucinated details that conflict with the established scene (e.g., mentions sunlight in an underground archive). May trail off mid-sentence or repeat itself. |
| 2 | Between 1 and 3. |
| **3** | Readable and logically consistent. Sentences follow from each other. Scene details don't contradict prior context. May be formulaic or generic, but nothing is confusing or broken. A player could understand what happened and what to do next. |
| 4 | Between 3 and 5. |
| **5** | Seamlessly coherent with strong narrative flow. Each sentence builds on the last. Establishes cause-and-effect within the scene. Details reference and build on the established world state (location, inventory, prior actions). Reads like authored interactive fiction. |

### D2: Command Parsing Accuracy

*Does the response correctly interpret and respond to the player's stated action?*

| Score | Anchor Description |
|---|---|
| **1** | Ignores or misinterprets the player's command entirely. Describes something unrelated to what was typed. Example: player says "pick up the key" and response describes walking through a door. |
| 2 | Between 1 and 3. |
| **3** | Correctly identifies the core action and responds to it. May miss secondary details or nuances in the command, but the main intent is addressed. Example: player says "carefully examine the glint under the desk" and response describes finding an object under the desk (but ignores the "carefully" modifier). |
| 4 | Between 3 and 5. |
| **5** | Precisely interprets both the action and its modifiers, context, and implications. Responds to exactly what was typed, including subtle qualifiers. Example: player says "carefully examine the glint under the desk" and response includes cautious approach, describes the glint resolving into a brass key, and notes consequences of being careful (no noise, no disturbance). |

### D3: Suggestion Relevance

*Are the 3 action suggestions contextually appropriate, distinct, and actionable?*

| Score | Anchor Description |
|---|---|
| **1** | Suggestions are missing, malformed (wrong count, broken formatting), or entirely nonsensical. Example: suggests "Go to the beach" in an underground archive, or only provides 1 suggestion, or outputs suggestions without the `> N.` format. |
| 2 | Between 1 and 3. |
| **3** | Exactly 3 suggestions are present in correct `> N.` format. They are contextually plausible (relate to the current scene) and distinct from each other. At least one suggests forward progress. May be generic ("Look around", "Go back", "Wait"). |
| 4 | Between 3 and 5. |
| **5** | Exactly 3 suggestions in correct format. Each is specific to the current scene state — references visible objects, NPCs, or exits by name. They offer meaningfully different gameplay paths (e.g., exploration vs. interaction vs. caution). At least one reveals a non-obvious possibility that rewards player curiosity. |

### D4: Tone Consistency

*Does the response maintain the sardonic, atmospheric, dark-literary tone established by the system prompt?*

| Score | Anchor Description |
|---|---|
| **1** | Completely wrong tone. Cheerful, modern, chatbot-like ("Sure! Here's what happens next!"), or clinical and detached. No atmospheric language. Breaks the fourth wall by referencing the AI, the game engine, or the player as a user. |
| 2 | Between 1 and 3. |
| **3** | Appropriate tone for interactive fiction — atmospheric, second-person narration, no fourth-wall breaks. Uses sensory language. May not be distinctively sardonic or literary, but reads as a competent game master narrating a dark fantasy scene. |
| 4 | Between 3 and 5. |
| **5** | Nails the sardonic, atmospheric voice. Prose has personality — dry observations, unsettling details, literary word choices. Sensory descriptions use taste, smell, and texture (not just sight and sound). Consistent with "the Archive remembers you" vibe. Could be excerpted as marketing copy for the game. |

### D5: World State Tracking

*Does the response respect and reflect the current game state (location, inventory, prior actions, NPC knowledge)?*

| Score | Anchor Description |
|---|---|
| **1** | Contradicts established state. Mentions items the player doesn't have, describes a location the player isn't in, or ignores a prior event that should have consequences. Example: player used the brass key (consumed) and response later suggests using it again. |
| 2 | Between 1 and 3. |
| **3** | Does not contradict established state. Response is consistent with the location context injected into the prompt. May not actively reference prior events, but nothing is wrong. A player reading the transcript wouldn't notice a continuity error. |
| 4 | Between 3 and 5. |
| **5** | Actively incorporates world state. References items in inventory, acknowledges prior actions and their consequences, reflects the current location's specific details (exits, NPCs, atmosphere). Creates a sense of persistent world. Example: after the player damaged a bookshelf earlier, subsequent room descriptions mention the damage. |

### D6: Response Length Appropriateness

*Is the response within the target word count (60-90 words narrative) and not truncated or padded?*

| Score | Anchor Description |
|---|---|
| **1** | Severely out of range. Fewer than 20 words (stub or fragment) or more than 200 words (wall of text that would overwhelm the terminal UI). Or: response is clearly truncated mid-sentence due to token limit. |
| 2 | Between 1 and 3. |
| **3** | Within an acceptable range (40-120 words narrative). Neither noticeably short nor painfully long. Reads as a complete thought. Suggestions are present and not competing for space with the narrative. |
| 4 | Between 3 and 5. |
| **5** | Precisely within the 60-90 word target for narrative text. Every sentence earns its place — no filler, no truncation. The response feels dense with meaning and atmosphere without taxing the player's reading patience. Suggestions are crisp (5-12 words each). |

---

## 2. Ten Canonical Test Scenarios

Each scenario specifies the exact prompt to submit, the game context (location, inventory, history), and which quality dimensions are primary evaluation targets.

### Scenario 1: Opening Scene Exploration

**Category:** Room exploration
**Primary dimensions tested:** D1 (Narrative Coherence), D4 (Tone Consistency), D6 (Response Length)
**Game context:**
- Location: The Antechamber (starting location)
- Inventory: Oil Lamp
- Turn: 1 (opening)
- History: None (first turn)

**System prompt preamble (always present):**
```
System: You are the Game Master of DANTE TERMINAL, a text adventure game.
Narrate atmospheric scenes in 2-3 sentences (60-90 words max).
Use vivid sensory detail -- sound, smell, texture. Always advance the story.
Acknowledge every player action with consequences.
End every response with exactly 3 action suggestions.

[EXAMPLE]
Player: look around the room
GM: Dust motes drift through a shaft of grey light from a crack in the ceiling. The archive's east wing stretches before you -- shelves of waterlogged books lean at drunken angles, and something metallic glints beneath a collapsed reading desk. The air tastes of copper and old paper. A corridor leads north, half-submerged.

> 1. Investigate the metallic glint under the desk
> 2. Wade north into the flooded corridor
> 3. Examine the waterlogged books on the nearest shelf
[/EXAMPLE]

CURRENT LOCATION: The Antechamber. Collapsed stairway, rubble blocks exit upward. Floor mosaic: open book in chains. Water seeps through debris. One corridor leads north to Main Hall. Exits: north.
```

**Exact prompt to submit:**
```
look around
```

**What to look for:**
- Does the response describe the Antechamber's specific features (rubble, mosaic, water, corridor north)?
- Is the tone atmospheric and dark, not cheerful?
- Are exactly 3 suggestions provided in the correct format?
- Is the narrative 60-90 words?

---

### Scenario 2: Object Manipulation

**Category:** Object manipulation
**Primary dimensions tested:** D2 (Command Parsing), D5 (World State Tracking), D3 (Suggestion Relevance)
**Game context:**
- Location: The East Wing
- Inventory: Oil Lamp
- Turn: 3
- History: Player explored Antechamber, moved north to Main Hall, then east to East Wing
- Location context: `CURRENT LOCATION: The East Wing. Ankle-deep dark water. Leaning bookshelves, waterlogged books. Collapsed reading desk with metallic glint underneath. Exits: west, north.`

**Exact prompt to submit:**
```
reach under the collapsed desk and grab the metallic object
```

**What to look for:**
- Does the response describe finding the Brass Key (or a plausible metallic object)?
- Does it acknowledge the physical action of reaching under a collapsed desk (effort, danger, wetness)?
- Do suggestions reflect the new state (now holding a new item)?
- Does it avoid mentioning items or exits not present in this location?

---

### Scenario 3: NPC Conversation (First Meeting)

**Category:** NPC conversation
**Primary dimensions tested:** D2 (Command Parsing), D4 (Tone Consistency), D5 (World State Tracking)
**Game context:**
- Location: The Reading Room
- Inventory: Oil Lamp, Archivist's Journal
- Turn: 7
- History: Player has explored several rooms, found the journal, now enters Reading Room
- Location context: `CURRENT LOCATION: The Reading Room. Large domed chamber. Star map mural -- constellations subtly wrong. Collapsed tables and chairs. Cold stone fire pit with oversized scorch marks. Exits: east, south. NPCs: maren.`
- Prior turn GM text: "The dome overhead is cracked like an eggshell. Between the broken tables, a figure sits hunched near the dead fire pit -- a woman, watching you with eyes that have forgotten how to blink."

**Exact prompt to submit:**
```
talk to the woman by the fire pit
```

**What to look for:**
- Does the NPC respond with personality (paranoid, guarded, dry humor)?
- Is dialogue formatted distinctly from narration (quotation marks or clear attribution)?
- Does the response acknowledge the player's approach, not just dump dialogue?
- Do suggestions offer different conversational branches (ask about X, show item, leave)?

---

### Scenario 4: Combat Encounter

**Category:** Combat encounter
**Primary dimensions tested:** D1 (Narrative Coherence), D2 (Command Parsing), D6 (Response Length)
**Game context:**
- Location: The Restricted Section
- Inventory: Oil Lamp, Cipher Wheel, Waterproof Satchel
- Turn: 12
- History: Player has progressed through Acts 1-2, gate is open, entering Restricted Section
- Location context: `CURRENT LOCATION: The Restricted Section. Carved from bedrock. Books chained to shelves, spines inward. Air thick and warm. Darkness unnaturally dense. Low hum from below. Exits: south, down (blocked). NPCs: the_warden.`
- Prior turn: The Warden has manifested and asked its question.

**Exact prompt to submit:**
```
attack the darkness with my lamp
```

**What to look for:**
- Does the response handle a combat-like action against an abstract entity (darkness/Warden)?
- Is the outcome narrated with consequences (likely failure -- the Warden is not fought with weapons)?
- Does it stay within the 60-90 word range despite action-heavy content?
- Is the action acknowledged (not ignored) even if the outcome is "that doesn't work"?

---

### Scenario 5: Inventory Management

**Category:** Inventory management
**Primary dimensions tested:** D2 (Command Parsing), D5 (World State Tracking), D3 (Suggestion Relevance)
**Game context:**
- Location: The Circulation Desk
- Inventory: Oil Lamp, Brass Key, Archivist's Journal
- Turn: 8
- Location context: `CURRENT LOCATION: The Circulation Desk. Hexagonal chamber with massive stone desk. Chained leather ledger. Polished brass bell. Iron gate north to Restricted Section needs brass key. Exits: south, east, west, north (locked). NPCs: the_cataloger.`

**Exact prompt to submit:**
```
use the brass key on the iron gate
```

**What to look for:**
- Does the response describe using the key on the gate specifically?
- Does it narrate the key breaking (consumable item -- per adventure data)?
- Does the response reflect the gate opening (state change)?
- Do suggestions reflect the new state (gate is now open, Restricted Section accessible)?

---

### Scenario 6: Nonsensical Input

**Category:** Nonsensical input
**Primary dimensions tested:** D2 (Command Parsing), D4 (Tone Consistency), D1 (Narrative Coherence)
**Game context:**
- Location: The Main Hall
- Inventory: Oil Lamp
- Turn: 2
- Location context: `CURRENT LOCATION: The Main Hall. Central vaulted corridor. Bioluminescent fungus on ceiling casts blue-green glow. Floor mosaic shows robed figures carrying books into a spiral. Exits: south, east, west, north.`

**Exact prompt to submit:**
```
eat the ceiling fungus
```

**What to look for:**
- Does the model handle the absurd-but-technically-parseable command gracefully?
- Is the response in-character (sardonic GM reaction) rather than a refusal or error?
- Are there consequences (taste, effect, minor humor)?
- Does the model stay in the game world (no "as an AI, I can't..." responses)?
- Are suggestions still provided in correct format, steering toward productive gameplay?

---

### Scenario 7: Ambiguous Command

**Category:** Ambiguous commands
**Primary dimensions tested:** D2 (Command Parsing), D1 (Narrative Coherence), D3 (Suggestion Relevance)
**Game context:**
- Location: The West Wing
- Inventory: Oil Lamp
- Turn: 5
- Location context: `CURRENT LOCATION: The West Wing. Bone-dry, warm air. Glass display cases, most shattered. One intact case with wax seal holds the Archivist's Journal. Cabinet drawer contains glass vial of solvent. Exits: east. Items: archivists_journal, glass_vial_solvent.`

**Exact prompt to submit:**
```
open it
```

**What to look for:**
- How does the model resolve "it" when multiple interactable objects exist (display case, cabinet drawer)?
- Does it pick one reasonable interpretation or ask for clarification (both acceptable)?
- Does it avoid ignoring the command entirely?
- Are suggestions specific enough to disambiguate (e.g., "Open the display case", "Open the cabinet drawer")?

---

### Scenario 8: Multi-Step Puzzle

**Category:** Multi-step puzzle
**Primary dimensions tested:** D1 (Narrative Coherence), D5 (World State Tracking), D3 (Suggestion Relevance)
**Game context:**
- Location: The Vault of the Codex
- Inventory: Oil Lamp, Cipher Wheel, Archivist's Journal, Waterproof Satchel
- Turn: 15
- History: Player has passed the Warden, descended to the Vault, and now faces the pedestal
- Location context: `CURRENT LOCATION: The Vault of the Codex. Circular obsidian chamber. Stone pedestal holds Codex Umbra -- black leather book absorbing light. Five-disc combination lock with star-map symbols. Exits: up.`
- The player has the combination (quest flag `combination_known` is true).

**Exact prompt to submit:**
```
enter the star-map combination on the pedestal lock
```

**What to look for:**
- Does the response narrate the puzzle solution attempt (turning discs, matching symbols)?
- Does it create dramatic tension (the Codex responding, the lock mechanism)?
- Does it advance the state (lock opens, Codex becomes available)?
- Do suggestions reflect the critical choice (take the Codex, examine it first, hesitate)?

---

### Scenario 9: Atmospheric Description Request

**Category:** Atmospheric description request
**Primary dimensions tested:** D4 (Tone Consistency), D6 (Response Length), D1 (Narrative Coherence)
**Game context:**
- Location: The Flooded Passage
- Inventory: Oil Lamp, Waterproof Satchel
- Turn: 6
- Location context: `CURRENT LOCATION: The Flooded Passage. Waist-deep black water, narrow walls, low ceiling. Sound distorts. Waterproof satchel on peg above water. Submerged shelf holds sealed lamp oil. Exits: south, west.`

**Exact prompt to submit:**
```
listen carefully to the sounds in the water
```

**What to look for:**
- Does the response focus on auditory detail (as requested) rather than defaulting to visual?
- Does it use the "sound distorts" atmosphere cue from the location data?
- Is the prose quality at its highest here (this is a pure atmosphere prompt)?
- Are sensory descriptions specific (dripping, echoing, gurgling) rather than generic ("you hear sounds")?
- Is the response appropriately eerie for waist-deep water in a dark passage?

---

### Scenario 10: Meta-Command Handling

**Category:** Meta-commands
**Primary dimensions tested:** D2 (Command Parsing), D4 (Tone Consistency), D1 (Narrative Coherence)
**Game context:**
- Location: The Main Hall
- Inventory: Oil Lamp, Brass Key
- Turn: 4
- Location context: `CURRENT LOCATION: The Main Hall. Central vaulted corridor. Bioluminescent fungus on ceiling casts blue-green glow. Floor mosaic shows robed figures carrying books into a spiral. Exits: south, east, west, north.`

**Exact prompt to submit:**
```
help
```

**What to look for:**
- Does the model respond in-character (GM narrating assistance) rather than breaking to a system help menu?
- Does it provide useful gameplay guidance while maintaining the fiction (e.g., "The Archive rewards the observant. Examine what you find, speak to those who linger, and trust your lamp.")?
- Does it avoid listing game mechanics, key bindings, or technical instructions?
- Are suggestions particularly helpful/tutorial-oriented for this meta moment?
- If the model does break character, note how severely (mild hint vs. full chatbot mode).

---

## 3. Pass-Fail Thresholds

### 3.1 Per-Dimension Minimum Scores

Each dimension has a minimum acceptable average score across all 10 scenarios. Falling below any single dimension minimum triggers a NO-SHIP decision.

| Dimension | Minimum Average (across 10 scenarios) | Rationale |
|---|---|---|
| **D1: Narrative Coherence** | **3.0** | Players tolerate generic prose but not confused or contradictory text. Below 3.0 means frequent "wait, what?" moments. |
| **D2: Command Parsing** | **3.0** | Players forgive occasional misreads but not systematic command ignoring. Below 3.0 means the game feels broken. |
| **D3: Suggestion Relevance** | **2.5** | Suggestions are a safety net, not the core experience. Generic-but-valid suggestions are acceptable at launch. Below 2.5 means suggestions actively mislead. |
| **D4: Tone Consistency** | **2.5** | Occasional tone breaks are tolerable if the core experience is atmospheric. Below 2.5 means the game doesn't feel like a "retro terminal adventure." |
| **D5: World State Tracking** | **2.5** | Small-model context limitations are expected. Mild state drift is acceptable. Below 2.5 means contradictions are frequent enough to break immersion. |
| **D6: Response Length** | **3.0** | Too short = empty experience. Too long = terminal UI breaks. Below 3.0 means frequent truncation or text walls. |

### 3.2 Per-Scenario Floor

No individual scenario may score below **2.0** on any dimension. A single 1-score on any dimension in any scenario indicates a catastrophic failure mode that must be investigated.

**Exception:** D5 (World State Tracking) on Scenario 1 is exempt from the floor because the opening turn has no prior state to track. Score it but exclude from the floor check.

### 3.3 Composite Score

The **composite score** is the unweighted average of all 6 dimension averages:

```
Composite = (avg_D1 + avg_D2 + avg_D3 + avg_D4 + avg_D5 + avg_D6) / 6
```

| Composite Score | Decision |
|---|---|
| **>= 3.5** | **SHIP** -- Quality exceeds baseline. Proceed to store submission. |
| **3.0 - 3.49** | **SHIP WITH CAVEATS** -- Quality is adequate. Ship but prioritize prompt engineering improvements in v1.1. Document specific weak scenarios for post-launch iteration. |
| **2.5 - 2.99** | **CONDITIONAL NO-SHIP** -- Quality is marginal. Review individual dimension scores. If all dimension minimums pass and the weakness is isolated to 1-2 scenarios, consider shipping with those scenario types avoided in onboarding. Otherwise, evaluate fallback model (Gemma 2 2B). |
| **< 2.5** | **NO-SHIP** -- Quality is insufficient. Switch to Gemma 2 2B IT fallback (per BL-123 section 4.2) and re-evaluate, or explore LoRA fine-tuning before launch. |

### 3.4 Critical Failure Rules (Automatic NO-SHIP)

Regardless of composite score, the following trigger an automatic NO-SHIP:

1. **Fourth-wall break:** Any scenario where the model responds as "an AI assistant" (e.g., "As a language model, I..."). Even one instance means the system prompt is failing to constrain the model.
2. **GBNF format failure:** More than 2 of 10 scenarios produce malformed suggestion blocks (wrong count, missing `> N.` prefix, suggestions embedded in narrative). This means the grammar constraint isn't reliable.
3. **Infinite loop or repetition:** Any scenario where the model repeats the same phrase or sentence 3+ times within a single response. Per BL-123, this was the defect that eliminated SmolLM2.
4. **Empty or sub-10-word response:** Any scenario producing fewer than 10 words of narrative text.

---

## 4. Test Execution Procedure

### 4.1 Prerequisites

| Requirement | Details |
|---|---|
| **Device** | Mid-range iOS or Android device (iPhone 12+ or equivalent). Must have >= 4GB RAM. |
| **Model file** | `qwen2-1_5b-instruct-q4_k_m.gguf` downloaded and verified (SHA-256 per BL-132). |
| **App build** | DANTE TERMINAL debug or release build with inference engine functional. |
| **Scoring sheet** | Copy the scoring template below (physical paper or spreadsheet). |
| **Timer** | Stopwatch or phone timer for per-scenario timing. |

### 4.2 Environment Setup

1. **Fresh state per scenario.** Before each scenario, reset the game session to the specified turn state. For scenarios requiring history (turns > 1), manually play through the prerequisite turns OR load a prepared save file with the correct state.
2. **No warm-up.** Run each scenario cold (first inference after model load) for the first scenario, then sequentially for the rest. This captures both cold-start and warm-cache performance.
3. **GBNF grammar active.** Ensure `game_master.gbnf` is loaded for all scenarios. The grammar is part of the production configuration.
4. **Context budget.** Use the default `contextBudgetTokens: 4096`, `maxResponseTokens: 200` per GameSession defaults.

### 4.3 Per-Scenario Execution Steps

For each of the 10 scenarios (estimated 5-8 minutes per scenario):

1. **Set up game state** as specified (location, inventory, history context). (2 min)
2. **Submit the exact prompt** as written in Section 2. Do not modify or rephrase.
3. **Wait for complete response** (narrative + suggestions). Note the wall-clock generation time.
4. **Screenshot the response.** Save as `BL-171-S{N}.png` where N is the scenario number (01-10).
5. **Score each of the 6 dimensions** immediately while the response is fresh. Write integer scores (1-5) on the scoring sheet.
6. **Note any critical failures** (fourth-wall break, format failure, repetition loop, empty response).
7. **Record generation time** in seconds (from prompt submission to last token).
8. **Optional: record qualitative notes** -- brief free-text observations (max 1 sentence) for post-evaluation analysis.

### 4.4 Scoring Sheet Template

Copy this table for each scenario:

```
Scenario: [N] - [Name]
Date/Time: ____________
Device: ____________
Generation time: ______ seconds

| Dimension                      | Score (1-5) | Notes |
|--------------------------------|-------------|-------|
| D1: Narrative Coherence        |             |       |
| D2: Command Parsing Accuracy   |             |       |
| D3: Suggestion Relevance       |             |       |
| D4: Tone Consistency           |             |       |
| D5: World State Tracking       |             |       |
| D6: Response Length             |             |       |

Critical failures: [ ] Fourth-wall  [ ] Format  [ ] Repetition loop  [ ] Empty response
Screenshot saved: [ ] BL-171-S{N}.png
```

### 4.5 Aggregation Method

After all 10 scenarios are scored:

1. **Compute dimension averages.** For each dimension D1-D6, average its 10 scores:
   ```
   avg_D1 = (S1_D1 + S2_D1 + ... + S10_D1) / 10
   ```

2. **Check dimension minimums.** Compare each `avg_DN` against the minimum in Section 3.1. Flag any failures.

3. **Check per-scenario floor.** Verify no individual score is below 2.0 (with the D5/Scenario 1 exemption).

4. **Check critical failure rules.** If any critical failure was noted, it's an automatic NO-SHIP regardless of scores.

5. **Compute composite score:**
   ```
   Composite = (avg_D1 + avg_D2 + avg_D3 + avg_D4 + avg_D5 + avg_D6) / 6
   ```

6. **Apply the decision matrix** from Section 3.3.

7. **Record the final verdict** and any caveats in `.godai/artifacts/BL-171/results.md` (created after evaluation).

### 4.6 Summary Scorecard Template

```
# BL-171 Evaluation Results
Date: ____________
Device: ____________
Model: Qwen2-1.5B-Instruct Q4_K_M (qwen2-1_5b-instruct-q4_k_m.gguf)

## Dimension Averages
| Dimension                    | Average | Minimum | Pass? |
|------------------------------|---------|---------|-------|
| D1: Narrative Coherence      |         | 3.0     |       |
| D2: Command Parsing Accuracy |         | 3.0     |       |
| D3: Suggestion Relevance     |         | 2.5     |       |
| D4: Tone Consistency         |         | 2.5     |       |
| D5: World State Tracking     |         | 2.5     |       |
| D6: Response Length           |         | 3.0     |       |

## Composite Score: ______ / 5.0
## Decision: [SHIP / SHIP WITH CAVEATS / CONDITIONAL NO-SHIP / NO-SHIP]

## Critical Failures: [None / List]
## Per-Scenario Floor Violations: [None / List]

## Generation Time Stats
- Mean: ______ seconds
- Min: ______ seconds
- Max: ______ seconds

## Evaluator Notes:
(Free-text observations and recommendations)
```

### 4.7 Time Budget

| Phase | Estimated Time |
|---|---|
| Environment setup and model loading | 10 minutes |
| 10 scenarios at 5-8 min each | 50-80 minutes |
| Score aggregation and decision | 10 minutes |
| **Total** | **70-100 minutes** |

### 4.8 Re-Test Protocol

If the result is CONDITIONAL NO-SHIP or if any scenario hit a critical failure:

1. **Run the failing scenario(s) 3 additional times** to confirm the failure is consistent (not a sampling fluke from temperature randomness).
2. **If 2 of 3 retries pass**, upgrade the scenario's score to the median of all 4 runs (original + 3 retries).
3. **If 2 of 3 retries still fail**, the failure is confirmed. Proceed to fallback evaluation (Gemma 2 2B IT per BL-123) or prompt engineering investigation.

---

## 5. Recommendations

1. **Run evaluation within the first 2 days of having inference working on-device.** This is the go/no-go gate for the entire product. Delaying evaluation while building more features is a sunk-cost risk.

2. **Both team members should score independently.** If both evaluate, average their scores. Inter-rater disagreement > 1.5 points on any dimension warrants discussion before finalizing.

3. **Save all raw responses.** Beyond screenshots, copy the raw text output for each scenario into a text file (`BL-171-raw-responses.txt`). This enables post-evaluation prompt engineering -- if scores are marginal, the raw responses reveal exactly which prompt patterns to improve.

4. **If SHIP WITH CAVEATS:** Create a follow-up backlog item (e.g., BL-XXX) targeting the weakest dimension with specific prompt engineering improvements (system prompt revisions, GBNF grammar tightening, style anchor modifications).

5. **If NO-SHIP:** Before switching models, try 3 interventions in order: (a) revise the system prompt with stronger constraints, (b) adjust GBNF grammar to force shorter responses, (c) add few-shot examples for the failing scenario types. Each takes < 1 hour and may recover 0.5-1.0 points.

---

## 6. Sources

- BL-123: Model Selection Matrix (quality scores, model constraints, fallback strategy)
- BL-010: GM Prompt Patterns (system prompt design, recency-bias exploitation)
- BL-036: Small-Model Prompting Techniques (style anchor, budget enforcement)
- BL-044: Sunken Archive Adventure (location/item/NPC data, quest structure)
- BL-049: GBNF Grammar (output format enforcement)
- BL-085: Accessibility Audit (UI constraints affecting response display)
- BL-132: Model Download Config (production model specification)
- `dante_terminal/assets/game_master_prompt.txt` (production system prompt, verbatim)
- `dante_terminal/assets/game_master.gbnf` (production grammar, verbatim)
- `dante_terminal/assets/adventures/sunken_archive.json` (production adventure data, verbatim)

---

*Evaluation protocol created: 2026-03-25. Test scenarios use production prompt and grammar. Re-evaluate if system prompt, GBNF grammar, or model are changed.*
