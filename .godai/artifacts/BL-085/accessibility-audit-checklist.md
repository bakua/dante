# BL-085: Accessibility Compliance Audit Checklist

**Target:** DANTE TERMINAL Flutter app (dante_terminal/) and landing page (docs/)
**Standards:** WCAG 2.1 AA, Apple HIG Accessibility, Google Play Pre-Launch Report
**Audience:** Developer implementing fixes before App Store / Google Play submission

---

## 1. Color and Contrast Audit

All measurements taken against the primary background color `#0A0A0A` (relative luminance 0.00304). WCAG AA requires **4.5:1** for normal text (< 18pt / < 14pt bold) and **3:1** for large text (≥ 18pt / ≥ 14pt bold). WCAG 2.1 SC 1.4.11 requires **3:1** for non-text UI components (borders, icons, focus indicators).

### 1.1 Flutter App — Terminal Screen (`lib/main.dart`)

| Element | Hex Value | Font Size | Contrast Ratio | WCAG AA | Status |
|---|---|---|---|---|---|
| Narrative text (primary) | `#00FF41` | 14px | **14.50:1** | 4.5:1 | ✅ PASS |
| Header text | `#00FF41` | 22px bold | **14.50:1** | 3.0:1 | ✅ PASS |
| System messages `[SYS]` | `#00AA2A` | 14px | **6.40:1** | 4.5:1 | ✅ PASS |
| Metrics text `[PERF]` | `#00886A` | 14px | **4.46:1** | 4.5:1 | ❌ **FAIL** |
| Suggestion text (inline) | `#00CC55` | 14px | **9.21:1** | 4.5:1 | ✅ PASS |
| Suggestion chip text | `#00CC55` | 12px | **9.21:1** | 4.5:1 | ✅ PASS |
| **Input placeholder/hint** | **`#004D15`** | **16px** | **1.95:1** | **4.5:1** | ❌ **FAIL** |
| Error text `[ERR]` | `#F44336` (Colors.red) | 14px | **5.38:1** | 4.5:1 | ✅ PASS |
| Input text | `#00FF41` | 16px | **14.50:1** | 4.5:1 | ✅ PASS |
| Prompt symbol `>` | `#00FF41` | 16px | **14.50:1** | 4.5:1 | ✅ PASS |
| Divider line | `#00FF41` | — | **14.50:1** | 3.0:1 (non-text) | ✅ PASS |
| Suggestion chip border | `#00CC55` @ 60% alpha → eff. `#047E37` | — | **3.81:1** | 3.0:1 (non-text) | ✅ PASS |
| Blinking cursor `_` | `#00FF41` | 20px | **14.50:1** | 3.0:1 | ✅ PASS |
| Send icon | `#00FF41` | 20px icon | **14.50:1** | 3.0:1 (non-text) | ✅ PASS |

### 1.2 Flutter App — Benchmark Screen (`lib/screens/benchmark_screen.dart`)

| Element | Hex Value | Font Size | Contrast Ratio | WCAG AA | Status |
|---|---|---|---|---|---|
| Log text (primary) | `#00FF41` | 12px | **14.50:1** | 4.5:1 | ✅ PASS |
| Description text | `#00AA2A` | 12px | **6.40:1** | 4.5:1 | ✅ PASS |
| Error text `[ERR]` | `#F44336` | 12px | **5.38:1** | 4.5:1 | ✅ PASS |
| Warning text `[WARN]` | `#FFC107` (Colors.amber) | 12px | **12.15:1** | 4.5:1 | ✅ PASS |
| Button text on `#003311` | `#00FF41` on `#003311` | default | **10.38:1** | 4.5:1 | ✅ PASS |
| Log container border | `#00AA2A` @ 30% alpha | — | ~2.6:1 | 3.0:1 (non-text) | ⚠️ **BORDERLINE** |

### 1.3 Landing Page (`docs/style.css`)

| Element | Hex Value | Context | Contrast Ratio | WCAG AA | Status |
|---|---|---|---|---|---|
| Body text | `#00FF41` on `#0A0A0A` | — | **14.50:1** | 4.5:1 | ✅ PASS |
| Dim text (version, labels) | `#00CC33` on `#0A0A0A` | .hero__version, .signup__label | **9.13:1** | 4.5:1 | ✅ PASS |
| Amber accent | `#FFB000` on `#0A0A0A` | .prompt-symbol, suggestions | **10.81:1** | 4.5:1 | ✅ PASS |
| Input placeholder | `rgba(0,255,65,0.3)` on `#0A0A0A` | .signup__input::placeholder | ~3.1:1 | 4.5:1 | ❌ **FAIL** |
| Footer text | `#00CC33` @ 50% opacity | .footer | ~3.7:1 | 4.5:1 | ❌ **FAIL** |
| Signup note | `#00CC33` @ 60% opacity | .signup__note | ~4.6:1 | 4.5:1 | ⚠️ **BORDERLINE** |
| Store badge text | `#00CC33` on `#0A0A0A` | .store-badge | **9.13:1** | 4.5:1 | ✅ PASS |

### 1.4 Failures — Required Fixes

#### FAIL-C1: Metrics text color too dim
- **Priority:** P1 (should-fix — metrics are secondary info, not store-blocker, but violates WCAG)
- **Effort:** 5 min
- **Current:** `#00886A` → 4.46:1 (fails AA by 0.04)
- **Fix:** Change `_metricsColor` to `#009977` (≈ 5.1:1) or `#00AA88` (≈ 5.8:1) — preserves teal-green hue distinction from narrative text while meeting AA
- **File:** `lib/main.dart` line 65

#### FAIL-C2: Input placeholder nearly invisible
- **Priority:** P0 (store-blocker — Apple HIG requires visible placeholder text for text fields)
- **Effort:** 5 min
- **Current:** `#004D15` → 1.95:1 (fails AA by > 50%)
- **Fix:** Change to `#338833` (≈ 4.0:1) or `#00752E` (≈ 3.2:1 — acceptable for placeholder per WCAG exception for inactive UI components, but Apple HIG expects visible prompts). Recommended: `#33884D` for ≈ 4.5:1
- **File:** `lib/main.dart` line 640

#### FAIL-C3: Landing page placeholder too dim
- **Priority:** P1 (should-fix)
- **Effort:** 5 min
- **Current:** `rgba(0,255,65,0.3)` → ~3.1:1
- **Fix:** Change to `rgba(0,255,65,0.45)` for ≈ 4.5:1
- **File:** `docs/style.css` line 240

#### FAIL-C4: Landing page footer too dim
- **Priority:** P2 (nice-to-have — footer is non-critical)
- **Effort:** 5 min
- **Current:** `.footer { opacity: 0.5 }` renders `#00CC33` at ~3.7:1
- **Fix:** Change to `opacity: 0.65` for ≈ 4.8:1
- **File:** `docs/style.css` line 318

---

## 2. Screen Reader Compatibility Checklist

### 2.1 Current State

The Flutter app uses **zero** `Semantics` widgets. All interactive elements rely on implicit semantics from Material widgets, which is insufficient for a custom terminal UI.

### 2.2 Required Flutter Semantics Additions

#### SR-1: Suggestion chips need button semantics
- **Priority:** P0 (store-blocker — tappable elements without labels cause Apple review rejection)
- **Effort:** 15 min
- **Current:** `GestureDetector` wrapping a `Container` + `Text` — invisible to screen readers (GestureDetector provides no semantic role)
- **Fix:** Wrap each suggestion chip in `Semantics` widget:
```dart
Semantics(
  button: true,
  label: 'Suggestion ${index}: $suggestion',
  hint: 'Double tap to use this action',
  enabled: !_isGenerating,
  child: GestureDetector(
    onTap: _isGenerating ? null : () => _onSuggestionTap(suggestion),
    child: Container(/* existing chip */),
  ),
)
```
- **File:** `lib/main.dart`, `_buildSuggestionChips()` method (line 541)

#### SR-2: Terminal output needs live region announcements
- **Priority:** P0 (store-blocker — new narrative text must be announced by VoiceOver/TalkBack)
- **Effort:** 20 min
- **Current:** `ListView.builder` renders text lines with no live region semantics — screen reader users cannot hear new game output
- **Fix:** Wrap the terminal output `ListView` in a `Semantics` widget with `liveRegion: true`. Additionally, after typewriter animation completes (not during), post a one-shot announcement:
```dart
SemanticsService.announce(completedNarrativeText, TextDirection.ltr);
```
- **File:** `lib/main.dart`, `build()` method (line 577) and `_typewriteGameResponse()` (after line 355)

#### SR-3: Send button needs accessible label
- **Priority:** P0 (store-blocker — icon-only buttons require labels per Apple HIG)
- **Effort:** 5 min
- **Current:** `IconButton(icon: Icon(Icons.send))` — has no `tooltip` or explicit semanticLabel
- **Fix:** Add `tooltip` property (which also serves as the semantic label):
```dart
IconButton(
  icon: Icon(Icons.send, color: _terminalGreen, size: 20),
  onPressed: _onSubmit,
  tooltip: 'Send command',
  padding: EdgeInsets.zero,
  constraints: const BoxConstraints(),
)
```
- **File:** `lib/main.dart` line 649

#### SR-4: Text input field needs accessible label
- **Priority:** P0 (store-blocker — text fields must have labels for VoiceOver)
- **Effort:** 5 min
- **Current:** `TextField` has `hintText` but no explicit semantic label. The `>` prompt symbol before it is a separate `Text` widget, not associated with the input.
- **Fix:** Add `InputDecoration.labelText` (visually hidden) or wrap in `Semantics`:
```dart
TextField(
  controller: _inputController,
  onSubmitted: (_) => _onSubmit(),
  decoration: InputDecoration(
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
    hintText: _gameSession != null ? 'What do you do?' : 'Type a command...',
    hintStyle: /* ... */,
    // Hidden label for screen readers
    labelText: 'Game command input',
    labelStyle: const TextStyle(fontSize: 0, height: 0),
    floatingLabelBehavior: FloatingLabelBehavior.never,
  ),
)
```
Alternatively, wrap the entire input row in `Semantics(label: 'Game command input')`.
- **File:** `lib/main.dart` line 620

#### SR-5: Blinking cursor (generating indicator) needs status semantics
- **Priority:** P1 (should-fix — users should know when AI is generating)
- **Effort:** 10 min
- **Current:** `_BlinkingCursor` is a visual-only animation with no semantic meaning — screen reader users have no indication that generation is in progress
- **Fix:** Wrap in `Semantics`:
```dart
Semantics(
  label: 'Generating response, please wait',
  liveRegion: true,
  child: _BlinkingCursor(),
)
```
Also announce state changes:
```dart
// When generation starts:
SemanticsService.announce('Generating response...', TextDirection.ltr);
// When generation ends:
SemanticsService.announce('Response complete', TextDirection.ltr);
```
- **File:** `lib/main.dart` line 646 and within `_onSubmit()`

#### SR-6: Adventure title header needs heading semantics
- **Priority:** P1 (should-fix — improves navigation structure)
- **Effort:** 5 min
- **Current:** "DANTE TERMINAL v0.2.0" and adventure title rendered as plain `Text` — screen readers cannot navigate by headings
- **Fix:** Wrap header lines in `Semantics(header: true)`:
```dart
Semantics(
  header: true,
  child: Text(line.text, style: /* headerStyle */),
)
```
- **File:** `lib/main.dart`, `itemBuilder` in `ListView.builder` (line 580)

#### SR-7: Benchmark screen — start button and log area
- **Priority:** P2 (nice-to-have — benchmark is a developer tool, not player-facing)
- **Effort:** 10 min
- **Current:** `ElevatedButton` has implicit semantics (acceptable). Log output area has no live region.
- **Fix:** Add `Semantics(liveRegion: true)` around the log `ListView` for benchmark progress announcements.
- **File:** `lib/screens/benchmark_screen.dart` line 172

### 2.3 Navigation Flow Order

The current widget tree creates this focus order: Header text → (terminal lines) → suggestion chips → text input → send button. This is **correct** for a terminal UI flow (read output → choose suggestion OR type command → submit). No `FocusOrder` overrides needed.

However, the terminal `ListView.builder` may trap focus with hundreds of text items. Add `ExcludeSemantics` for completed/old terminal lines beyond the last 10, keeping only recent output traversable:
- **Priority:** P1 (should-fix)
- **Effort:** 20 min
- **File:** `lib/main.dart`, `itemBuilder` in `ListView.builder`

---

## 3. Motion and Timing

### 3.1 Current Animations

| Animation | Location | Duration | Purpose |
|---|---|---|---|
| Typewriter text streaming | `_typewriteGameResponse()` | 20ms per char (~2-4s total) | Reveal narrative text character-by-character |
| Raw inference typewriter | `_typewriteRawResponse()` | 20ms per char | Same for fallback raw mode |
| Blinking cursor `_` | `_BlinkingCursor` | 800ms loop (infinite) | Generation-in-progress indicator |
| Scroll animation | `_scrollToBottom()` | 100ms | Auto-scroll to new content |
| Landing: typewriter | `script.js` | 35-50ms per char | Hero text reveal |
| Landing: cursor blink | `style.css` | 1s loop | Decorative cursor |
| Landing: scanline flicker | `style.css` | 8s loop | CRT aesthetic |
| Landing: scroll reveal | `script.js` (IntersectionObserver) | CSS transition | Section fade-in |

### 3.2 Required Fixes

#### MOT-1: Respect `accessibleNavigation` for typewriter effect
- **Priority:** P0 (store-blocker — Apple requires respecting "Reduce Motion" system setting; content must not be delayed behind animation)
- **Effort:** 30 min
- **Current:** Typewriter animation runs unconditionally at 20ms/char. A 200-character response takes ~4 seconds of animation before all content is visible. Screen reader users waiting for the full text get fragmented announcements.
- **Fix:** Check `MediaQuery.of(context).accessibleNavigation` (which reflects the iOS "Reduce Motion" toggle and Android equivalent). When true, skip the character-by-character reveal and display the full text instantly:
```dart
final reduceMotion = MediaQuery.of(context).accessibleNavigation;

// In _typewriteGameResponse / _typewriteRawResponse:
if (reduceMotion) {
  // Wait for producer to finish, then display all at once
  await producerFuture;
  setState(() {
    _lines[lineIdx] = _TerminalLine(displayBuf.toString());
  });
} else {
  // Existing character-by-character consumer loop
}
```
- **File:** `lib/main.dart`, both `_typewriteGameResponse()` and `_typewriteRawResponse()`

#### MOT-2: Disable blinking cursor for reduced motion
- **Priority:** P1 (should-fix — WCAG 2.3.3 recommends no blinking content without user control)
- **Effort:** 10 min
- **Current:** `_BlinkingCursor` blinks infinitely with `AnimationController.repeat()`
- **Fix:** Check `MediaQuery.of(context).disableAnimations` or `accessibleNavigation`. When reduce-motion is active, show a static `_` instead of animating:
```dart
@override
Widget build(BuildContext context) {
  final reduceMotion = MediaQuery.of(context).accessibleNavigation;
  if (reduceMotion) {
    return const Text('_', style: TextStyle(
      fontFamily: 'monospace', fontSize: 20, color: Color(0xFF00FF41),
    ));
  }
  return FadeTransition(/* existing animation */);
}
```
- **File:** `lib/main.dart`, `_BlinkingCursorState.build()` (line 705)

#### MOT-3: Landing page already handles reduced motion ✅
- **Priority:** N/A — already implemented
- **Current:** `docs/style.css` includes `@media (prefers-reduced-motion: reduce)` (lines 372-386) that disables typewriter cursor blink, cursor block blink, and scanline flicker
- **Status:** Compliant. No changes needed for landing page.

#### MOT-4: Ensure no content is only conveyed through animation
- **Priority:** P0 (store-blocker — information cannot depend on perceiving motion)
- **Effort:** 0 min (already OK)
- **Current:** The typewriter effect is purely decorative timing — the same text appears regardless of whether animation plays. The blinking cursor is a status indicator but should also have a semantic announcement (covered by SR-5). No content is lost when animations are disabled.
- **Status:** Compliant once MOT-1 and SR-5 are implemented.

---

## 4. Text Scaling and Touch Targets

### 4.1 Dynamic Type / Text Scaling

Flutter respects `MediaQuery.textScaleFactorOf(context)` by default for `Text` widgets. However, the terminal UI uses hardcoded `fontSize` values throughout, which may interact poorly with large text settings.

#### TS-1: Verify layout at 200% text scale
- **Priority:** P0 (store-blocker — Apple requires Dynamic Type support; Google tests at "Largest" font size)
- **Effort:** 45 min
- **Current:** All font sizes are hardcoded constants (12px, 14px, 16px, 22px). At 200% scale:
  - 14px narrative → 28px: likely OK in single-column layout
  - 22px header → 44px: may clip on narrow screens (< 360dp)
  - 12px suggestion chip text → 24px: chip containers will grow but `Wrap` widget handles overflow
  - 16px input text → 32px: input row may overflow horizontally
- **Fix:** Test in Flutter DevTools with `textScaleFactor: 2.0` via `MediaQuery` override. Key risk areas:
  1. Input row (`Row` with `>` prompt + `Expanded(TextField)` + icon): the `>` and icon may squeeze the text field at large scale
  2. Header with `letterSpacing: 4` at 44px may exceed screen width
  3. Suggestion chips with long text at 24px may need word wrapping
- **File:** `lib/main.dart` — primarily the `build()` method

#### TS-2: Respect textScaleFactor cap for terminal aesthetic
- **Priority:** P1 (should-fix)
- **Effort:** 15 min
- **Note:** A terminal UI can legitimately cap text scaling at a reasonable maximum (e.g., 1.5x) while still respecting the system setting. Apple allows this if the cap still provides adequate readability. Wrapping the `Scaffold` in `MediaQuery` with a capped `textScaleFactor` is acceptable:
```dart
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(
      MediaQuery.of(context).textScaler.scale(14).clamp(14, 28) / 14,
    ),
  ),
  child: Scaffold(/* ... */),
)
```
- **File:** `lib/main.dart`, `build()` method

### 4.2 Touch Target Sizes

Apple HIG minimum: **44x44 pt**. Google Material: **48x48 dp**. WCAG 2.5.8 (AAA): **44x44 CSS px**.

| Element | Current Size | Minimum | Status |
|---|---|---|---|
| Suggestion chips | ~24px tall (6px pad + 12px text + 6px pad) × variable width | 44x44 pt | ❌ **FAIL** |
| Send button (IconButton) | ~20x20px (zero padding, no constraints) | 44x44 pt | ❌ **FAIL** |
| Text input field | ~20px tall (isDense, zero padding) | 44px tall | ❌ **FAIL** |
| Benchmark start button | default ElevatedButton | ~48x36px | ⚠️ **BORDERLINE** |

#### TT-1: Increase suggestion chip touch targets
- **Priority:** P0 (store-blocker — Apple HIG explicit requirement for tappable UI)
- **Effort:** 15 min
- **Current:** Chips have `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)` with 12px font → total height ~24px
- **Fix:** Increase vertical padding to reach 44px minimum height:
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
  // ... rest unchanged
)
```
- **File:** `lib/main.dart`, `_buildSuggestionChips()` (line 544)

#### TT-2: Increase send button touch target
- **Priority:** P0 (store-blocker)
- **Effort:** 5 min
- **Current:** `padding: EdgeInsets.zero, constraints: const BoxConstraints()` → 20x20px
- **Fix:** Remove the zero-padding override and use minimum constraints:
```dart
IconButton(
  icon: Icon(Icons.send, color: _terminalGreen, size: 20),
  onPressed: _onSubmit,
  tooltip: 'Send command',
  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
)
```
- **File:** `lib/main.dart` line 648

#### TT-3: Increase text input touch target height
- **Priority:** P1 (should-fix — the `Expanded` widget ensures width is adequate, but height may be too small on tap)
- **Effort:** 10 min
- **Current:** `isDense: true, contentPadding: EdgeInsets.zero` compresses the field to the text line height (~20px)
- **Fix:** Increase content padding to meet minimum height:
```dart
InputDecoration(
  border: InputBorder.none,
  isDense: false,
  contentPadding: const EdgeInsets.symmetric(vertical: 12),
  // ...
)
```
- **File:** `lib/main.dart` line 635

---

## 5. Priority Summary

### P0 — Store Blockers (must fix before submission)

| ID | Section | Issue | Effort |
|---|---|---|---|
| FAIL-C2 | Color | Input placeholder `#004D15` at 1.95:1 ratio | 5 min |
| SR-1 | Screen Reader | Suggestion chips have no button semantics | 15 min |
| SR-2 | Screen Reader | Terminal output has no live region announcements | 20 min |
| SR-3 | Screen Reader | Send button has no accessible label | 5 min |
| SR-4 | Screen Reader | Text input has no accessible label | 5 min |
| MOT-1 | Motion | Typewriter animation ignores Reduce Motion setting | 30 min |
| TS-1 | Text Scaling | Layout untested at 200% text scale | 45 min |
| TT-1 | Touch Targets | Suggestion chips ~24px tall (need 44px) | 15 min |
| TT-2 | Touch Targets | Send button 20x20px (need 44x44) | 5 min |

**Total P0 effort: ~2.5 hours**

### P1 — Should Fix (strongly recommended)

| ID | Section | Issue | Effort |
|---|---|---|---|
| FAIL-C1 | Color | Metrics text `#00886A` at 4.46:1 (AA fail by 0.04) | 5 min |
| FAIL-C3 | Color | Landing placeholder too dim | 5 min |
| SR-5 | Screen Reader | Blinking cursor has no status semantics | 10 min |
| SR-6 | Screen Reader | Headers lack heading semantics | 5 min |
| SR (nav) | Screen Reader | Old terminal lines trap screen reader focus | 20 min |
| MOT-2 | Motion | Blinking cursor ignores Reduce Motion | 10 min |
| TS-2 | Text Scaling | No textScaleFactor cap for terminal aesthetic | 15 min |
| TT-3 | Touch Targets | Text input field too short for tap | 10 min |

**Total P1 effort: ~1.5 hours**

### P2 — Nice to Have

| ID | Section | Issue | Effort |
|---|---|---|---|
| FAIL-C4 | Color | Landing footer text at ~3.7:1 (opacity too low) | 5 min |
| SR-7 | Screen Reader | Benchmark log area has no live region | 10 min |

**Total P2 effort: ~15 min**

---

## 6. Implementation Order (Recommended)

Suggested fix order optimizing for maximum risk reduction per unit of effort:

1. **SR-3 + SR-4** (10 min) — add labels to send button and text input
2. **FAIL-C2** (5 min) — fix placeholder color
3. **TT-2** (5 min) — fix send button touch target
4. **TT-1** (15 min) — fix suggestion chip touch targets
5. **SR-1** (15 min) — add button semantics to suggestion chips
6. **SR-2** (20 min) — add live region to terminal output
7. **MOT-1** (30 min) — respect Reduce Motion for typewriter
8. **TS-1** (45 min) — test and fix 200% text scale layout

After these 8 items (~2.5 hours), the app passes all P0 store-blocker checks.

---

## Appendix A: Color Reference — Compliant Alternatives

| Original | Ratio | Recommended Replacement | New Ratio | Notes |
|---|---|---|---|---|
| `#004D15` (hint) | 1.95:1 | `#33884D` | ~4.5:1 | Maintains green hue, now visible |
| `#00886A` (metrics) | 4.46:1 | `#00AA88` | ~5.8:1 | Keeps teal distinction from green |
| `rgba(0,255,65,0.3)` (landing placeholder) | ~3.1:1 | `rgba(0,255,65,0.45)` | ~4.5:1 | Higher opacity |
| `.footer opacity: 0.5` | ~3.7:1 | `opacity: 0.65` | ~4.8:1 | Higher opacity |

## Appendix B: Testing Checklist for Verification

After implementing fixes, verify with:

- [ ] **iOS VoiceOver:** Navigate full game flow — hear suggestion labels, narrative announcements, input label, generating status
- [ ] **Android TalkBack:** Same flow — verify labels read correctly, live regions announce
- [ ] **iOS Reduce Motion ON:** Typewriter effect skipped, text appears instantly, cursor static
- [ ] **iOS Largest Dynamic Type:** Layout does not clip or overflow at 200% text scale
- [ ] **Android Largest Font Size:** Same verification
- [ ] **Xcode Accessibility Inspector:** Run on simulator, verify zero warnings
- [ ] **Google Play Pre-Launch Report:** Submit internal test build, check accessibility section shows no critical errors
- [ ] **Manual contrast check:** Use Digital Color Meter (macOS) to spot-check all updated colors against their backgrounds
