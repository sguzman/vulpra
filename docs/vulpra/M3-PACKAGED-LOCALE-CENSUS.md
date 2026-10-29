# M3 actual packaged locale-resource census

**Accepted evidence:** [GitHub Actions 40923776304](https://github.com/sguzman/vulpra/actions/runs/40923776304) **PASSED**. It reused the historical, independently SHA-256-verified **normal full Vulpra** native archive from [run 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401), built from **source `1683ca67b69389a879717bcd537772c3b40624b6`**, with no Firefox compilation or execution. The script additionally passed nine synthetic archive-classification and anti-tamper fixtures. Its downloadable `m3-historical-package-localization-census` JSON artifact retains the package digest, file/member count, inner-ZIP compressed-byte accounting, and original versus census source provenance.

## Direct observations from that historical default Linux package

| Quantity | Observed value |
| --- | ---: |
| Whole compressed `tar.xz` archive | **86,930,792 bytes** |
| Regular files at outer tar layer | **47** |
| Root `vulpra/omni.ja` non-directory entries | **2,674** |
| Browser `vulpra/browser/omni.ja` non-directory entries | **5,327** |
| Browser `omni.ja` localization resources | **689,418 logical bytes** |
| Root/toolkit `omni.ja` localization resources | **312,382 logical bytes** |
| Dictionaries inside root `omni.ja` | **552,470 logical bytes** |
| Hyphenation inside root `omni.ja` | **4,471,692 logical bytes** |
| Legacy locale/chrome entries inside both `omni.ja` files | **274,525 logical bytes** |
| Generated `default.locale` inside root `omni.ja` | **6 logical bytes** |

The reported localization/dictionary/hyphenation/legacy/default buckets comprise **6,300,493 bytes of classified uncompressed resource-entry payloads** across the two JARs (about 6.01 MiB). They are **not 6.01 MiB of removable content**. Unclassified entries are excluded, and this is not a complete translation inventory or installed-filesystem footprint.

The archive's **outer regular-file entries have zero directly classified localization/dictionary/default-locale bytes**; these resources are found within its two `omni.ja` ZIP archives. The browser and toolkit each use a `localization/` path prefix inside their own JAR, so correct attribution requires preserving the **containing JAR path**. The first audit incorrectly aggregated all such prefixes as toolkit localization; the corrected replay (40923776304) verifies container-aware categorization.

## Engineering interpretation

1. There is a concrete, physically packaged default-locale resource footprint in the actual compiled Linux browser. Deleting localization **source** wholesale would be dangerous and would not establish a byte reduction.
2. Browser and toolkit localization, language dictionaries/hyphenation and legacy chrome resources have different consumers. The [build dependency crosswalk](M3-TESTING-LOCALE-DEPENDENCIES.md) confirms Fluent registries, `default.locale`, browser packaging and language repack paths are wired.
3. Per-entry logical bytes and ZIP compressed member sizes **must not be used as marginal `tar.xz` savings**. Archive-wide deduplication, gzip/ZIP/XZ interaction, and package nondeterminism make any isolated removal estimate unverified.
4. This normal archive is **historical**. It is not an exact whole-source-matched build of the current main branch. No new browser runtime behavior, deletion, or current package-size comparison is established.

**Next evidence:** inspect whether a given optional locale/translation/dictionary resource is actually reachable, implement a reversible guarded omission with fallback, compile an identical-source normal and opt-in pair, validate native browsing/WebExtensions/Wayland/profile and locale fallback, then compare packaged members and compression with independent checksums. If actual savings are negligible or nondeterministic, retain the feature.

**Progress accounting:** this adds a verified *packaged artifact* submap to M3's unfinished complete dependency/asset inventory. It is not a passed broad gate. **M3 2/6 (33%); overall Vulpra 44%, Δ0 pp.**
