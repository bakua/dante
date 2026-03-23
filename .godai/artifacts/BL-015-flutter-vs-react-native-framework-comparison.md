# Flutter vs React Native Framework Comparison for DANTE TERMINAL

> **BL-015** | Created: 2026-03-23 | Audience: founding team (framework selection before BL-002)
>
> Purpose: Inform the framework choice for DANTE TERMINAL's cross-platform scaffold. Evaluates Flutter and React Native across 8 dimensions specific to this project's needs — a retro terminal text adventure powered by on-device LLM inference. Cross-references BL-008 (SDK maturity), BL-012 (prototype findings), and BL-014 (device constraints).

---

## 1. Evaluation Matrix

| # | Dimension | Flutter | React Native | Winner |
|---|-----------|---------|-------------|--------|
| 1 | **LLM SDK integration paths** | Dart FFI calls llama.cpp C API directly. Primary package: `llama_cpp_dart` (v0.2.2, 76 likes, 130 pub pts, Jan 2026). Also: `fllama` (v0.0.1, stale). No JS bridge overhead — native C calls from Dart isolate. | `llama.rn` (v0.11.4, 871 stars, Mar 2026) — mature, actively maintained RN binding for llama.cpp. Metal + OpenCL + Hexagon NPU. Requires New Architecture (v0.10+). Vercel AI SDK integration. | **React Native** — llama.rn is more battle-tested (871★ vs 76 likes), more frequently updated, and has production deployments. |
| 2 | **Custom text rendering** (monospace, green-on-black, CRT effects) | Renders every pixel via Impeller/Skia engine — no native widget layer. Full `Canvas` API for scanlines, phosphor glow, CRT curvature, vignette. Custom `TextPainter` for monospace with per-character control. Shader support via `FragmentProgram` for post-processing effects. | Renders through native platform views. Custom CRT effects require `react-native-skia` (adds Skia dependency) or `react-native-canvas`. Monospace text is straightforward but scanline/glow effects need extra native modules. New Architecture (Fabric) improves but doesn't eliminate this gap. | **Flutter** — pixel-level rendering is built-in, not bolted on. CRT effects are first-class via shaders and canvas. |
| 3 | **Text streaming / typewriter display** | `StreamBuilder` + `setState` per character — zero bridge overhead. Rendering happens on the same pipeline as the animation. Packages: `animated_text_kit`, `typewritertext`. Dart `Isolate` feeds tokens from llama.cpp FFI without blocking UI thread. | `llama.rn` streams tokens via JS callback. Each token crosses the JSI bridge (fast but non-zero cost). Packages: `react-native-typewriter`, `react-native-type-animation`. Reanimated worklets can handle animation on UI thread. | **Flutter** — no bridge hop between token arrival and pixel update. Simpler architecture for streaming display. |
| 4 | **Offline data persistence** | `path_provider` for filesystem paths. `Hive` or `ObjectBox` for game state. `sqflite` for structured data. Large model files via `dart:io` File API — direct filesystem access, no bridge. Isolates handle file I/O without blocking UI. | `react-native-fs` for filesystem. `MMKV` (30× faster than AsyncStorage) or `react-native-sqlite-storage` for game state. Large model files work but JS bridge adds overhead for file metadata operations. | **Flutter** — marginally better for large file handling (no bridge overhead), but both are fully capable. Slight edge. |
| 5 | **App binary size baseline** | ~15–20 MB baseline (includes Impeller/Skia engine + ICU data). + ~5–15 MB for llama.cpp native lib. **Total estimate: ~25–35 MB** before model. | ~8–12 MB baseline (uses native platform rendering). + ~5–15 MB for llama.rn native lib. **Total estimate: ~18–27 MB** before model. Expo adds ~10 MB overhead (avoid for this project). | **React Native** — ~7 MB smaller baseline. But model download is 1–2 GB, making the ~7 MB gap irrelevant in practice. |
| 6 | **Hot reload & dev velocity** | Hot reload in 0.4–0.8s, preserves widget state. Single language (Dart) for all code — UI, logic, FFI declarations. "Do everything in Dart" — simpler mental model. Teams report 30–40% faster iteration vs legacy approaches. | Fast Refresh via JSI — reliable in New Architecture. JavaScript/TypeScript familiar to more developers. But native module changes require full rebuild. Split between JS and native code complicates debugging. | **Flutter** — faster reload, single-language stack, simpler for a 2-person team. React Native's edge in hiring pool is irrelevant for our team size. |
| 7 | **Platform API access** (filesystem for model storage) | Platform channels + Dart FFI for native APIs. `path_provider` covers app documents/cache dirs. Direct FFI to C libraries. Less boilerplate than RN for C/C++ integration. | Turbo Native Modules (New Architecture) for native APIs. `react-native-fs` for filesystem. `llama.rn` already handles model file loading. More mature native module ecosystem overall. | **Tie** — both have full platform access. Flutter's FFI is cleaner for C libraries; RN has more pre-built native modules. |
| 8 | **Community & ecosystem health** | ~165k GitHub stars. 46% cross-platform market share (Statista 2026). ~45k packages on pub.dev. Google-backed. Flutter Favorites curation program. Very active community. | ~116k GitHub stars. 35–38% cross-platform share. Access to 2M+ npm packages. Meta-backed. Larger hiring pool. More production apps in market. | **Flutter** — higher community momentum, but React Native has deeper ecosystem breadth. Flutter wins on trajectory; RN wins on existing ecosystem. **Slight Flutter edge** for new projects. |

### Score Summary

| Dimension | Flutter | React Native |
|-----------|---------|-------------|
| LLM SDK integration | ○ | ● |
| Custom text rendering | ● | ○ |
| Text streaming / typewriter | ● | ○ |
| Offline data persistence | ● | ○ |
| App binary size | ○ | ● |
| Hot reload & dev velocity | ● | ○ |
| Platform API access | ◐ | ◐ |
| Community & ecosystem | ● | ○ |

**Flutter: 5 wins, 1 tie. React Native: 2 wins, 1 tie.**

---

## 2. LLM Integration Analysis

BL-008 evaluated 4 SDK candidates. Here is the integration path for each into both frameworks:

### 2.1 llama.cpp (BL-008 Recommendation — primary SDK)

| Aspect | Flutter | React Native |
|--------|---------|-------------|
| **Primary binding** | `llama_cpp_dart` v0.2.2 (pub.dev, MIT, Jan 2026). 3 abstraction levels: raw FFI, high-level wrapper, managed Isolate. | `llama.rn` v0.11.4 (npm, MIT, Mar 2026). C++ Turbo Module with JSI. 871 GitHub stars. |
| **Alternative bindings** | `fllama` v0.0.1 (stale, Nov 2024). `llamafu` (newer, layered architecture). Custom FFI via `dart:ffi` + `ffigen`. | `@react-native-ai/llama` (Vercel AI SDK provider). `cui-llama.rn` (community fork). |
| **GPU acceleration** | Metal (iOS) via llama.cpp Metal backend. Vulkan (Android) available but Mali GPUs underperform (BL-014). | Metal (iOS), OpenCL (Android, Adreno 700+), Hexagon NPU (experimental). |
| **Streaming tokens** | FFI callback → Dart `Stream` → `StreamBuilder` widget. Runs in `Isolate` to avoid UI jank. | C++ callback → JSI → JS callback → React state update. Token-by-token. |
| **Model loading** | `dart:io` File API reads GGUF from app documents dir. mmap supported by llama.cpp internally. | `react-native-fs` or llama.rn's built-in model path handling. mmap supported. |
| **Build complexity** | Need to compile llama.cpp as static lib for iOS/Android, bundle via FFI plugin. `ffigen` generates Dart bindings. Well-documented Flutter FFI pattern. | llama.rn bundles pre-compiled native libs. `pod install` (iOS) + Gradle (Android). Simpler initial setup, but requires New Architecture. |
| **Maturity assessment** | **Medium.** `llama_cpp_dart` is actively maintained but community-driven (unverified publisher). Custom FFI is always an option — llama.cpp's C API is stable and well-documented. | **High.** `llama.rn` has 871 stars, 740+ commits, 12-day-old release. Production-tested. Vercel AI SDK integration signals enterprise adoption. |

**Key insight:** React Native has a more mature llama.cpp binding today. However, Flutter's Dart FFI provides a clean, zero-overhead path to the same underlying C API. The `llama_cpp_dart` package is functional and covers our needs (load model, stream tokens, manage context). If it proves insufficient, writing custom FFI bindings is a well-documented Flutter pattern — the llama.cpp C API has ~20 functions we'd actually use.

### 2.2 MLC LLM (BL-008 — eliminated for iOS, included for completeness)

| Aspect | Flutter | React Native |
|--------|---------|-------------|
| **Binding** | No official or community plugin. Would require custom platform channel bridge to MLC's Swift/Kotlin SDKs. | No official plugin. Same — custom Turbo Native Module wrapping MLC's native SDKs. |
| **Effort** | High. Must bridge Dart → platform channel → Swift/Kotlin → MLC native API. | High. Must bridge JS → JSI → native → MLC native API. |
| **Viability** | **Not recommended.** MLC crashes on 4GB iPhones (BL-008 finding). No framework-level advantage. | **Not recommended.** Same iOS crash issue. No existing bindings to leverage. |

### 2.3 ONNX Runtime Mobile (BL-008 — eliminated for mobile GenAI immaturity)

| Aspect | Flutter | React Native |
|--------|---------|-------------|
| **Binding** | Community plugins: `onnxruntime` (pub.dev), `flutter_onnxruntime`, `fonnx`. Platform channel approach. Multiple contributors maintaining competing packages. | **Official:** `onnxruntime-react-native` (npm, Microsoft-maintained). First-party support. Documented on onnxruntime.ai. |
| **GenAI support** | General ONNX inference only. No GenAI-specific API (streaming, KV-cache, sampling) in Flutter plugins. Would need custom implementation. | General ONNX inference. `react-native-transformers` existed but is **no longer maintained** (as of Jul 2025). GenAI-specific mobile API is nascent. |
| **Viability** | **Not recommended** for LLM inference. ONNX Runtime's GenAI mobile story is too immature (BL-008). Flutter plugins are community-only. | **Marginal.** Official Microsoft plugin exists, but GenAI mobile is nascent. Better than Flutter's community plugins but still not ready for production LLM use. |

### 2.4 MediaPipe / LiteRT-LM (BL-008 — eliminated, deprecated)

| Aspect | Flutter | React Native |
|--------|---------|-------------|
| **Binding** | **Official Google plugins:** `mediapipe_genai` (pub.dev). Google maintains Flutter MediaPipe plugins. `flutter_litert` for LiteRT runtime. | **No official plugin.** No community RN binding for MediaPipe GenAI or LiteRT-LM. Would require full native module from scratch. |
| **Viability** | **Not recommended** despite official Flutter support. MediaPipe LLM Inference is deprecated (BL-008). LiteRT-LM v0.6.1 is early preview. Building on deprecated infra is unacceptable risk. | **Not viable.** No bindings exist. Deprecated SDK. |

### Integration Summary

| SDK | Flutter Path | Flutter Maturity | RN Path | RN Maturity | Better Framework |
|-----|-------------|-----------------|---------|-------------|-----------------|
| **llama.cpp** ★ | `llama_cpp_dart` / custom FFI | Medium | `llama.rn` | High | **React Native** |
| MLC LLM | Custom platform channel | Low | Custom Turbo Module | Low | Tie (both bad) |
| ONNX Runtime | Community plugins | Low | Official MS plugin | Medium | **React Native** |
| MediaPipe/LiteRT | Official Google plugins | Medium (deprecated) | None | None | **Flutter** (moot — deprecated) |

**For our chosen SDK (llama.cpp):** React Native has the more mature binding. But Flutter's FFI path is viable and eliminates the JS bridge entirely for inference hot paths.

---

## 3. Risk Assessment

### 3.1 Top 3 Risks: Flutter

| # | Risk | Severity | Likelihood | Mitigation |
|---|------|----------|-----------|-----------|
| 1 | **llama.cpp Flutter bindings are less mature than llama.rn** — `llama_cpp_dart` has 76 likes vs llama.rn's 871 stars. Fewer production deployments. Potential for undiscovered bugs in edge cases (memory management, Metal backend, concurrent inference). | High | Medium | Write custom Dart FFI bindings if `llama_cpp_dart` proves insufficient. llama.cpp's C API is stable (~20 functions needed). Dart FFI is well-documented. Effort: ~2-3 days for custom bindings. |
| 2 | **Dart developer scarcity** — If the project needs to hire beyond the founding team, Dart developers are harder to find than JavaScript/TypeScript developers. The AI team member mitigates this (language-agnostic). | Medium | Low | (a) The AI team member is equally productive in Dart and TypeScript. (b) Dart is syntactically similar to Java/Kotlin — ramp-up is fast. (c) Only relevant if team grows beyond 2. |
| 3 | **Impeller rendering engine edge cases on older devices** — Impeller is Flutter's newer rendering backend (replaced Skia). On iPhone 11 (A13) and Galaxy A53, CRT shader effects may hit performance limits or driver bugs. | Medium | Low | Test CRT shader effects on floor devices early (week 1). Fall back to simpler effects (CSS-like overlays instead of fragment shaders) if needed. Impeller has been stable since Flutter 3.16+. |

### 3.2 Top 3 Risks: React Native

| # | Risk | Severity | Likelihood | Mitigation |
|---|------|----------|-----------|-----------|
| 1 | **CRT terminal UI requires non-native rendering** — React Native renders through platform native views. Scanlines, phosphor glow, CRT barrel distortion, and per-character color effects require `react-native-skia` or custom native views. This adds a rendering dependency that's not part of RN's core value proposition. | High | High | Use `react-native-skia` (Shopify, well-maintained). Adds ~3-5 MB to binary. But introduces a second rendering paradigm alongside native views — architectural complexity for a 2-person team. |
| 2 | **New Architecture requirement for llama.rn** — `llama.rn` v0.10+ requires React Native's New Architecture (Fabric renderer + Turbo Modules). Many older RN libraries haven't migrated. This narrows the usable library pool and can cause compatibility issues with other dependencies. | High | Medium | Use RN 0.76+ which defaults to New Architecture. Carefully vet all dependencies for New Arch compatibility before committing. Avoid Expo (its overhead is unnecessary for our use case). |
| 3 | **JS bridge latency for token streaming** — Each token from llama.cpp crosses JSI from C++ → JS runtime. At 8+ tok/s (BL-014 target), this means 8+ bridge crossings per second during generation. While JSI is fast (~microseconds per call), cumulative overhead during streaming + UI updates + state management could cause dropped frames on floor devices. | Medium | Medium | llama.rn uses JSI (not the old async bridge), which is fast. Profile on floor devices early. If jank appears, batch tokens (e.g., deliver 2-3 tokens per callback) at cost of perceived streaming smoothness. |

---

## 4. Recommendation

### Primary Choice: **Flutter**

**Rationale:**

DANTE TERMINAL is fundamentally a **rendering-intensive, offline-first, single-purpose app** with a distinctive visual identity. The framework choice should optimize for:

1. **Visual fidelity of the terminal UI** — This is the product. The green-on-black CRT terminal with scanlines, phosphor glow, typewriter streaming, and retro effects IS the user experience. Flutter's Impeller/Skia engine renders every pixel directly, making these effects first-class citizens. React Native would need `react-native-skia` bolted on, creating architectural complexity.

2. **Streaming pipeline simplicity** — Tokens flow from llama.cpp C API → Dart FFI → Dart Stream → StreamBuilder widget → rendered pixels. Zero bridge hops. In React Native: llama.cpp C++ → JSI → JS callback → React state → native view update. More hops, more potential for jank.

3. **Team velocity for 2 people** — Flutter's single-language model (Dart for everything: UI, logic, FFI) is simpler than React Native's split between JavaScript/TypeScript and native modules. Our AI team member is equally productive in both, but debugging a single-language stack is faster.

4. **llama.cpp integration is viable** — While `llama.rn` is more mature today, Flutter's Dart FFI provides a direct, zero-overhead path to the same C API. `llama_cpp_dart` v0.2.2 covers our core needs (load model, stream tokens, manage context). If it falls short, custom FFI bindings are ~2-3 days of work — the llama.cpp C API is stable and small (~20 functions for our use case).

5. **Flutter wins 5 of 8 evaluation dimensions** — including the 3 most critical for this project: custom rendering, text streaming, and dev velocity.

**The one dimension React Native clearly wins — LLM SDK maturity — is addressable.** The llama.cpp C API is the same underneath both bindings. Flutter's FFI path is inherently zero-overhead (direct C function calls from Dart). Building or improving bindings is bounded work with a stable target API.

### Fallback Plan: **React Native + llama.rn**

**Trigger conditions to switch:**

1. Flutter's llama.cpp integration hits a **showstopper** that can't be resolved in ≤1 week — e.g., Metal memory leak that only manifests through Dart FFI, or Dart isolate limitations that prevent concurrent inference + UI.
2. `llama_cpp_dart` AND custom FFI bindings both fail to achieve **≥4 tok/s streaming** on iPhone 11 (BL-014 floor) due to framework-level overhead, while llama.rn demonstrates higher throughput on the same device.
3. CRT shader effects cause **sustained frame drops below 30fps** on floor devices through Flutter's Impeller, with no viable simplification.

**Fallback execution plan:**

- Scaffold React Native project with New Architecture enabled (bare RN, not Expo)
- Integrate `llama.rn` v0.11+ for LLM inference
- Add `react-native-skia` for CRT terminal rendering effects
- Port game logic from Dart to TypeScript (mechanical translation, ~1-2 days for initial prototype scope)
- Estimated switch cost: **3-5 days** from trigger to functional parity, assuming prototype-stage codebase

**Risk of switching late:** If the switch happens after significant UI work in Flutter, the CRT shader effects would need to be reimplemented in react-native-skia's API. Budget 1-2 extra days for this. To minimize switch cost, validate Flutter's llama.cpp integration AND CRT rendering on floor devices in the **first week** of BL-002 execution.

### Decision Timeline

| Milestone | Validation Gate |
|-----------|----------------|
| BL-002 Day 1-2 | Flutter scaffold + llama_cpp_dart basic integration working |
| BL-002 Day 3-4 | Streaming tokens displayed with basic typewriter effect on iOS simulator |
| BL-002 Day 5-7 | **Critical gate:** Test on iPhone 11 (or oldest available iOS device) AND Android floor device. Measure tok/s, check for Metal leaks, verify CRT shader at 60fps. |
| BL-002 Day 7 | **Go/no-go decision.** If all gates pass → commit to Flutter. If any gate fails → evaluate if fixable in ≤3 days. If not → trigger fallback to React Native. |

---

## Appendix: Data Sources

- llama.rn GitHub: https://github.com/mybigday/llama.rn (871 stars, v0.11.4)
- llama_cpp_dart pub.dev: https://pub.dev/packages/llama_cpp_dart (v0.2.2, 76 likes)
- fllama pub.dev: https://pub.dev/packages/fllama (v0.0.1, stale)
- llamafu pub.dev: https://pub.dev/packages/llamafu
- onnxruntime-react-native npm: https://www.npmjs.com/package/onnxruntime-react-native
- flutter_onnxruntime pub.dev: https://pub.dev/packages/flutter_onnxruntime
- mediapipe_genai pub.dev: https://pub.dev/documentation/mediapipe_genai/latest/
- Flutter FFI docs: https://docs.flutter.dev/platform-integration/ios/c-interop
- React Native New Architecture: https://reactnative.dev/docs/new-architecture-intro
- Flutter vs React Native 2026 benchmarks: https://www.synergyboat.com/blog/flutter-vs-react-native-vs-native-performance-benchmark-2025
- Flutter vs React Native 2026 comparison: https://dasroot.net/posts/2026/03/flutter-vs-react-native-2026-comprehensive-comparison/
- HuggingFace LLM edge inference guide: https://huggingface.co/blog/llm-inference-on-edge
- Vercel AI SDK + llama.rn: https://www.npmjs.com/package/@react-native-ai/llama
- BL-008 on-device LLM SDK maturity research (llama.cpp as primary SDK, MLC/MediaPipe/ONNX eliminated)
- BL-012 CLI prototype findings (3B+ models minimum viable, streaming non-negotiable)
- BL-014 target device specs (iOS 4GB floor, 1,500 MB inference budget, ≥4 tok/s decode)
