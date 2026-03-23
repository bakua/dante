# Target Device Spec Sheet & Performance Budget

> **BL-014** | Created: 2026-03-23 | Audience: founding team (benchmarking & architecture decisions)
>
> Purpose: Provide quantitative pass/fail thresholds for BL-001 benchmarking and BL-003 architecture decisions. Without these numbers, there is no objective way to decide if a model "works" on mobile.

---

## 1. Target Device Floor

The "floor" is the weakest device we commit to supporting. Any model/runtime combo that fails on a floor device is a hard reject. Devices were selected based on: (a) still-significant market share in early 2026, (b) representing the low end of what users reasonably still carry, and (c) having known LLM inference limitations that stress-test our design.

### iOS Floor Devices

| Device | SoC | RAM | Base Storage | Neural Engine | NPU TOPS (est.) | Market Context |
|--------|-----|-----|-------------|---------------|-----------------|----------------|
| **iPhone 11** | A13 Bionic | 4 GB | 64 GB | 8-core | ~5.5 TOPS | Released 2019. Still in active use globally. Oldest device still receiving iOS 17+. Represents the true performance floor for iOS. |
| **iPhone 12** | A14 Bionic | 4 GB | 64 GB | 16-core | 11 TOPS | Released 2020. 5G-capable entry point. 4GB RAM is the binding constraint — identical to iPhone 11. |
| **iPhone SE (2022)** | A15 Bionic | 4 GB | 64 GB | 16-core | 15.8 TOPS | Released 2022. Has the most powerful SoC of the three, but the same 4GB RAM constraint. Sold as the budget iPhone — guarantees a large install base among price-sensitive users. |

**Key iOS constraint:** All three floor devices have **4 GB RAM**. iOS jetsam (the kernel memory manager) enforces a hard per-process memory limit of approximately **2,048 MB (~2 GB)** on 4GB devices. This is the single most critical constraint for on-device inference on iOS.

**NPU note:** A13's Neural Engine is ~5.5 TOPS; A14 is 11 TOPS; A15 is 15.8 TOPS. While NPU acceleration for LLM inference (via Core ML or similar) is still maturing, the A13 represents the performance floor for any NPU-accelerated path.

### Android Floor Devices

| Device | SoC | RAM | Base Storage | GPU | NPU | Market Context |
|--------|-----|-----|-------------|-----|-----|----------------|
| **Samsung Galaxy A53** | Exynos 1280 | 6 GB | 128 GB | Mali-G68 | Weak (no dedicated AI accelerator) | Samsung's A-series is the best-selling Android line globally. A53 remains widely used in 2025-2026, especially in price-sensitive markets. |
| **Google Pixel 6a** | Google Tensor (1st gen) | 6 GB | 128 GB | Mali-G78 | TPU-derived (good ML perf) | Budget Pixel with Google's custom Tensor chip. 6GB RAM is the constraint. Represents the "developer reference" floor — Google's own budget hardware. |
| **Samsung Galaxy A54** | Exynos 1380 | 6 GB | 128 GB | Mali-G68 MC4 | Improved over A53 | Direct successor to A53 with ~20% faster CPU. Available in 8GB variant in some regions, but 6GB is the floor config. Expandable storage up to 1TB via microSD. |

**Key Android constraint:** All three floor devices have **6 GB RAM**. Android's per-app memory budget on a 6GB device is typically **1.5–2.5 GB** depending on manufacturer configuration and background pressure. The `largeHeap` manifest flag can increase this, but we should not depend on more than ~2 GB reliably.

**GPU note:** Mali GPUs show "unusually poor" LLM inference performance in benchmarks (per academic evaluation, arxiv:2410.03613). CPU-only inference via llama.cpp is likely the more reliable path for Android floor devices. Adreno GPUs (Snapdragon) perform ~1.6x better for decode, but our floor devices use Mali.

---

## 2. Memory Budget

### RAM Budget for Inference

| Platform | Total RAM | OS + Background Overhead | Hard Per-App Limit | Safe Inference Budget | Notes |
|----------|-----------|-------------------------|--------------------|-----------------------|-------|
| **iOS (4GB floor)** | 4 GB | ~1.5–2 GB | ~2,048 MB (jetsam) | **1,500 MB** | Must leave headroom for app UI, KV-cache, and buffers within the jetsam limit. Exceeding limit = instant kill (no warning). |
| **Android (6GB floor)** | 6 GB | ~2–3 GB | ~2,000–2,500 MB | **1,800 MB** | Varies by OEM. Samsung's memory management is aggressive. Budget conservatively. |

**Breakdown of the inference memory budget:**

| Component | Budget (iOS) | Budget (Android) | Notes |
|-----------|-------------|------------------|-------|
| Model weights (GGUF) | ≤1,200 MB | ≤1,400 MB | Loaded via mmap; counts against memory pressure |
| KV-cache | ~150–200 MB | ~150–200 MB | Scales with context length; budget for 2048 tokens |
| Inference buffers | ~50–100 MB | ~50–100 MB | Scratch space for computation |
| App UI + framework | ~100–150 MB | ~150–200 MB | Flutter/RN runtime, UI textures, etc. |
| **Total** | **≤1,500 MB** | **≤1,800 MB** | Hard ceiling — exceeding triggers OOM kill |

### Model File Size Budget (Disk)

| Constraint | Value | Rationale |
|------------|-------|-----------|
| **Max model file size** | **2.0 GB** | Mid-range floor devices ship with 64 GB (iOS) or 128 GB (Android). Typical free space after OS + apps: ~20–40 GB. A 2 GB model is <5% of available space — acceptable for a game download. |
| Target model file size | ≤1.5 GB | Better for app store download size perception and faster initial setup |
| Initial download ceiling | 2.5 GB | Maximum total download including model + app bundle. Beyond this, app store conversion drops significantly. |

### Derived Maximum Model Size

Given the RAM and disk constraints:

| Quantization | Max Parameters | File Size (est.) | RAM at Load (est.) | Viable? |
|-------------|---------------|-------------------|--------------------| --------|
| Q4_K_M (4-bit) | **3B** | ~2.0 GB | ~2.0 GB | ✅ Fits Android; **tight on iOS** — needs mmap + careful buffer management |
| Q4_K_M (4-bit) | 1.5B | ~1.0 GB | ~1.2 GB | ✅ Comfortable on both platforms |
| Q4_K_M (4-bit) | 7B | ~4.5 GB | ~4.5 GB | ❌ Exceeds both RAM and disk budgets |
| Q8_0 (8-bit) | 3B | ~3.5 GB | ~3.5 GB | ❌ Exceeds iOS RAM limit |
| Q4_K_M (4-bit) | 1B | ~0.7 GB | ~0.9 GB | ✅ Easy fit; quality may be insufficient (see BL-012 findings: TinyLlama 1.1B scored 1/5) |

**Hard limit: Model must be ≤3B parameters at Q4 quantization (≤2 GB GGUF file).**

**Recommended sweet spot: 1.5B–3B parameters at Q4_K_M quantization (1.0–2.0 GB file).**

This aligns with BL-012 findings: Phi-3-mini 3.8B showed good quality (4/5) for the first 5 turns but collapsed at turn 6+ due to context pressure. A well-tuned 3B model at Q4 is at the absolute edge of iOS viability.

---

## 3. Latency Budget

### Token Generation Speed (Decode)

| Metric | Hard Floor | Target | Ideal | UX Rationale |
|--------|-----------|--------|-------|--------------|
| **Decode tokens/sec** | **≥4 tok/s** | **≥8 tok/s** | ≥12 tok/s | Human comfortable reading speed is ~250 WPM ≈ ~5.5 tokens/sec. At 4 tok/s the typewriter effect feels "deliberate but readable." Below 4 tok/s, text feels painfully slow and users disengage. At 8+ tok/s, text flows naturally. |

**Empirical reference points** (from arxiv:2410.03613 and BL-012):
- Snapdragon 870 (mid-tier, 2021): ~1.6 tok/s with 7B Q4 — too slow, but a 3B model would roughly double this
- Cortex-A76/A77 (Armv8-A): 2–4 tok/s with 7B Q4 — borderline with 7B, likely ~5-8 tok/s with 3B
- Apple A13/A14 (iPhone 11/12): estimated ~6-10 tok/s with 3B Q4 (extrapolated from M1 benchmarks)
- Newer Armv9-A chips (Cortex-X4): comparable to Apple performance

**Pass/fail threshold for BL-001: A model/runtime combination PASSES if it achieves ≥4 tok/s decode on both the iPhone 11 AND the Galaxy A53. Target is ≥8 tok/s.**

### Time-to-First-Token (TTFT)

| Metric | Hard Floor | Target | Ideal | UX Rationale |
|--------|-----------|--------|-------|--------------|
| **TTFT** | **≤3.0 s** | **≤1.5 s** | ≤0.5 s | Per Nielsen's response time research: <0.1s feels instant, <1.0s maintains flow of thought, <10s holds attention. For a text adventure, the player submits a command and waits for the story to continue. 3s feels like "the game is thinking" (acceptable with a visual indicator). Beyond 3s, players will assume the app froze. Target of 1.5s feels responsive for a "Game Master pondering your action." |

**TTFT depends heavily on prompt length.** With aggressive context windowing (per BL-012: safe zone ~1,500 prompt tokens), TTFT should stay well under the 3s ceiling. TTFT grows roughly linearly with prompt token count on CPU inference.

### Model Load Time (Cold Start)

| Metric | Hard Floor | Target | Notes |
|--------|-----------|--------|-------|
| **Cold start load** | **≤8 s** | **≤4 s** | Time from app launch to first inference-ready state. Includes model file mmap/load and initial warmup. Can be masked with a splash screen / "booting terminal" animation. Beyond 8s, users may force-quit. |
| **Warm resume** | ≤1 s | ≤0.5 s | Model already in memory from previous session. Should be near-instant. |

### End-to-End Response Latency

For a typical game turn (player submits command → full response visible):

| Metric | Value | Derivation |
|--------|-------|------------|
| Prompt processing | 0.5–1.5 s | ~1,500 prompt tokens at 1,000–3,000 tok/s prefill |
| TTFT | included in above | First token appears as soon as prefill completes |
| Response generation | 5–15 s | 50–120 output tokens at 4–8 tok/s decode |
| **Total perceived time** | **6–17 s** | But with streaming typewriter, player is reading from TTFT onward — perceived wait is only the TTFT |

**This is why streaming is non-negotiable.** Without streaming, the player waits 6–17 seconds staring at nothing. With streaming, they wait ≤3 seconds for the first character and then read along naturally.

---

## 4. Battery & Thermal Budget

### Power Draw

| Metric | Hard Floor | Target | Rationale |
|--------|-----------|--------|-----------|
| **Sustained inference power** | **≤6 W** | **≤4 W** | Mobile SoCs have a thermal design power (TDP) of ~5-7W sustained before throttling. At 6W, we're at the thermal ceiling — device will be warm but not throttling. At 4W, comfortable sustained use. |
| **Peak power (prefill burst)** | ≤8 W | ≤6 W | Prefill is compute-bound and spikes power. Brief spikes (1-2s) are acceptable. |

### Battery Drain

| Metric | Hard Floor | Target | Rationale |
|--------|-----------|--------|-----------|
| **Drain per 30-min session** | **≤15%** | **≤10%** | A typical mobile game session is 15-30 minutes. If the game drains >15% in 30 min, users will avoid playing unless plugged in. At 10%, it's comparable to video streaming — acceptable. |
| **Drain per hour of active play** | ≤25% | ≤18% | For extended sessions. At 25%/hr, a full battery gives ~4 hours — barely acceptable. At 18%/hr, ~5.5 hours — good. |

**Calculation basis:** Mid-range phone battery ~4,000–5,000 mAh at ~3.8V ≈ 15–19 Wh. At 4W sustained draw, that's ~4–5 hours total. But inference is intermittent (player reads, types, thinks between turns), so effective duty cycle is ~30–50%. Realistic drain: ~2W average → ~8–10 hours of gameplay.

### Thermal Throttling

| Constraint | Value | Impact |
|-----------|-------|--------|
| **Max sustained junction temp** | <65°C | Above this, SoCs begin aggressive frequency throttling. Tokens/sec drops 30-50%. |
| **Thermal throttling detection** | Required | The app should detect thermal state via platform APIs and either: (a) reduce context length, (b) increase inter-turn cooldown, or (c) warn the user. |
| **Inference duty cycle** | ≤50% of wall time | Between player input, reading, and thinking, inference should not run continuously. Natural game pacing helps. If a player rapid-fires commands, consider a brief cooldown or shorter responses. |

### Thermal Mitigation Strategies

1. **Natural game pacing:** Interactive fiction has built-in pauses (reading time, typing time). Average turn cycle is ~30-60 seconds, of which only ~5-15 seconds is active inference. This gives ~50-80% idle time for cooling.
2. **Adaptive response length:** If thermal state is elevated, generate shorter responses (fewer output tokens = less decode time = less heat).
3. **Context window management:** Smaller prompts = faster prefill = less energy per turn. Aggressive context windowing (per BL-012: safe zone ~1,500 tokens) naturally helps.

---

## Summary: Pass/Fail Thresholds for BL-001 Benchmarking

| Metric | PASS Threshold | FAIL Threshold | Notes |
|--------|---------------|----------------|-------|
| Model file size | ≤2.0 GB | >2.5 GB | Must fit comfortably on 64GB device |
| RAM usage (inference) | ≤1,500 MB (iOS) / ≤1,800 MB (Android) | >2,000 MB on either platform | Exceeding = jetsam kill / OOM |
| Decode speed | ≥4 tok/s on floor devices | <3 tok/s on any floor device | Below 3 tok/s is unusable for typewriter UX |
| Time-to-first-token | ≤3.0 s with 1,500-token prompt | >5.0 s | Beyond 5s, users assume crash |
| Cold start load time | ≤8 s | >12 s | With splash screen masking |
| Quality (subjective) | ≥3/5 for interactive fiction (per BL-012 rubric) | <2/5 | Must maintain coherent scene, respond to commands meaningfully |
| Battery drain (30 min) | ≤15% | >20% | Measured during active gameplay |

### Priority Order for Trade-offs

When constraints conflict, optimize in this order:

1. **RAM usage** — exceeding memory limits crashes the app (unrecoverable UX failure)
2. **Quality** — a fast but incoherent Game Master is worse than a slow but good one
3. **Decode speed** — directly affects moment-to-moment UX
4. **TTFT** — can be partially masked with UI animations
5. **Battery/thermal** — users will tolerate some drain for a good experience
6. **Model file size** — one-time download cost, least important in moment-to-moment UX

---

## Appendix: Data Sources & Methodology

- Device specs: GSMArena, PhoneArena, Apple Support, Wikipedia
- iOS memory limits: Apple Developer Forums (jetsam documentation), developer community measurements
- Android memory limits: Android Developer documentation (`getMemoryClass()`, `largeHeap`)
- LLM benchmarks: arxiv:2410.03613 (mobile LLM benchmarking study, 2024), BL-012 prototype findings
- UX latency thresholds: Jakob Nielsen's response time research (NNGroup), Redis LLM UX guide, various TTFT research
- NPU performance: hollance/neural-engine GitHub documentation, Apple press materials
- Market share: TelemetryDeck iPhone model share (Feb 2026), GSMArena top phones 2025, StatCounter
- Battery/power: MNN-AECS energy optimization paper (arxiv:2506.19884), on-device LLM state of the union (2026)
- Model file sizes: Hugging Face model repositories (Llama-3.2-3B-Instruct-Q4_K_M-GGUF: 2.02 GB)
