# On-Device LLM SDK Maturity for Mobile Interactive Fiction

> **BL-008** | Created: 2026-03-23 | Audience: founding team (framework selection)
>
> Purpose: De-risk BL-001 by surveying the production-viability of on-device LLM inference SDKs for mobile before spending time on hands-on benchmarks. This is desk research — no hands-on benchmarking was performed.

---

## 1. SDK Comparison Matrix

| Attribute | **llama.cpp** | **MLC LLM** | **MediaPipe LLM Inference** | **ONNX Runtime Mobile + GenAI** |
|---|---|---|---|---|
| **Maintainer** | ggml-org (Georgi Gerganov + community) | mlc-ai (Apache TVM team, Tianqi Chen) | Google AI Edge | Microsoft |
| **GitHub Stars** | ~99k | ~22.3k | ~34.3k (full MediaPipe repo) | ~19.6k (full ORT repo) |
| **Open Issues** | ~490 | ~280 | ~435 (full repo) | ~837 (full repo) |
| **Contributors** | 800+ | ~159 | Google-internal + community | Microsoft-internal + community |
| **Latest Release** | b8479 (2026-03-23) — daily releases | v0.1.dev0 (pre-release); uses rolling commits | v0.10.32 (2026-01-30) | v1.24.4 (2026-03-17) |
| **Release Cadence** | Daily automated builds | Irregular; commit-based | Monthly-ish | Quarterly major, monthly patches |
| **Primary Language** | C/C++ | Python (69%) + C++ | C++ (63%) | C++ (90%) |
| **iOS Support** | ✅ Metal GPU acceleration. Official Swift example app. Community bindings: llama.rn (React Native), llama_sdk (Flutter/Dart). New: KMP bindings (experimental). | ✅ Metal on Apple A-series GPU. Native Swift SDK with OpenAI-compatible API. MLC Chat app in App Store. | ✅ iOS via LLM Inference API. GPU (Metal) backend. Note: only Gemma 2B int4 confirmed stable on 4GB iPhones. **Deprecated — Google recommends migrating to LiteRT-LM.** | ✅ iOS via CoreML and XNNPACK accelerators. Obj-C bindings. Custom build reduces binary size. |
| **Android Support** | ✅ Full acceleration since Dec 2025 (new GUI binding). Kotlin Flow API. Supports ARM NEON + Vulkan. Official `llama.android` example. | ✅ OpenCL on Adreno and Mali GPUs. Android SDK with Java/Kotlin bindings. | ✅ Android via LLM Inference API. GPU (OpenCL) backend. Targets high-end devices (Pixel 8+, Galaxy S23+). **Deprecated — migrate to LiteRT-LM.** | ✅ Android via NNAPI, XNNPACK, and QNN accelerators. Java bindings. Gradle integration. |
| **Model Format** | GGUF | MLC (custom compiled format via TVM) | TFLite (.task / .litertlm bundles) | ONNX (with GenAI extensions) |
| **GPU Backend** | Metal (iOS), Vulkan (Android), OpenCL (experimental) | Metal (iOS), OpenCL (Android) | Metal (iOS), OpenCL (Android) | CoreML (iOS), NNAPI/QNN (Android) |
| **Streaming Support** | ✅ Token-by-token via callback | ✅ Token-by-token via API | ✅ Token-by-token | ✅ Token-by-token via GenAI API |
| **Quantization Support** | 1.5-bit through 8-bit (Q2_K, Q3_K, Q4_0, Q4_K_M, Q5_K, Q6_K, Q8_0, IQ variants) | q4f16_1, q4f32_1, q0f16, q0f32 | int4, int8 (via TFLite conversion) | INT4, INT8 (via model optimization) |
| **LoRA Support** | ✅ Runtime LoRA adapter loading | ✅ Via compilation | ✅ Gemma-2 2B, Gemma 2B, Phi-2 only | ✅ Via PEFT/LoRA fine-tuning |
| **Documentation Quality** | Good. Extensive docs, examples, community guides. Active GitHub Discussions. | Moderate. Official docs exist but sparse for mobile-specific usage. | Good for Android. iOS documentation thin. Deprecation notice adds uncertainty. | Good. Microsoft-quality docs. Mobile-specific guide exists but GenAI mobile docs are thinner. |
| **Community Activity** | Very high. Daily commits. Thousands of forks. Most active LLM inference project. | Moderate. Academic roots. Slower issue response times. | Moderate. Google-backed but LLM Inference is a small part of MediaPipe. Transitioning to LiteRT-LM. | High for ONNX Runtime overall. GenAI mobile is a newer sub-project with growing activity. |

### Key Takeaway

**llama.cpp is the clear leader** in maturity, community activity, release cadence, and breadth of model support. It is the only SDK with daily releases and a 99k-star community. MLC LLM offers a compelling GPU-accelerated alternative but has a smaller community and irregular releases. MediaPipe is being deprecated in favor of LiteRT-LM, creating migration risk. ONNX Runtime is solid infrastructure but its GenAI mobile story is still maturing.

---

## 2. Known Mobile-Specific Issues and Limitations

### llama.cpp

| Issue | Severity | Details |
|---|---|---|
| **iOS memory pressure / jetsam kills** | High | On 4GB iPhones, loading a 3B Q4_K_M model (~2 GB) via mmap pushes close to the ~2,048 MB jetsam limit. No graceful degradation — process is killed instantly. Requires careful memory budgeting (see BL-014). |
| **Metal backend memory leak** | Medium | Reported memory leak when repeatedly initializing/freeing llama contexts on Metal. Accumulates over many cycles. Workaround: avoid repeated context creation. |
| **iOS SwiftUI sampling crash** | Medium | Assertion failure when adding topK + topP to sampler chain in the SwiftUI sample app. May be fixed in recent releases. |
| **Android Mali GPU performance** | Medium | Mali GPUs (Galaxy A53/A54) show poor GPU inference performance. CPU-only inference via llama.cpp is the more reliable path for our Android floor devices. |
| **No NPU/DSP offload** | Low | llama.cpp does not leverage mobile NPUs (Apple Neural Engine, Qualcomm Hexagon). Pure CPU + GPU path only. This leaves performance on the table but avoids NPU API fragmentation. |
| **App binary size** | Low | C/C++ library compiles to ~5-15 MB depending on backends included. Minimal impact on app size. |
| **Background execution** | Medium | iOS suspends apps aggressively. Model must be kept warm via mmap but inference cannot run in background. Android similar but more lenient. |

### MLC LLM

| Issue | Severity | Details |
|---|---|---|
| **GPU OOM on 4GB devices** | Critical | MLC LLM crashes on 4GB iPhones. The team recommends "at least 6GB free VRAM." This **fails our iOS floor device requirement** (iPhone 11/12/SE all have 4GB total RAM). |
| **OpenCL buffer errors on Android** | High | Memory errors after opening models on Android. OpenCL errors with invalid buffer sizes. Requires careful GPU memory utilization tuning. |
| **Model compilation complexity** | High | Models must be compiled to MLC format using TVM. This is a non-trivial toolchain step that adds friction when testing new models. No GGUF/ONNX direct loading. |
| **Irregular releases** | Medium | Only one official release tag (v0.1.dev0). Developers must build from source/commit hashes. Makes reproducible builds harder. |
| **Prefill slower than llama.cpp** | Medium | Benchmarks show MLC prefill speed is slower than llama.cpp on CPU, which impacts TTFT. Decode speed can be faster on GPU-equipped devices. |
| **Limited community support** | Medium | ~159 contributors vs llama.cpp's 800+. Issue response times are slower. Academic project feel. |

### MediaPipe LLM Inference

| Issue | Severity | Details |
|---|---|---|
| **Deprecated — migrate to LiteRT-LM** | Critical | Google officially recommends migrating to LiteRT-LM. Continuing to build on MediaPipe LLM Inference means building on a deprecated foundation. |
| **Limited model support** | High | Only supports Gemma, Phi-2, Falcon-RW-1B, and StableLM-3B. Cannot easily add new models without conversion pipeline work. |
| **iOS: only Gemma 2B int4 confirmed** | High | On 4GB iPhones, only Gemma 2B at int4 runs reliably. Other models cause memory issues. |
| **Targets high-end devices** | High | Documentation explicitly states "optimized for high-end Android devices, such as Pixel 8 and Samsung S23 or later." Our floor devices (Galaxy A53, Pixel 6a) are below this tier. |
| **LiteRT-LM is early preview** | Medium | The successor (LiteRT-LM v0.6.1, released June 2025) only supports CPU and Android GPU initially. iOS GPU support is immature. Migration path is unclear. |
| **Complex model conversion** | Medium | Models must be converted to TFLite flatbuffers using MediaPipe Python package. Non-trivial pipeline. |

### ONNX Runtime Mobile + GenAI

| Issue | Severity | Details |
|---|---|---|
| **GenAI mobile is nascent** | High | The onnxruntime-genai extension for mobile LLM inference is relatively new. Most production deployments are desktop/server. Mobile GenAI examples are limited. |
| **Model conversion overhead** | Medium | Models must be converted to ONNX format and then optimized for mobile (ORT format). Two-step pipeline with potential compatibility issues. |
| **Binary size without custom build** | Medium | Full ORT package is large. Custom builds are needed to reduce binary size for mobile, adding build complexity. |
| **Fewer community benchmarks** | Medium | Very few community benchmarks for ONNX Runtime GenAI specifically on mobile phones. Most benchmarks are desktop/server. |
| **QNN accelerator is Qualcomm-only** | Low | The best Android acceleration (QNN) only works on Snapdragon devices. Our Galaxy A53/A54 (Exynos) would fall back to XNNPACK/CPU. |
| **NNAPI deprecation concerns** | Low | Google is deprecating NNAPI in favor of newer APIs. Long-term Android acceleration path for ORT is uncertain. |

---

## 3. Model Compatibility Table — Small Models (<4GB)

The following models are viable candidates for our use case (interactive fiction on mobile, ≤3B params at Q4, ≤2GB file size per BL-014 constraints).

### Model Overview

| Model | Parameters | Q4_K_M Size (est.) | Quality for IF | Notes |
|---|---|---|---|---|
| **Phi-3-mini** | 3.8B | ~2.2 GB | Good (4/5 per BL-012) | Microsoft. Strong reasoning. Collapsed at turn 6+ in BL-012 testing due to context pressure. Slightly over our 2GB limit at Q4_K_M. |
| **Llama 3.2 3B Instruct** | 3.0B | ~2.0 GB | Expected good | Meta. Multilingual. At the absolute edge of our iOS memory budget. |
| **Gemma 3n E2B** | 5B raw / ~2B effective | ~1.2 GB effective | Expected good | Google. Mobile-first design. Per-Layer Embedding reduces memory to ~2GB. Multimodal capable. |
| **Qwen 2.5 1.5B Instruct** | 1.5B | ~1.0 GB | Moderate | Alibaba. Good reasoning for size. Multilingual (29 languages). Fast inference. |
| **Phi-4-mini** | 3.8B | ~2.2 GB | Expected very good | Microsoft. Beats GPT-4o on math benchmarks. Slightly over 2GB limit. |
| **SmolLM3 3B** | 3.0B | ~1.9 GB | Unknown | HuggingFace. Recent release. Community benchmarks pending. |
| **Llama 3.2 1B Instruct** | 1.0B | ~0.7 GB | Low-moderate | Meta. Very fast (30-50 tok/s). Quality may be insufficient for IF (compare TinyLlama 1/5 in BL-012). |

### Format Compatibility per SDK

| Model | llama.cpp (GGUF) | MLC LLM (MLC format) | MediaPipe (TFLite) | ONNX Runtime (ONNX) |
|---|---|---|---|---|
| **Phi-3-mini 3.8B** | ✅ Native GGUF on HuggingFace | ✅ Supported, needs compilation | ⚠️ Phi-2 supported, Phi-3 requires conversion | ✅ Official ONNX models from Microsoft |
| **Llama 3.2 3B** | ✅ Native GGUF on HuggingFace | ✅ Supported (q4f16_1, q4f32_1) | ❌ Not in supported model list | ✅ Supported via onnxruntime-genai |
| **Gemma 3n E2B** | ✅ GGUF via dynamic quantization | ⚠️ Likely needs custom compilation | ✅ Native Google model, LiteRT-LM support | ⚠️ Would need conversion, untested |
| **Qwen 2.5 1.5B** | ✅ Native GGUF on HuggingFace | ✅ Supported (multiple quant levels) | ❌ Not in supported model list | ⚠️ Community ONNX conversions exist |
| **Phi-4-mini 3.8B** | ✅ Native GGUF on HuggingFace | ⚠️ Likely supported, needs verification | ❌ Not in supported model list | ✅ Expected official ONNX from Microsoft |
| **SmolLM3 3B** | ✅ GGUF available on HuggingFace | ⚠️ Would need compilation | ❌ Not in supported model list | ⚠️ Would need conversion |
| **Llama 3.2 1B** | ✅ Native GGUF on HuggingFace | ✅ Supported | ❌ Not in supported model list | ✅ Supported via onnxruntime-genai |

**Legend:** ✅ = confirmed support, ⚠️ = likely possible but requires work/verification, ❌ = not supported or not feasible

### Key Observations

1. **llama.cpp has universal model support.** Every model on HuggingFace with GGUF files works immediately. No compilation or conversion pipeline needed. This is a massive advantage for rapid experimentation.
2. **MLC LLM requires compilation** for each model, which adds friction but enables GPU-specific optimizations.
3. **MediaPipe has the narrowest model support** — essentially limited to Gemma and a handful of older models. This is a dealbreaker for flexibility.
4. **ONNX Runtime has good support for Microsoft models** (Phi family) and Meta models (Llama) but less ecosystem breadth than GGUF.

---

## 4. Recommended Shortlist: 2 SDK+Model Pairings to Benchmark First

### Recommendation 1: llama.cpp + Llama 3.2 3B Instruct (Q4_K_M GGUF)

**Rationale:**

| Factor | Assessment |
|---|---|
| **SDK maturity** | Highest of all candidates. 99k stars, daily releases, 800+ contributors. Battle-tested on mobile. |
| **Mobile readiness** | Full Android acceleration since Dec 2025 (Kotlin Flow API). iOS Metal support mature. Official mobile example apps. |
| **Model quality** | Llama 3.2 3B is Meta's purpose-built small model with strong instruction-following. Expected to perform well for interactive fiction based on BL-012's finding that 3B+ models are the minimum viable tier. |
| **Memory fit** | 3B Q4_K_M = ~2.0 GB GGUF. At the edge of iOS budget but within BL-014 thresholds. mmap loading keeps RSS manageable. |
| **Ecosystem** | GGUF format is the industry standard for local inference. Largest selection of quantized models on HuggingFace. Zero conversion friction. |
| **Risk** | Medium. The 2.0 GB file size is at the iOS memory edge. If it doesn't fit, can fall back to Qwen 2.5 1.5B (~1.0 GB) with the same SDK. |
| **Cross-platform bindings** | React Native (llama.rn), Flutter/Dart (llama_sdk), KMP (experimental), native Swift/Kotlin. Matches any framework choice. |

**Why this pairing first:** llama.cpp is the safest SDK bet — it has the most momentum, the broadest model support, and the simplest model acquisition pipeline (download GGUF, load, infer). Llama 3.2 3B is the strongest general-purpose 3B model from a major lab with explicit small-model optimization. This pairing tests the "can we run a quality 3B model on our floor devices?" question with minimal SDK risk.

---

### Recommendation 2: llama.cpp + Gemma 3n E2B (Q4_K_M GGUF)

**Rationale:**

| Factor | Assessment |
|---|---|
| **SDK maturity** | Same as above — llama.cpp. Reusing the same SDK reduces integration risk and keeps the variable to just the model. |
| **Model quality** | Gemma 3n is Google's purpose-built mobile-first model. Per-Layer Embedding architecture reduces effective memory footprint to ~2B equivalent while maintaining 5B-class quality. This could be the "cheat code" that solves our iOS memory constraint. |
| **Memory fit** | ~1.2 GB effective memory at Q4 — well within both iOS (1,500 MB budget) and Android (1,800 MB budget) per BL-014. Significantly more headroom than Llama 3.2 3B. |
| **Mobile optimization** | Designed from the ground up for phones. Google claims 0.75% battery per session on Gemma 3. Selective parameter activation is a game-changer for memory-constrained devices. |
| **Risk** | Medium. Gemma 3n GGUF support via llama.cpp is newer and less battle-tested than Llama family models. Need to verify quantization quality is preserved with the PLE architecture. |
| **Format** | Dynamic GGUF available. Compatible with llama.cpp, Ollama, and downstream tools. |

**Why this pairing second:** Gemma 3n E2B directly addresses our #1 constraint (RAM) with its parameter-efficient architecture. If it delivers quality comparable to a standard 3B model at ~60% of the memory cost, it becomes the frontrunner. Testing it on the same SDK (llama.cpp) isolates the model variable and makes comparison clean. If Gemma 3n's GGUF quality is strong, it may resolve the iOS memory tension that BL-014 identified as the critical risk.

---

### Why Not MLC LLM, MediaPipe, or ONNX Runtime?

| SDK | Elimination Rationale |
|---|---|
| **MLC LLM** | Crashes on 4GB iPhones (our entire iOS floor). Would require 6GB+ free VRAM which is impossible on iPhone 11/12/SE. Additionally, model compilation toolchain adds friction for rapid experimentation. Could revisit if llama.cpp hits a performance wall on Android GPU — MLC's OpenCL backend may offer a decode speed advantage on Adreno GPUs specifically. |
| **MediaPipe LLM Inference** | Deprecated by Google in favor of LiteRT-LM. LiteRT-LM itself is early preview (v0.6.1). Building on a deprecated SDK with an immature successor is unacceptable risk for a shipping product. Additionally, the supported model list is too narrow (no Llama, no Qwen, limited Phi support). |
| **ONNX Runtime Mobile** | GenAI mobile story is still maturing. Fewer community benchmarks on actual phones. Model conversion pipeline (PyTorch → ONNX → ORT mobile format) adds friction. QNN acceleration is Qualcomm-only, leaving our Exynos floor devices on slower XNNPACK. Could revisit if Microsoft ships a polished mobile GenAI SDK — their Phi model optimization expertise is strong. |

---

## Appendix: Data Sources

- llama.cpp GitHub: https://github.com/ggml-org/llama.cpp (99k stars, b8479 release 2026-03-23)
- MLC LLM GitHub: https://github.com/mlc-ai/mlc-llm (22.3k stars)
- MediaPipe GitHub: https://github.com/google-ai-edge/mediapipe (34.3k stars, v0.10.32)
- ONNX Runtime GitHub: https://github.com/microsoft/onnxruntime (19.6k stars, v1.24.4)
- LiteRT-LM GitHub: https://github.com/google-ai-edge/LiteRT-LM
- Mobile LLM benchmarks: arxiv:2410.03613 (Understanding LLMs in Your Pockets)
- Comparative framework study: arxiv:2511.05502 (MLX vs MLC-LLM vs Ollama vs llama.cpp)
- BL-012 prototype findings (Phi-3-mini 3.8B: 4/5 quality, context collapse at turn 6+; TinyLlama 1.1B: 1/5 quality)
- BL-014 target device specs (iOS 4GB floor, 1,500 MB inference budget, ≤2.0 GB model file)
- Best Small Language Models March 2026: https://localaimaster.com/blog/small-language-models-guide-2026
- MediaPipe LLM Inference deprecation: https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference
- LiteRT-LM announcement: https://developers.googleblog.com/on-device-genai-in-chrome-chromebook-plus-and-pixel-watch-with-litert-lm/
- Gemma 3n GGUF guide: https://www.gemma-3n.net/blog/gemma-3n-gguf-quantization-complete-guide/
- llama.cpp Android binding (Dec 2025): https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md
