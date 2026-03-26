# Build Verification Baseline Report

> **BL-216** | HEAD: `e9c4608` | Date: 2026-03-26 | 29 unpushed commits

This report captures the exact build state of the DANTE TERMINAL codebase at the
current HEAD so the human knows what to expect when pushing. Read this before `git push`.

---

## Environment

| Property | Value |
|----------|-------|
| Flutter | 3.38.9 (stable) |
| Dart | 3.10.8 |
| Framework revision | 67323de285 |
| Source files (lib/) | 16 .dart files |
| Test files (test/) | 14 _test.dart files |
| Unpushed commits | 29 (808abd0..e9c4608) |
| Build machine | macOS (local) |

---

## 1. Static Analysis (`flutter analyze`)

**Result: CLEAN**

```
Analyzing dante_terminal...
No issues found! (ran in 1.3s)
```

- Zero warnings, zero errors, zero hints.
- Full output: `flutter_analyze_output.txt`

---

## 2. Unit Tests (`flutter test`)

**Result: ALL 196 TESTS PASSING**

```
00:13 +196: All tests passed!
```

- 196 tests across 14 test files.
- Execution time: ~13 seconds.
- Zero failures, zero skips.
- Full output: `flutter_test_output.txt`

---

## 3. Android Release Build (`flutter build appbundle --release`)

**Result: SUCCESS**

```
Running Gradle task 'bundleRelease'...                             50.7s
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from
  1645184 to 1468 bytes (99.9% reduction).
✓ Built build/app/outputs/bundle/release/app-release.aab (92.0MB)
```

- Output: `build/app/outputs/bundle/release/app-release.aab` (92.0 MB)
- Build time: ~51 seconds.
- **Note:** This build uses the debug keystore. For Play Store submission, a release
  keystore must be generated (see BL-195 task H5) and configured in
  `android/key.properties`. The current `.aab` is suitable for local device testing
  via `flutter install` but NOT for store upload.
- Full output: `flutter_build_appbundle_output.txt`

---

## 4. iOS Release Build (`flutter build ios --release --no-codesign`)

**Result: SUCCESS**

```
Warning: Building for device with codesigning disabled. You will have
  to manually codesign before deploying to device.
Building com.danteterminal.danteTerminal for device (ios-release)...
Running pod install...                                             535ms
Running Xcode build...
Xcode build done.                                           35.2s
✓ Built build/ios/iphoneos/Runner.app (21.3MB)
```

- Output: `build/ios/iphoneos/Runner.app` (21.3 MB)
- Build time: ~35 seconds.
- **Note:** The `--no-codesign` flag means this app CANNOT be deployed to a device
  without manual code signing. For device testing, either use `flutter run` on a
  connected device with a valid provisioning profile (see BL-195 task H4) or enroll
  in the Apple Developer Program (BL-195 task H6) for distribution signing.
- Full output: `flutter_build_ios_output.txt`

---

## Summary: What the Human Should Expect

| Check | Status | Action Required |
|-------|--------|-----------------|
| Static analysis | CLEAN | None |
| Unit tests | 196/196 PASS | None |
| Android .aab build | BUILDS | Generate release keystore (H5) for store upload |
| iOS .app build | BUILDS (unsigned) | Apple Developer enrollment (H6) for signing |
| CI pipeline | UNTESTED | Will run after `git push` (H1) — see BL-215 playbook |

**Bottom line:** The code compiles, passes all tests, and produces release artifacts
on both platforms. The only missing pieces are signing credentials (human-only tasks
H5 and H6 in the BL-195 handoff checklist).

---

## Files in This Artifact

- `build-baseline-report.md` — This report
- `flutter_analyze_output.txt` — Raw `flutter analyze` output
- `flutter_test_output.txt` — Raw `flutter test` output (196 tests)
- `flutter_build_appbundle_output.txt` — Raw Android release build output
- `flutter_build_ios_output.txt` — Raw iOS release build output
