# BL-087: Model Delivery Strategy for Mobile GGUF Distribution

> **BL-087** | Created: 2026-03-25 | Status: **COMPLETE**
>
> Purpose: Decision-ready strategy for delivering the GGUF model file to end-user devices.
> Audience: Founding team making build and distribution architecture decisions.
> Replaces: BL-072 (skipped twice due to task description formatting issue per L-014, L-015).

---

## Summary

The GGUF model file (1.5 to 2.0 GB depending on candidate) cannot be bundled inside the app binary for either platform without hitting store limits. The recommended approach is a **first-launch download** hosted on **Cloudflare R2** (zero egress fees, 10 GB free storage) with **GitHub Releases as fallback CDN** (no documented bandwidth cap, 2 GB per-file limit). This hybrid approach costs $0 at launch and scales to 100K downloads before meaningful costs appear. The download UX should use the `background_downloader` Flutter package with WiFi detection, pause and resume, and a retro-themed progress screen.

---

## 1. Delivery Option Analysis

### 1.1 Option A: Bundle Model Inside App Binary

| Dimension | iOS | Android |
|---|---|---|
| **Max app size** | 4 GB uncompressed total | 150 MB APK; 200 MB base AAB module |
| **Model fits in binary?** | Technically yes (1.5 to 2.0 GB within 4 GB) | **No** (exceeds 150 MB APK and 200 MB AAB base) |
| **OTA cellular download** | No limit since iOS 13 removed 200 MB cap | Play Store handles, but users may abandon large initial downloads |
| **App Store review risk** | Large apps get extra scrutiny; 2 GB app may be flagged | N/A (doesn't fit) |

**Pros:**
- Simplest implementation; zero download UX needed
- Works offline immediately after install
- No hosting costs

**Cons:**
- **Android: impossible** without Play Asset Delivery (model exceeds 200 MB base module limit)
- iOS: 2 GB app will deter downloads (average app is 40 to 80 MB)
- Every model update requires a full app update and re-review
- App Store page shows large download size, reducing conversion rate

**Verdict: Not viable** as a standalone strategy due to Android size constraints.

### 1.2 Option B: Platform-Native Asset Delivery (Hybrid Bundle)

**iOS: Background Assets Framework (BADownloadManager)**
- Apple's recommended approach for large post-install assets (introduced WWDC22, updated WWDC23)
- Downloads begin automatically before first launch via app extension
- Supports essential (blocks launch until complete) and non-essential downloads
- Requires accurate file size declaration upfront
- Assets hosted on your own infrastructure (not Apple-hosted, unless using the newer Apple-Hosted Background Assets from WWDC25)
- Size limit: 8 GB per asset pack (iOS 18 and later)

**Android: Play Asset Delivery (PAD)**
- Google's official solution for large game assets
- Three delivery modes: install-time (up to 1 GB), fast-follow (auto-downloads post-install, up to 512 MB per pack), on-demand (user-triggered, up to 512 MB per pack)
- Total asset pack limit: 2 GB across all packs
- Flutter plugin available: `asset_delivery` package on pub.dev
- Fast-follow mode ideal for model file: downloads immediately after app install, user sees progress

**Pros:**
- Platform-sanctioned approach; no store review friction
- Android fast-follow: model downloads in background immediately after install
- iOS Background Assets: can start download before user even opens the app
- Integrated with platform download managers (resume, progress, WiFi preference)

**Cons:**
- Two different implementations for two platforms (significant engineering cost)
- iOS Background Assets: still requires your own hosting infrastructure
- Android PAD: model must be uploaded to Play Console with each app release
- Version coupling: model updates require app updates on Android
- Flutter integration maturity: `asset_delivery` plugin is relatively new

**Verdict: Best for Android** (via PAD fast-follow); **complex for iOS** (still needs custom hosting). Consider hybrid.

### 1.3 Option C: First-Launch Download from Custom CDN

Download the model from a CDN on first app launch, with a dedicated download screen.

**Pros:**
- Identical implementation for both platforms via Flutter (single codebase)
- Decouples model updates from app updates (can ship new models without app review)
- Small initial app size (under 50 MB) maximizes install conversion
- Full control over download UX
- Can A/B test different models without store submission

**Cons:**
- Requires hosting infrastructure and ongoing bandwidth costs
- User must wait for download before first play session
- Requires robust download UX (progress, pause, resume, error handling)
- Cellular users may not want to download 1.5 to 2 GB on mobile data

**Verdict: Most practical** for a two-person team. Single implementation, full control, decoupled updates.

### 1.4 Option D: Hybrid (Small App plus First-Launch Download with Platform Fallback)

Ship a minimal app (under 50 MB) with first-launch CDN download for both platforms. On Android, optionally also publish a PAD fast-follow variant for users who prefer Play Store-managed downloads.

**Pros:**
- Best of both worlds: simple CDN download works everywhere, PAD enhances Android
- Small app size for initial install on both platforms
- Can add PAD integration later as optimization, not blocker

**Cons:**
- Slightly more complex than pure CDN approach if PAD is added
- Two download paths to maintain (if PAD variant is built)

**Verdict: Recommended path** (start with Option C, add Android PAD as a v2 optimization).

### 1.5 Comparison Matrix

| Criterion | A: Bundle | B: Platform Native | C: CDN Download | D: Hybrid |
|---|---|---|---|---|
| Works on iOS | Yes | Yes | Yes | Yes |
| Works on Android | **No** | Yes | Yes | Yes |
| Engineering effort | Trivial | High (2 platforms) | Medium (1 impl) | Medium to High |
| Hosting cost | $0 | Partial (iOS needs CDN) | Yes | Yes |
| Model update without app update | No | No (Android PAD) | **Yes** | **Yes** |
| App install size | 1.5 to 2 GB | 50 MB (then download) | Under 50 MB | Under 50 MB |
| Time to first play | Instant | Minutes (background) | Minutes (foreground) | Minutes |
| Store review risk | High (large) | Low | Low | Low |

---

## 2. Hosting and Bandwidth Analysis

### 2.1 Model Size Budget

Based on BL-003 and BL-014 findings:

| Model Candidate | GGUF File Size | Notes |
|---|---|---|
| Phi-3-mini 3.8B Q4 | 2.28 GB | Best quality (4 out of 5) but exceeds 2 GB budget |
| Gemma 3n E2B Q4_K_M | ~1.5 GB | Projected quality 4 out of 5, fits all budgets |
| TinyLlama 1.1B Q4_K_M | 0.64 GB | Low quality (2 out of 5), not recommended |

**Planning assumption:** 1.5 to 2.0 GB per download. Use **1.75 GB** as the median for cost calculations.

### 2.2 Hosting Option Comparison

#### Option 1: GitHub Releases

| Attribute | Details |
|---|---|
| **Per-file limit** | 2 GB (technically 2 GiB) |
| **Total release size** | No documented limit |
| **Bandwidth cap** | No documented cap for release asset downloads |
| **Monthly cost** | $0 |
| **CDN** | GitHub's CDN (Fastly) |
| **Reliability** | Very high (GitHub uptime SLA) |
| **Limitations** | No analytics; not designed as a CDN; GitHub may throttle at extreme scale; per-file 2 GB limit means Phi-3 at 2.28 GB would need splitting |
| **Setup effort** | Minimal: `gh release create` with asset upload |

**Cost at scale:**

| Downloads per month | Bandwidth | Estimated cost |
|---|---|---|
| 1,000 | 1.75 TB | $0 |
| 10,000 | 17.5 TB | $0 (risk of throttling) |
| 100,000 | 175 TB | $0 (likely throttled or TOS concern) |

**Assessment:** Excellent for launch and early growth (up to ~10K downloads). At 100K downloads, GitHub may rate-limit or flag the repository. No SLA for this use case.

#### Option 2: Hugging Face Hub

| Attribute | Details |
|---|---|
| **Per-file limit** | 50 GB (LFS) |
| **Storage** | Unlimited for public models |
| **Bandwidth cap** | Rate-limited per 5-minute windows; exact limits undisclosed |
| **Monthly cost** | $0 (free tier); $9 per month (PRO for higher rate limits) |
| **CDN** | Hugging Face CDN (Cloudfront) |
| **Reliability** | High; designed for model distribution |
| **Limitations** | Rate limits may throttle concurrent downloads; no custom domain; no download analytics |
| **Setup effort** | Minimal: create model repo, upload GGUF, use direct download URL |

**Cost at scale:**

| Downloads per month | Bandwidth | Estimated cost |
|---|---|---|
| 1,000 | 1.75 TB | $0 |
| 10,000 | 17.5 TB | $0 to $9 (may need PRO for rate limits) |
| 100,000 | 175 TB | Unknown (likely need Enterprise or custom agreement) |

**Assessment:** Purpose-built for model distribution. The GGUF file format is native to the HF ecosystem. Good for launch, but rate limits at scale are opaque and not guaranteed.

#### Option 3: Cloudflare R2

| Attribute | Details |
|---|---|
| **Storage limit** | 10 GB free; $0.015 per GB-month after |
| **Egress** | **$0 always** (zero egress fees, R2's key differentiator) |
| **Operations** | 10M Class B reads free per month; $0.36 per million after |
| **Monthly cost** | See table below |
| **CDN** | Cloudflare's global CDN (300+ PoPs) |
| **Reliability** | Very high (Cloudflare SLA) |
| **Limitations** | Requires Cloudflare account; storage exceeds free tier at 1.75 GB model |
| **Setup effort** | Medium: create bucket, upload file, configure public access or Workers endpoint |

**Cost at scale:**

| Downloads per month | Bandwidth | Storage cost | Operations cost | Total monthly |
|---|---|---|---|---|
| 1,000 | 1.75 TB | $0 (within rounding) | $0 (1K reads, well within 10M free) | **~$0.01** |
| 10,000 | 17.5 TB | $0.03 | $0 (10K reads, within 10M free) | **~$0.03** |
| 100,000 | 175 TB | $0.03 | $0.004 (100K reads, within 10M free) | **~$0.03** |

*Note: Storage cost is for 1.75 GB stored, which rounds to 2 GB at $0.015 per GB-month = $0.03. The 10 GB free tier covers this initially.*

**Assessment:** The clear winner for cost at any scale. Zero egress means 100K downloads costs the same as 1K downloads (just storage). The only cost driver is storage, which is negligible.

#### Option 4: Firebase Cloud Storage (Blaze Plan)

| Attribute | Details |
|---|---|
| **Free tier** | Requires Blaze (pay-as-you-go) plan since Feb 2026; includes some no-cost usage |
| **Storage** | $0.026 per GB per month |
| **Egress** | $0.12 to $0.15 per GB download |
| **Monthly cost** | See table below |
| **CDN** | Google Cloud CDN |
| **Reliability** | Very high (Google Cloud SLA) |
| **Limitations** | Egress costs scale linearly and are significant; must be on Blaze plan (requires billing account) |
| **Setup effort** | Medium: Firebase project, storage bucket, security rules, upload |

**Cost at scale:**

| Downloads per month | Bandwidth | Storage cost | Egress cost | Total monthly |
|---|---|---|---|---|
| 1,000 | 1.75 TB | $0.05 | **$225** | **~$225** |
| 10,000 | 17.5 TB | $0.05 | **$2,250** | **~$2,250** |
| 100,000 | 175 TB | $0.05 | **$22,500** | **~$22,500** |

*Egress calculated at $0.13 per GB average (Google Cloud egress pricing varies by region).*

**Assessment:** Prohibitively expensive at any meaningful scale due to egress pricing. Only viable if usage stays under the no-cost tier (~1 GB per day free). Not recommended.

#### Option 5: Backblaze B2 plus Cloudflare (Bandwidth Alliance)

| Attribute | Details |
|---|---|
| **Storage** | 10 GB free; $0.006 per GB-month after |
| **Egress** | $0 when routed through Cloudflare (Bandwidth Alliance partner) |
| **Monthly cost** | ~$0.01 at any scale (storage only) |
| **Setup effort** | Medium-high: B2 bucket, Cloudflare DNS, Workers or Transform Rules |

**Assessment:** Similar economics to R2 but more complex setup. R2 is simpler since it's all within Cloudflare.

### 2.3 Hosting Recommendation Matrix

| Hosting Option | 1K downloads | 10K downloads | 100K downloads | Setup effort | Reliability | Recommended? |
|---|---|---|---|---|---|---|
| **GitHub Releases** | $0 | $0 | Risk of throttle | Minimal | High | **Yes (fallback)** |
| **Hugging Face Hub** | $0 | $0 to $9 | Unknown | Minimal | High | Yes (secondary) |
| **Cloudflare R2** | ~$0 | ~$0.03 | ~$0.03 | Medium | Very High | **Yes (primary)** |
| Firebase Storage | ~$0 | ~$2,250 | ~$22,500 | Medium | Very High | **No** |
| Backblaze B2 plus CF | ~$0 | ~$0.01 | ~$0.01 | Medium-High | High | Optional |

---

## 3. Download UX Specification

### 3.1 First-Launch Flow

```
App Install (< 50 MB)
    |
    v
First Launch
    |
    v
[Welcome Screen]
"DANTE TERMINAL requires a one-time download
of the AI Game Master engine (~1.5 GB).
This will enable fully offline gameplay."
    |
    +-- [Download Now] (primary action)
    +-- [Download Later] (dismiss, reminder on next launch)
    |
    v
[Pre-Download Checks]
    |
    +-- Check available storage (need model size + 500 MB headroom)
    |   +-- If insufficient: "Free up X GB to continue"
    |
    +-- Check network type (connectivity_plus)
    |   +-- If cellular: "You're on cellular data. This download is ~1.5 GB. Continue or wait for WiFi?"
    |   +-- If WiFi: proceed silently
    |   +-- If no connection: "Connect to the internet to download the AI engine"
    |
    v
[Download Screen - Retro Terminal Aesthetic]
    |
    +-- ASCII progress bar: [#########-------] 58%
    +-- Status line: "DOWNLOADING AI ENGINE... 892 MB of 1,536 MB"
    +-- Speed indicator: "TRANSFER RATE: 12.4 MB per sec"
    +-- Time estimate: "ETA: 52 SECONDS"
    +-- [PAUSE] button (tap to pause, tap again to resume)
    +-- Thematic flavor text cycling during download:
        "Initializing neural pathways..."
        "Loading dungeon cartography..."
        "Calibrating narrative engine..."
    |
    v
[Download Complete]
"AI ENGINE LOADED. READY TO EXPLORE."
    +-- Auto-transition to game start (3 second delay)
    |
    v
[Opening Scene - The Sunken Archive]
```

### 3.2 Technical Implementation

**Recommended Flutter Package:** `background_downloader` (pub.dev)
- Uses NSURLSession on iOS (supports background transfer)
- Uses WorkManager on Android (survives app termination)
- Built-in pause and resume via resume data
- Progress callbacks with bytes transferred and total
- Automatic retry on network failure

**Key Implementation Details:**

| Concern | Implementation |
|---|---|
| **Pause and resume** | `background_downloader` natively supports pause and resume via HTTP Range headers; stores resume data automatically |
| **Background download** | iOS: NSURLSession background session (download continues when app backgrounded). Android: WorkManager (survives process death) |
| **Cellular detection** | `connectivity_plus` package: check `ConnectivityResult.mobile` vs `ConnectivityResult.wifi` before starting download |
| **Storage pre-check** | Dart `path_provider` for app documents directory; use `dart:io` `FileSystemEntity.statSync` or platform channel to query free disk space |
| **Error recovery** | On network error: auto-retry with exponential backoff (3 attempts). On storage error: alert user. On corrupt download: delete and restart with integrity check |
| **Integrity verification** | SHA-256 hash check after download completes; hash embedded in app binary at build time |
| **CDN failover** | Primary: Cloudflare R2 URL. Fallback: GitHub Releases URL. App tries primary; on 3 consecutive failures, switches to fallback |
| **Model versioning** | App binary contains expected model version and SHA-256. On app update, if model version changes, trigger re-download |

### 3.3 Edge Cases

| Scenario | Behavior |
|---|---|
| User kills app during download | On next launch, detect partial file, resume from where it stopped |
| Download completes in background | Show notification: "AI Engine ready. Tap to play." |
| Insufficient storage mid-download | Pause download, alert user to free space, resume when space available |
| Network switches WiFi to cellular | Pause download, ask user if they want to continue on cellular |
| Model file corrupted after download | SHA-256 mismatch detected on verification; delete file, show error, offer retry |
| User has downloaded model, app updates but model version unchanged | Skip download, reuse existing model file |
| User has downloaded model, app updates and model version changes | Show "Updating AI Engine" screen, download new model, delete old on success |

---

## 4. Recommended Approach

### Recommendation: First-Launch CDN Download with Dual-CDN Failover

**Primary CDN:** Cloudflare R2 (zero egress, predictable near-zero cost at any scale)
**Fallback CDN:** GitHub Releases (zero cost, no documented bandwidth cap, minimal setup)
**Download package:** `background_downloader` Flutter package
**Network detection:** `connectivity_plus` Flutter package

### Rationale

1. **Cost certainty:** R2's zero-egress model means costs are flat regardless of download volume. At 100K monthly downloads of a 1.75 GB file (175 TB egress), R2 costs ~$0.03 per month versus $22,500 on Firebase or $2,625 on S3.

2. **Single Flutter implementation:** One download flow for both platforms. No need for platform-specific Background Assets (iOS) or Play Asset Delivery (Android) at launch.

3. **Decoupled model updates:** Can ship new models without app store review. Just upload to R2, update the version manifest, and users download the new model on next launch.

4. **Dual-CDN resilience:** GitHub Releases as fallback means even if the R2 bucket has an issue, users can still download the model.

5. **Minimal constraint violation:** The $0 monthly cost means this violates no spending constraints. The Cloudflare free tier covers 10 GB storage (sufficient for one model file). GitHub Releases is entirely free.

### Implementation Steps

1. **Set up Cloudflare R2 bucket** (30 minutes)
   - Create Cloudflare account (free tier)
   - Create R2 bucket named `dante-models`
   - Upload GGUF model file
   - Configure public access via custom domain or R2.dev subdomain
   - Note the public download URL

2. **Set up GitHub Releases fallback** (15 minutes)
   - Create a GitHub Release tagged with model version (e.g., `model-v1.0.0`)
   - Upload GGUF file as release asset (must be under 2 GB; if Phi-3 at 2.28 GB, split into two parts or use Gemma at 1.5 GB)
   - Note the release asset download URL

3. **Create model manifest** (15 minutes)
   - Create a JSON manifest file embedded in the app binary:
     ```json
     {
       "modelVersion": "1.0.0",
       "fileName": "game-master.gguf",
       "fileSizeBytes": 1610612736,
       "sha256": "abc123...",
       "primaryUrl": "https://dante-models.r2.dev/game-master-v1.0.0.gguf",
       "fallbackUrl": "https://github.com/org/repo/releases/download/model-v1.0.0/game-master.gguf",
       "minAppVersion": "1.0.0"
     }
     ```

4. **Implement ModelDownloadService in Flutter** (4 to 6 hours)
   - Add `background_downloader` and `connectivity_plus` dependencies
   - Implement `ModelDownloadService` class with:
     - `checkModelExists()`: verify local file exists and SHA-256 matches
     - `checkPrerequisites()`: storage space, network type
     - `startDownload()`: initiate with progress callback, CDN failover logic
     - `pauseDownload()` and `resumeDownload()`
     - `verifyIntegrity()`: SHA-256 hash comparison
   - Wire into app startup flow: if model missing, show download screen before game

5. **Build download UI screen** (2 to 3 hours)
   - Retro terminal-themed download screen matching existing DANTE TERMINAL aesthetic
   - ASCII progress bar, status text, speed indicator, ETA
   - Pause and resume button
   - Cellular warning dialog
   - Storage insufficient dialog
   - Error state with retry option

6. **Test download flow** (2 hours)
   - Test on WiFi: full download, verify SHA-256, launch game
   - Test pause and resume: pause mid-download, kill app, relaunch, verify resume
   - Test cellular warning: switch to cellular, verify prompt appears
   - Test failover: block primary URL, verify fallback kicks in
   - Test insufficient storage: fill device storage, verify user-friendly error
   - Test corrupt file: modify downloaded file, verify re-download triggered

7. **Future optimization: Add Android PAD** (optional, 4 to 6 hours)
   - As a v2 enhancement, add Play Asset Delivery fast-follow for Android
   - This lets the model download in background immediately after install
   - Keeps CDN download as iOS path and Android fallback

**Total estimated effort:** 9 to 12 hours for the core implementation (steps 1 through 6).

---

## Sources

### Apple Platform
- [Maximum build file sizes - Apple Developer](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)
- [On-demand resources size limits - Apple Developer](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/)
- [Meet Background Assets - WWDC22](https://developer.apple.com/videos/play/wwdc2022/110403/)
- [Downloading essential assets in the background - Apple Developer](https://developer.apple.com/documentation/BackgroundAssets/downloading-essential-assets-in-the-background)
- [Discover Apple-Hosted Background Assets - WWDC25](https://developer.apple.com/videos/play/wwdc2025/325/)

### Google Platform
- [Play Asset Delivery - Android Developers](https://developer.android.com/guide/playcore/asset-delivery)
- [Optimize your app size - Play Console Help](https://support.google.com/googleplay/android-developer/answer/9859372)
- [asset_delivery Flutter package](https://pub.dev/packages/asset_delivery)
- [Android App Bundle FAQ - Android Developers](https://developer.android.com/guide/app-bundle/faq)

### Hosting
- [Cloudflare R2 Pricing](https://developers.cloudflare.com/r2/pricing/)
- [About releases - GitHub Docs](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [About large files on GitHub - GitHub Docs](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)
- [Hugging Face Hub Rate Limits](https://huggingface.co/docs/hub/en/rate-limits)
- [Hugging Face Storage Limits](https://huggingface.co/docs/hub/en/storage-limits)
- [Firebase Pricing](https://firebase.google.com/pricing)
- [Firebase Storage Pricing Changes FAQ](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)

### Flutter Implementation
- [background_downloader Flutter package](https://pub.dev/packages/background_downloader)
- [connectivity_plus Flutter package](https://pub.dev/packages/connectivity_plus)

### Project Internal References
- BL-003: PoC findings with model size measurements
- BL-014: Performance budget with RAM and file size constraints
- L-005: Constraint priority stack (RAM > Quality > Decode speed > TTFT > Battery > Model size)

---

*Research conducted: 2026-03-25. Hosting pricing and platform limits are subject to change.*
