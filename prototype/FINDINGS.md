# DANTE TERMINAL - CLI Prototype Findings

## Test Setup
- **Machine:** Apple Silicon Mac (arm64, M-series)
- **Runtime:** llama-cpp-python 0.3.17 (Metal GPU acceleration)
- **Context window:** 2048 (TinyLlama), 4096 (Phi-3-mini)
- **Generation params:** temp=0.8, top_p=0.95, repeat_penalty=1.1, max_tokens=512
- **Test method:** Automated 7-turn scripted game loop (test_game_loop.py)
- **Date:** 2026-03-23

---

## Model 1: TinyLlama 1.1B Chat v1.0 (Q4_K_M)
- **Size:** 638 MB on disk
- **Parameters:** 1.1B
- **Quantization:** Q4_K_M
- **Context used:** 2048 tokens

### Quality Assessment (1-5 scale)

| Dimension | Score | Notes |
|-----------|-------|-------|
| Narrative quality | 1 | Outputs meta-conversation (fake "Player:"/"GM:" dialogue) instead of actual narrative prose |
| Command understanding | 2 | Vaguely acknowledges commands but doesn't act on them meaningfully |
| World consistency | 1 | No coherent world state; mentions random items and rooms without continuity |
| Suggestion relevance | 0 | Never outputs the "> 1. / 2. / 3." format despite system prompt instruction |
| Instruction following | 1 | Ignores almost all system prompt constraints; generates its own dialogue format |

### Observations
- Model generates a bizarre "Player: (sighing)" / "Game Master:" dialogue format — role-playing both sides
- Heavy repetition starts by turn 3-4: "Alrighty then! Let's make this brief" appears in nearly every response
- By turn 5-6, responses are near-identical copy-paste blocks with minor word changes
- Context trimming works mechanically but doesn't help quality since the model can't follow instructions
- Opening scene is a meta-discussion about playing games rather than an actual scene

### Token Speed
- Tokens/sec: 187-222 tok/s (excellent)
- Total 8-turn session: 20.0s
- Model load time: 0.1s

---

## Model 2: Phi-3-mini 3.8B Instruct (Q4)
- **Size:** 2.2 GB on disk
- **Parameters:** 3.8B
- **Quantization:** Q4
- **Context used:** 4096 tokens

### Quality Assessment (1-5 scale)

| Dimension | Score | Notes |
|-----------|-------|-------|
| Narrative quality | 4 | Turns 1-5 produce genuinely immersive, atmospheric prose with vivid imagery |
| Command understanding | 3 | Processes commands contextually, though sometimes over-elaborates instead of advancing plot |
| World consistency | 3 | Maintains Eldoria setting and remembers staff/map/key across several turns |
| Suggestion relevance | 0 | Never outputs the "> 1. / 2. / 3." format despite system prompt instruction |
| Instruction following | 2 | Good narrative role but fails on structured output (suggestions format) |

### Observations
- **Turns 1-5: EXCELLENT.** Rich, atmospheric prose: "The sun's rays gently caress your face as you find yourself lying on a bed of soft moss..." — this is actually good interactive fiction
- **Turn 6: DEGRADATION BEGINS.** As context fills (~2500 prompt tokens), output starts mixing coherent text with garbled fragments
- **Turn 7-8: CATASTROPHIC COLLAPSE.** Output degenerates into nonsensical character soup: "yoursurren-in in your in yours in thebreilessi" — model cannot maintain coherence at high context utilization
- Item tracking works for ~4 turns: staff, map, and silver key are remembered and referenced
- The model creates its own world ("Eldoria") with internal consistency — creative and engaging
- Verbose: averages 350-500 tokens per response when ~100-150 would be ideal for mobile

### Token Speed
- Tokens/sec: 64-106 tok/s (decreases as context grows)
- Total 8-turn session: 40.9s
- Model load time: 1.6s

---

## Comparative Summary

| Metric | TinyLlama 1.1B | Phi-3-mini 3.8B |
|--------|----------------|-----------------|
| File size | 638 MB | 2.2 GB |
| Tokens/sec | 187-222 | 64-106 |
| Fiction quality (1-5) | 1 | 4 (turns 1-5), 0 (turns 6+) |
| Follows GM format | No | Partially (prose yes, structured output no) |
| Suggestion quality | 0/5 — never produced | 0/5 — never produced |
| Context coherence (5 turns) | Poor — repetitive by turn 3 | Good for 5 turns, collapses at turn 6+ |
| Mobile viability | Fast but useless quality | Quality good but size + degradation are problems |

## Key Findings

### Prompt Structure
1. **Neither model follows the 3-suggestions format.** The system prompt instruction to print "> 1. [action] > 2. [action] > 3. [action]" is completely ignored by both models. This needs few-shot examples or a post-processing extraction step.
2. **Role assignment works for Phi-3 but not TinyLlama.** Phi-3 stays in character as a narrator; TinyLlama generates both player and GM dialogue, breaking immersion entirely.
3. **System prompt length matters.** The current ~200-word system prompt consumes ~50 tokens. For 2048-ctx models, every token counts. Need a minimal prompt variant.
4. **Instruction-tuned models are mandatory.** Base or chat-tuned models with weak instruction following (TinyLlama) produce unusable results for structured game output.

### Context Window Management
1. **Phi-3 collapses catastrophically at ~2500 prompt tokens** — not a gradual degradation but a cliff. The context trimming in the script triggers too late.
2. **Aggressive trimming needed.** Keep only system prompt + last 2-3 exchanges. Current estimator (4 chars ≈ 1 token) is too conservative; should use actual tokenizer.
3. **Context budget: ~1500 prompt tokens is the safe zone** for Phi-3 at Q4. Beyond that, quality drops precipitously.
4. **Summarization strategy needed.** Instead of dropping old messages, compress them into a running "story so far" summary to preserve world state.

### Mobile Implications
1. **1.1B models are NOT viable** for interactive fiction. Speed is great but quality is unusable. Minimum 3B+ needed.
2. **3.8B at Q4 (2.2GB) is borderline viable** — excellent prose for short sessions but context management is critical.
3. **Token speed decreases with context length.** Phi-3 went from 106 tok/s (empty context) to 64 tok/s (full context). On mobile hardware this will be worse.
4. **Response length control is missing.** Both models produce 300-500 token responses. Mobile UI needs 100-150 tokens max. Need `max_tokens` tuning + prompt instruction for brevity.
5. **GPU layer offloading works well on Apple Silicon.** Both models used Metal acceleration seamlessly.

## Recommendations for Mobile Implementation
1. **Target 3B-4B parameter models minimum.** Phi-3-mini quality is acceptable; anything smaller (1B) is not.
2. **Implement aggressive context windowing.** Keep prompt under 1500 tokens. Use a "story summary" message that gets updated each turn rather than keeping full history.
3. **Add few-shot examples to system prompt** for the suggestion format — or extract/generate suggestions in a separate, shorter inference call.
4. **Cap response length at 150-200 tokens** via max_tokens and prompt instruction ("Be concise, 2-3 sentences max").
5. **Consider Phi-3.5-mini or Gemma-2B-IT** as alternatives — may offer better instruction following at similar size.
6. **Plan for ~2.5GB model download** as part of first-launch experience. This is acceptable for a game.
7. **Test on actual mobile hardware ASAP** — desktop speeds (65-220 tok/s) will be 3-10x slower on phone.
