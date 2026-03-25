# BL-043: Game Master System Prompt — Before/After Comparison

> **Model:** Phi-3-mini 3.8B Q4 | **Context:** 4096 tokens | **Turns:** 7 + opening
> **Test script:** `prototype/test_game_loop.py` with 7 scripted player actions
> **Date:** 2026-03-25

---

## Prompt Variants

### Legacy Prompt (245 tokens)
The original `dante_cli.py` system prompt written before any research. A 245-token instruction-heavy prompt with 7 bullet-point rules, including negative instructions ("If a command is nonsensical, gently redirect") and verbose format descriptions. No few-shot example, no pacing constraints, no anchor note.

### Production Prompt (248 tokens)
Synthesizes findings from 4 research artifacts:
- **BL-010** (prompt patterns): Few-shot example, Author's Note anchor pattern
- **BL-036** (small model techniques): 1 example max, repeat-instruction anchoring, positive-only instructions, max_tokens=200 cap
- **BL-013** (game design): 60-90 word target, exactly 3 suggestions, sardonic/atmospheric/fair tone
- **BL-028** (tech stack ADR): Optimized for 3B-class models, context-aware budgeting

**Key structural changes:**
1. Few-shot example baked into prompt (BL-036 technique #1)
2. `max_tokens` reduced from 512 to 200 (BL-036 technique: response length control)
3. Repeat-instruction anchor note injected near generation point after turn 1 (BL-036 technique #3)
4. All negative instructions removed; reframed as positive directives (BL-036 technique #6)
5. Role-play framing kept concise: "You are the Game Master of DANTE TERMINAL" (BL-036 technique #4)

---

## Results Summary

| Metric | Legacy | Production | Delta | Target |
|--------|--------|------------|-------|--------|
| **Avg word count** | 244.8 | 107.0 | -56% | 60-90 words |
| **Suggestion rate** | 0% | 25% | +25pp | 100% (needs GBNF) |
| **Composite score** | 1.05 | 1.62 | +54% | 3.0+ |
| **Total test time** | 37.8s | 15.2s | -60% | -- |
| **Context collapse** | Turn 6 (gibberish) | None | Eliminated | Never |
| **Coherence maintained** | Partial (turns 6-7 gibberish) | Full (all 8 turns coherent) | Fixed | Full |
| **Suggestion compliance** | 0.0 | 0.75 | +0.75 | 5.0 |
| **Length compliance** | 0.25 | 2.25 | +2.0 | 5.0 |
| **Sensory detail** | 5.0 | 4.62 | -0.38 | 5.0 |

---

## Per-Turn Score Comparison

### Legacy Prompt (before)
| Turn | Words | Sug# | SugCompl | Length | Sensory | Format | Composite |
|------|-------|------|----------|--------|---------|--------|-----------|
| 0 | 205 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 1 | 296 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 2 | 272 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 3 | 244 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 4 | 282 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 5 | 333 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 6 | 184 | 0 | 0 | 0 | 5 | 0 | 1.0 |
| 7 | 142 | 0 | 0 | 2 | 5 | 0 | 1.4 |

### Production Prompt (after)
| Turn | Words | Sug# | SugCompl | Length | Sensory | Format | Composite |
|------|-------|------|----------|--------|---------|--------|-----------|
| 0 | 137 | 0 | 0 | 2 | 5 | 0 | 1.4 |
| 1 | 130 | 0 | 0 | 2 | 5 | 0 | 1.4 |
| 2 | 46 | 4 | 1 | 3 | 5 | 2 | 2.2 |
| 3 | 119 | 0 | 0 | 3 | 5 | 0 | 1.6 |
| 4 | 144 | 0 | 0 | 2 | 5 | 0 | 1.4 |
| 5 | 124 | 0 | 0 | 2 | 5 | 0 | 1.4 |
| 6 | 124 | 0 | 0 | 2 | 5 | 0 | 1.4 |
| 7 | 32 | 3 | 5 | 2 | 2 | 2 | 2.2 |

---

## Analysis

### What improved significantly

1. **Response length cut by 56%** — The `max_tokens=200` cap (BL-036) is the single most impactful change. Legacy prompt produced 244.8 avg words (3-4x the 60-90 target); production prompt averages 107 words. Still above target but within the "acceptable" range (120 word hard limit per BL-013). The few-shot example's ~75-word length also calibrates the model's output length expectations.

2. **Context collapse eliminated** — The legacy prompt produced complete gibberish at turns 6-7 (context exceeded ~2,500 tokens, triggering the BL-012 quality cliff). The production prompt, with shorter responses and max_tokens cap, keeps context well within the safe zone. All 8 turns remain coherent and narratively connected.

3. **Test execution 60% faster** — Shorter responses (200 vs 512 max tokens) mean faster generation. Total test time dropped from 37.8s to 15.2s. This directly maps to better mobile UX per BL-013's 25-40s per-turn target.

4. **Suggestion compliance emerged** — Two turns (2 and 7) produced numbered lists. While 25% is far from the 100% target, it proves the few-shot example has some influence. The legacy prompt achieved 0% across all turns despite explicit format instructions — confirming BL-036's finding that "small models learn by seeing patterns, not parsing instructions."

### What still needs improvement

1. **Suggestion format reliability** — 25% is not production-ready. As BL-036 and BL-010 both identified, **GBNF grammar-constrained decoding is the only path to 100% compliance** at this model scale. The prompt alone cannot solve this. GBNF grammar support is the #1 next step.

2. **Word count still over target** — 107 avg words is down from 245 but still above the 60-90 target. Two factors: (a) Phi-3 is 3.8B and naturally verbose; (b) max_tokens=200 still allows ~130-150 words. Tightening to max_tokens=150 or using the final target model (Gemma 3n E2B / Llama 3.2 3B) may close this gap.

3. **Tone/personality** — Both prompts produce "helpful fantasy narrator" tone rather than the "sardonic, atmospheric, fair" personality specified in BL-013. The anchor note helps but isn't sufficient alone. Genre-specific fine-tuning (BL-010 §4.3) or more aggressive tone examples in the few-shot would help.

### BL-036 techniques applied and their observed effect

| # | Technique | Applied? | Observed Effect |
|---|-----------|----------|-----------------|
| 1 | Few-shot example (1 max) | Yes | Partial suggestion format learning (0% -> 25%); length calibration |
| 2 | GBNF constrained decoding | No (needs llama.cpp integration) | N/A — this is the critical missing piece |
| 3 | Repeat-instruction anchoring | Yes (STYLE_ANCHOR) | Maintained coherence through all turns; prevented context collapse |
| 4 | Role-play framing (concise) | Yes | Baseline persona maintained (no "as an AI" breaks) |
| 5 | Positive-only instructions | Yes (removed all negatives) | Hard to isolate, but no "can't do that" refusals observed |
| 6 | max_tokens=200 cap | Yes | 56% word count reduction; 60% speed improvement |

---

## Recommendations for Next Steps

1. **GBNF grammar is non-negotiable** — Implement grammar-constrained decoding for the suggestion format. This is the single change that would move suggestion compliance from 25% to ~100%.

2. **Test with target models** — This comparison used Phi-3-mini 3.8B. The actual target models (Gemma 3n E2B, Llama 3.2 3B per BL-028) may behave differently. Llama 3.2 3B has the highest IFEval score (77.4) at this scale and may follow the suggestion format more reliably even without GBNF.

3. **Consider max_tokens=150** — Further tightening would bring word counts closer to the 60-90 target.

4. **Port prompt to Flutter** — The production prompt (`prototype/game_master_prompt.txt`) and anchor note pattern are ready to be integrated into `dante_terminal/lib/services/inference_service.dart`.
