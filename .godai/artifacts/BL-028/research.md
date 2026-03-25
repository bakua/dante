# Architecture Decision Record: DANTE TERMINAL Tech Stack

> **BL-028** | Created: 2026-03-25 | Status: **ACCEPTED**
>
> Purpose: Consolidate decisions from BL-008, BL-012, BL-014, BL-015, and BL-024 into a single authoritative reference for all implementation tasks. This ADR formally declares the tech stack for DANTE TERMINAL and replaces the now-superseded BL-001.

---

## Summary

DANTE TERMINAL will be built with **Flutter** (cross-platform framework), **llamadart** (Dart FFI bridge to llama.cpp for on-device inference), and **Gemma 3n E2B Q4_K_M** as the primary model (with Llama 3.2 3B Q4_K_M as fallback). This stack was selected through 5 research and validation tasks spanning SDK maturity analysis, empirical prototyping, device constraint modeling, framework comparison, and FFI spike testing. Every decision optimizes for the #1 constraint: fitting quality interactive fiction inference within the 1,500 MB iOS memory budget on 4GB iPhones.

---

## Decision 1: Cross-Platform Framework — Flutter

### Decision

**Flutter** (stable channel, ≥3.38) is the cross-platform framework for DANTE TERMINAL.

### Context

Two frameworks were evaluated: Flutter and React Native. The decision was driven by DANTE TERMINAL's nature as a rendering-intensive, offline-first app with a distinctive retro CRT terminal UI that requires pixel-level visual control.

### Evidence

| Source | Key Finding | Impact on Decision |
|--------|-------------|-------------------|
| **BL-015** (`/.godai/artifacts/BL-015-flutter-vs-react-native-framework-comparison.md`) | Flutter won 5 of 8 evaluation dimensions, including the 3 most critical: custom text rendering (CRT effects via built-in Impeller/Skia engine), text streaming (zero-bridge token pipeline: FFI → Dart Stream → StreamBuilder → pixel), and dev velocity (single Dart language for 2-person team). React Native won only LLM SDK maturity and binary size. | Flutter's rendering engine makes CRT terminal effects (scanlines, phosphor glow, typewriter streaming) first-class; React Native would require bolting on `react-native-skia` as a secondary rendering paradigm. |
| **BL-024** (`/.godai/artifacts/BL-024-llama-cpp-dart-ffi-ios-simulator-spike.md`) | Flutter + llama.cpp FFI validated end-to-end on iOS simulator. `llamadart` v0.6.7 (160 pub points, 2.18k weekly downloads) auto-downloads pre-built native binaries — zero manual compilation. Build succeeds in 45s first / 5.5s incremental. TinyLlama 1.1B loads in 707ms, inference produces 20 coherent tokens. No crashes, no memory warnings. | Eliminated the primary Flutter risk identified in BL-015 (immature llama.cpp bindings). Discovered `llamadart` as a significantly more mature alternative to the originally-identified `llama_cpp_dart`. |
| **BL-015** | React Native fallback trigger conditions defined: (1) showstopper FFI issue unresolvable in ≤1 week, (2) Flutter can't achieve ≥4 tok/s on iPhone 11 while llama.rn can, (3) CRT shaders cause sustained <30fps on floor devices. | None of the 3 fallback triggers were hit during BL-024 spike testing. React Native remains a documented fallback but is **not needed**. |

### Consequences

- All mobile code is written in Dart
- CRT terminal UI effects use Flutter's `Canvas` API and `FragmentProgram` shaders
- Token streaming uses `StreamBuilder` with zero bridge overhead
- LLM inference runs in a Dart `Isolate` to avoid UI thread blocking
- Binary size baseline ~25–35 MB (before model download) — acceptable given 1–2 GB model download

---

## Decision 2: Inference Runtime — llamadart (llama.cpp via Dart FFI)

### Decision

**llamadart** v0.6.7+ is the Dart FFI bridge to **llama.cpp** for all on-device LLM inference.

### Context

Four inference SDKs were evaluated in BL-008: llama.cpp, MLC LLM, MediaPipe LLM Inference, and ONNX Runtime Mobile. Three were eliminated. The remaining SDK (llama.cpp) was validated through both desktop CLI prototyping (BL-012) and Flutter FFI spike testing (BL-024).

### Evidence

| Source | Key Finding | Impact on Decision |
|--------|-------------|-------------------|
| **BL-008** (`/.godai/artifacts/BL-008-on-device-llm-sdk-maturity-research.md`) | llama.cpp is the clear maturity leader: 99k GitHub stars, daily releases, 800+ contributors, universal GGUF model support. MLC LLM eliminated (crashes on 4GB iPhones — fails iOS floor). MediaPipe eliminated (deprecated by Google in favor of LiteRT-LM v0.6.1 early preview). ONNX Runtime eliminated (GenAI mobile is nascent, fewer community benchmarks, QNN acceleration is Qualcomm-only). | llama.cpp was the only SDK that met all requirements: works on 4GB iOS devices, actively maintained, broad model support, stable C API. |
| **BL-012** (`/prototype/FINDINGS.md`) | llama.cpp (via llama-cpp-python) successfully ran both TinyLlama 1.1B (187–222 tok/s) and Phi-3-mini 3.8B (64–106 tok/s) on Apple Silicon. Proved model loading, context management, streaming, and Metal GPU acceleration all work through the llama.cpp runtime. | Empirical validation that llama.cpp delivers inference quality and performance needed for interactive fiction. |
| **BL-024** (`/.godai/artifacts/BL-024-llama-cpp-dart-ffi-ios-simulator-spike.md`) | `llamadart` v0.6.7 discovered as superior to originally-identified `llama_cpp_dart`: auto-built native binaries (no manual compilation), 160 pub points, 2.18k weekly downloads, explicit iOS simulator support. Model loads in 707ms, inference produces coherent output, clean disposal. | `llamadart` eliminates the #1 integration risk (manual native lib compilation) and provides a Dart-first API (`LlamaEngine` + `ChatSession`) that maps directly to DANTE TERMINAL's game session model. |
| **BL-008** | llama.cpp has universal GGUF format support — every model on HuggingFace with GGUF files works immediately. No compilation or conversion pipeline needed. MLC requires model-specific TVM compilation; MediaPipe supports only ~4 model families; ONNX requires two-step conversion. | GGUF universality enables rapid model experimentation. Can switch models (Gemma ↔ Llama ↔ Phi ↔ Qwen) without changing any runtime code. |

### Consequences

- All inference goes through `llamadart`'s `LlamaEngine` API
- Models must be in GGUF format (industry standard, widest availability on HuggingFace)
- GPU acceleration: Metal on iOS (automatic), Vulkan on Android (automatic via llamadart)
- CPU fallback on Mali GPUs (Galaxy A53/A54) where GPU inference underperforms (BL-008, BL-014)
- Token streaming via Dart FFI callback → Dart `Stream` — zero JS bridge overhead
- `llamadart` releases should be monitored — v0.6.7 is actively developed (updated 2026-03-18)

---

## Decision 3: Model and Quantization — Gemma 3n E2B Q4_K_M (Primary) / Llama 3.2 3B Q4_K_M (Fallback)

### Decision

**Primary model:** Google Gemma 3n E2B at Q4_K_M quantization (~1.2 GB effective memory, ~1.5 GB GGUF file)
**Fallback model:** Meta Llama 3.2 3B Instruct at Q4_K_M quantization (~2.0 GB GGUF file)

Both must pass on-device benchmarking (BL-003) before final lock-in. The primary model is chosen for its memory efficiency advantage; the fallback is chosen for its broader community validation.

### Context

The model choice is the most constrained decision in the stack. BL-014 established that iOS 4GB devices have a hard jetsam limit of ~2,048 MB, with a safe inference budget of only 1,500 MB (after subtracting KV-cache, buffers, and UI overhead). BL-012 proved that 1B models are unusable for interactive fiction (1/5 quality) and 3B+ is the minimum viable tier.

### Memory Budget Fit

Per BL-014 (`/.godai/artifacts/BL-014-target-device-specs-and-performance-budget.md`), the component-level iOS memory budget is:

| Component | Budget (iOS) | Budget (Android) |
|-----------|-------------|------------------|
| Model weights (GGUF via mmap) | ≤1,200 MB | ≤1,400 MB |
| KV-cache (2048 tokens) | ~150–200 MB | ~150–200 MB |
| Inference buffers | ~50–100 MB | ~50–100 MB |
| App UI + Flutter framework | ~100–150 MB | ~150–200 MB |
| **Total** | **≤1,500 MB** | **≤1,800 MB** |

### Model Comparison

| Attribute | Gemma 3n E2B (Primary) | Llama 3.2 3B (Fallback) |
|-----------|----------------------|------------------------|
| Parameters | 5B raw / ~2B effective (Per-Layer Embedding) | 3.0B |
| GGUF file size (Q4_K_M) | ~1.2 GB effective | ~2.0 GB |
| RAM at load (mmap) | ~1.2 GB | ~2.0 GB |
| Fits iOS weight budget (≤1,200 MB) | **✅ Yes — with headroom** | **⚠️ At the absolute edge** (2.0 GB vs 1,200 MB weight budget — relies heavily on mmap partial loading) |
| Fits Android weight budget (≤1,400 MB) | **✅ Yes — comfortable** | **⚠️ Tight** |
| Expected IF quality | Good (5B-class quality via PLE architecture) | Good (Meta's purpose-built small model, strong instruction-following) |
| Mobile optimization | Purpose-built for phones. Google claims 0.75% battery per session. Selective parameter activation. | General-purpose small model. Not phone-optimized but well-benchmarked. |
| GGUF availability | ✅ Dynamic GGUF available on HuggingFace | ✅ Native GGUF on HuggingFace |
| Community validation | Newer; less battle-tested in GGUF form | Extensive; one of the most downloaded 3B GGUF models |

### Evidence

| Source | Key Finding | Impact on Decision |
|--------|-------------|-------------------|
| **BL-014** (`/.godai/artifacts/BL-014-target-device-specs-and-performance-budget.md`) | Hard limit: model must be ≤3B parameters at Q4 (≤2 GB GGUF file). Recommended sweet spot: 1.5B–3B at Q4_K_M (1.0–2.0 GB). iOS weight budget: ≤1,200 MB. 3B Q4_K_M at 2.02 GB sits at the "absolute edge of iOS memory budget" — any KV-cache or buffer overshoot triggers instant jetsam kill. | Gemma 3n's ~1.2 GB effective footprint is the only 3B+-class model that fits comfortably within the 1,200 MB iOS weight budget. Llama 3.2 3B at 2.0 GB exceeds the weight sub-budget and depends on mmap partial residency to avoid jetsam. |
| **BL-012** (`/prototype/FINDINGS.md`) | TinyLlama 1.1B scored 1/5 quality (unusable — generates meta-dialogue, ignores instructions, repetitive by turn 3). Phi-3-mini 3.8B scored 4/5 for turns 1–5 (immersive prose, remembers items, creates coherent world) but collapses catastrophically at turn 6+ (~2,500 prompt tokens). Neither model followed the 3-suggestions format. | 1B models are eliminated. 3B+ is the minimum for interactive fiction. Context must stay under ~1,500 prompt tokens. Response length must be capped at 100–150 tokens. Few-shot examples or grammar-constrained decoding needed for suggestion format. |
| **BL-008** (`/.godai/artifacts/BL-008-on-device-llm-sdk-maturity-research.md`) | Gemma 3n E2B identified as the "cheat code" — Per-Layer Embedding reduces effective memory to ~2B equivalent while maintaining 5B-class quality. Solves the iOS RAM constraint that makes all standard 3B models borderline. llama.cpp has confirmed GGUF support for Gemma 3n. | Gemma 3n is the only model that delivers 3B+-class quality at 1B-class memory cost. Testing it on llama.cpp isolates the model variable vs Llama 3.2 3B. |
| **BL-014** | Priority order for constraint trade-offs: (1) RAM > (2) Quality > (3) Decode speed > (4) TTFT > (5) Battery > (6) Model size. RAM is the #1 constraint — exceeding memory limits crashes the app (unrecoverable UX failure). | The model that fits most comfortably in RAM wins, assuming quality is above the 3/5 threshold. This directly favors Gemma 3n over Llama 3.2 3B. |

### Performance Targets (from BL-014)

Both candidate models must meet these thresholds on floor devices during BL-003 benchmarking:

| Metric | PASS Threshold | FAIL Threshold |
|--------|---------------|----------------|
| Model file size | ≤2.0 GB | >2.5 GB |
| RAM usage (inference) | ≤1,500 MB (iOS) / ≤1,800 MB (Android) | >2,000 MB |
| Decode speed | ≥4 tok/s on floor devices | <3 tok/s |
| TTFT (1,500-token prompt) | ≤3.0 s | >5.0 s |
| Cold start load time | ≤8 s | >12 s |
| IF quality (subjective) | ≥3/5 | <2/5 |
| Battery drain (30 min) | ≤15% | >20% |

### Consequences

- First-launch experience includes a model download (~1.2–2.0 GB depending on final model)
- Model stored in app documents directory, loaded via mmap
- Context window budget: 2,048 tokens max (safe zone: ~1,500 prompt tokens per BL-012)
- Response length capped at 100–150 tokens via `max_tokens` + prompt instruction
- Suggestion format enforced via GBNF grammar-constrained decoding (not prompt instruction — BL-012 proved both tested models ignore format instructions)
- BL-003 on-device benchmarking is the next gate: if Gemma 3n quality or GGUF stability disappoints, switch to Llama 3.2 3B; if both fail, evaluate Qwen 2.5 1.5B (~1.0 GB, moderate quality) as a fallback

---

## Decision 4: Risk Register

### Risk 1: iOS Memory Pressure / Jetsam Kill (Severity: HIGH)

**Description:** On 4GB iPhones (iPhone 11, 12, SE 2022 — our entire iOS floor), the iOS kernel enforces a hard per-process memory limit of ~2,048 MB. Exceeding this triggers an instant process kill with no warning and no graceful degradation. Model weights loaded via mmap count against memory pressure. A 3B Q4_K_M model at 2.0 GB leaves almost zero headroom for KV-cache, buffers, and UI.

**Sources:**
- BL-014: iOS jetsam hard limit ~2,048 MB on 4GB devices; safe inference budget 1,500 MB; component-level breakdown shows weights ≤1,200 MB
- BL-008: llama.cpp known issue — "On 4GB iPhones, loading a 3B Q4_K_M model (~2 GB) via mmap pushes close to the ~2,048 MB jetsam limit" (severity: High)

**Mitigation Status: PARTIALLY MITIGATED**
- ✅ Gemma 3n E2B selected as primary model (~1.2 GB effective) — provides ~300 MB of headroom within the 1,200 MB weight budget
- ✅ Llama 3.2 3B retained as fallback only (not primary) due to its edge-case memory fit
- ⏳ Pending: On-device memory profiling during BL-003 to validate actual mmap residency behavior
- ⏳ Pending: Implement memory pressure monitoring via iOS `os_proc_available_memory()` with adaptive response (reduce context length, shorter responses)

---

### Risk 2: Model Quality Degradation at Context Length (Severity: HIGH)

**Description:** BL-012 demonstrated that Phi-3-mini 3.8B produces excellent prose for 5 turns but collapses catastrophically at turn 6+ when prompt tokens exceed ~2,500. This is not gradual degradation — it's a quality cliff where output degenerates into "nonsensical character soup." Smaller models (1.1B) are entirely unusable for interactive fiction. Neither tested model followed structured output formats (3 suggestions) despite explicit system prompt instructions.

**Sources:**
- BL-012: Phi-3 quality cliff at ~2,500 prompt tokens; TinyLlama 1/5 quality; neither model follows suggestion format
- BL-014: Context budget derivation — safe zone ~1,500 prompt tokens

**Mitigation Status: PARTIALLY MITIGATED**
- ✅ Context window budget set at 1,500 prompt tokens (safe zone from BL-012 empirical testing)
- ✅ Response length will be capped at 100–150 tokens via `max_tokens` + prompt instruction
- ✅ GBNF grammar-constrained decoding identified for suggestion format enforcement (BL-010 research)
- ⏳ Pending: Implement per-turn state serialization (compress old turns into running summary) instead of keeping full history
- ⏳ Pending: Validate Gemma 3n and Llama 3.2 3B against same degradation pattern during BL-003
- ⏳ Pending: Few-shot prompt template within 1,500-token budget (designed in BL-036)

---

### Risk 3: Flutter llama.cpp Binding Maturity (Severity: MEDIUM)

**Description:** The Flutter ecosystem's llama.cpp bindings are less battle-tested than React Native's `llama.rn` (871 GitHub stars, 740+ commits, Vercel AI SDK integration). The selected binding (`llamadart` v0.6.7) has 160 pub points and 2.18k weekly downloads — respectable but not yet production-proven at scale. Undiscovered bugs in edge cases (Metal memory leak, concurrent inference + UI, long-running sessions) could surface during real-device testing.

**Sources:**
- BL-015: llama.rn rated "High" maturity vs Flutter bindings rated "Medium"; custom Dart FFI is always a fallback option (~2–3 days)
- BL-024: llamadart validated on iOS simulator — no crashes, no memory warnings, clean lifecycle — but simulator is not real device
- BL-008: llama.cpp has a known Metal backend memory leak "when repeatedly initializing/freeing llama contexts" (severity: Medium)

**Mitigation Status: PARTIALLY MITIGATED**
- ✅ llamadart validated end-to-end on iOS simulator (BL-024) — build, load, infer, dispose all clean
- ✅ Custom Dart FFI is a documented fallback — llama.cpp C API has ~20 functions needed, well-documented pattern
- ✅ React Native + llama.rn remains a documented framework-level fallback (BL-015) with 3 explicit trigger conditions
- ⏳ Pending: Real-device validation during BL-003 (Metal GPU, memory pressure, thermal behavior)
- ⏳ Pending: Long-running session testing (10+ turns, repeated context creation/disposal)

---

### Risk 4: Android Floor Device GPU Performance (Severity: MEDIUM)

**Description:** The Android floor devices (Galaxy A53, A54 with Exynos/Mali GPUs; Pixel 6a with Tensor/Mali-G78) use Mali GPUs which show "unusually poor" LLM inference performance. CPU-only inference is the likely path for Android floor devices, which means performance will be lower than iOS devices with Metal GPU acceleration.

**Sources:**
- BL-014: "Mali GPUs show 'unusually poor' LLM inference performance in benchmarks (per arxiv:2410.03613). CPU-only inference via llama.cpp is likely the more reliable path for Android floor devices."
- BL-008: llama.cpp Android Mali GPU performance rated Medium severity issue

**Mitigation Status: PARTIALLY MITIGATED**
- ✅ llama.cpp supports ARM NEON CPU acceleration on Android — viable non-GPU path
- ✅ Android floor devices have 6 GB RAM (vs iOS 4 GB) — more memory headroom compensates for slower inference
- ✅ Gemma 3n's smaller memory footprint leaves more room for larger KV-cache, potentially enabling faster prefill
- ⏳ Pending: Actual Android floor device benchmarking during BL-003
- ⏳ Pending: If CPU decode <4 tok/s on Galaxy A53, evaluate Vulkan backend or smaller model (Qwen 2.5 1.5B) for Android-specific fallback

---

### Risk 5: Gemma 3n GGUF Stability via llama.cpp (Severity: MEDIUM)

**Description:** Gemma 3n's Per-Layer Embedding (PLE) architecture is novel — it reduces effective parameter count through selective activation. GGUF support for this architecture via llama.cpp is newer and less battle-tested than standard transformer models (Llama, Phi, Qwen). Quantization quality may not be preserved with the PLE architecture, and edge cases in llama.cpp's handling of PLE models could surface.

**Sources:**
- BL-008: "Gemma 3n GGUF support via llama.cpp is newer and less battle-tested than Llama family models. Need to verify quantization quality is preserved with the PLE architecture."
- BL-008: GGUF compatibility listed as "✅ GGUF via dynamic quantization" for Gemma 3n — confirmed available but flagged as requiring verification

**Mitigation Status: PARTIALLY MITIGATED**
- ✅ Llama 3.2 3B Q4_K_M designated as fallback — a standard transformer with extensive GGUF community validation
- ✅ llama.cpp's daily release cadence means Gemma 3n support is actively improving
- ⏳ Pending: Head-to-head quality comparison (Gemma 3n vs Llama 3.2 3B) during BL-003 on-device benchmarking
- ⏳ Pending: Verify Gemma 3n Q4_K_M GGUF maintains interactive fiction quality ≥3/5

---

## Tech Stack Summary

| Layer | Choice | Key Rationale |
|-------|--------|---------------|
| **Framework** | Flutter (≥3.38, stable) | Pixel-level CRT rendering, zero-bridge streaming, single-language team velocity |
| **Inference Runtime** | llamadart v0.6.7+ (llama.cpp via Dart FFI) | Auto-built binaries, Dart-first API, zero JS bridge overhead, universal GGUF model support |
| **Primary Model** | Gemma 3n E2B Q4_K_M (~1.2 GB effective) | Only 3B+-class model that fits comfortably within iOS 1,200 MB weight budget |
| **Fallback Model** | Llama 3.2 3B Instruct Q4_K_M (~2.0 GB) | Extensively validated GGUF, strong instruction-following, at iOS memory edge |
| **Emergency Fallback Model** | Qwen 2.5 1.5B Instruct Q4_K_M (~1.0 GB) | Comfortable memory fit on all devices; quality may be moderate but viable |
| **Model Format** | GGUF | Industry standard, widest HuggingFace availability, zero conversion pipeline |
| **GPU Backend** | Metal (iOS, automatic), Vulkan (Android, automatic), CPU fallback (Mali GPUs) | llama.cpp handles backend selection; Mali GPUs fall back to ARM NEON CPU |
| **Context Strategy** | 2,048 token window, ≤1,500 prompt token safe zone | BL-012 empirical quality cliff at ~2,500 tokens |
| **Streaming** | Token-by-token via Dart FFI callback → Stream → StreamBuilder | Non-negotiable per BL-014 latency analysis (6–17s total response time without streaming) |

---

## Cross-Reference Index

| Backlog Item | Artifact Path | What It Contributed to This ADR |
|-------------|---------------|-------------------------------|
| BL-008 | `/.godai/artifacts/BL-008-on-device-llm-sdk-maturity-research.md` | SDK comparison matrix, elimination rationale for MLC/MediaPipe/ONNX, model compatibility table, recommended pairings |
| BL-012 | `/prototype/FINDINGS.md` | Empirical quality baselines (1B=1/5, 3.8B=4/5), context collapse threshold (~2,500 tokens), suggestion format failure, mobile implications |
| BL-014 | `/.godai/artifacts/BL-014-target-device-specs-and-performance-budget.md` | Floor device specs, memory budgets (1,500 MB iOS / 1,800 MB Android), latency targets (≥4 tok/s, ≤3s TTFT), battery/thermal constraints, pass/fail thresholds |
| BL-015 | `/.godai/artifacts/BL-015-flutter-vs-react-native-framework-comparison.md` | 8-dimension framework evaluation (Flutter 5/RN 2), LLM integration analysis, risk assessment, fallback trigger conditions |
| BL-024 | `/.godai/artifacts/BL-024-llama-cpp-dart-ffi-ios-simulator-spike.md` | llamadart discovery and validation, FFI end-to-end proof, go/no-go decision for Flutter, performance metrics on simulator |

---

## Appendix: Decision Log

| Date | Decision | Deciding Evidence |
|------|----------|-------------------|
| 2026-03-23 | llama.cpp selected as inference SDK | BL-008: only SDK meeting all requirements (4GB iOS, active maintenance, broad model support) |
| 2026-03-23 | Flutter recommended over React Native | BL-015: 5/8 dimension wins including critical rendering and streaming |
| 2026-03-23 | Flutter go decision confirmed | BL-024: llamadart FFI spike passes all tests on iOS simulator |
| 2026-03-23 | llamadart replaces llama_cpp_dart as primary binding | BL-024: superior maturity (160 pts vs 130 pts, auto-built binaries vs manual compilation) |
| 2026-03-23 | Gemma 3n E2B recommended as primary model | BL-008 + BL-014: only 3B+-class model fitting within 1,200 MB iOS weight sub-budget |
| 2026-03-23 | MLC LLM, MediaPipe, ONNX Runtime eliminated | BL-008: MLC crashes on 4GB iPhones, MediaPipe deprecated, ONNX GenAI mobile nascent |
| 2026-03-25 | ADR formalized (this document) | BL-028: consolidation of all above into single authoritative reference |
