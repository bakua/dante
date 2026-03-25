# AI Game Master Prompt Patterns from Existing Interactive Fiction Products

> **BL-010** | Created: 2026-03-25 | Audience: founding team for prompt design decisions
>
> Purpose: Survey how existing AI-powered interactive fiction products structure their prompts to produce engaging game experiences, with emphasis on patterns applicable to small on-device models. This research directly informs BL-005 (Game Master prompt implementation).

---

## Summary

Existing AI interactive fiction products (AI Dungeon, NovelAI, KoboldAI, and the broader SillyTavern/KoboldCpp ecosystem) share a remarkably consistent prompt architecture: a layered context assembly system with fixed metadata at the top, keyword-triggered lore injection in the middle, narrative history filling the bulk, and high-influence style directives near the generation point. The critical insight for DANTE TERMINAL is that these products solve context window limitations through *selective injection* (only surfacing lore when keywords trigger it) and *hierarchical summarization* (compressing old turns into summaries while keeping recent turns verbatim). For sub-4B models, the research points toward aggressive task scoping, few-shot examples baked into the prompt, GBNF grammar-constrained generation for structured output (suggestions), and genre-specific fine-tunes that dramatically outperform base instruction-tuned models at the same parameter count.

---

## 1. System Prompt Anatomy: Common Structural Elements

### 1.1 Layered Context Assembly (Universal Pattern)

Every surveyed product constructs its prompt from the same fundamental layers, assembled in a specific order. The position of each layer relative to the generation point determines its influence strength (closer to generation = stronger influence).

**Universal Layer Stack (top to bottom):**

| Layer | AI Dungeon | NovelAI | KoboldAI | Purpose |
|-------|-----------|---------|----------|---------|
| **System Instructions** | "AI Instructions" (always included, up to 70% budget priority) | System role in instruct mode | N/A (text completion) | Define AI role, rules, output format constraints |
| **Plot/World Metadata** | "Plot Essentials" + "Story Summary" (always included) | "Memory" block (top of context) | "Memory" (inserted at very top) | Persistent high-level facts: setting, protagonist, central conflict |
| **Keyword-Triggered Lore** | "Story Cards" (~25% of dynamic tokens, triggered by recency/frequency of keyword mentions) | "Lorebook" entries (triggered when keys appear in story text) | "World Info" (triggered when keywords appear in story text) | Conditional context: character details, location descriptions, item properties. Only injected when relevant |
| **Narrative History** | ~50% of dynamic tokens (most recent actions first, fills backwards) | Main story text (fills available context) | Story text (fills available context) | The actual story so far, as much as fits |
| **Style Directives** | "Author's Note" (inserted near bottom for maximum influence) | "Author's Note" (inserted ~3 paragraphs before generation point) | "Author's Note" (inserted near end, before new text) | Tone, genre, writing style — high influence due to proximity to generation |
| **Generation Point** | Last player action + Front Memory | Last story token | Last story token | Where the AI begins generating |

**Key Insight for DANTE TERMINAL:** The Author's Note / style directive pattern is critical. Placing tone instructions ("sardonic, atmospheric, fair" from BL-013) near the generation point — not at the top of the system prompt — will have far more influence on output style, especially with small models that struggle to maintain instructions from the top of context.

### 1.2 Specific Structural Elements Observed

**a) World State Block (AI Dungeon "Plot Essentials" / KoboldAI "Memory")**

A compact, always-present block containing the ground truth of the current game state. In AI Dungeon, this is always included regardless of context pressure. KoboldAI recommends budgeting ~200 tokens for Memory, structured as "a book's dust jacket summary."

For DANTE TERMINAL, this maps directly to the game state JSON from BL-021:
```
[WORLD STATE]
Location: The Sunken Archive - East Wing
Inventory: oil lamp, torn map fragment
Quest flags: east_wing_explored, ghost_encountered
Act: II (Escalation)
Turn: 12/25
```

**b) Character/NPC Memory (NovelAI Lorebook / AI Dungeon Story Cards)**

Both systems use keyword-triggered entries that inject NPC descriptions, relationships, and history only when those characters are mentioned in recent text. This is a token-conservation technique: a 50-entry world bible would consume the entire context if always present, but keyword triggering ensures only 2-3 relevant entries (~100-300 tokens) are active at any time.

NovelAI's Lorebook system is the most sophisticated:
- Entries have configurable insertion positions (top, bottom, or relative to keyword location)
- Entries have per-entry token budgets (recommended: 50 tokens minor, 100 tokens characters, 150 tokens max)
- Entries support cascading activation (one entry's text can trigger another entry's keywords)
- Four-level trim hierarchy: no trim → newline trim → sentence trim → token trim

**c) Tone/Style Instructions (Author's Note pattern)**

All three products place style directives near the generation point rather than in the system prompt. AI Dungeon recommends keeping Author's Note to "3 or 4 sentences" focused on genre, writing style, and tone. KoboldAI recommends under 50 tokens to avoid fragmenting recent narrative.

Example Author's Note for DANTE TERMINAL:
```
[Style: sardonic narrator, sensory-specific descriptions, 60-90 words max.
Respond with scene narration followed by exactly 3 action suggestions.
Acknowledge all player actions with consequences, never refuse.]
```

**d) Output Format Constraints**

The DEV Community prompt architecture article describes the most rigorous approach: enforcing four mandatory response sections:
- `[NARRATIVE]`: Story prose (unrestricted style)
- `[MECHANICS]`: Machine-readable tags (`HP_CHANGE`, `ITEM_USED`, `ENEMY_HP`)
- `[SUGGESTIONS]`: Player options with `roll:true/false` flags
- `[CHRONICLE]`: Campaign log entries for significant beats

The parser then maps mechanics tags to deterministic state transitions. This is directly relevant to DANTE TERMINAL's need to extract suggestions and update game state from AI responses.

### 1.3 The Intra Architecture: A Modern Reference

Intra (2025) inverts the typical pattern by making the *game engine* the "user" role rather than the player:
- **System role**: General rules
- **User role**: Game engine requests (action resolution, NPC responses)
- **Assistant role**: Historical event log

This separation of world simulation (formal game state) from narrative generation (LLM-powered) prevents "narrative necessity" hallucinations where the AI makes things true simply because the story demands it. Intra also uses **guided thinking** — a sequence of structured questions that force the model to commit to outcomes before narrating:

1. Is the action possible and player-initiated?
2. Is it trivially easy?
3. Success outcome?
4. Failure outcome?
5. Difficulty rating?
6. Use dice roll or narrative determination?

This technique is particularly valuable for small models that tend to generate plausible-sounding but logically inconsistent responses.

---

## 2. Context Window Management Strategies

### Strategy 1: Sliding Window with Hierarchical Summarization (AI Dungeon)

**How it works:** AI Dungeon's Memory System creates AI-generated summaries of every 6 past actions. These summaries are embedded (vector representations) and stored in a Memory Bank. When the story exceeds context capacity:

1. Recent history is included verbatim (most recent first, filling ~50% of dynamic token budget)
2. The Memory Bank retrieves relevant older memories ranked by embedding similarity to the current action (~25% of dynamic budget)
3. Story Cards (keyword-triggered lore) fill ~25% of dynamic budget
4. Required elements (system prompt, plot essentials, author's note) get priority allocation (up to 70% total budget)

**Token allocation formula:**
- Required elements: up to 70% of context
- Story Cards: ~25% of remaining 30%
- Memory Bank: ~25% of remaining 30%
- History: ~50% of remaining 30%

**Trade-offs:**
- *Pro:* Preserves long-term narrative coherence through semantic retrieval of relevant past events
- *Pro:* Automatic — no user intervention needed
- *Con:* Requires an embedding model in addition to the generative model (memory + compute cost)
- *Con:* Summarization can lose critical details (the specific item name, exact dialogue)
- *Con:* Embedding similarity may retrieve thematically related but plot-irrelevant memories

**Applicability to DANTE TERMINAL:** The full Memory Bank with embeddings is too heavy for our mobile constraint (requires a second model for embeddings). However, the *summarization* component is directly applicable: compressing old turns into a running "story so far" paragraph that replaces verbatim history. BL-012 already identified this need ("instead of dropping old messages, compress them into a running 'story so far' summary to preserve world state"). The 6-action summarization window maps well to our ~5-turn coherence window from BL-012's Phi-3 findings.

### Strategy 2: Keyword-Triggered Selective Injection (NovelAI Lorebook / KoboldAI World Info)

**How it works:** Instead of including all world information in every prompt, entries are stored in a database and only injected when their keywords appear in recent story text. This is fundamentally a token-conservation strategy.

**KoboldAI World Info implementation:**
- Entries activate when keywords appear in story text
- Inserted after Memory but before story text (moderate influence)
- Token budgets per entry: 50 (minor), 100 (characters), 150 (major) tokens
- Multiple entries can activate simultaneously, cascading via cross-referenced keywords

**NovelAI Lorebook implementation (more sophisticated):**
- Supports key-relative insertion (entry appears near where keyword was mentioned)
- Four-level trim hierarchy when context is tight
- Forced activation override for critical entries
- Per-entry token limits prevent any single entry from dominating context

**Trade-offs:**
- *Pro:* Massive token savings — a 50-entry world can exist with only 2-3 entries (~200 tokens) active at any time
- *Pro:* Information is fresh when it matters (injected right when relevant)
- *Con:* Keyword matching is brittle (synonyms, pronouns, and paraphrases may not trigger)
- *Con:* Requires upfront authoring of entries with good keyword sets
- *Con:* Can create jarring inconsistencies if a character re-enters after long absence

**Applicability to DANTE TERMINAL:** Highly applicable for our adventure themes. Each theme's NPCs, locations, and items can be defined as World Info entries triggered by keywords. With BL-013's game design specifying only 2-3 NPCs and 5-8 discoverable items per adventure, the entry count stays manageable. The keyword trigger approach naturally fits our state JSON — when `"location": "east_wing"` is in the state block, East Wing description entries activate.

### Strategy 3: Per-Turn State Serialization (Intra / DEV Community Architecture)

**How it works:** Rather than relying on conversation history as the source of truth, the entire game state is serialized and injected fresh into every prompt. The state-in-context is the authoritative record, not the model's memory of past turns.

**DEV Community D&D architecture implementation:**
- Combat state (initiative, distance, line of sight, cover) injected every turn
- Death save tracker and round counts maintained externally
- Previous turn's machine-readable combat trace included to prevent drift
- A keyword extractor scores player input and injects the top 3 most relevant rules from a structured database

**Trade-offs:**
- *Pro:* Eliminates hallucinated state — the model can't "remember" wrong HP or forget an item
- *Pro:* State can be validated/corrected by game engine between turns
- *Con:* Consumes fixed token budget every turn regardless of relevance
- *Con:* Requires a robust state schema and extraction pipeline

**Applicability to DANTE TERMINAL:** This is the recommended primary strategy. Our game state JSON (BL-021) should be injected at the top of every prompt as ground truth. Combined with Strategy 2 (keyword-triggered lore) for theme-specific details, this gives us reliable state without the memory overhead of Strategy 1's embeddings. The state JSON should be compact — BL-013's constraint table specifies it must be "tiny" due to the 1,500 MB iOS memory budget.

### Strategy Comparison Summary

| Strategy | Token Cost | Reliability | Complexity | Mobile Fit |
|----------|-----------|-------------|------------|------------|
| Sliding window + summarization | Medium (summary ~100-200 tokens) | Medium (summary may lose details) | Medium (needs summarization prompt) | Good — no extra model needed if same model summarizes |
| Keyword-triggered injection | Low (~100-300 tokens when active) | Medium (keyword matching is brittle) | Medium (requires authored entries) | Good — pure text matching, no ML overhead |
| Per-turn state serialization | Fixed (~150-300 tokens) | High (authoritative source of truth) | Low-Medium (needs state schema + extraction) | Best — deterministic, minimal overhead |

**Recommendation for DANTE TERMINAL:** Use Strategy 3 (per-turn state serialization) as the primary approach, with Strategy 1's summarization component (compress old turns into a "story so far" block, no embeddings) as secondary. Strategy 2 (keyword-triggered lore) for theme-specific NPC/location details if context budget allows. This matches BL-012's finding that the safe context zone is ~1,500 tokens.

---

## 3. Suggestion Generation Techniques

### 3.1 Inline Generation (Most Common)

**Pattern:** The system prompt instructs the model to include action suggestions as part of its response, typically in a specific format at the end.

**AI Dungeon approach:** Suggestions are generated as part of the `[SUGGESTIONS]` section of the response, with each suggestion flagged as requiring a roll or not. The parser extracts them from the response text.

**Intra approach:** Uses guided thinking to generate suggestions as part of the action resolution pipeline. The model proposes actions that are consistent with the current game state and available items.

**BL-012 finding:** Neither TinyLlama nor Phi-3-mini followed the `> 1. [action]` format despite system prompt instructions. This is the central challenge for small models.

### 3.2 Structured Output Enforcement via GBNF Grammar

**Pattern:** llama.cpp supports GBNF (GGML BNF) grammars that constrain the model's token generation to follow a defined format. This can force the model to produce valid structured output even when instruction-following is weak.

**Example GBNF grammar for DANTE TERMINAL suggestions:**
```gbnf
root ::= narrative "\n\n" suggestions
narrative ::= [^\n]+ ("\n" [^\n]+)*
suggestions ::= "> 1. " suggestion "\n> 2. " suggestion "\n> 3. " suggestion
suggestion ::= [A-Z] [a-zA-Z0-9 ,.'!?-]+
```

This grammar forces the model to generate narrative text followed by exactly 3 suggestions in the required format. The model is still free to generate any narrative content, but the structure is guaranteed.

**Trade-offs:**
- *Pro:* 100% reliable structured output — eliminates BL-012's "never outputs the format" problem
- *Pro:* Works with any model, even weak instruction followers
- *Con:* Can degrade narrative quality if grammar is too restrictive (model may contort phrasing to fit)
- *Con:* Requires careful grammar design to allow natural language within structure
- *Con:* Grammar evaluation adds ~5-10% overhead per token

**Applicability to DANTE TERMINAL:** Strongly recommended. GBNF grammar is already supported by llama.cpp (our chosen inference SDK from BL-008). This eliminates the suggestion format problem identified in BL-012 without requiring a separate model call or post-processing.

### 3.3 Two-Pass Generation

**Pattern:** Generate the narrative response first (unconstrained), then make a second, shorter inference call with the narrative as context to extract/generate suggestions.

**How it works:**
1. First pass: Generate narrative response (free-form, ~80-120 tokens)
2. Second pass: Short prompt like "Given the scene above, suggest 3 brief actions the player could take:" → generate 3 suggestions (~30-50 tokens)

**Trade-offs:**
- *Pro:* Narrative quality is uncompromised by format constraints
- *Pro:* Suggestions are contextually grounded in the just-generated narrative
- *Con:* Doubles latency (two inference calls per turn)
- *Con:* Second call may still not follow format without GBNF
- *Con:* On mobile with 25-40s turn target (BL-013), adding a second inference call may break pacing

**Applicability to DANTE TERMINAL:** Viable as a fallback if GBNF grammar degrades narrative quality, but the latency cost is concerning given BL-014's <=3s TTFT and BL-013's 25-40s turn target. A second pass of ~30 tokens at 4-8 tok/s adds 4-8 seconds — potentially acceptable but not ideal.

### 3.4 Post-Processing Extraction

**Pattern:** Let the model generate freely, then use regex/heuristic extraction to identify potential actions from the narrative text.

**How it works:** Parse the model's response for action-like phrases (imperative verbs, exploration cues, dialogue options) and format them as suggestions. Fall back to generic contextual suggestions if extraction fails.

**Trade-offs:**
- *Pro:* Zero inference overhead
- *Pro:* Works with any model output
- *Con:* Suggestions may feel generic or miss the model's actual intent
- *Con:* Regex extraction is brittle and model-dependent
- *Con:* Requires maintaining extraction heuristics as models change

**Applicability to DANTE TERMINAL:** Viable as a tertiary fallback but not recommended as primary. The suggestions would feel disconnected from the narrative.

### Recommendation

**Primary:** GBNF grammar-constrained generation to enforce narrative + 3 suggestions format. **Fallback:** Two-pass generation if grammar degrades narrative quality. **Emergency fallback:** Post-processing extraction with generic suggestions.

---

## 4. Small-Model Adaptation Techniques

### 4.1 Few-Shot Examples in System Prompt

**Pattern:** Include 1-2 complete example exchanges (player input → GM response with suggestions) in the system prompt to show the model exactly what output looks like.

**Why it works for small models:** Small models (<4B) have weaker instruction-following (confirmed by BL-012: TinyLlama scored 1/5 on instruction following). Few-shot examples compensate by showing the pattern rather than describing it. The model learns the output format from examples rather than parsing natural language instructions.

**Token cost:** Each example exchange costs ~150-200 tokens. With 2 examples, that's 300-400 tokens — a significant portion of the ~1,500 token safe zone (BL-012). Recommendation: 1 example maximum, kept under 150 tokens.

**Example for DANTE TERMINAL system prompt:**
```
[EXAMPLE]
Player: look around the room
GM: Dust motes drift through a shaft of grey light from a crack in the ceiling. The archive's east wing stretches before you — shelves of waterlogged books lean at drunken angles, and something metallic glints beneath a collapsed reading desk. The air tastes of copper and old paper. A corridor leads north, half-submerged.

> 1. Investigate the metallic glint under the desk
> 2. Wade north into the flooded corridor
> 3. Examine the waterlogged books on the nearest shelf
[/EXAMPLE]
```

### 4.2 Constrained Generation (GBNF Grammars)

As detailed in Section 3.2, GBNF grammars are particularly valuable for small models because they bypass weak instruction-following entirely. The model doesn't need to "understand" the format instruction — the grammar enforces it at the token level.

The SINE research project (2025) demonstrated this approach with open-weight LLMs generating interactive fiction in the Ink scripting language, achieving 68-86% success rates with grammar-guided decoding. However, the researchers noted that "grammar masking on top of reasoning prompts did not consistently improve outcomes" — suggesting that grammars work best for structural enforcement, not semantic guidance.

### 4.3 Genre-Specific Fine-Tunes

Several sub-4B models fine-tuned for interactive fiction and roleplay are available on HuggingFace:

| Model | Base | Params | Size (Q4_K_M) | Focus | Link |
|-------|------|--------|---------------|-------|------|
| **CreativeWriter-Llama3.2-3B** | Llama 3.2 3B | 3.2B | ~1.8 GB | Creative writing, trained on writing coach + creative writing datasets | [HuggingFace](https://huggingface.co/theprint/CreativeWriter-Llama3.2-3B-GGUF) |
| **Llama-3.2-3B-NEO-SI-FI** | Llama 3.2 3B | 3.2B | ~1.8 GB | Sci-fi narrative, increased prose vividness | [HuggingFace](https://huggingface.co/DavidAU/Llama-3.2-3B-Instruct-NEO-SI-FI-GGUF) |
| **Llama-3.2-1B-NEO-WEE-HORROR** | Llama 3.2 1B | 1.1B | ~0.6 GB | Horror genre, intense scene generation | [HuggingFace](https://huggingface.co/DavidAU/Llama-3.2-1B-Instruct-NEO-WEE-HORROR-GGUF) |
| **Gemma 3n E2B-it** | Gemma 3n | 6B (2B effective) | ~1.2 GB | General instruction following, multimodal, 32K context | [HuggingFace](https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF) |
| **Qwen 2.5 3B Instruct** | Qwen 2.5 | 3B | ~1.8 GB | Strong instruction following, 128K context, enhanced roleplay support | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF) |
| **Phi-3.5-mini-instruct** | Phi-3.5 | 3.8B | ~2.2 GB | Long context (128K), strong reasoning, good prose quality (confirmed by BL-012 turns 1-5) | [HuggingFace](https://huggingface.co/microsoft/Phi-3.5-mini-instruct) |

**Key observations:**
- Genre-specific fine-tunes (NEO-SI-FI, NEO-WEE-HORROR) produce more vivid, tonally consistent prose than base instruction-tuned models at the same parameter count
- Gemma 3n E2B is the most memory-efficient option (~1.2 GB effective via Per-Layer Embedding), matching BL-008's recommendation
- Qwen 2.5 3B is specifically noted for being "more resilient to diversity of system prompts, enhancing role-play implementation" — valuable for our multi-theme approach (BL-013's 4 themes)
- The RP-Ink series of Qwen fine-tunes (released Oct 2025) target "style-specific outputs in RPG-style storytelling" with improved multi-turn coherence

### 4.4 Aggressive Task Scoping

Research on small language models for game content (arxiv:2601.23206) demonstrated that a 1B model (Llama 3.2-1B) can achieve 92.5% success rates when:

1. **Each model handles a single, narrow task** rather than being a general-purpose narrator
2. **Training data is synthetic but high-quality** (teacher-student methodology with GPT-4o generating gold-standard outputs)
3. **Output is structurally constrained** (format enforced through training data, not runtime prompting)
4. **LoRA fine-tuning** adapts the base model with minimal parameter overhead

This suggests that if DANTE TERMINAL's GM prompt proves too complex for a single 3B model call, decomposing the turn into multiple narrow tasks (narrative generation, suggestion extraction, state update) — each with a fine-tuned LoRA adapter — could dramatically improve reliability. However, this adds latency from multiple inference calls and complexity from managing multiple adapters.

### 4.5 Response Length Control

BL-012 found that both tested models produced 300-500 token responses when 80-120 tokens were needed. Techniques for constraining response length on small models:

1. **`max_tokens` parameter:** Hard cap at 150-200 tokens. Simple and effective but may cut mid-sentence.
2. **Prompt instruction:** "Respond in 2-3 sentences, under 90 words." Unreliable with small models (BL-012 showed weak instruction following).
3. **Stop sequences:** Define custom stop sequences (e.g., `\n\n> 1.` to stop after suggestions). Works well with GBNF grammar.
4. **Few-shot calibration:** The example in the system prompt implicitly teaches response length. A 60-word example response sets the model's length expectation.

**Recommendation:** Combine `max_tokens=200` with a concise few-shot example (~80 words) and GBNF grammar that terminates after the third suggestion.

---

## Analysis: Mapping Patterns to DANTE TERMINAL

### What We Should Adopt

1. **Per-turn state serialization** (from Intra / DEV Community architecture) as the primary context management approach — inject game state JSON at the top of every prompt
2. **Author's Note pattern** (from all three products) — place tone/style directives near the generation point, not in the system prompt header
3. **GBNF grammar-constrained generation** — enforce narrative + 3 suggestions format at the token level, bypassing weak instruction following
4. **One few-shot example** in the system prompt — teach response length, format, and tone by showing rather than telling
5. **Keyword-triggered lore injection** — store NPC/location descriptions as World Info entries, injected only when relevant keywords appear in state or recent history

### What We Should Skip

1. **Embedding-based memory retrieval** (AI Dungeon Memory Bank) — too heavy for mobile, requires a second model
2. **Multi-model routing** (Intra's initial approach) — we have exactly one model on-device
3. **350-line system prompts** (DEV Community D&D architecture) — our ~1,500 token safe zone cannot accommodate this; DANTE TERMINAL needs a <200 token system prompt
4. **Cascading Lorebook entries** (NovelAI's advanced feature) — overkill for our 2-3 NPC, 5-8 item adventure scope

### Proposed DANTE TERMINAL Prompt Architecture

```
[SYSTEM PROMPT: ~150 tokens]
You are the Game Master of DANTE TERMINAL. Narrate interactive fiction.
Rules: (1) Respond in 2-3 atmospheric sentences, max 90 words.
(2) Use sensory details. (3) Always advance the story.
(4) End with exactly 3 action suggestions.
(5) Never refuse player actions — show consequences instead.

[EXAMPLE: ~120 tokens]
Player: examine the door
GM: The iron door is warm to the touch — wrong, for a room this deep underground. Rust flakes away under your fingers, revealing symbols etched into the metal. Something shifts behind it. Not heavy, not mechanical. Patient.

> 1. Try to force the door open
> 2. Study the etched symbols more closely
> 3. Press your ear against the door and listen

[WORLD STATE: ~100-150 tokens — injected every turn]
{location, inventory, quest_flags, act, turn, npc_present, active_effects}

[THEME OVERLAY: ~50-80 tokens — keyword-triggered]
{setting vocabulary, item types, NPC descriptions when relevant}

[STORY SUMMARY: ~100-200 tokens — compressed history]
Previously: {2-3 sentence summary of turns before the sliding window}

[RECENT HISTORY: ~400-600 tokens — last 2-3 verbatim exchanges]
Player: {action}
GM: {response}

[AUTHOR'S NOTE: ~30 tokens — near generation point]
[Style: sardonic narrator, sensory detail, atmospheric tension. Max 90 words.]

[PLAYER INPUT]
Player: {current action}
GM:
```

**Total budget:** ~950-1,300 tokens, well within the 1,500-token safe zone from BL-012.

---

## Recommendations

1. **Implement GBNF grammar for suggestion format immediately** when building BL-005. This is the single highest-impact technique for solving BL-012's "never outputs the format" problem without model changes.

2. **Use per-turn state serialization as primary context strategy.** Inject compact game state JSON every turn. Do not rely on the model to "remember" state from conversation history.

3. **Place style directives near the generation point** (Author's Note pattern), not at the top of the system prompt. This is especially critical for 3B models where early-context instructions fade.

4. **Budget exactly 1 few-shot example** in the system prompt (~120 tokens). This teaches format, length, and tone simultaneously. Two examples would consume too much of the 1,500-token budget.

5. **Evaluate Gemma 3n E2B and Qwen 2.5 3B** as primary model candidates alongside Phi-3.5-mini. Gemma 3n's ~1.2 GB effective footprint solves BL-014's iOS memory constraint, and Qwen 2.5 3B's roleplay-optimized system prompt handling is ideal for our multi-theme architecture.

6. **Consider genre-specific LoRA adapters** as a v2 enhancement. Rather than one model for all 4 themes, 4 small LoRA adapters (~50-100 MB each) could specialize tone and vocabulary per theme while sharing the base model weights. llama.cpp supports runtime LoRA loading (confirmed in BL-008).

7. **Implement sliding-window summarization** for the "story so far" block. Every 5-6 turns, compress the oldest verbatim exchanges into a 2-3 sentence summary. This matches AI Dungeon's 6-action memory window and BL-012's ~5-turn coherence window.

8. **Build a keyword-triggered lore system** for theme-specific content (NPC descriptions, location details, item properties). Keep entries under 100 tokens each and trigger on game state keywords (location name, NPC name, item name).

---

## Sources

### Products Analyzed
1. **AI Dungeon** — Memory System, Context Architecture, Author's Note, Plot Components
   - [What goes into the Context sent to the AI?](https://help.aidungeon.com/faq/what-goes-into-the-context-sent-to-the-ai)
   - [What is the Memory System?](https://help.aidungeon.com/faq/the-memory-system)
   - [What is Author's Note?](https://help.aidungeon.com/faq/what-is-the-authors-note)
   - [What are Plot Components?](https://help.aidungeon.com/faq/plot-components)

2. **NovelAI** — Lorebook, Context System, Memory
   - [NovelAI Lorebook Documentation](https://docs.novelai.net/en/text/lorebook/)
   - [NovelAI Context System](https://tapwavezodiac.github.io/novelaiUKB/Context.html)
   - [NovelAI Lorebook Guide](https://tapwavezodiac.github.io/novelaiUKB/Lorebook.html)

3. **KoboldAI** — Memory, Author's Note, World Info
   - [Memory, Author's Note and World Info Wiki](https://github.com/KoboldAI/KoboldAI-Client/wiki/Memory,-Author's-Note-and-World-Info)
   - [KoboldAI Client](https://github.com/KoboldAI/KoboldAI-Client)
   - [KoboldCpp World Info Discussion](https://github.com/LostRuins/koboldcpp/discussions/838)

4. **SillyTavern** — Context Templates, Character Cards, Advanced Formatting
   - [Context Template Docs](https://docs.sillytavern.app/usage/prompts/context-template/)
   - [Character Design Docs](https://docs.sillytavern.app/usage/core-concepts/characterdesign/)

5. **LitRPG Adventures** — AI RPG content generation
   - [LitRPG Adventures](https://www.litrpgadventures.com/)

### Architecture References
6. [Prompt Architecture for a Reliable AI Dungeon Master](https://dev.to/austin_amento_860aebb9f55/prompt-architecture-for-a-reliable-ai-dungeon-master-d99) — DEV Community (versioned system prompt, per-turn state injection, structured output sections)
7. [Intra: Design Notes on an LLM-driven Text Adventure](https://ianbicking.org/blog/2025/07/intra-llm-text-adventure) — Ian Bicking (game engine as user role, guided thinking, ground truth enforcement)
8. [Story2Game: Generating Almost Everything in an Interactive Fiction Game](https://arxiv.org/abs/2505.03547) — Dynamic action generation from game state

### Small Model Research
9. [High-quality generation of dynamic game content via small language models](https://arxiv.org/html/2601.23206) — Llama 3.2-1B LoRA fine-tuning for game content, 92.5% success with narrow task scoping
10. [Automated Generation and Evaluation of Interactive-Fiction Serious Games](https://www.mdpi.com/2076-3417/16/6/2932) — GBNF grammar-guided decoding for IF generation
11. [GBNF Grammar Documentation (llama.cpp)](https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md)

### Model Sources
12. [CreativeWriter-Llama3.2-3B-GGUF](https://huggingface.co/theprint/CreativeWriter-Llama3.2-3B-GGUF)
13. [Llama-3.2-3B-Instruct-NEO-SI-FI-GGUF](https://huggingface.co/DavidAU/Llama-3.2-3B-Instruct-NEO-SI-FI-GGUF)
14. [Llama-3.2-1B-Instruct-NEO-WEE-HORROR-GGUF](https://huggingface.co/DavidAU/Llama-3.2-1B-Instruct-NEO-WEE-HORROR-GGUF)
15. [Gemma 3n E2B-it](https://huggingface.co/google/gemma-3n-E2B-it) / [GGUF](https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF)
16. [Qwen 2.5 3B Instruct GGUF](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF)
17. [Fine-tuned Qwen models for storytelling](https://grokipedia.com/page/Fine-tuned_Qwen_models_for_storytelling)

### Cross-Referenced Project Artifacts
- BL-008: On-device LLM SDK maturity research (llama.cpp selected, GBNF grammar support confirmed)
- BL-012: CLI prototype findings (context collapse at ~2,500 tokens, suggestion format failure, 1,500-token safe zone)
- BL-013: Game design one-pager (60-90 word responses, 15-25 turns/session, sardonic tone, 3 suggestions per turn)
- BL-014: Target device specs and performance budget (1,500 MB iOS memory, >=4 tok/s decode, <=3s TTFT)
- BL-015: Flutter vs React Native comparison (Flutter selected, llama.cpp FFI path confirmed)
