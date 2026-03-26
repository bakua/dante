# BL-220: Cross-Reference Audit Results

> Audited: 2026-03-26 | Status: **ALL REFERENCES VALID**

## BL-195 File Path References

| # | Referenced Path | Source Section | Exists |
|---|----------------|----------------|--------|
| 1 | `./../BL-216/build-baseline-report.md` | H1 | YES |
| 2 | `./../BL-215/ci-failure-playbook.md` | H1 | YES |
| 3 | `docs/privacy-policy.html` | H2 | YES |
| 4 | `docs/terms-of-service.html` | H2 | YES |
| 5 | `docs/index.html` | H2 | YES |
| 6 | `dante_terminal/lib/config/legal_urls.dart` | H2 | YES |
| 7 | `.github/workflows/deploy-pages.yml` | H2 | YES |
| 8 | `dante_terminal/lib/main.dart` | H3 | YES |
| 9 | `scripts/generate_keystore.sh` | H5 | YES |
| 10 | `dante_terminal/android/key.properties.template` | H5 | YES |
| 11 | `dante_terminal/android/app/build.gradle.kts` | H5 | YES |
| 12 | `scripts/archive_ios.sh` | H6 | YES |
| 13 | `dante_terminal/ios/ExportOptions.plist` | H6 | YES |
| 14 | `.godai/artifacts/BL-171/research.md` | H8 | YES |

## BL-212 File Path References

| # | Referenced Path | Exists |
|---|----------------|--------|
| 1 | `.godai/artifacts/BL-195/human-handoff-checklist.md` | YES |
| 2 | `.godai/artifacts/BL-156/app-store-listing-package.md` | YES |
| 3 | `docs/privacy-policy.html` | YES |
| 4 | `docs/terms-of-service.html` | YES |
| 5 | `.godai/artifacts/BL-171/research.md` | YES |

## Stale Data Fixes Applied

| Document | Field | Old Value | New Value | Reason |
|----------|-------|-----------|-----------|--------|
| BL-195 H1 table | Commit count | 29 | 33+ | Commits accumulated since BL-195 was written |
| BL-195 H1 title | Commit count | 26 | 33+ | Same |
| BL-195 H1 body | Commit range | "BL-069 through BL-217" | "BL-069 through BL-220" | Additional BL items executed |
| BL-195 H1 body | Clean commits count | 29 | 33+ | Same |
| BL-195 H1 steps | Expected commit count | 29 | 33+ | Same |
| BL-212 row 1 | Commit count | 27 | 33+ | Same |

Used "33+" notation since the count increases with each new commit (including this audit).

## BL-Item Attribution References (Not File Paths)

These are parenthetical attributions like "(BL-198)" that tell the human which backlog item produced an artifact. They do NOT point to files inside artifact directories. No action needed.

- BL-069, BL-144, BL-150, BL-156, BL-171, BL-198, BL-204, BL-205, BL-210, BL-215, BL-216, BL-217

## Summary

- **17 file paths audited** across BL-195 and BL-212
- **17/17 exist on disk** (100%)
- **0 missing artifacts** (BL-215 and scripts/generate_keystore.sh were both created by prior executions)
- **6 stale commit counts** updated to reflect current state
- **Handoff is ready for human consumption** with no dead links
