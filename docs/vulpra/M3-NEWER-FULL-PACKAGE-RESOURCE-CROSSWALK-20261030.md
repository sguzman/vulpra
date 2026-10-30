# M3 newer-source full-native resource crosswalk

**Verified real-package results:** [strict physical-root CI 41077783489](https://github.com/sguzman/vulpra/actions/runs/41077783489) **PASSED**, artifact **12988211924**, after [exact-source ELF and locale CI 41077034156](https://github.com/sguzman/vulpra/actions/runs/41077034156) **PASSED**, artifact **12987621504**; [workflow lint 41077783478](https://github.com/sguzman/vulpra/actions/runs/41077783478) **PASSED**.

The physical full-normal Linux package was built by [native CI 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527) from exact source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, `tar.xz` **87,154,544 bytes**, SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The original archive, scanners and resource crosswalk agree on the digest; neither the browser nor the workstation was modified by this census.

## Actual physical package observations

The native scan found **28 ELF regular files**, **268 direct DT_NEEDED edges**, and **50 distinct required SONAME names**: 14 matching packaged ELF name/SONAME declarations, 36 names requiring external resolution. Two `omni.ja` ZIPs contain **8,001 regular entries**: 2,674 in the toolkit JAR, 5,327 in the browser JAR. The exact source and normal package are more recent than the older `1683ca6` footprint, not identical to subsequent `main` commits.

Entries below are selected **exact physical path-prefix groups**, not exhaustive feature closures. Bytes are uncompressed nested ZIP-entry lengths, **not removable compressed tar.xz bytes**.

| Physical namespace | ZIP entries | Logical bytes |
| --- | ---: | ---: |
| Built-in New Tab bundle | 152 | 5,713,031 |
| New Tab feed-library subset | 63 | 1,079,637 |
| ASRouter modules | 31 | 797,913 |
| Normandy resource namespace | 26 | 115,994 |
| Sync modules | 33 | 613,058 |
| FxAccounts-named modules | 16 | 443,370 |
| AI Window roots | 257 | 2,662,819 |
| GenAI roots | 32 | 257,306 |
| DevTools roots | 2,301 | 20,824,628 |
| Remote automation/Marionette | 157 | 2,192,533 |
| Fluent localization | 241 | 1,001,800 |
| Hyphenation patterns | 46 | 4,471,692 |
| Dictionaries | 2 | 552,470 |
| Named Telemetry/Glean roots | 16 | 403,255 |
| Named crash-reporting roots | 3 | 71,676 |

The New Tab feed modules are **included within** the New Tab bundle. Other groupings can overlap, so never sum group sizes or infer package savings. Both browser and toolkit localization contribute to Fluent's 241 entries; dictionary/hyphenation resources are distinct. Named Telemetry/Glean and crash paths do **not** encompass all native and indirect components.

## Safeguards and decisions

The largest listed resource grouping is DevTools (**2,301 entries / 20,824,628 logical bytes**). Vulpra's current real QA and debugging depend on the DevTools/remote infrastructure, including WebDriver (**157 named remote-automation entries**); size alone does not justify removing either. Keep Sync/FxAccounts unless all browser UI, account and WebExtension consumers have independent fallbacks. Keep default localization, dictionaries and hyphenation for page layout and language behavior. Keep native Telemetry/Glean, crash-reporting, policy controls and deletion-request paths until privacy-safe proof exists. Narrow guarded Normandy, ASRouter promo, AdsFeed and PromoCard omissions have **separate** candidate-specific runtime and byte evidence; the full normal package's 26 Normandy resource entries are not 26 individually safe deletions. GenAI/AI Window resources require deeper import/UI/authentication mapping.

**Scope:** read-only physical entry/ELF declaration census. It does not establish loader ABI compatibility, complete runtime call paths, remote content delivery, default-browser source removal, current-main recompilation, RAM savings or reliable marginal compressed bytes. The newer normal New Tab [runtime 41004025705](https://github.com/sguzman/vulpra/actions/runs/41004025705) separately passed 26 protected behavior assertions; that is not a result of this static scanner.

**M3 remains 2/6 (33%); overall 44%; Δ0 pp.** The broad build/feature/platform and safety-fallback gates remain open.
