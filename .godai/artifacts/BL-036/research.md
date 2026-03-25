# Small Language Model Prompting Techniques for Maximizing Interactive Fiction Quality (1-3B Parameters)

> **BL-036** | Created: 2026-03-25 | Audience: founding team & prompt engineering work (BL-005, BL-018)
>
> Purpose: Provide evidence-based prompting guidelines so BL-005 (Game Master prompt implementation) and BL-018 (genre template testing) build on proven small-model techniques rather than trial-and-error. This research fills the gap between BL-010's product-level prompt patterns (designed for large cloud models) and BL-012's empirical findings (which showed those patterns failing on small models).

---

## Summary

Small language models (1-3B parameters) behave fundamentally differently from the large cloud-hosted models (GPT-4, Claude) that power existing AI interactive fiction products. Published benchmarks and our own BL-012 findings confirm three critical gaps: (1) instruction-following fidelity drops dramatically below 3B parameters — Llama 3.2 1B achieves only 25.7% on BFCL V2 structured output vs. 67.0% for the 3B variant; (2) multi-turn conversation degrades performance by an average of 39% even on large models, and small models are even more sensitive; (3) zero-shot structured output (JSON/suggestions) is essentially non-functional on sub-3B models (7.34% parsability on the best-performing 1.3B model). However, three techniques reliably compensate: few-shot examples (boosting JSON parsability from 7% to 89%), GBNF grammar-constrained decoding (guaranteeing 100% structural compliance at any model size), and instruction anchoring near the generation point (the "Author's Note" pattern). This document provides a concrete prompting playbook for DANTE TERMINAL's 1-3B parameter interactive fiction generation.

---

## 1. Small Model Behavior Profile: Large vs. Small Model Differences

This section documents the empirically verified behavioral differences between large models (7B+/cloud) and small models (1-3B) across four dimensions critical to interactive fiction.

### 1.1 Instruction-Following Fidelity

**The core problem:** Small models do not reliably follow natural-language instructions, especially when those instructions describe output formatting, response length, or multi-part constraints.

**Benchmark evidence:**

| Benchmark | Llama 3.2 1B | Llama 3.2 3B | Phi-3.5-mini (3.8B) | Llama 3.1 8B | What It Measures |
|-----------|-------------|-------------|---------------------|-------------|------------------|
| **IFEval** (Instruction Following) | ~49* | **77.4** | 59.2 | 80.4 | Strict instruction adherence (format, length, constraints) |
| **MMLU** (5-shot) | ~36* | **63.4** | **69.0** | 73.0 | General knowledge/reasoning |
| **ARC-Challenge** (5-shot) | ~55* | **78.6** | **87.4** | 83.4 | Commonsense reasoning |
| **BFCL V2** (Tool Use/Structured Output) | **25.7** | **67.0** | — | — | JSON function call generation |

*Sources: Meta Llama 3.2 model cards (HuggingFace), Medium/Towards AGI benchmark analysis, Phi-3 Technical Report (arXiv:2404.14219). Scores marked * are interpolated from available data.*

**Key findings:**

1. **The 3B threshold is real.** Research on small models for function calling (arXiv:2504.19277) establishes "a clear capability boundary around the 3B-parameter threshold." Models below 2B struggle fundamentally with structured output — only Deepseek-Coder-1.3B achieved *any* non-zero JSON parsability in zero-shot (7.34%), while all other sub-4B models scored 0%.

2. **IFEval shows the gap most clearly.** Llama 3.2 3B scores 77.4 on IFEval — impressive, but this measures single-turn instruction following. In multi-turn interactive fiction scenarios (where instructions compete with narrative context), effective adherence drops substantially.

3. **Instruction finetuning has limits.** The JMLR scaling study (Chung et al., 2024) found that instruction finetuning *without* chain-of-thought data can actually degrade reasoning ability. Full-parameter instruction fine-tuning risks "overwriting pre-trained knowledge during the fine-tuning process," leading to increased hallucination.

**DANTE TERMINAL implication:** The 3B floor confirmed by BL-012 is also confirmed by the literature. 1B models are not viable for instruction-following tasks. Even at 3B, natural-language format instructions ("end with exactly 3 suggestions") will fail — mechanical enforcement (grammar constraints, few-shot examples) is required.

### 1.2 Structured Output Compliance

**The core problem:** Small models cannot reliably produce structured output (JSON, numbered lists, specific formats) from instruction alone.

**Empirical evidence:**

| Model | Params | Zero-Shot JSON Parsability | 3-Shot JSON Parsability | Fine-Tuned Parsability |
|-------|--------|--------------------------|------------------------|----------------------|
| Deepseek-Coder-1.3B | 1.3B | 7.34% | **89.38%** | **99.44%** |
| Phi-3-mini | 3.8B | 0% | 0% | **99.62%** |
| Phi-2 | 2.78B | 0% | 0% | — |
| StarCoder2-3B | 2.8B | 0% | 0% | — |

*Source: "Small Models, Big Tasks" (arXiv:2504.19277)*

**Critical observations:**

1. **Zero-shot structured output is essentially broken at <4B.** Most small models cannot produce valid JSON even when explicitly instructed. BL-012 confirmed this: neither TinyLlama 1.1B nor Phi-3-mini produced the `> 1. / 2. / 3.` suggestion format despite clear system prompt instruction.

2. **Few-shot examples provide massive uplift — but not universally.** Deepseek-Coder jumped from 7% to 89% with just 3 examples. However, Phi-3-mini remained at 0% even with few-shot, suggesting the technique is model-dependent. The general finding: few-shot works best on models already partially capable of the format.

3. **Constrained decoding is the only universal guarantee.** Grammar-constrained decoding via GBNF ensures 100% structural compliance regardless of model capability, because invalid tokens are masked at generation time (see Section 2.4).

4. **Format choice matters.** Research on structured output robustness (arXiv:2507.01810) found that YAML and XML formats show higher parseability than JSON for small models, likely because they require fewer precise punctuation tokens. For DANTE TERMINAL's suggestion format (simple numbered list), the structure is simple enough that GBNF enforcement is straightforward.

**DANTE TERMINAL implication:** Do not rely on instructions alone for the suggestion format. Use GBNF grammar as primary enforcement, with 1 few-shot example as secondary reinforcement.

### 1.3 Persona Maintenance Over Turns

**The core problem:** Small models struggle to maintain a consistent persona, tone, and character across multi-turn conversations. Instructions from the system prompt "fade" as conversation context grows.

**Research evidence:**

1. **"Lost in Conversation" (arXiv:2505.06120):** Models show an average -39% performance degradation in multi-turn vs. single-turn settings, with a 112% increase in output variance. Even strong models (Claude 3.7, GPT-4.1) experience 30-40% degradation. Smaller models show "more sensitivity to instruction rephrasing" but similar multi-turn unreliability patterns.

2. **"Lost in the Middle" (Liu et al., TACL 2024):** Performance is highest when relevant information occurs at the beginning or end of context, and "significantly degrades when models must access relevant information in the middle of long contexts." For a system prompt at the top of a growing conversation, its effective influence decreases as more turns are added.

3. **"Context Rot" (Chroma Research, 2025):** Performance degrades consistently with increasing input length, even when the model can perfectly retrieve all relevant information. The degradation is 13.9-85% depending on the task, and occurs well within models' claimed context lengths. Models perform *better* on shuffled (incoherent) haystacks than logically coherent ones — suggesting structural patterns can paradoxically harm attention mechanisms.

4. **BL-012 empirical finding:** Phi-3-mini maintained coherent persona (the "Eldoria" world) for 5 turns, then suffered catastrophic collapse at ~2,500 prompt tokens — "not a gradual degradation but a cliff." TinyLlama 1.1B lost persona by turn 3, generating both player and GM dialogue.

**Quantified degradation pattern for small models:**

| Turn Count | Prompt Tokens (est.) | Persona Coherence | Instruction Adherence |
|------------|---------------------|-------------------|----------------------|
| 1-3 | 300-800 | High | Moderate |
| 4-5 | 800-1,500 | Good | Degrading |
| 6-8 | 1,500-2,500 | Poor | Minimal |
| 9+ | 2,500+ | Collapsed | Absent |

*Based on BL-012 Phi-3-mini empirical results and "Lost in Conversation" research trends.*

**DANTE TERMINAL implication:** The "Author's Note" pattern (placing style directives near the generation point rather than only in the system prompt) is critical. Small models need persona reinforcement at the *end* of context, not just the beginning. Additionally, aggressive context windowing (~1,500 tokens max, per BL-012) is non-negotiable.

### 1.4 Creative Narrative Generation

**The core problem:** Generating high-quality, atmospheric prose requires balancing creativity (high temperature, diverse vocabulary) with coherence (staying on-topic, maintaining world state). Small models are more prone to the extremes: either repetitive/generic output or hallucinated/incoherent output.

**Evidence:**

1. **BL-012 empirical results:** TinyLlama 1.1B produced "meta-conversation (fake Player/GM dialogue) instead of actual narrative prose" — quality score 1/5. Phi-3-mini 3.8B produced "genuinely immersive, atmospheric prose" at 4/5 quality for turns 1-5, but collapsed to unintelligible output by turn 6+. The quality gap between 1B and 3B is not linear — it's a step function.

2. **Response length control failure:** Both BL-012 models produced 300-500 token responses when 80-120 tokens were needed (per BL-013 game design). Small models cannot follow length instructions reliably. Hard `max_tokens` caps and few-shot example calibration are needed.

3. **Genre-specific fine-tunes outperform base instruction models.** BL-010 identified several sub-4B creative fine-tunes (CreativeWriter-Llama3.2-3B, NEO-SI-FI, NEO-WEE-HORROR) that produce "more vivid, tonally consistent prose than base instruction-tuned models at the same parameter count." This aligns with the literature: targeted fine-tuning on narrative data is the most reliable way to improve creative quality at small scale.

4. **Temperature sensitivity.** Small models require more careful temperature tuning. Too low (0.3-0.5) → repetitive, formulaic output. Too high (0.9+) → hallucinated, incoherent output. The sweet spot for narrative generation is typically 0.7-0.8 with top_p 0.9-0.95 and a moderate repeat_penalty (1.05-1.15).

**DANTE TERMINAL implication:** Narrative quality is achievable at 3B but requires: (a) keeping within the ~1,500 token context window, (b) using `max_tokens` + few-shot calibration for response length, (c) considering genre-specific fine-tunes or LoRA adapters for BL-013's 4 themes.

---

## 2. Prompting Technique Effectiveness at Small Scale (1-3B Parameters)

This section evaluates 8 named prompting techniques with expected effectiveness at 1-3B scale.

### 2.1 Few-Shot Examples

**Technique:** Include 1-3 complete input→output examples in the prompt to demonstrate desired format and behavior.

**Effectiveness at 1-3B: ✅ EFFECTIVE (with caveats)**

**Evidence:**
- Few-shot prompting boosted Deepseek-Coder-1.3B JSON parsability from 7.34% to 89.38% with just 3 examples (arXiv:2504.19277).
- Research on Phi-3-mini and OLMo-2-7B shows "merely two examples" can "approach or exceed 7B-class baselines" for select mid-sized models (arXiv:2507.01810).
- The "Few-Shot Dilemma" research (arXiv:2509.13196) warns that smaller models (3-4B) show "severe performance collapse with excessive examples" and "struggle beyond 20 examples." The optimal range for sub-4B models is 1-3 examples.
- BL-012 found that both tested models ignored the suggestion format without examples. BL-010 recommended "1 example maximum, kept under 150 tokens" to conserve the 1,500-token budget.

**Optimal configuration for DANTE TERMINAL:**
- **1 example** (not 2-3) to conserve tokens
- Example should be ~100-120 tokens showing: atmospheric prose (2-3 sentences) + exactly 3 numbered suggestions
- Example implicitly teaches response length, tone, and format simultaneously
- Place example after system instructions, before conversation history

**Rating: EFFECTIVE — the single highest-impact technique for small models when combined with constrained decoding.**

### 2.2 XML/JSON Structured Prompting

**Technique:** Use XML tags (`<narrative>`, `<suggestions>`) or JSON structure to delineate output sections, leveraging training data familiarity with markup.

**Effectiveness at 1-3B: ⚠️ DEGRADED**

**Evidence:**
- LLMs are trained on massive amounts of structured/semi-structured data including XML and HTML, making them "particularly adept at recognizing and processing information wrapped in tags" (CodeConductor, 2025).
- However, at <4B parameters, XML tag compliance is inconsistent. Models may open tags but fail to close them, mix narrative text into structured sections, or ignore tag boundaries entirely.
- The structured output benchmark (arXiv:2501.10868) found that "LM-only approaches achieve acceptable coverage on easy-to-medium datasets but show significant performance drops on harder datasets" — and harder datasets include those requiring multi-section structured output.
- For *input* structuring (organizing the prompt), XML tags are universally helpful. For *output* structuring (expecting the model to produce XML), small models are unreliable without constrained decoding.

**Optimal configuration for DANTE TERMINAL:**
- **Use XML tags for INPUT structuring:** `[WORLD STATE]`, `[EXAMPLE]`, `[STYLE]`, `[HISTORY]` — these help the model parse the prompt even if it can't produce structured output.
- **Do NOT rely on XML tags for OUTPUT structuring.** Instead, use GBNF grammar to enforce the narrative + suggestions format.
- Keep tag names simple and short — `[STATE]` not `<game_world_state_information>`.

**Rating: DEGRADED for output; EFFECTIVE for input structuring.**

### 2.3 Role-Play Framing

**Technique:** Assign the model a specific persona ("You are a sardonic Game Master") to steer tone and behavior.

**Effectiveness at 1-3B: ⚠️ DEGRADED (but still worth doing)**

**Evidence:**
- PromptHub research (2024) found persona prompting is "effective for open-ended tasks (e.g., creative writing), but it's generally not beneficial for accuracy-based tasks." Since interactive fiction is primarily creative, role-play framing should help.
- BL-012 confirmed: Phi-3-mini 3.8B successfully adopted the GM persona and maintained it for 5 turns. TinyLlama 1.1B failed entirely — it "role-played both sides," generating both player and GM dialogue.
- Qwen 2.5 3B is specifically noted for being "more resilient to diversity of system prompts, enhancing role-play implementation" — making it a strong candidate for multi-theme role-play (BL-013's 4 genre themes).
- Role-play framing is more reliable when combined with a few-shot example that demonstrates the persona in action, rather than relying on instruction alone.

**Optimal configuration for DANTE TERMINAL:**
- Keep the persona instruction short: "You are the Game Master of DANTE TERMINAL — sardonic, atmospheric, fair."
- **Reinforce persona near the generation point** via Author's Note pattern, not just in the system prompt header.
- Combine with 1 few-shot example that demonstrates the persona tone.
- Budget: ~20-30 tokens for role-play framing.

**Rating: DEGRADED — works at 3B+ for creative tasks, fails at 1B. Must be reinforced via proximity to generation point.**

### 2.4 Constrained Decoding (GBNF Grammar)

**Technique:** Use GBNF grammars in llama.cpp to mask invalid tokens at generation time, guaranteeing structural compliance in output.

**Effectiveness at 1-3B: ✅ HIGHLY EFFECTIVE**

**Evidence:**
- Grammar-constrained decoding "substantially outperforms unconstrained LMs or even beats task-specific finetuned models" (arXiv:2305.13971). LLaMA-33B with GCD achieved 36.0 F1 vs. 17.5 F1 unconstrained — more than doubling performance.
- "Smaller models are more liable to produce non-valid output, meaning GCD is especially valuable for researchers working in memory-constrained environments" (Cooper, 2024).
- GCD guarantees 100% parse tree validity vs. 64.2% unconstrained (constituency parsing benchmark).
- Constrained decoding achieves ~50% faster generation than unconstrained for structured output (arXiv:2501.10868) because structural scaffolding (field names, brackets, numbering) bypasses the generation process entirely.
- The SINE interactive fiction research demonstrated GBNF grammar-guided decoding achieving 68-86% success rates for IF generation in the Ink scripting language (noted in BL-010).

**Limitations:**
- **Grammar-model misalignment:** When forced outputs diverge significantly from what the model would naturally predict, semantic quality can degrade. The grammar should allow natural language within structural constraints, not over-constrain prose.
- **~5-10% per-token overhead** for grammar evaluation (BL-010 estimate).
- Requires local inference (llama.cpp) — not available via API. This is fine for DANTE TERMINAL (fully on-device).

**Optimal GBNF grammar for DANTE TERMINAL:**
```gbnf
root        ::= narrative "\n\n" suggestions
narrative   ::= sentence (" " sentence)* (" " sentence)?
sentence    ::= [A-Z] [a-zA-Z0-9 ,;:''""'!\-—.…?]+ "."
suggestions ::= "> 1. " suggestion "\n> 2. " suggestion "\n> 3. " suggestion "\n"
suggestion  ::= [A-Z] [a-zA-Z0-9 ,.'!?\- ]+
```

This allows free-form narrative prose (any number of sentences) while enforcing exactly 3 numbered suggestions. The narrative section is minimally constrained — only requiring sentences to start with a capital letter and end with a period — preserving creative freedom.

**Rating: HIGHLY EFFECTIVE — the single most reliable technique for structured output on small models. Non-negotiable for DANTE TERMINAL.**

### 2.5 Repeat-Instruction Anchoring

**Technique:** Repeat key instructions at multiple points in the prompt (system prompt header AND near the generation point) to counteract instruction drift over long contexts.

**Effectiveness at 1-3B: ✅ EFFECTIVE**

**Evidence:**
- "Lost in the Middle" research (Liu et al., 2024) proves that information at the beginning and end of context has the strongest influence on generation. Instructions only at the top of context fade as conversation grows.
- The "Author's Note" pattern — placing style directives 3 paragraphs before the generation point — is universally adopted by AI Dungeon, NovelAI, and KoboldAI (BL-010). All three products independently discovered that style instructions near the generation point have "maximum influence" on output.
- Contextual anchoring literature confirms: "LLMs weigh the initial context of prompts significantly" and "by seeding prompts with the right domain vocabulary or prior information, developers anchor the model's response" (Lakera, 2026).
- For small models with limited attention capacity, repeat-instruction anchoring is even more critical than for large models, because the attention mechanism has fewer parameters to maintain long-range dependencies.

**Optimal configuration for DANTE TERMINAL:**
- **System prompt header:** Full instructions (role, rules, constraints) — ~100-150 tokens
- **Author's Note (near generation point):** Compressed reminder — ~25-35 tokens: `[Style: sardonic narrator, sensory detail, atmospheric. Max 90 words. Exactly 3 suggestions.]`
- The Author's Note should be inserted after conversation history but before the current player input, placing it in the high-influence zone near generation.

**Rating: EFFECTIVE — essential for maintaining instruction adherence across multi-turn interactive fiction sessions.**

### 2.6 Negative Examples ("Do NOT...")

**Technique:** Explicitly instruct the model to avoid specific failure modes: "Do NOT break character," "Do NOT generate more than 3 suggestions," "Do NOT include meta-commentary."

**Effectiveness at 1-3B: ❌ INEFFECTIVE (counterproductive)**

**Evidence:**
- Research on hallucination mitigation (Frontiers in AI, 2025) found that "negative prompting can reduce fabrication in summarization and QA tasks." However, this finding applies to larger models with strong instruction following.
- For small models, negative instructions are problematic for two reasons:
  1. **They consume precious tokens** describing what NOT to do instead of demonstrating what TO do. With a 1,500-token budget, every token matters.
  2. **Small models may fixate on the prohibited behavior** rather than avoiding it. The "don't think of a pink elephant" effect is well-documented in prompt engineering: mentioning a failure mode can prime the model to produce it.
  3. **Incorrect negative examples can induce more hallucinations.** Microsoft's best practices note: "Always test with and without the examples to verify that they help."
- BL-012 implicitly tested this: the system prompt said "respond with exactly 3 suggestions" (positive framing), but neither model complied. Adding "do NOT skip suggestions" would not have helped — the model lacks the instruction-following capacity, not the intent.

**Optimal configuration for DANTE TERMINAL:**
- **Do NOT use negative examples in the system prompt.** Use the token budget for positive demonstrations (few-shot examples) and mechanical enforcement (GBNF grammar) instead.
- The one exception: a single brief negative constraint in the Author's Note can work if phrased as a positive: "Always advance the story" instead of "Do NOT refuse player actions."

**Rating: INEFFECTIVE — wastes tokens and can prime failure modes. Use positive framing + mechanical enforcement instead.**

### 2.7 Chain-of-Thought (CoT) Prompting

**Technique:** Ask the model to "think step by step" before generating its final answer, improving reasoning quality.

**Effectiveness at 1-3B: ❌ INEFFECTIVE (harmful at small scale)**

**Evidence:**
- The hallucination survey (Frontiers in AI, 2025) explicitly states: "Smaller models cannot process and utilize the multi-step dependencies that CoT relies on, thus yielding lower accuracy than standard prompting methods."
- The JMLR scaling study (Chung et al., 2024) found CoT benefits emerge primarily above 8B parameters. Below that threshold, CoT instructions consume tokens without improving output quality.
- CD-CoT research shows that "noisy rationales" in chain-of-thought prompting (where intermediate reasoning steps are irrelevant or incorrect) cause "LLMs performing worse with flawed rationales than with no examples at all." Small models produce noisy rationales more frequently.
- For creative narrative generation specifically, CoT is inappropriate — the output should be atmospheric prose, not step-by-step reasoning. CoT would produce "Step 1: The room is dark. Step 2: There is a door..." instead of evocative fiction.

**Optimal configuration for DANTE TERMINAL:**
- **Do NOT use chain-of-thought prompting.** It wastes tokens, degrades quality at small scale, and is inappropriate for creative narrative output.
- The exception: Intra's "guided thinking" pattern (Section 1.3 of BL-010) uses structured questions to force outcome commitment *before* narration. This is a constrained variant of CoT that works with small models because the questions are simple binary choices, not open-ended reasoning. Consider this for action resolution but NOT for narrative generation.

**Rating: INEFFECTIVE — actively harmful for sub-8B models. Inappropriate for creative narrative tasks.**

### 2.8 Few-Shot with Task Scoping (Narrow Task Decomposition)

**Technique:** Instead of asking the model to perform the complex task of "generate narrative + parse game state + produce suggestions" in one call, decompose into narrow sub-tasks with dedicated prompts.

**Effectiveness at 1-3B: ✅ EFFECTIVE (but adds latency)**

**Evidence:**
- Research on small language models for game content (arXiv:2601.23206) demonstrated that a 1B model can achieve 92.5% success when "each model handles a single, narrow task rather than being a general-purpose narrator."
- The SINE interactive fiction research showed improved results when separating narrative generation from game mechanics extraction.
- BL-010 noted this as "aggressive task scoping" — the most reliable approach for small models, at the cost of latency from multiple inference calls.

**Optimal configuration for DANTE TERMINAL:**
- **Primary approach (single-call):** Use GBNF grammar to enforce narrative + suggestions format in one inference call. This avoids the latency penalty.
- **Fallback (two-pass):** If GBNF degrades narrative quality (grammar-model misalignment), use a two-pass approach: (1) generate narrative unconstrained, (2) generate suggestions with GBNF grammar using the narrative as context. Cost: ~4-8 seconds additional latency at 4 tok/s.
- **Advanced option (multi-LoRA):** For v2, use genre-specific LoRA adapters to specialize the model per task. llama.cpp supports runtime LoRA loading.

**Rating: EFFECTIVE — proven to dramatically improve small-model reliability, but latency cost must be weighed against BL-014's ≤3s TTFT target.**

### Technique Effectiveness Summary Table

| # | Technique | 1B Rating | 3B Rating | Token Cost | Evidence Strength |
|---|-----------|-----------|-----------|------------|-------------------|
| 1 | Few-shot examples (1-2) | Effective | **Effective** | ~100-150 tokens | Strong (multiple papers) |
| 2 | XML/JSON structured prompting | Ineffective (output) | Degraded (output) | ~20-40 tokens | Moderate |
| 3 | Role-play framing | Ineffective | Degraded | ~20-30 tokens | Moderate (BL-012 + PromptHub) |
| 4 | GBNF constrained decoding | **Highly Effective** | **Highly Effective** | 0 prompt tokens | Strong (arXiv:2305.13971) |
| 5 | Repeat-instruction anchoring | Effective | **Effective** | ~25-35 tokens | Strong ("Lost in Middle") |
| 6 | Negative examples | Ineffective | Ineffective | Wasteful | Moderate (against) |
| 7 | Chain-of-thought | Harmful | Ineffective | Wasteful | Strong (against) |
| 8 | Task scoping/decomposition | Effective | Effective | Latency cost | Strong (arXiv:2601.23206) |

---

## 3. Interactive Fiction-Specific Recommendations

### 3.1 Recommended System Prompt Structure

Based on the research above, here is the concrete prompt structure template optimized for 1-3B models generating interactive fiction for DANTE TERMINAL.

**Total prompt budget: ≤1,500 tokens** (BL-012 safe zone, BL-014 memory constraint)

```
┌─────────────────────────────────────────────────┐
│ ZONE 1: SYSTEM INSTRUCTIONS (~80-100 tokens)    │
│ Compact role + rules. No negative examples.     │
│ No chain-of-thought. Positive framing only.     │
├─────────────────────────────────────────────────┤
│ ZONE 2: FEW-SHOT EXAMPLE (~100-120 tokens)      │
│ Exactly 1 example showing:                      │
│   - Player input                                │
│   - GM response (2-3 atmospheric sentences)     │
│   - Exactly 3 numbered suggestions              │
│ Implicitly teaches: tone, length, format        │
├─────────────────────────────────────────────────┤
│ ZONE 3: WORLD STATE (~100-150 tokens)           │
│ Injected fresh every turn. Authoritative.       │
│ Compact key-value format: location, inventory,  │
│ quest flags, act, turn, NPC present.            │
├─────────────────────────────────────────────────┤
│ ZONE 4: THEME OVERLAY (~50-80 tokens)           │
│ Keyword-triggered. Only present when relevant.  │
│ Setting vocabulary, active NPC descriptions.    │
├─────────────────────────────────────────────────┤
│ ZONE 5: STORY SUMMARY (~100-150 tokens)         │
│ Compressed history of earlier turns.            │
│ Updated every 5-6 turns via summarization.      │
├─────────────────────────────────────────────────┤
│ ZONE 6: RECENT HISTORY (~400-500 tokens)        │
│ Last 2-3 verbatim exchanges (player + GM).      │
│ Primary context for coherent continuation.      │
├─────────────────────────────────────────────────┤
│ ZONE 7: AUTHOR'S NOTE (~25-35 tokens)           │
│ Repeat-instruction anchor near generation point.│
│ Compressed style + constraint reminder.         │
├─────────────────────────────────────────────────┤
│ ZONE 8: CURRENT INPUT (~10-30 tokens)           │
│ "Player: {action}\nGM:"                         │
└─────────────────────────────────────────────────┘
```

**Total: ~865-1,165 tokens**, leaving 335-635 tokens of headroom within the 1,500-token budget for longer conversations or theme-specific content.

### 3.2 Concrete Prompt Template

```
[SYSTEM]
You are the Game Master of DANTE TERMINAL. Narrate interactive fiction.
Rules: (1) Respond in 2-3 atmospheric sentences, under 90 words.
(2) Use sensory details — sounds, textures, light, smell.
(3) Always advance the story — every response changes something.
(4) End with exactly 3 action suggestions for the player.
(5) Acknowledge every player action with consequences.

[EXAMPLE]
Player: look around the room
GM: Dust motes drift through a shaft of grey light from a crack overhead. The archive's east wing stretches before you — shelves of waterlogged books lean at drunken angles, and something metallic glints beneath a collapsed desk. The air tastes of copper and old paper.

> 1. Investigate the metallic glint under the desk
> 2. Wade north into the flooded corridor
> 3. Examine the waterlogged books on the nearest shelf

[STATE]
Location: {location}
Inventory: {inventory_csv}
Flags: {quest_flags_csv}
Act: {act_number} | Turn: {current}/{max}
NPCs: {present_npcs}

[THEME: {theme_name}]
{keyword_triggered_theme_content}

[PREVIOUSLY]
{compressed_summary_of_earlier_turns}

[RECENT]
Player: {turn_n_minus_2_action}
GM: {turn_n_minus_2_response}

Player: {turn_n_minus_1_action}
GM: {turn_n_minus_1_response}

[STYLE]
Sardonic narrator. Sensory detail. Atmospheric tension. Max 90 words. 3 suggestions.

Player: {current_action}
GM:
```

**Recommended system prompt token count range: 80-100 tokens** (Zone 1 only). The full assembled prompt should be **900-1,200 tokens** in typical gameplay, never exceeding 1,500.

### 3.3 Suggestion Generation Approach

**Primary: GBNF grammar-constrained single-call generation** (Section 2.4)

The GBNF grammar enforces the narrative + 3 suggestions structure at the token level. The model generates freely within the narrative section, then is mechanically forced to produce exactly 3 numbered suggestions. This:
- Eliminates the suggestion format failure from BL-012 (0/5 compliance for both models)
- Adds only ~5-10% per-token overhead
- Works with any model, regardless of instruction-following capability
- Is already supported by llama.cpp (BL-008), our chosen inference SDK

**Fallback: Two-pass generation** if GBNF causes grammar-model misalignment and degrades narrative quality:
1. Pass 1: Generate narrative unconstrained (~80-120 tokens, ~10-15s at 4-8 tok/s)
2. Pass 2: Short prompt "Given the scene above, suggest 3 actions:" with GBNF grammar (~30-50 tokens, ~4-8s)
3. Total latency: ~14-23s — acceptable within BL-013's 25-40s turn target but above the ideal

**Emergency fallback: Post-processing extraction** from unconstrained output using regex/heuristic parsing, with generic contextual suggestions as safety net.

### 3.4 Context Management That Minimizes Instruction Drift

The research overwhelmingly shows that context growth is the primary enemy of instruction adherence. The mitigation strategy:

1. **Hard context cap at ~1,500 prompt tokens.** Per BL-012's empirical finding: Phi-3-mini collapses catastrophically at ~2,500 tokens. The 1,500-token budget provides a safety margin.

2. **Per-turn state serialization** (Zone 3). Inject game state fresh every turn as authoritative ground truth. The model never needs to "remember" state from conversation history — it reads it from the state block.

3. **Sliding-window summarization** (Zone 5). Every 5-6 turns, compress the oldest verbatim exchanges into a 2-3 sentence "previously" summary. This matches AI Dungeon's 6-action memory window and BL-012's ~5-turn coherence window.

4. **Author's Note anchor** (Zone 7). Place compressed style/constraint instructions immediately before the current player input. This exploits the "Lost in the Middle" finding that information at the end of context has the strongest influence on generation.

5. **max_tokens hard cap at 200.** Prevents runaway response length (BL-012 saw 300-500 token responses). Combined with the few-shot example (~80 words) and Author's Note ("Max 90 words"), this triple reinforcement controls length.

---

## 4. Risk Mitigations: Failure Modes and Countermeasures

### 4.1 Character Name Amnesia

**Failure mode:** The model forgets NPC names, the player's quest, or location names mid-adventure. Names mentioned in early turns fade as context grows.

**Root cause:** "Lost in the Middle" effect — information from earlier turns has weakened influence. Small models have limited attention capacity for maintaining multiple named entities across turns.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **Per-turn state injection** | Include NPC names, location, and quest in `[STATE]` block every turn. Model reads state, not memory. | High — state is re-read every turn |
| P1 | **Keyword-triggered lore** | When NPC name appears in state or recent history, inject their description from theme overlay. | Medium — depends on keyword matching |
| P2 | **Summary reinforcement** | Include key names in the `[PREVIOUSLY]` summary: "You've been exploring the Sunken Archive with archivist Maren." | Medium — summary must be concise |

### 4.2 Tone Drift (Losing the Sardonic/Atmospheric Voice)

**Failure mode:** The model gradually shifts from the desired "sardonic, atmospheric" narrator voice to generic, bland prose or overly cheerful/helpful assistant tone. Common after 5+ turns.

**Root cause:** Persona fading over context growth ("Lost in Conversation" -39% degradation). The model's default assistant training overrides the persona instruction as it recedes in context.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **Author's Note anchor** | `[STYLE] Sardonic narrator. Sensory detail. Atmospheric tension.` placed immediately before current input — maximum proximity influence. | High — proven by AI Dungeon/NovelAI/KoboldAI |
| P1 | **Few-shot tone calibration** | The single example in Zone 2 demonstrates the target tone. Model mimics the demonstrated style. | Medium — effective for 3-5 turns, then fades |
| P2 | **Genre-specific LoRA** | Fine-tune LoRA adapters per theme (horror, noir, sci-fi, dungeon) that bake tone into weights. Eliminates need for prompt-based tone instruction. | High — but requires fine-tuning investment (v2) |
| P3 | **Temperature tuning** | 0.7-0.8 temp with 0.9 top_p. Lower temp reduces randomness but maintains coherence. Repeat penalty 1.05-1.15 prevents the "Alrighty then!" loops seen in BL-012. | Medium — global setting, not per-turn adaptive |

### 4.3 Suggestion Count Non-Compliance

**Failure mode:** The model outputs 0, 1, 2, 4, or more suggestions instead of exactly 3. Or it embeds suggestions in the narrative text rather than as a separate numbered list. This was a 100% failure rate in BL-012 (both models, every turn).

**Root cause:** Small models have weak structured output compliance (Section 1.2). Natural-language instructions to "end with exactly 3 suggestions" are ignored because the model lacks the instruction-following capacity, not the intent.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **GBNF grammar enforcement** | Grammar forces exactly `> 1.` + `> 2.` + `> 3.` after the narrative section. Invalid token sequences are masked at generation time. 100% compliance guaranteed. | **Very High** — mechanical guarantee |
| P1 | **Few-shot example** | Example shows exactly 3 suggestions in the correct format, reinforcing the pattern. | Medium — helps but insufficient alone |
| P2 | **Post-processing fallback** | If GBNF is disabled (debugging, testing), regex extraction with generic fallback suggestions. | Low — unreliable but better than nothing |

### 4.4 Context Window Overflow (Catastrophic Collapse)

**Failure mode:** As the adventure progresses, the accumulated context exceeds the model's effective processing capacity (~1,500 tokens for 3B Q4 models per BL-012). Output degenerates into repetitive or nonsensical text: "yoursurren-in in your in yours in thebreilessi" (BL-012 turn 7-8).

**Root cause:** Attention mechanism cannot maintain coherence when prompt tokens approach quantized model capacity. Degradation is a cliff, not a slope — output goes from 4/5 quality to 0/5 in one turn.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **Hard context budget** | App-level token counter. Never assemble a prompt exceeding 1,500 tokens. Trim oldest history first, then summarize. | **Very High** — prevents the failure mode entirely |
| P1 | **Sliding-window summarization** | Every 5-6 turns, compress oldest verbatim exchanges into `[PREVIOUSLY]` summary (~100-150 tokens). Preserves narrative continuity within the budget. | High — proven pattern (AI Dungeon, KoboldAI) |
| P2 | **Tokenizer-based counting** | Use the actual model tokenizer for token counting, not the 4-chars-per-token heuristic from BL-012 (which was "too conservative"). Accurate counting prevents surprise overflows. | High — straightforward implementation |
| P3 | **Graceful degradation detection** | Monitor for repetition patterns (n-gram frequency) and coherence drops. If detected, force-trim context and warn the player with an in-fiction explanation ("Your vision blurs momentarily..."). | Medium — requires quality monitoring heuristics |

### 4.5 Hallucinated Items/Locations (World State Inconsistency)

**Failure mode:** The model invents items the player doesn't have, describes rooms that don't exist in the adventure, or contradicts established facts. BL-012 noted "no coherent world state" for TinyLlama and "good for ~4 turns" for Phi-3-mini before state errors appeared.

**Root cause:** Small models generate plausible-sounding narrative without verifying against established state. They pattern-match from training data (generic fantasy/sci-fi tropes) rather than adhering to the specific world defined in the prompt.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **Per-turn state injection** | Authoritative `[STATE]` block lists exactly what the player has and where they are. Model reads inventory from state, not from memory of past turns. | High — prevents most hallucinated items |
| P1 | **Post-generation state validation** | Parse the model's response for item/location mentions. Cross-check against game state. Flag or silently correct contradictions before display. | Medium — requires NER/pattern matching |
| P2 | **Constrained vocabulary in theme overlay** | Theme content lists valid locations, items, and NPCs. Invalid entities can be detected via exclusion. | Medium — increases theme authoring effort |

### 4.6 Repetitive Output ("Alrighty then!" Loops)

**Failure mode:** The model falls into repetitive phrasing patterns, reusing the same openings, transitions, or descriptive language across turns. BL-012 noted TinyLlama produced "near-identical copy-paste blocks with minor word changes" by turn 3-4.

**Root cause:** Small models have limited vocabulary diversity and tend toward high-probability token sequences. Repetition is a well-known failure mode exacerbated by: low temperature, long context (model fixates on its own prior output), and weak instruction tuning.

**Countermeasures:**
| Priority | Technique | Implementation | Confidence |
|----------|-----------|---------------|------------|
| P0 | **repeat_penalty parameter** | Set `repeat_penalty` 1.05-1.15 in llama.cpp. Penalizes recently generated tokens, forcing vocabulary diversity. | High — direct mechanical intervention |
| P1 | **Temperature calibration** | 0.7-0.8 temperature with 0.9-0.95 top_p. Balances creativity vs. coherence. BL-012 used 0.8/0.95 — reasonable defaults. | Medium — global tuning |
| P2 | **Varied Author's Notes** | Rotate style descriptors: "gothic atmosphere," "creeping dread," "wry observation." Prevents the model from locking onto a single phrase pattern. | Medium — requires per-turn variation logic |
| P3 | **Few-shot example diversity** | If using multiple examples (not recommended for token reasons), ensure they show different sentence structures and openings. | Low — token cost prohibitive |

---

## Analysis: Connecting Research to DANTE TERMINAL Architecture

### What the Research Changes vs. BL-010's Recommendations

BL-010 studied prompt patterns from products using large cloud models. This research reveals three critical adjustments needed for small on-device models:

1. **System prompt length must be radically shorter.** BL-010's proposed prompt architecture totals ~950-1,300 tokens. This research confirms the budget is sound but emphasizes that Zone 1 (system instructions) must be ≤100 tokens — not the 350+ line system prompts used by AI Dungeon or the DEV Community D&D architecture. Every token spent on instructions is a token *not* available for conversation history, and conversation history is what makes the fiction feel coherent.

2. **GBNF grammar is not optional — it's mandatory.** BL-010 recommended GBNF as "primary" for suggestion format. This research strengthens that to **non-negotiable**: zero-shot structured output is 0% reliable at <4B parameters. Without GBNF, DANTE TERMINAL has no suggestion system.

3. **Chain-of-thought and negative examples are harmful.** BL-010 mentioned Intra's "guided thinking" as valuable. This research clarifies: structured question sequences (binary choices) work for small models; open-ended CoT does not. And negative examples ("do NOT break character") waste tokens and can prime the failure mode they attempt to prevent.

### Priority Stack for BL-005 Implementation

Based on this research, BL-005 (Game Master prompt implementation) should implement techniques in this order:

1. **GBNF grammar** — guarantees structural compliance (suggestions format)
2. **Per-turn state serialization** — guarantees world state consistency
3. **1 few-shot example** — teaches format, tone, and length simultaneously
4. **Author's Note anchoring** — maintains persona over multi-turn sessions
5. **Hard context budget (1,500 tokens)** — prevents catastrophic collapse
6. **max_tokens=200** — prevents response length runaway
7. **Sliding-window summarization** — enables adventures longer than 5 turns
8. **repeat_penalty=1.1** — prevents repetitive output loops

### Model Selection Implications

This research confirms and refines BL-008's model shortlist:

| Model | Params | Effective Size | IF Strength | IF Weakness | Recommendation |
|-------|--------|---------------|-------------|-------------|----------------|
| **Llama 3.2 3B Q4_K_M** | 3B | ~2.0 GB | Strong IFEval (77.4), good instruction following | At iOS memory edge; no creative fine-tune | Primary candidate |
| **Gemma 3n E2B Q4_K_M** | 6B (2B eff.) | ~1.2 GB | Memory-efficient, 32K context | Newer, less community testing | Strong candidate (solves iOS RAM) |
| **Qwen 2.5 3B Instruct** | 3B | ~1.8 GB | Best role-play support, 128K context | Less tested for creative writing | Strong candidate for multi-theme |
| **Phi-3.5-mini Q4** | 3.8B | ~2.2 GB | Confirmed good prose (BL-012) | Exceeds iOS memory budget; zero structured output compliance in few-shot | Fallback only |

---

## Sources

### Published Research
1. **"LLMs Get Lost In Multi-Turn Conversation"** — arXiv:2505.06120 (2025). Average -39% degradation in multi-turn settings, 112% increase in output variance.
2. **"Lost in the Middle: How Language Models Use Long Contexts"** — Liu et al., TACL 2024 (doi:10.1162/tacl_a_00638). Performance degrades when relevant information is in the middle of context.
3. **"Context Rot: How Increasing Input Tokens Impacts LLM Performance"** — Chroma Research (2025). 13.9-85% degradation with increasing context, even with perfect retrieval.
4. **"Grammar-Constrained Decoding for Structured NLP Tasks without Finetuning"** — arXiv:2305.13971 (2023/2025). GCD doubles F1 performance, guarantees structural validity.
5. **"Generating Structured Outputs from Language Models: Benchmark and Studies"** — arXiv:2501.10868 (2025). Constrained decoding achieves 50% faster generation, highest compliance rates.
6. **"Small Models, Big Tasks: An Exploratory Empirical Study on Small Language Models for Function Calling"** — arXiv:2504.19277 (2025). Zero-shot JSON parsability: 7.34% best case at 1.3B; few-shot boosts to 89%.
7. **"The Few-Shot Dilemma: Over-prompting Large Language Models"** — arXiv:2509.13196 (2025). 8B parameter threshold for effective few-shot comprehension; sub-4B models collapse with excessive examples.
8. **"Scaling Instruction-Finetuned Language Models"** — Chung et al., JMLR 2024. CoT benefits emerge above 8B; instruction finetuning without CoT degrades reasoning.
9. **"A Comprehensive Survey of Small Language Models"** — ACM TIST 2025 (doi:10.1145/3768165). 3B capability boundary for structured output compliance.
10. **"Phi-3 Technical Report: A Highly Capable Language Model Locally on Your Phone"** — arXiv:2404.14219 (2024). Phi-3-mini benchmarks and instruction following capabilities.
11. **"A Guide to Structured Outputs Using Constrained Decoding"** — Cooper (2024). Practical GBNF implementation, grammar-model misalignment risks.
12. **"High-quality generation of dynamic game content via small language models"** — arXiv:2601.23206 (2026). 92.5% success with 1B model via aggressive task scoping and LoRA.
13. **"Evaluating Structured Output Robustness of Small Language Models"** — arXiv:2507.01810 (2025). Format comparison (JSON/YAML/XML) and model size effects on structured output.
14. **"Quantifying Conversational Reliability of Large Language Models under Multi-Turn Interaction"** — arXiv:2603.01423 (2026). Loss of instruction adherence, intent confusion failure modes.

### Practitioner Sources
15. **Llama 3.2 Benchmark Analysis** — Medium/Towards AGI (2024). [Link](https://medium.com/towards-agi/llama-3-2-benchmark-insights-and-revolutionizing-edge-ai-and-vision-88542fe3dc0d)
16. **Role-Prompting Research** — PromptHub (2024). [Link](https://www.prompthub.us/blog/role-prompting-does-adding-personas-to-your-prompts-really-make-a-difference)
17. **Contextual Anchoring** — Lakera Prompt Engineering Guide (2026). [Link](https://www.lakera.ai/blog/prompt-engineering-guide)
18. **Teaching an LLM to Write Assembly: GBNF-Constrained Generation** — Randall (2025). [Link](https://www.jamesdrandall.com/posts/gbnf-constrained-generation/)

### Cross-Referenced Project Artifacts
- **BL-008:** On-device LLM SDK maturity research (llama.cpp selected, GBNF support confirmed)
- **BL-010:** AI Game Master prompt patterns from existing IF products (large-model patterns, Author's Note, GBNF recommendation)
- **BL-012:** CLI prototype findings (context collapse at ~2,500 tokens, suggestion format 0% compliance, 1,500-token safe zone)
- **BL-013:** Game design one-pager (60-90 word responses, 15-25 turns/session, sardonic tone, 3 suggestions)
- **BL-014:** Target device specs & performance budget (1,500 MB iOS memory, ≥4 tok/s decode, ≤3s TTFT)
