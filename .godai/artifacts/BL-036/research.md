# Small Language Model Prompting Techniques for Interactive Fiction (1-3B Parameters)

> **BL-036** | Created: 2026-03-25 | Audience: founding team, prompt engineering for BL-005/BL-018
>
> Purpose: Provide evidence-based prompting guidelines so BL-005 (Game Master prompt) and BL-018 (genre template testing) build on proven small-model techniques rather than large-model intuitions applied blindly to constrained environments. This research fills the gap between BL-010's product-level prompt patterns (designed for GPT-4/Claude-class models) and the empirical realities of 1-3B parameter on-device inference.

---

## Summary

Small language models (1-3B parameters) behave fundamentally differently from large models in ways that directly impact interactive fiction generation: instruction following drops from ~84% (72B) to ~58-77% (3B) to ~28% (0.5B) on IFEval; persona consistency degrades measurably within 8 dialogue turns; and structured output compliance is near-zero without constrained decoding. However, targeted techniques -- few-shot examples (1-2 max), GBNF grammar-constrained generation, repeat-instruction anchoring near the generation point, and aggressive context budgeting under 1,500 tokens -- can compensate for these limitations. The key insight is that small models learn by *seeing patterns* (few-shot), not by *parsing instructions* (zero-shot), and that format compliance must be *enforced mechanically* (grammar) rather than *requested linguistically* (system prompt).

---

## 1. Small Model Behavior Profile: Large vs. Small Model Differences

### 1.1 Instruction Following Fidelity

The gap between large and small models in instruction following is steep and well-documented:

**IFEval Benchmark (Strict-Prompt) -- Instruction Following Evaluation:**

| Model | Parameters | IFEval Score | Source |
|-------|-----------|-------------|--------|
| Qwen2.5-72B-Instruct | 72B | 84.1 | Qwen technical report [1] |
| Qwen2.5-14B-Instruct | 14B | 81.0 | Qwen technical report [1] |
| Llama 3.2 3B Instruct | 3B | **77.4** | Meta eval / HuggingFace blog [2] |
| Gemma 2B IT | 2B | **61.9** | Llama 3.2 benchmark comparison [2] |
| Phi-3.5-mini-Instruct | 3.8B | **59.2** | Llama 3.2 benchmark comparison [2] |
| Qwen2.5-3B-Instruct | 3B | **58.2** | Qwen technical report [1] |
| Qwen2.5-1.5B-Instruct | 1.5B | 42.5 | Qwen technical report [1] |
| Qwen2.5-0.5B-Instruct | 0.5B | 27.9 | Qwen technical report [1] |

**Key observations for DANTE TERMINAL:**
- **Llama 3.2 3B is the outlier**: 77.4 IFEval is remarkably high for 3B -- matching Llama 3.1 8B performance. This is the single strongest instruction-following model at the <=3B scale.
- **Qwen 2.5 3B lags in IFEval** (58.2) despite being better at math/coding. For interactive fiction where instruction format compliance matters, Llama 3.2 3B is the stronger base.
- **The 1B to 3B jump is dramatic**: Qwen drops from 42.5 (1.5B) to 58.2 (3B) -- a 37% improvement. BL-012's finding that "1B models are NOT viable" is confirmed by benchmarks.
- **Nuanced instructions degrade further**: Research shows performance can drop by up to 61.8% on nuanced prompt variations (IFEval++), with small models suffering >80% drops on composed instructions [4].

**What this means for interactive fiction:** A 3B model can follow simple, direct instructions ("respond in 2-3 sentences, end with 3 suggestions") roughly 58-77% of the time -- but compound instructions ("respond in 2-3 sentences AND use sensory detail AND maintain sardonic tone AND end with exactly 3 suggestions AND advance the plot") will see compliance plummet. **Design for one critical instruction at a time; enforce the rest mechanically.**

### 1.2 Structured Output Compliance

Small models are dramatically worse at producing structured output through prompting alone:

**Schema Accuracy (Llama 3.2-1B, unconstrained prompting):**

| Dataset Complexity | Compliance Rate (LM-only) | With Constrained Decoding |
|-------------------|--------------------------|--------------------------|
| Simple (GlaiveAI) | 90% | 95-96% |
| Moderate (GitHub Easy) | 65% | 75-86% |
| Complex (GitHub Medium) | 38% | ~60% |
| High (Snowplow) | 46% | ~65% |

Source: "Generating Structured Outputs from Language Models: Benchmark and Studies" [3]

**Critical finding:** On complex structured output tasks, a 1B model achieves only 38% compliance through prompting alone -- meaning ~62% of responses will have broken format. Constrained decoding frameworks (including llama.cpp's GBNF grammar) improve this to 60-86% depending on complexity.

**BL-012 confirmation:** Both TinyLlama (1.1B) and Phi-3-mini (3.8B) achieved 0% compliance on the suggestion format (`> 1. [action]`) despite explicit system prompt instructions. This is consistent with the benchmark data -- structured output through prompting alone is unreliable at this scale.

**Supervised fine-tuning as alternative:** A fine-tuned 1B model achieves 88.9% schema accuracy and 81.7% content similarity [3] -- dramatically better than prompting. This suggests LoRA fine-tuning for structured output format is a viable future path if GBNF grammar proves insufficient.

### 1.3 Persona Maintenance Over Turns

Persona drift -- the gradual loss of character consistency during multi-turn conversation -- is a documented phenomenon that worsens with smaller models:

**Quantitative findings:**
- LLaMA2-chat-70B shows "significant persona drift within 8 rounds of dialogue" [5]
- After 8-12 dialogue turns, persona self-consistency metrics degrade by **more than 30%**, even with context intact [6]
- The transformer attention mechanism causes "attention decay over long exchanges" -- the model's behavior is influenced most strongly by the **most recent user message** rather than the system prompt [9]
- Persona fidelity degrades especially in goal-oriented conversations where the model must sustain both persona AND instruction following simultaneously

**The "Lost in the Middle" effect amplifies this:**
- Information placed in the middle of context receives the least attention -- a U-shaped performance curve with primacy bias (beginning) and recency bias (end) [7]
- For a 1,500-token context, the "dead zone" is roughly tokens 400-1,100 -- exactly where narrative history sits in our proposed prompt architecture
- GPT-3.5's performance drops >20% for information placed in the middle of 20+ document contexts [7]

**What this means for interactive fiction:** The GM's sardonic tone, world-building style, and narrative voice will drift toward generic assistant behavior within 6-10 turns unless actively reinforced. Smaller models will drift faster because:
1. Weaker attention to distant system prompt instructions
2. Lower instruction-following baseline means drift starts from a lower fidelity point
3. The "lost in the middle" effect buries the persona definition under growing narrative history

**Mitigation data:**
- **System prompt repetition** (re-injecting persona instructions periodically) is effective but "consumes a substantial portion of the context window" [5]
- **Split-softmax** (amplifying attention to system prompt tokens) reduces drift but is not available in llama.cpp
- The Author's Note pattern (BL-010) -- placing style directives near the generation point -- directly exploits recency bias to counteract persona drift

### 1.4 Creative Narrative Generation Quality

**Performance scaling for creativity:**
- Creativity scales at approximately N^0.45 with model size -- the steepest scaling exponent among measured capabilities [17]
- This means the quality gap between 1B and 3B for creative writing is **proportionally larger** than for factual tasks
- Small open-source models (1-3B) score 56-60% on creative writing benchmarks where frontier models score ~70% [LitBench]

**MMLU scores for reference (general knowledge, correlates with creative world-building):**

| Model | Parameters | MMLU (5-shot) |
|-------|-----------|--------------|
| Phi-4-mini | 3.8B | 67.3 |
| Llama 3.2 3B | 3B | 63.4 |
| Gemma 3 4B IT | 4B | 59.6 |
| Gemma 2B IT | 2B | 57.8 |

**Specific model observations:**
- BL-012 empirically confirmed: Phi-3-mini (3.8B) produces "genuinely immersive, atmospheric prose with vivid imagery" for turns 1-5, scoring 4/5 on narrative quality
- Genre-specific fine-tunes (DavidAU's NEO series) produce more vivid, tonally consistent prose than base instruction-tuned models at the same parameter count (BL-010 finding)
- Gemma 3 models are noted for strong narrative coherence and immersive world-building, though most data is for the 27B variant [Google Developers Blog]

---

## 2. Prompting Technique Effectiveness at Small Scale

### Overview Table

| # | Technique | Expected Effectiveness (1-3B) | Evidence Basis | Token Cost | Priority for DANTE |
|---|-----------|-------------------------------|---------------|------------|-------------------|
| 1 | Few-shot examples | **Effective** | Strong | 120-200 per example | P0 -- Critical |
| 2 | GBNF constrained decoding | **Effective** | Strong | ~0 (CPU overhead only) | P0 -- Critical |
| 3 | Repeat-instruction anchoring | **Effective** | Moderate | 30-50 per anchor | P0 -- Critical |
| 4 | Role-play framing | **Effective** (with caveats) | Moderate | 20-40 tokens | P1 -- Important |
| 5 | XML/tag-structured prompting | **Degraded** | Moderate | 10-30 tokens overhead | P1 -- Important |
| 6 | Negative examples | **Ineffective** | Strong | Wastes tokens | P3 -- Avoid |
| 7 | Chain-of-thought | **Degraded** | Moderate | 50-100+ tokens | P2 -- Situational |
| 8 | JSON-structured output prompting | **Degraded** | Strong | 50-100 tokens | P2 -- Only with grammar |

### 2.1 Few-Shot Examples -- EFFECTIVE

**What it is:** Including 1-2 complete input->output examples in the prompt to demonstrate the expected format, length, and tone.

**Why it works at small scale:** Small models have weak instruction-following (Section 1.1) but retain strong pattern-matching from pre-training. Few-shot examples bypass the instruction-parsing bottleneck by showing the pattern directly. The model learns "generate output that looks like this" rather than parsing "generate 2-3 sentences of atmospheric prose ending with exactly 3 action suggestions."

**Evidence:**
- "The first few examples improve accuracy sharply, with additional examples yielding smaller boosts and plateauing by 4-5 examples" [Brown et al., NeurIPS 2020]
- "2 strong examples outperform 6 mediocre ones every time" -- quality over quantity [15]
- For small models, the diminishing returns are even more pronounced: "beyond 5 examples, the model gets confused by variation rather than guided by it" [phrasly.ai]
- BL-010 already recommended 1 example maximum (~120-150 tokens) due to the 1,500-token safe zone constraint

**Optimal configuration for DANTE TERMINAL:**
- **1 example** (not 2) -- saves ~150 tokens while still establishing format and tone
- Example should demonstrate: exact response length (60-90 words), suggestion format (> 1. / > 2. / > 3.), sardonic tone, sensory detail
- The example implicitly teaches all constraints that explicit instructions would fail to enforce
- Place example immediately after system instructions, before any dynamic content

**Token cost:** ~120-150 tokens for one well-crafted example

**Rating: EFFECTIVE** -- Single most important technique for small models. Non-negotiable for BL-005.

### 2.2 GBNF Constrained Decoding -- EFFECTIVE

**What it is:** Using llama.cpp's GBNF grammar system to mechanically constrain which token sequences the model can produce, enforcing structural format at the decoding level.

**Why it works at small scale:** Bypasses instruction following entirely -- the model doesn't need to "understand" the format instruction because the grammar prevents invalid token sequences. "Smaller models are more liable to produce non-valid output, meaning [grammar-constrained decoding] is especially valuable for researchers working in memory-constrained environments" [11].

**Evidence:**
- Constrained decoding achieves 95-96% compliance where unconstrained prompting achieves 90% on simple tasks, and the gap widens dramatically on complex tasks (86% vs 65%) [3]
- "GBNF is a guardrail that solves the 'will this even assemble?' problem completely, eliminating an entire class of errors upfront" [12]
- llama.cpp token mask computation averages 50us per token with p99 at 0.5ms -- negligible overhead [10]
- The SINE interactive fiction research project achieved 68-86% success rates using grammar-guided decoding for generating IF content in the Ink scripting language [MDPI Applied Sciences 2025]
- BL-010 already confirmed this as the primary recommendation for suggestion format enforcement

**Proposed GBNF grammar for DANTE TERMINAL:**
```gbnf
root ::= narrative "\n\n" suggestions
narrative ::= sentence (" " sentence)* ("\n" sentence (" " sentence)*)*
sentence ::= [A-Z] [a-zA-Z0-9 ,;:'"!?.\-\u2014\u2019()]+ "."
suggestions ::= "> 1. " suggestion "\n> 2. " suggestion "\n> 3. " suggestion "\n"
suggestion ::= [A-Z] [a-zA-Z0-9 ,.'!?\- ]+
```

**Caveats:**
- Overly restrictive grammars can "degrade narrative quality" by contorting phrasing to fit constraints [BL-010, Section 3.2]
- The narrative portion should be as unconstrained as possible -- only enforce the suggestion structure
- "Grammar masking on top of reasoning prompts did not consistently improve outcomes" -- grammars work best for structural enforcement, not semantic guidance [MDPI 2025]
- Performance gotcha: avoid `x?` repetition patterns; use `x{0,N}` instead [llama.cpp docs]

**Token cost:** Zero additional prompt tokens. CPU overhead ~5-10% per token during decoding.

**Rating: EFFECTIVE** -- The definitive solution to BL-012's "never outputs the format" problem. Non-negotiable for BL-005.

### 2.3 Repeat-Instruction Anchoring -- EFFECTIVE

**What it is:** Re-injecting critical instructions (tone, format, length) near the generation point rather than relying solely on the system prompt at the top of context.

**Why it works at small scale:** Exploits the well-documented recency bias in transformer attention -- tokens near the generation point receive disproportionate attention weight. "The relative importance of the system prompt with respect to the context decreases as the context length increases" [8]. This is the same principle as the Author's Note pattern (BL-010, Section 1.2).

**Evidence:**
- "Repeating or echoing critical guidance (especially at the tail) helps the model stay on track" -- Positional Prompting research [16]
- "Early and late tokens receive disproportionate influence in attention scores" [16]
- System prompt repetition is one of the two most effective persona drift mitigations, "excelling in regions with a larger number of turns" [5]
- All major IF products (AI Dungeon, NovelAI, KoboldAI) independently converged on this pattern via the Author's Note -- placing style directives 2-3 paragraphs before the generation point [BL-010]

**Recommended implementation for DANTE TERMINAL:**
```
[... narrative history ...]

[Style: sardonic narrator, sensory detail, max 90 words. Exactly 3 suggestions.]

Player: {current action}
GM:
```

This 15-20 token anchor near the generation point reinforces the three most critical constraints: tone, length, and suggestion count.

**Token cost:** 15-30 tokens per turn (the anchor note). Over a 15-turn session, this costs 225-450 tokens total -- but prevents the much costlier failure of losing persona coherence.

**Rating: EFFECTIVE** -- Essential for maintaining persona and format compliance beyond turn 5. Directly addresses the persona drift documented in Section 1.3.

### 2.4 Role-Play Framing -- EFFECTIVE (with caveats)

**What it is:** Framing the model's task as a character role ("You are the Game Master of DANTE TERMINAL") rather than a generic instruction ("Generate interactive fiction responses").

**Why it works at small scale:** Role-play framing activates role-specific patterns from the model's training data (RP datasets, character.ai-style interactions, SillyTavern conversations). At the 3B scale, models have seen substantial role-play training data -- Qwen 2.5 specifically notes "enhanced role-play implementation and condition-setting for chatbots" [1].

**Evidence:**
- "Prompts that include role instructions help the model anchor its response" [codeconductor.ai]
- BL-012 confirmed: Phi-3 "stays in character as a narrator" while TinyLlama "generates both player and GM dialogue, breaking immersion entirely" -- the 3B+ threshold enables basic role adherence
- Qwen 2.5 is specifically noted for being "more resilient to diversity of system prompts, enhancing role-play implementation" [1]

**Caveats:**
- "Certain persona prompts reduce reliable@10 by up to 8.2%" [4] -- the specific wording matters. Overly elaborate persona descriptions can hurt instruction following.
- Keep the role assignment concise: "You are the Game Master" (6 tokens) not "You are a sardonic, world-weary Game Master who has seen countless adventurers fail..." (25+ tokens). The elaboration goes in the Author's Note anchor, not the role definition.

**Token cost:** 6-15 tokens for the role assignment.

**Rating: EFFECTIVE** -- Basic role-play framing works at 3B scale. Keep it concise; elaborate personality goes in the Author's Note anchor.

### 2.5 XML/Tag-Structured Prompting -- DEGRADED

**What it is:** Using XML-like tags (`<instructions>`, `<context>`, `<output>`) to delimit sections of the prompt.

**Why it's degraded at small scale:** XML tag understanding requires the model to have learned tag semantics from training data. Large models (Claude, GPT-4) are explicitly trained on tagged prompts; small open-weight models have less exposure.

**Evidence:**
- Claude and GPT-4 show clear improvements from XML structuring; smaller models show inconsistent results [arxiv:2509.08182]
- Community practice: SillyTavern/KoboldAI ecosystems use minimal tagging (`[SYSTEM]`, `[EXAMPLE]`) rather than full XML for local models
- BL-010's proposed prompt uses simple bracket tags (`[WORLD STATE]`, `[STYLE]`) not XML -- this is the right level of structure for 3B models

**Recommendation:** Use simple bracket/label tags (`[WORLD STATE]`, `[EXAMPLE]`, `[Style:]`) as section delimiters. Avoid nested XML (`<instructions><format><suggestions>...</suggestions></format></instructions>`) which wastes tokens and may confuse small models.

**Token cost:** 5-10 tokens per section tag (brackets) vs. 15-30 tokens (full XML with opening/closing tags).

**Rating: DEGRADED** -- Simple label tags work; full XML structure is wasted effort at 1-3B scale.

### 2.6 Negative Examples ("Don't do this") -- INEFFECTIVE

**What it is:** Including examples of unwanted behavior or explicit "do not" instructions to prevent specific failure modes.

**Why it's ineffective at small scale:** Language models process negative instructions by first activating the concept being negated -- the "Pink Elephant Problem." "Instructions like 'don't uppercase names' frequently fail. Instead, positively phrased instructions like 'always lowercase names' consistently deliver better results" [14]. This effect is amplified in small models where instruction parsing is already weak (Section 1.1).

**Evidence:**
- "Token generation inherently leans toward positive selection -- choosing what token comes next, rather than explicitly avoiding certain tokens" [14]
- "Language models like GPT-3 and GPT-Neo consistently struggle with negation across multiple benchmarks" [14] -- and these are larger models than our targets
- "The Ironic Process Theory suggests that trying to suppress a specific thought makes it more likely to surface" -- telling a 3B model "Don't generate dialogue for the player" risks activating exactly that behavior [13]
- Alignment research confirms: "Existing alignment methods primarily focus on positive examples while overlooking the importance of negative responses" [NEAT, OpenReview]

**What to do instead:** Reframe every "don't" as a "do":
- ~~"Don't generate player dialogue"~~ -> "Narrate only the GM's response"
- ~~"Don't write more than 90 words"~~ -> "Respond in 2-3 sentences, under 90 words"
- ~~"Don't forget the suggestions"~~ -> (use GBNF grammar -- mechanical enforcement)
- ~~"Don't break character"~~ -> (use repeat-instruction anchoring)

**Token cost:** Negative examples waste tokens and risk activating the unwanted behavior. Net negative value.

**Rating: INEFFECTIVE** -- Actively harmful at small scale. Always reframe as positive instructions.

### 2.7 Chain-of-Thought (CoT) -- DEGRADED

**What it is:** Asking the model to "think step by step" or show its reasoning process before generating the final output.

**Why it's degraded at small scale:** CoT requires the model to maintain coherent multi-step reasoning, which degrades rapidly below 7B parameters. The tokens spent on reasoning are also tokens NOT spent on narrative quality -- a costly trade-off in a 1,500-token budget.

**Evidence:**
- Reasoning capability scales at N^0.4 [17] -- meaning a 3B model has roughly (3/70)^0.4 ~ 20% of a 70B model's reasoning capability
- GSM8K (math reasoning): Llama 3.2 3B scores 77.7% vs. Llama 3.1 70B at ~95% -- a meaningful gap for structured reasoning
- Intra's "guided thinking" pattern (BL-010, Section 1.3) uses structured questions to force step-by-step outcomes -- this works better than free-form CoT because it constrains the reasoning format

**Situational use:** CoT is worth the token cost ONLY for complex action resolution where the narrative consequence isn't obvious (e.g., "I throw the lamp at the bookshelf" -> needs reasoning about fire, damage, inventory change). For standard exploration/dialogue turns, CoT wastes 50-100 tokens that should go to narrative quality.

**Rating: DEGRADED** -- Skip for standard turns. Consider Intra-style guided questions for complex action resolution only.

### 2.8 JSON-Structured Output Prompting -- DEGRADED (without grammar)

**What it is:** Asking the model to produce output in JSON format through prompt instructions alone (without constrained decoding).

**Why it's degraded at small scale:** "Small open-weight models like Llama-3.2-1B, 3B, and Mistral-7B-v0.2 achieve near-zero schema accuracy and content similarity across most datasets through direct prompting" [3]. JSON requires precise syntax -- a single missing quote, comma, or brace breaks the output.

**Evidence:**
- Llama 3.2-1B unconstrained: 38-90% compliance depending on complexity (Section 1.2)
- JSON parseability is the highest among formats (vs. YAML, XML) when it works, but failure rate is also high without enforcement [3]

**Recommendation:** If JSON output is needed (e.g., for game state extraction), ALWAYS pair with GBNF grammar or JSON schema constraint. Never rely on prompt instructions alone for JSON at 1-3B scale.

**Rating: DEGRADED** -- Use GBNF grammar for any structured output requirement. Prompting alone is insufficient.

---

## 3. Interactive Fiction-Specific Recommendations

### 3.1 Recommended System Prompt Structure

Based on the research above, here is the optimized prompt architecture for DANTE TERMINAL at 1-3B parameter scale:

```
[SYSTEM PROMPT -- ~80 tokens, lean and directive]
You are the Game Master of DANTE TERMINAL.
Narrate atmospheric scenes in 2-3 sentences (under 90 words).
Use vivid sensory detail. Always advance the story.
End with exactly 3 action suggestions the player can take.

[FEW-SHOT EXAMPLE -- ~130 tokens, demonstrates everything]
Player: look around the room
GM: Dust motes drift through a shaft of grey light from a crack in the
ceiling. Rust-eaten shelves lean at drunken angles, and something metallic
glints beneath a collapsed desk. The air tastes of copper and old paper.

> 1. Investigate the metallic glint under the desk
> 2. Examine the waterlogged books on the nearest shelf
> 3. Search for another way deeper into the archive

[WORLD STATE -- ~100-150 tokens, injected every turn]
Location: The Sunken Archive - East Wing
Inventory: oil lamp, torn map fragment
Flags: east_wing_explored, ghost_encountered
Act: II | Turn: 12/25

[THEME OVERLAY -- ~50-80 tokens, keyword-triggered]
{Setting-specific vocabulary, active NPC description if present}

[STORY SUMMARY -- ~100-200 tokens, compressed old turns]
Previously: {2-3 sentence summary of events before the sliding window}

[RECENT HISTORY -- ~400-600 tokens, last 2-3 verbatim exchanges]
Player: {previous action}
GM: {previous response with suggestions}

[ANCHOR NOTE -- ~20 tokens, near generation point]
[Style: sardonic narrator, sensory detail, max 90 words.]

Player: {current action}
GM:
```

**Total token budget: ~880-1,260 tokens** -- well within the 1,500-token safe zone from BL-012.

### 3.2 Recommended System Prompt Token Count

| Section | Token Count | Fixed/Dynamic | Notes |
|---------|------------|---------------|-------|
| System prompt | 70-90 | Fixed | 5-6 concise directive sentences |
| Few-shot example | 120-140 | Fixed | 1 example only; quality over quantity |
| World state | 80-150 | Dynamic | Grows with inventory/flags; cap at 150 |
| Theme overlay | 0-80 | Dynamic | Only when keyword-triggered |
| Story summary | 80-200 | Dynamic | Grows as game progresses; compress aggressively |
| Recent history | 300-600 | Dynamic | Last 2-3 exchanges; trim oldest first |
| Anchor note | 15-25 | Fixed | Style reinforcement near generation point |
| **Total** | **665-1,285** | -- | **Target: <=1,200 to leave buffer** |

**Critical constraint:** The system prompt (fixed instructions + example) should not exceed **230 tokens total**. Every token spent on instructions is one fewer token for narrative history and world context. At 1-3B scale, shorter system prompts correlate with better instruction adherence because:
1. The model has less to parse and prioritize
2. More budget remains for the few-shot example (which is more effective than instructions)
3. The "lost in the middle" effect is less severe with shorter total context

### 3.3 Suggestion Generation Approach

**Primary: GBNF grammar-constrained inline generation**

Generate narrative + suggestions in a single inference call, with the grammar enforcing exactly 3 suggestions after the narrative block. This is the only approach that guarantees 100% format compliance at 1-3B scale.

**Why not separate calls:**
- BL-014's latency budget: <=3.0s TTFT, >=4 tok/s decode. A second inference call adds 2-8 seconds.
- BL-013's pacing: 25-40s per turn. With a single call at ~4-8 tok/s generating ~100-150 tokens, that's 12-37 seconds -- acceptable. A second call pushes this toward or beyond the upper bound.
- Single-call with grammar is both faster and more reliable than two-pass.

**Fallback: Post-processing extraction + generic suggestions**

If GBNF grammar degrades narrative quality (Section 2.2 caveat), fall back to:
1. Generate narrative unconstrained
2. Use regex to extract any suggestion-like phrases
3. If extraction fails, generate 3 contextual suggestions from the world state (e.g., "Explore further north", "Examine your surroundings", "Check your inventory")

### 3.4 Context Format That Minimizes Instruction Drift

The research points to three structural principles:

**Principle 1: Bookend critical instructions** -- Place the role assignment and core rules at the TOP (primacy) and the style anchor at the BOTTOM (recency). The middle is for dynamic content that can tolerate some attention decay.

**Principle 2: Use the few-shot example as the primary instructor** -- The example teaches format, length, tone, and suggestion structure simultaneously. The system prompt text is a secondary reinforcement, not the primary teaching mechanism.

**Principle 3: Keep total context under 1,200 tokens** -- BL-012 showed catastrophic collapse at ~2,500 tokens and degradation starting around 1,500. Keeping a buffer of 300+ tokens below the safe zone ensures quality doesn't degrade as the game progresses.

---

## 4. Risk Mitigations: Failure Modes and Prompt-Level Countermeasures

### 4.1 Character Name Amnesia

**Failure mode:** The model forgets NPC names, player inventory items, or location names introduced more than 3-4 turns ago.

**Root cause:** Information in narrative history falls into the "lost in the middle" attention dead zone as more turns accumulate. Small models have weaker attention across long contexts.

**Countermeasures:**
1. **World state injection (P0):** Include all active NPC names, inventory, and current location in the `[WORLD STATE]` block at the top of every prompt. The model reads this fresh each turn -- it doesn't need to "remember" from history.
2. **Story summary with names (P1):** When compressing old turns into the summary, explicitly preserve proper nouns: "Previously: You met **Aldric the Keeper** in the West Hall and received the **silver key**."
3. **Keyword-triggered lore (P2):** When an NPC name appears in the world state, inject their 50-100 token description (BL-010, Strategy 2).

**Expected effectiveness:** High. Per-turn state serialization (BL-010 Strategy 3) eliminates reliance on the model's memory entirely. This is a solved problem if implemented correctly.

### 4.2 Tone Drift (Sardonic -> Generic Assistant)

**Failure mode:** The GM's sardonic, atmospheric narrative voice gradually shifts toward bland, helpful assistant-style responses ("That's a great idea! Let me describe what you see...").

**Root cause:** Small models are heavily RLHF'd toward helpful-assistant behavior. Without reinforcement, the default "helpful AI" persona overwhelms the game master persona within 6-10 turns (Section 1.3).

**Countermeasures:**
1. **Anchor note near generation point (P0):** The `[Style: sardonic narrator, sensory detail, max 90 words.]` note placed 1-2 lines before `GM:` exploits recency bias to maintain tone. This is the single most impactful mitigation.
2. **Few-shot example sets the tone baseline (P0):** The example response should be unmistakably sardonic/atmospheric -- the model pattern-matches this more reliably than it follows tone instructions.
3. **Role framing (P1):** "You are the Game Master" activates RP training data rather than assistant training data.
4. **Avoid trigger phrases (P1):** Don't include helper-assistant language anywhere in the prompt ("help the player," "assist the user"). Use game-master language ("narrate," "describe," "present options").
5. **Genre-specific LoRA (P2, future):** A LoRA fine-tuned on atmospheric fiction would override the assistant baseline -- but this is a v2 enhancement.

**Expected effectiveness:** Moderate. The anchor note + few-shot example combination should maintain tone for 10-15 turns in most cases. Beyond 15 turns, some drift is likely unavoidable at 3B scale without fine-tuning.

### 4.3 Suggestion Count Non-Compliance

**Failure mode:** The model generates 0, 1, 2, 4, or 5 suggestions instead of exactly 3.

**Root cause:** Small models cannot reliably count or follow numeric constraints through prompting alone. BL-012: both tested models produced 0 suggestions despite explicit "exactly 3" instructions.

**Countermeasures:**
1. **GBNF grammar (P0):** The grammar mechanically enforces exactly 3 suggestions. This is a 100% reliable solution -- the model literally cannot generate any other count.
2. **Few-shot example (P0, backup):** The example shows exactly 3 suggestions, establishing the pattern even without grammar.
3. **max_tokens cap (P1):** Set max_tokens to 200 to prevent runaway generation that might produce extra suggestions before the grammar terminates.

**Expected effectiveness:** With GBNF grammar, this is fully solved (100% compliance). Without grammar, expect ~60-70% compliance with few-shot + instruction, based on benchmark data.

### 4.4 Response Length Inflation

**Failure mode:** The model generates 300-500 token responses when 60-90 words (~80-120 tokens) are needed for mobile UI.

**Root cause:** Small instruction-tuned models default to verbose responses. BL-012 confirmed: "Both models produce 300-500 token responses. Mobile UI needs 100-150 tokens max."

**Countermeasures:**
1. **max_tokens parameter (P0):** Hard cap at 180-200 tokens. Simple, reliable, but may cut mid-sentence.
2. **Few-shot example length (P0):** A 60-80 word example implicitly calibrates the model's response length. "Few-shot calibration: The example in the system prompt implicitly teaches response length" (BL-010).
3. **GBNF grammar termination (P1):** The grammar's `suggestions` rule naturally creates an endpoint -- after the 3rd suggestion, generation terminates.
4. **Anchor note word count (P1):** "max 90 words" in the anchor note provides a secondary length constraint.

**Expected effectiveness:** High. The combination of max_tokens + few-shot calibration + grammar termination provides triple redundancy.

### 4.5 Context Window Overflow

**Failure mode:** As the game progresses, accumulated history pushes total context beyond the safe zone, causing quality degradation or catastrophic collapse (BL-012 turn 6+).

**Root cause:** Without active context management, each turn adds ~100-300 tokens (player input + GM response), exhausting the budget in 5-8 turns.

**Countermeasures:**
1. **Aggressive context windowing (P0):** Keep only the last 2-3 verbatim exchanges (~400-600 tokens). Older exchanges are compressed into the story summary.
2. **Sliding-window summarization (P0):** Every 3-5 turns, compress the oldest verbatim exchange into 1-2 sentences in the story summary. Cap the summary at 200 tokens.
3. **Token counting before inference (P0):** Use the model's tokenizer to count actual prompt tokens before each inference call. If total exceeds 1,200 tokens, compress more aggressively.
4. **Theme overlay budget cap (P1):** Keyword-triggered lore has a hard 80-token cap. If multiple entries trigger, priority-rank and truncate.

**Expected effectiveness:** High if implemented correctly. The 1,200-token target budget (Section 3.2) provides a 300-token buffer below the 1,500-token safe zone.

### 4.6 Hallucinated Inventory/World State

**Failure mode:** The model references items the player doesn't have, mentions NPCs that don't exist, or describes locations inconsistently with established lore.

**Root cause:** Generative models will produce plausible-sounding content regardless of actual game state, especially when the context is ambiguous or the state information has been summarized away.

**Countermeasures:**
1. **Per-turn state injection (P0):** The `[WORLD STATE]` block is the authoritative source of truth. The model sees current inventory, location, and flags every turn.
2. **State validation post-generation (P1):** After generation, programmatically check the response for references to items/NPCs not in the state. Flag or regenerate if hallucinated content is detected.
3. **Positive-only inventory cues (P1):** List what the player HAS, not what they don't have. "Inventory: lamp, map" -- the model will draw from this list. Don't say "You don't have a sword" (Section 2.6 -- negative instructions are ineffective).

**Expected effectiveness:** Moderate-high. State injection prevents most hallucinations, but creative models may still introduce new elements not in the state. Post-generation validation catches the remainder.

---

## Sources

### Published Benchmarks and Research Papers
1. [Qwen2.5-LLM Technical Report](https://qwenlm.github.io/blog/qwen2.5-llm/) -- IFEval strict-prompt scores for Qwen 2.5 family (0.5B through 72B)
2. [Llama 3.2 Benchmark Insights](https://medium.com/towards-agi/llama-3-2-benchmark-insights-and-revolutionizing-edge-ai-and-vision-88542fe3dc0d) -- IFEval 77.4 for Llama 3.2 3B, comparison with Gemma 2B and Phi-3.5-mini
3. [Generating Structured Outputs from Language Models: Benchmark and Studies](https://arxiv.org/html/2501.10868v1) -- Llama 3.2-1B structured output compliance rates across datasets
4. [Revisiting the Reliability of Language Models in Instruction-Following](https://arxiv.org/html/2512.14754v1) -- IFEval++ showing up to 61.8% degradation on nuanced instructions
5. [Measuring and Controlling Persona Drift in Language Model Dialogs](https://arxiv.org/html/2402.10962v1) -- Persona drift within 8 rounds, mitigation techniques
6. [A Taxonomy of Persona Collapse in Large Language Models](https://huggingface.co/blog/unmodeled-tyler/persona-collapse-in-llms) -- 30%+ consistency degradation after 8-12 turns
7. [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172) -- U-shaped attention curve, primacy/recency bias (Liu et al., TACL 2024)
8. [LLM Reinforcement in Context](https://arxiv.org/html/2511.12782) -- System prompt efficacy decay with context length
9. [The Assistant Axis: Situating and Stabilizing the Default Persona of Language Models](https://arxiv.org/html/2601.10387v1) -- Model behavior influenced most by recent messages
10. [Lost in Space: Optimizing Tokens for Grammar-Constrained Decoding](https://arxiv.org/html/2502.14969v1) -- GBNF token mask computation overhead benchmarks

### Practitioner Sources and Community Findings
11. [A Guide to Structured Outputs Using Constrained Decoding](https://www.aidancooper.co.uk/constrained-decoding/) -- Constrained decoding especially valuable for small models
12. [Teaching an LLM to Write Assembly: GBNF-Constrained Generation](https://www.jamesdrandall.com/posts/gbnf-constrained-generation/) -- GBNF as a guardrail eliminating format errors
13. [The Pink Elephant Problem: Why "Don't Do That" Fails with LLMs](https://eval.16x.engineer/blog/the-pink-elephant-negative-instructions-llms-effectiveness-analysis) -- Negative instruction failure mechanism
14. [Why Positive Prompts Outperform Negative Ones with LLMs](https://gadlet.com/posts/negative-prompting/) -- Positive vs. negative instruction effectiveness data
15. [Token Efficiency Traps: Hidden Costs of Few-Shot Prompting](https://medium.com/@johnmunn/token-efficiency-traps-the-hidden-costs-of-zero-shot-vs-few-shot-prompting-8fdc7f2e3d29) -- Diminishing returns after 2-3 examples
16. [Positional Prompting / Context Framing Strategy](https://prompton.wordpress.com/2025/04/17/positional-prompting-context-framing-strategy/) -- Repeat-instruction anchoring effectiveness
17. [AI Model Size vs Performance 2026](https://localaimaster.com/blog/ai-model-size-vs-performance-analysis-2025) -- Capability scaling exponents by task type
18. [Small Language Model Leaderboard](https://awesomeagents.ai/leaderboards/small-language-model-leaderboard/) -- Cross-model benchmark comparison for sub-10B models

### Cross-Referenced Project Artifacts
- BL-008: On-device LLM SDK maturity research (llama.cpp GBNF grammar support confirmed)
- BL-010: AI Game Master prompt patterns from existing IF products (Author's Note, per-turn state, GBNF recommendation)
- BL-012: CLI prototype findings (1,500-token safe zone, context collapse at 2,500 tokens, 0% suggestion compliance)
- BL-013: Game design one-pager (60-90 words/response, sardonic tone, 3 suggestions, 15-25 turns/session)
- BL-014: Target device specs (>=4 tok/s decode, <=3s TTFT, 1,500 MB iOS memory budget)
