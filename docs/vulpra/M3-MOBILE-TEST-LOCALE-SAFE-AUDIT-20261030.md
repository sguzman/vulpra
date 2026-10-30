# M3 — Mobile, test fixtures, and packaged localization preservation audit

**Accepted 2026-10-30 UTC:** [independent audit CI 41111493159](https://github.com/sguzman/vulpra/actions/runs/41111493159)
**PASS**, artifact **13003343450**;
[workflow lint 41111492817](https://github.com/sguzman/vulpra/actions/runs/41111492817)
**PASS**. This audit supports a **conservative retain-without-further-pruning**
decision for shared test and localization roots, and accepts only three
**previously native-verified** non-Linux source-pruning cohorts.

## Bounded unsupported-platform source pruning

| Original accepted removal | Distinct Git paths removed | Original Git blob bytes | Native acceptance |
| --- | ---: | ---: | --- |
| Unsupported Windows/Cocoa widget and installer scope | 453 | 6,266,676 | [40519242468](https://github.com/sguzman/vulpra/actions/runs/40519242468) |
| Unsupported Android app-only roots | 14,134 | 115,996,869 | [40585240593](https://github.com/sguzman/vulpra/actions/runs/40585240593) |
| Eight specific Android/iOS/UIKit-only leaves | 280 | 7,704,040 | [40600510147](https://github.com/sguzman/vulpra/actions/runs/40600510147) |
| **Total, disjoint accepted source-only cohorts** | **14,867** | **129,967,585** | **All passed** |

The independent current-source audit checked that all eight specific
unsupported platform leaf paths remain absent: Android fonts, examples,
test_infra, test_runner, geckoview_example, branding, mobile/ios and
widget/uikit. These are **not** instructions to remove entire
`mobile/android` or `widget/android` trees: the shared GeckoView app
integration and Android toolkit code are retained, as is the complete
Linux GTK source. Native compile/Wayland/JS/WebExtensions/Nimbus were
already accepted in the original pruning workflows. Unsupported Android
Gradle/Taskcluster and `stage-android` targets are **not restored**
or silently claimed functional.

The new source check also verified 12 exact retained shared
GeckoView/GTK, testing/Marionette/mozbase and browser/toolkit
localization-registry source paths. Its source and run identity are
recorded in the evidence artifact. Prior per-candidate inventory
`source_files` fields overlap and must not be summed as removals.

## Testing: retain existing QA and build infrastructure

[Current 25-boundary QA source contract 41107821628](https://github.com/sguzman/vulpra/actions/runs/41107821628)
**PASS**, **25/25 deliberately removed-source fixtures rejected**.
[Existing test and locale manifest audit 40922064826](https://github.com/sguzman/vulpra/actions/runs/40922064826)
**PASS**, **14 bounded build relationships and 17 invalid mutations**.
[Independent QA/source/native crosswalk 41109168322](https://github.com/sguzman/vulpra/actions/runs/41109168322)
**PASS**, with genuine packaged WebDriver/browser evidence from
[41106584931](https://github.com/sguzman/vulpra/actions/runs/41106584931).

The entire shared `testing/` source root stays **KEEP**, including
manifest, mozbase, mozharness, GeckoDriver/Marionette, standards WPT,
Talos/Raptor performance corpora and unmeasured peripheral fixtures.
`--disable-tests` does not establish that these sources are unused by
the build system. No unverified peripheral fixture was removed.
The full generated build graph and independent fixture omission
benchmarks are **not** proven by this audit.

## Physically compiled normal-browser packaged localization

The successful [newer physical normal-browser inventory
41077783489](https://github.com/sguzman/vulpra/actions/runs/41077783489)
was authenticated against its original native compile and package
[40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527):

- Compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`.
- Full-normal archive SHA-256
  `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`;
  compressed archive **87,154,544 bytes**.
- Actual `omni.ja` entries **8,001**; **241 Fluent localization**
  paths, **46 hyphenation** paths, **2 dictionaries**, and
  **157 remote QA resource** paths in the bounded source-prefix census.
- Six protected language categories: 137 browser-l10n, 104 toolkit-l10n,
  one generated default.locale, two dictionaries, 46 hyphenation
  patterns, and 93 legacy chrome-locale entries. Combined **383**
  classified entries and **6,300,493 uncompressed logical ZIP bytes**.
- Earlier normal package [historical
  locale-census 40923776304](https://github.com/sguzman/vulpra/actions/runs/40923776304)
  and actual Hungarian hyphenation CSS
  [40937941448](https://github.com/sguzman/vulpra/actions/runs/40937941448)
  also passed their independently scoped checks.

All language and dictionary resources remain **KEEP**. The logical ZIP
bytes are not a safe deletion target or marginal compressed saving.
No language repack, optional langpack omission, remote service, new
source deletion, or fresh native browser build was performed by this
**read-only** crosscheck. Further optional localizations would require
a *new, explicitly scoped and reversible* trial and locale fallback
tests. Existing source and native results do not prove the entire
Mozilla dynamic dependency graph.

## Acceptance and continuing constraints

The audit goal was to **classify mobile, test and optional packaged
localization boundaries while retaining required desktop
functionality**. Its result is conservative, not an optimization:
prior mobile-only source pruning remains accepted; shared desktop, QA,
WebDriver and all physically observed language services remain in the
normal browser. This closes the **mobile/test/localization audit** gate
without expanding what may be removed. The independent **whole feature/
build/binary dependency graph** and **Pocket/promotion/Sync/telemetry
policy audit** are still separate M3 gates.

**M3: 4 of 6 accepted gates (66%); overall: 55%; this gate adds
+16 M3 percentage points and +5 overall percentage points**,
subject to the updated roadmap and full regression-suite acceptance.
