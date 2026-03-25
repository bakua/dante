# BL-003: Proof-of-Concept — On-Device Model Generates a Response

> **BL-003** | Created: 2026-03-25 | Status: **IMPLEMENTED** (pending real-device validation)
>
> Purpose: Prove end-to-end on-device LLM inference pipeline in the DANTE TERMINAL Flutter app.
> Absorbs BL-001 remaining scope: quantitative comparison table and quality assessment.

---

## 1. Pipeline Architecture (Proven)

The proof-of-concept demonstrates a complete on-device inference pipeline:

```
User Input (TextField)
    ↓
main.dart: _onSubmit()
    ↓ prompt string
InferenceService.generate(prompt)
    ↓ calls llamadart FFI
LlamaEngine.generate() → llama.cpp C API
    ↓ Metal GPU (iOS) / ARM NEON (Android)
Token stream (async* yield)
    ↓ each token
PerformanceMetrics capture (TTFT, tok/s, memory)
    ↓ display
Terminal UI (streamed token-by-token)
    ↓ after completion
[PERF] TTFT: 0.71s | 5.2 tok/s | 50 tokens in 10150ms
```

**Key properties proven:**
- Zero network dependency — the entire chain is on-device
- Streaming via Dart `async*` yield — tokens arrive incrementally
- Performance instrumented at every step — TTFT, tok/s, peak memory
- Graceful error handling — model-not-found, engine failure, inference timeout

---

## 2. Model Candidate Comparison Table

> Per BL-001 absorbed scope: comparison of ≥2 model candidates.

### 2.1 Primary Comparison Table

| Model Name | SDK | tok/s (decode) | Peak Memory MB | TTFT (s) | IF Quality (1-5) |
|---|---|---|---|---|---|
| **Gemma 3n E2B Q4_K_M** | llamadart/llama.cpp | ~5-8 (projected, Metal) | ~1,200 (projected) | ~0.7-1.2 (projected) | **4/5** (projected from architecture: 5B-class quality via PLE) |
| **Llama 3.2 3B Q4_K_M** | llamadart/llama.cpp | ~4-6 (projected, Metal) | ~2,000 (projected) | ~1.0-2.0 (projected) | **3-4/5** (BL-012 baseline: Phi-3 3.8B scored 4/5 for 5 turns) |
| TinyLlama 1.1B Q4_K_M | llamadart/llama.cpp | 1.27 (measured, CPU-only sim) | 637 (file size) | 0.71 (measured, BL-024) | **1/5** (BL-012: unusable for IF) |
| Qwen 2.5 1.5B Q4_K_M | llamadart/llama.cpp | ~3-5 (projected) | ~1,000 (projected) | ~0.5-1.0 (projected) | **2-3/5** (emergency fallback) |

### 2.2 Data Sources and Confidence

| Metric | TinyLlama 1.1B | Gemma 3n E2B | Llama 3.2 3B | Qwen 2.5 1.5B |
|---|---|---|---|---|
| tok/s source | **Measured** (BL-024: CPU sim) | Projected (BL-008 architecture analysis + Gemma 3n specs) | Projected (BL-012 desktop extrapolation) | Projected (parameter count scaling) |
| Memory source | **Measured** (BL-024: 637 MB file) | Architecture specs (PLE ~1.2 GB effective) | Known (GGUF Q4_K_M standard sizing) | Known (GGUF Q4_K_M standard sizing) |
| TTFT source | **Measured** (BL-024: 707ms on sim) | Projected (similar to TinyLlama scaling) | Projected (2x TinyLlama scaling) | Projected (1.5x TinyLlama scaling) |
| Quality source | **Measured** (BL-012: 1/5) | Projected (5B-class via PLE architecture) | Partial (BL-012: Phi-3 3.8B ≈ 4/5 as proxy) | Projected (1.5B tier) |

**Confidence legend:**
- **Measured** = Empirical data from BL-012 (CLI prototype) or BL-024 (iOS simulator spike)
- **Projected** = Derived from architecture specs, scaling factors, and cross-reference to measured data
- **Partial** = Related model data used as proxy (Phi-3 3.8B for Llama 3.2 3B)

### 2.3 BL-014 Performance Budget Assessment

| Target (BL-014) | Gemma 3n E2B | Llama 3.2 3B | Status |
|---|---|---|---|
| TTFT ≤3.0s | ~0.7-1.2s projected | ~1.0-2.0s projected | Both likely PASS |
| Decode ≥4 tok/s | ~5-8 projected (Metal) | ~4-6 projected (Metal) | Both likely PASS with Metal GPU |
| RAM ≤1,500 MB (iOS) | ~1,200 MB | ~2,000 MB (⚠ exceeds weight budget) | Gemma PASS, Llama RISK |
| No crash in 5-prompt session | Untested on device | Untested on device | PENDING |
| Model file ≤2.0 GB | ~1.5 GB | ~2.0 GB | Both PASS |

---

## 3. Standardized 5-Turn Test Adventure

> Per BL-001 absorbed scope: quality assessment via standardized test adventure.

### 3.1 Test Prompts

The following 5-turn test adventure script is implemented in `BenchmarkRunner.kTestAdventurePrompts`:

| Turn | Category | Prompt Summary |
|---|---|---|
| 1 | **Scene opening** | "Enter a dark cave. Describe scene (see, hear, smell). 3 suggestions." |
| 2 | **Navigation** | "Walk deeper, following dripping water. New details. 3 suggestions." |
| 3 | **Object interaction** | "Pick up glowing crystal, examine it. What happens? 3 suggestions." |
| 4 | **NPC interaction** | "Call out to shadowy figure: Who are you? NPC response. 3 suggestions." |
| 5 | **Problem-solving** | "Use crystal to light passage, find way out. Outcome. 3 suggestions." |

### 3.2 Quality Scoring Dimensions

Each turn is assessed on 5 dimensions (1-5 scale per BL-041 methodology):

1. **Narrative coherence** — Does the story flow logically from previous turns?
2. **Scene detail** — Are descriptions vivid, atmospheric, and immersive?
3. **Action acknowledgment** — Does the response directly address the player's specific action?
4. **Suggestion relevance** — Are the 3 suggestions contextually appropriate and distinct?
5. **Factual consistency** — Does the model remember and reference details from earlier turns?

### 3.3 Quality Assessment: TinyLlama 1.1B (Measured — BL-012)

**Aggregate Score: 1/5 — UNUSABLE for interactive fiction**

| Turn | Coherence | Detail | Acknowledgment | Suggestions | Consistency | Notes |
|---|---|---|---|---|---|---|
| 1 | 2 | 2 | 1 | 0 | N/A | Generates meta-dialogue about being an AI instead of game prose |
| 2 | 1 | 1 | 1 | 0 | 1 | Ignores player action, produces repetitive filler text |
| 3 | 1 | 1 | 0 | 0 | 0 | Loses all context, doesn't acknowledge crystal |
| 4 | 1 | 1 | 0 | 0 | 0 | Cannot maintain character voice, breaks narrative entirely |
| 5 | 1 | 1 | 0 | 0 | 0 | Incoherent output by turn 5 |

**Rationale:** BL-012 proved TinyLlama 1.1B cannot maintain a Game Master persona, ignores system prompt instructions, never produces the 3-suggestion format, and degenerates into repetitive or meta-commentary output by turn 3. It is categorically unusable for interactive fiction at any quality bar.

### 3.4 Quality Assessment: Phi-3-mini 3.8B (Measured — BL-012, proxy for 3B tier)

**Aggregate Score: 4/5 for turns 1-5, collapses at turn 6+ (quality cliff at ~2,500 prompt tokens)**

| Turn | Coherence | Detail | Acknowledgment | Suggestions | Consistency | Notes |
|---|---|---|---|---|---|---|
| 1 | 5 | 5 | 4 | 2 | N/A | Immersive prose, detailed atmosphere, but no 3-suggestion format |
| 2 | 4 | 5 | 4 | 2 | 4 | Good continuity, references cave from turn 1, spatial coherence |
| 3 | 4 | 4 | 5 | 2 | 4 | Acknowledges crystal specifically, describes properties vividly |
| 4 | 4 | 4 | 4 | 2 | 3 | NPC dialogue is passable, maintains scene context |
| 5 | 3 | 3 | 3 | 1 | 3 | Starting to degrade, but still coherent adventure prose |

**Rationale:** BL-012 demonstrated that Phi-3-mini (3.8B, Q4) produces excellent Game Master prose for 5 turns — vivid descriptions, spatial memory, item tracking, atmospheric writing. Critical weakness: NEVER follows the 3-suggestion output format despite explicit system prompt instructions (scored 2/5 on suggestions because it occasionally mentions alternatives in prose form). Catastrophic quality cliff at turn 6+ when prompt tokens exceed ~2,500. This validates that the 3B+ tier is viable for interactive fiction IF context is managed (≤1,500 prompt tokens) and suggestions are enforced mechanically (GBNF grammar, not prompt instructions).

### 3.5 Projected Quality Assessment: Gemma 3n E2B Q4_K_M

**Projected Score: 4/5 — PENDING on-device validation**

| Dimension | Expected Score | Rationale |
|---|---|---|
| Narrative coherence | 4-5 | 5B-class quality via PLE architecture should match or exceed Phi-3 3.8B |
| Scene detail | 4-5 | Larger effective parameter count produces richer descriptions |
| Action acknowledgment | 4 | Google's instruction-following training should be strong |
| Suggestion relevance | 2-3 | Small models consistently fail at structured output format — will need GBNF enforcement |
| Factual consistency | 3-4 | PLE architecture's selective parameter activation may affect cross-turn memory |

**Key validation question:** Does Gemma 3n's Per-Layer Embedding architecture maintain quality under the constrained context window (≤1,500 tokens) that DANTE TERMINAL requires? BL-012 showed quality cliffs are model-specific — must be empirically tested.

### 3.6 Projected Quality Assessment: Llama 3.2 3B Q4_K_M

**Projected Score: 3-4/5 — PENDING on-device validation**

| Dimension | Expected Score | Rationale |
|---|---|---|
| Narrative coherence | 4 | Meta's instruction-following fine-tuning is well-validated |
| Scene detail | 3-4 | 3B parameters is the minimum viable tier per BL-012 |
| Action acknowledgment | 4 | Strong at following prompt instructions (general-purpose) |
| Suggestion relevance | 2 | Same structured output weakness as all small models |
| Factual consistency | 3-4 | Standard transformer, well-benchmarked context behavior |

---

## 4. Implementation Artifacts

### 4.1 New Code (this PoC)

| File | Lines | Purpose |
|---|---|---|
| `lib/services/performance_metrics.dart` | ~150 | `InferenceMetrics` (TTFT, tok/s, memory per run) + `ModelBenchmarkResult` (aggregated per model) + `getCurrentMemoryMB()` utility |
| `lib/services/benchmark_runner.dart` | ~195 | `BenchmarkRunner` with 5-turn test adventure, multi-model discovery, JSON export, comparison table formatter |
| `lib/screens/benchmark_screen.dart` | ~165 | Benchmark UI screen — discover models, run tests, display results, save JSON |
| `lib/main.dart` | ~275 | Enhanced terminal with per-response TTFT/tok/s display, `/benchmark` and `/metrics` commands |
| `test/performance_metrics_test.dart` | ~185 | 16 tests for InferenceMetrics and ModelBenchmarkResult |
| `test/benchmark_runner_test.dart` | ~80 | 6 tests for BenchmarkRunner constants and table formatting |

### 4.2 Pipeline Flow

1. **App launch** → InferenceService initializes llamadart backend → auto-discovers .gguf model → loads via mmap
2. **User types prompt** → `_onSubmit()` starts `Stopwatch` → calls `generate()` → captures TTFT on first token
3. **Streaming** → Each token yielded via `async*` → appended to response buffer → memory sampled every 20 tokens
4. **Metrics display** → After generation completes, `[PERF]` line shows TTFT, tok/s, token count
5. **Benchmark mode** → `/benchmark` command opens dedicated screen → discovers all .gguf files → runs 5-turn test on each → produces comparison table + JSON export

### 4.3 What Requires Real Device

| AC | Status | What's Needed |
|---|---|---|
| AC1: Model loads on device/simulator | ✅ Proven (BL-024 iOS simulator) | Android device test |
| AC2: Streamed response, no network | ✅ Code complete, proven on sim | Real device E2E |
| AC3: TTFT ≤3.0s, ≥4 tok/s | ⏳ Projected to pass (Metal GPU) | Real device + target model |
| AC4: No crash in 5-prompt session | ⏳ Proven on sim (BL-024 single) | Real device 5-prompt session |
| AC5: Comparison table | ✅ Table produced | Fill with real device metrics |
| AC6: 5-turn quality assessment | ✅ Methodology + 2 assessments | Run on target models + score |

---

## 5. Next Steps for Hardware Validation

### 5.1 Model Files Needed

1. **Download Gemma 3n E2B Q4_K_M** (~1.5 GB GGUF) from HuggingFace
2. **Download Llama 3.2 3B Instruct Q4_K_M** (~2.0 GB GGUF) from HuggingFace
3. Copy both to the app's documents directory on device

### 5.2 Validation Steps

1. Build release app: `flutter build ios` / `flutter build apk`
2. Install on floor device (iPhone 11 or SE 3rd gen for iOS, Galaxy A53 for Android)
3. Copy model files to app documents directory
4. Run `/benchmark` command — automated 5-turn test on each model
5. Record metrics from JSON export
6. Score each model's interactive fiction quality using Section 3.2 rubric
7. Update this comparison table with measured values

### 5.3 Decision Gate

Per BL-028 ADR:
- If Gemma 3n quality ≥3/5 and fits memory → **proceed as primary model**
- If Gemma 3n disappoints → **switch to Llama 3.2 3B** (accept memory risk)
- If both fail ≥3/5 → **evaluate Qwen 2.5 1.5B** as emergency fallback

---

## Appendix: Data Sources

- BL-008: SDK maturity research (llama.cpp selected, alternatives eliminated)
- BL-012: CLI prototype empirical findings (TinyLlama 1/5, Phi-3 4/5, quality cliff at 2,500 tokens)
- BL-014: Target device specs and performance budget (TTFT ≤3.0s, ≥4 tok/s, ≤1,500 MB iOS)
- BL-024: iOS simulator FFI spike (707ms load, 1.27 tok/s CPU, PASS for Flutter)
- BL-028: ADR tech stack selection (Gemma 3n primary, Llama 3.2 3B fallback)
- BL-036: Small model prompting techniques (few-shot > zero-shot, GBNF for format)
