# Firefox 159 post-beta security patch-presence audit — 2026-11-04 UTC

## New source audit: five previously unreviewed high-impact CVEs — 2026-11-04 UTC

This is a new extension of the existing 17-issue spot audit, **not a re-count of previously verified CVEs**. Actual upstream fix commits from [Mozilla's Firefox 159 advisory](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) were compared against the pinned `FIREFOX_159_0b5_RELEASE` source, official stable Firefox 159, and Vulpra `main`:

| CVE | Verified source presence | Qualification |
| --- | --- | --- |
| **CVE-2026-117873**, FFmpeg frame bounds, Bug 2071733 | The `FFmpegVideoUtils.h` patch-result Git blob is **exactly identical** in all four sources. `FFmpegVideoDecoder.cpp` has different whole-file hashes but retains the actual checked buffer extent and per-plane backing buffer conditions | No live native-decoding regression or exploit proof |
| **CVE-2026-117874**, internationalization use-after-free, Bug 2073685 | **6/6 original patched C++ code file blobs**, plus its original cross-realm HTML crashtest, are byte-identical in fixed commit, beta, stable and Vulpra | No browser crashtest execution here |
| **CVE-2026-117875**, scrollbar use-after-free, Bug 2073686 | **1/1** existing patched code file matches all four sources exactly | No runtime regression |
| **CVE-2026-117876**, SVG glyph use-after-free, Bug 2074167 | **1/1** existing patched code file matches all four sources exactly | No runtime regression |
| **CVE-2026-118005**, WebRTC frame buffer use-after-free, Bug 2073653 | **3/4** original patched file blobs match exactly; `RTCEncodedFrameBase.cpp` is different as a whole but retains the `JS_WrapObject` cross-compartment guards | No live WebRTC cross-realm replay |

**Revised cumulative spot-audit totals: 22 CVEs examined, two original-beta missing fixes, 15 with exact patch-result code-file identities or verified fix ancestry, and five with bounded protective-hunk matches but differing whole-file hashes.** The newly discovered checks indicate that all five additional reviewed vulnerabilities have relevant fixes in the original beta/Vulpra code; they do **not** establish completeness of all Mozilla Firefox 159 advisories. The two confirmed missing original-beta fixes remain transplanted only on the isolated security branch, and its full patched native runtime acceptance remains outstanding.


## Verified result: two missing high-impact upstream fixes

The Vulpra `main` source at `ea5022bd731662999b439739ab6213ff383ff081` still contains **two concretely verified post-159.0b5 security patch gaps**, independently anchored to official upstream Git tags, upstream landed fix commits, and byte-identical Git source blobs. This is a **source-patch presence audit**, not an exploitation demonstration.

| Mozilla advisory | Issue and fixed release | Exact upstream fix | Vulpra vs beta and fixed release |
| --- | --- | --- | --- |
| [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) (2026-10-27) | **CVE-2026-117860**, high-impact same-origin-policy bypass, DOM Navigation, Bug 2046558, Firefox 159 | [`9a2dc53`](https://github.com/mozilla-firefox/firefox/commit/9a2dc53c369c7ae5172018b35988e1d2ffeff402) | All **14/14** source files modified by the landed fix still have the **exact 159.0b5 blobs** in Vulpra; none has the fixed Firefox 159 blob |
| [MFSA 2026-123](https://www.mozilla.org/en-US/security/advisories/mfsa2026-123/) (2026-11-03) | **CVE-2026-120572**, high-impact layout boundary issue, Bug 2079035, Firefox 159.0.1 | [`603a78a`](https://github.com/mozilla-firefox/firefox/commit/603a78af8401f8f30c388b3fa330589e35d8b727) | All **3/3** existing code files changed by the patch still have the **exact 159.0b5 blobs**; none has its 159.0.1 fixed blob. The upstream fix also added an HTML crashtest, not counted as a preexisting code file |

Source provenance and ancestry were confirmed directly from Mozilla's public GitHub source repository:

- Frozen beta `FIREFOX_159_0b5_RELEASE` → `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`.
- Stable `FIREFOX_159_0_RELEASE` → `9a2dc53c369c7ae5172018b35988e1d2ffeff402`, a direct descendant in the [Git compare](https://github.com/mozilla-firefox/firefox/compare/34ac0671eb25f31f8c56ace36e1c413dd471eb8d...9a2dc53c369c7ae5172018b35988e1d2ffeff402), **6,900** commits ahead.
- Patched `FIREFOX_159_0_1_RELEASE` → `6181e6b5f28a8fbae1d5c3ef6f6626b5a2180213`, a descendant of stable, [27 commits ahead](https://github.com/mozilla-firefox/firefox/compare/9a2dc53c369c7ae5172018b35988e1d2ffeff402...6181e6b5f28a8fbae1d5c3ef6f6626b5a2180213). Its Bug 2079035 fix is exactly `603a78af8401f8f30c388b3fa330589e35d8b727`.

Each source path was fetched directly at both the Vulpra `main` HEAD and the corresponding Mozilla tagged beta and fixed releases. **Exact Git blob SHA equality** between Vulpra and the beta, **and inequality** with the applicable stable fixed release, were verified for all 17 preexisting modified source files. The full per-file 40-hex digests are preserved in [machine-readable evidence](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json).

## File-level authenticated differences

| Upstream fix | Source path | Vulpra/beta blob (prefix) | Fixed upstream blob (prefix) |
| --- | --- | --- | --- |
| `CVE-2026-117860` | `docshell/base/BrowsingContext.cpp` | `241224f6f853` | `0986f712c924` |
| `CVE-2026-117860` | `docshell/base/CanonicalBrowsingContext.cpp` | `e0f4a668c6d2` | `86b2939a8387` |
| `CVE-2026-117860` | `docshell/base/CanonicalBrowsingContext.h` | `49a31c22232f` | `4f00705f3038` |
| `CVE-2026-117860` | `docshell/shistory/SessionHistoryEntry.cpp` | `319f965e0b77` | `a16e4ec279d7` |
| `CVE-2026-117860` | `docshell/shistory/SessionHistoryEntry.h` | `2ee5b72e8671` | `68e46ffedaf2` |
| `CVE-2026-117860` | `docshell/shistory/nsSHEntryShared.h` | `558a36de625e` | `368acfaf59cb` |
| `CVE-2026-117860` | `dom/ipc/ContentParent.cpp` | `3e8987e97db1` | `e7ac12f052d6` |
| `CVE-2026-117860` | `dom/ipc/ContentParent.h` | `f2ef070f7124` | `cffb55b774c4` |
| `CVE-2026-117860` | `dom/ipc/PContent.ipdl` | `e41cbabe7103` | `3715db0dc9dd` |
| `CVE-2026-117860` | `dom/ipc/ParentProcessChannelHandle.cpp` | `1afc0cb89f74` | `286d235f5941` |
| `CVE-2026-117860` | `dom/ipc/ParentProcessChannelHandle.h` | `ef6f7a71cd92` | `0b1fcd547ed5` |
| `CVE-2026-117860` | `dom/ipc/WindowGlobalParent.cpp` | `2014c80a6eb5` | `59c74d956b86` |
| `CVE-2026-117860` | `dom/ipc/WindowGlobalParent.h` | `c3386ba78041` | `446101c1ad40` |
| `CVE-2026-117860` | `netwerk/ipc/DocumentLoadListener.cpp` | `b9465bbcb888` | `10b16322a4a5` |
| `CVE-2026-120572` | `layout/generic/AbsoluteContainingBlock.cpp` | `885ece81d8e3` | `0f15a8fc8175` |
| `CVE-2026-120572` | `layout/generic/AbsoluteContainingBlock.h` | `deac3bd8b039` | `eb95b77d9578` |
| `CVE-2026-120572` | `layout/generic/nsLineLayout.cpp` | `57d0f421b9ab` | `452ffc656ded` |

## Verified 159 advisory fixes already present in the beta

**Do not classify every Firefox 159 advisory as a missing Vulpra fix.** The official Mozilla [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) also covers two high-impact issues whose actual upstream patches were already integrated before the frozen beta:

| Advisory issue | Upstream code fix and Git ancestry | Current Vulpra verification |
| --- | --- | --- |
| **CVE-2026-117861** / Bug 2053240 — sandbox escape, DOM Navigation | [Mozilla commit `2335ef39`](https://github.com/mozilla-firefox/firefox/commit/2335ef39b6a42febce70ac44e61453a75844c73b), with upstream compare `merge_base_commit` **equal** to that fix when comparing fix → `FIREFOX_159_0b5_RELEASE`; therefore direct ancestor of the beta | **10/10** existing code files from that fix still have the exact same Git blob SHA on current Vulpra `main` as the original tagged beta |
| **CVE-2026-117862** / Bug 2054644 — privilege escalation, HTTP networking cache | [Mozilla commit `b61c80e`](https://github.com/mozilla-firefox/firefox/commit/b61c80e501f1d8fab7643c928709baa502f7cd66), also authenticated as a direct ancestor of `FIREFOX_159_0b5_RELEASE` via Git comparison merge base | **6/6** code files touched by the fix have identical beta/current Vulpra Git blobs; all six also have identical beta/Firefox 159 stable Git blobs |

A third spot check, **CVE-2026-117868 / Bug 2059961** (DOM Networking WebTransport sandbox escape), also found the [upstream fix `315f2bc`](https://github.com/mozilla-firefox/firefox/commit/315f2bc612414bcf088fc865d2b2225489aba010) in the pinned beta. All **three/three** files changed by its fix have the **exact same Git blob SHA** in the upstream patch-result commit, tagged Firefox 159.0b5, tagged Firefox 159 stable, and Vulpra `main`. Unlike the two fixes above, Git's compare of this commit to the beta shows **diverged ancestry**, not a direct ancestor; this classification relies on **exact resulting code-file identity**, not a falsely asserted ancestry relationship.

This finding is **positive evidence of upstream patch inclusion and retained source code**, not independent exploit testing or complete security readiness. It is independent of the **two genuinely missing** patches above. The exact 16 file SHA values and upstream parent commits are recorded in the [machine-readable audit](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json), with verified provenance `main` at `d96d1147`.

A fourth spot check covers **CVE-2026-117893 / Bug 2078946**, incorrect TLS short-write boundary handling in **Security: PSM**. Mozilla's [code fix `58f4688`](https://github.com/mozilla-firefox/firefox/commit/58f4688447b58e69ef29414b709f6d6850de4caa) modifies `NSSSocketControl.cpp`, `NSSSocketControl.h`, and `nsNSSIOLayer.cpp`. All **three/three** resulting code blobs match **exactly** across this fix-result commit, pinned 159.0b5, stable 159 and Vulpra `main` (three full SHA-1 blob identities retained in the JSON audit). Source identity verifies the fix-result code is present; commit ancestry for this fix was **not checked**, and this does not establish that all certificate-path or security behaviors are safe.

### Five additional high-impact Firefox 159 issues checked (2026-11-04)

The following source and patch records were independently checked against Mozilla's landed fix commits, `FIREFOX_159_0b5_RELEASE`, stable 159 and Vulpra `main`:

| Advisory fix | Verifiable retained code | Evidence scope |
| --- | --- | --- |
| **CVE-2026-117866 / Bug 2059011** — Canvas2D use-after-free | [Fix `62e595b`](https://github.com/mozilla-firefox/firefox/commit/62e595ba156c7324fd691ed5c00002e803554af5): **4/4 identical patched-result code blobs** (Cairo, recording and Skia) across all four sources | Fixed-source identity, no runtime exploit probe |
| **CVE-2026-117867 / Bug 2059110** — Layout use-after-free | [Fix `c404438`](https://github.com/mozilla-firefox/firefox/commit/c4044389e238759a9d6d64eff2e58f8e08801a2d): `nsFrameSelection.cpp` has the **same fixed-result blob** in all four sources | Source identity, not runtime memory-safety proof |
| **CVE-2026-117869 / Bug 2068362** — DOM event-handler use-after-free | [Fix `244b5a6`](https://github.com/mozilla-firefox/firefox/commit/244b5a637f793b26b4ac50cb769e1e05c1fef6e4): **direct ancestor** of tagged beta, and its `EventListenerManager.cpp` resulting blob matches all four sources | Confirmed ancestry plus source identity |
| **CVE-2026-117865 / Bug 2058653** — JavaScript GC ephemeron marking | [Fix `a52b040`](https://github.com/mozilla-firefox/firefox/commit/a52b040d2697ccdc47f3c2abb53c72cc23da35bb): the exact introduced `edge.target()->zone()` and `zone->shouldMarkInZone(targetColor)` guard appears in Vulpra's beta-identical `Marking.cpp` | **Relevant protection hunk present**, but whole-file Git blob differs from upstream fix-result and ancestry diverges; not a byte-identical fixed-result claim |
| **CVE-2026-117912 / Bug 2079209** — CSS same-origin-policy bypass | [Fix `ee6eaa5`](https://github.com/mozilla-firefox/firefox/commit/ee6eaa5a9b93b8ac4340924834e5609b731300c0): `mLoadedAsImage` cache-key initialization, mismatch rejection and lookup argument appear in Vulpra `Loader.cpp`; `Loader.h` has exact fixed-result blob | **Relevant fix hunks present**, but `Loader.cpp` whole-file Git blob differs and ancestry diverges; not a byte-identical result claim |

These classifications rely on **9 inspected changed code files** plus upstream commit metadata. The exact per-file blob hashes, source-match flags, upstream ancestry where verified, and literal protective hunks are retained in [the JSON audit](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json). Test files added with those commits are not counted as source-code patch identities. This is **no substitute for security regression tests**, and does not establish that other patches are present.

The **11-issue spot audit now has two confirmed missing fixes**, **seven fixes with patched-result code-file identity or authenticated ancestry**, and **two fixes whose specific protective hunks are present despite other whole-file differences**. The remaining advisory issues remain unreviewed; no security-readiness claim or native milestone credit is justified. Original comparison source and installed browser profiles are unchanged.

## Four additional Firefox 159 high-impact fixes checked (2026-11-04)

Mozilla's [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) identifies all four issues as high impact. Each fix's landed upstream code was compared with `FIREFOX_159_0b5_RELEASE`, stable 159 and Vulpra `main`; divergent Git ancestry **does not imply** a missing fix when source code matches.

| Advisory issue | Code evidence | Limits |
| --- | --- | --- |
| **CVE-2026-117872 / Bug 2068410**, JavaScript Standard Library use-after-free | [Fix `bf82d96`](https://github.com/mozilla-firefox/firefox/commit/bf82d965a621cc4d7bd91b546347a8d491a71bf2): **2/2** existing changed code files, `js/src/builtin/Array.cpp` and `js/src/vm/ArrayObject.h`, have the exact fix-result Git blobs in Vulpra, beta and stable | No added jit-test counted as existing code; no execution or exploit probe |
| **CVE-2026-117922 / Bug 2079692**, WebSocket use-after-free | [Fix `b5e0496`](https://github.com/mozilla-firefox/firefox/commit/b5e0496b140550be2d82768a6829814588b4828e): patched `WebSocketChannel.cpp` Git blob matches across all four sources | Fixed-source identity only |
| **CVE-2026-118008 / Bug 2075440**, DOM Navigation privilege escalation | [Fix `44c8fd8`](https://github.com/mozilla-firefox/firefox/commit/44c8fd8df124546b1aec37bd794eed0a97140cf3): patched `PdfEmbedFallbackParent.sys.mjs` Git blob matches across all four sources | Fixed-source identity only |
| **CVE-2026-117871 / Bug 2068400**, Graphics invalid pointer | [Fix `48440d8`](https://github.com/mozilla-firefox/firefox/commit/48440d86a6ba6de2516c77520f8eef311cf04d98): Vulpra's `Swizzle.cpp` contains the introduced gap-based `CollapseSize` guard and checked source/destination stride-gap calculations | **Relevant protective code only**: whole-file blob differs from fix-result; ancestry diverges, no runtime proof |

All changed-code SHA identities and relevant protective hunks are recorded in the [machine-readable audit](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json). These findings do not establish security readiness, patch provenance across every dependency, or browser-level regression acceptance.

**Current spot audit: 15 CVEs checked, two confirmed missing patches; ten additional issues with exact resulting code-file identities or verified fix ancestry, plus three where relevant security-remediation hunks are present but full fixed-result file identity differs.** Most of the large Firefox 159 advisory still requires review, and a separate security-updated native build is release-blocking.

## Two additional Firefox 159 high-impact fixes verified (2026-11-04)

Two more [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) defects were independently checked against their actual upstream fix-result commits, tagged 159.0b5, stable 159 and Vulpra `main`:

| Issue | Exact code evidence | Qualification |
| --- | --- | --- |
| **CVE-2026-117870 / Bug 2068395** — JavaScript sparse-array densification use-after-free | The two upstream source fixes [`b8032b0`](https://github.com/mozilla-firefox/firefox/commit/b8032b08e3f65822ab9be50d7f8a6f00a0b3eec2) and [`40efda3`](https://github.com/mozilla-firefox/firefox/commit/40efda3cb0542d8c8c9741b20d3351f3e658ee23) were confirmed sequential by Git ancestry. Their final **4/4 changed existing code files** in `js/src/vm` match the fix-result, beta, stable release and Vulpra Git blobs exactly | The fix chain itself is sequential, but the final commit is not an ancestor of the tagged beta; verification relies on code identity and is not an exploit run |
| **CVE-2026-117921 / Bug 2079687** — CSS parent-rule use-after-free | [Upstream fix `e54211e`](https://github.com/mozilla-firefox/firefox/commit/e54211ea08efc3e4a6440739aa173b9edfc83b67): **8/8 existing changed code files** (`dom/webidl` and `layout/style`) have identical Git blobs in patch result, tagged beta, stable and Vulpra | Commit ancestry to beta diverges, but each post-fix file is identical; no runtime memory-safety assertion |

The [JSON crosswalk](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json) records all 12 matched code paths and SHA-1 blobs. This **17-issue spot audit** now classifies **two missing** fixes, **12 fixes with verified complete patch-result code-file identities or authenticated fix ancestry**, and **three with the relevant fixed-condition hunks present but differing whole-file hashes**. It is not exhaustive and does not change the security-port branch's compiled/runtime acceptance status.

## Scope and required continuation

**These two exact upstream patch changes are missing.** The audit does not prove that the corresponding exploit is reachable in every Vulpra configuration, that a missing patch necessarily makes a specific user action exploitable, or that other Mozilla security fixes are missing or present. Do not extrapolate these two findings to an exhaustive CVE inventory. Some upstream fixes may predate the beta; others may require applicability/patch-review rather than cherry-picking.

**Security-maintenance issue [#3](https://github.com/sguzman/vulpra/issues/3) remains open and becomes a concrete blocker to routine or public use.** Prior successful native M2/M3 rendering, navigation, extension, Nimbus, TLS-negative fixtures and package checks are not a substitute for upstream security maintenance. Until a newly security-patched source is built and independently tested, keep using an updated production browser for ordinary or sensitive browsing.

Next: audit the remaining MFSA 2026-118 and 2026-123 fixes for applicability and patch presence; prepare a **separate source-maintenance upgrade** (prefer an appropriately recent upstream patched release over blind cherry-picking), preserve Vulpra branding/security/extension/profile assumptions and the immutable M3 original package, run full source-pinned native build and security/runtime acceptance, and only then reconsider use/release readiness.

No upstream source files changed, no original comparison package modified, no installed Firefox Developer Edition or its profiles touched. This security review does **not** close the broad M3 feature/FFI dependency gate or claim package savings. **Overall 61%; M3 5/6 (83%); Δ+0 pp.**

## Additional scoped source verification: 117864 and 117877 (2026-11-04)

Two previously unaudited **high-impact** entries in [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) have been checked against exact Mozilla Git blobs at `FIREFOX_159_0b5_RELEASE`, `FIREFOX_159_0_RELEASE`, upstream patch-result commits and Vulpra `main` at `ed76a0fc`. The full 40-character per-file crosswalk is in the companion JSON.

- **CVE-2026-117864, Bug 2058614 (Form Manager sandbox escape):** Mozilla commits [`7543595`](https://github.com/mozilla-firefox/firefox/commit/7543595667ef859ad83cba275f114cd08ea94079) and [`276e954`](https://github.com/mozilla-firefox/firefox/commit/276e954dae00a968addc4e51cdfc4ed5c01791c2) update a Lit vendor patch and its generated `lit.all.mjs`. Both **2/2** Git blobs at the final patch result are *identical* in the beta tag, stable tag and Vulpra `main`. This is fix-result source identity, not runtime exploit testing.
- **CVE-2026-117877, Bug 2074209 (font palette lifetime use-after-free):** the selected final upstream landing [`b193e85`](https://github.com/mozilla-firefox/firefox/commit/b193e850fbf39925b5dfa8c0f8a741371458ee12) touches **16** code files. All **16/16** corresponding Git blobs are *identical* between the beta tag, fixed stable tag, and Vulpra `main`. **5/16** also equal that selected landing's postimage; **11/16** do not, and must not be misreported as exact selected-commit identity or direct ancestry. The upstream revert/reland sequence was not reconstructed in this round. The conclusion is scoped to fixed-release source identity for those 16 paths, not to the entire graphics lifetime behavior or exploit tests.

The targeted audit now records **24 distinct CVEs**: two confirmed missing from the immutable original beta and 22 with scoped positive source evidence (some are full fixed-blob identities, others only selected protective hunks). The two missing fixes have been transplanted to the **isolated** maintenance branch; they are **not** on `main`.

Separately, the isolated source `cb9f10dc` completed [full native compilation, packaging, Wayland/JavaScript/WebExtension/Nimbus/TLS testing and original Mozilla CSS crashtest](https://github.com/sguzman/vulpra/actions/runs/41926016069). The [independent security reconciliation](https://github.com/sguzman/vulpra/actions/runs/41933247296) also passed, including original-fixture evidence. These results **do not** establish full Firefox 159 advisory coverage, updated stable-version parity, universal sandbox behavior, target-workstation parity or release readiness. Preserve the unmodified M3 comparator until a complete maintenance integration decision is justified.

## Four additional high-impact fix checks: IndexedDB, tables, XML, networking (2026-11-04)

The targeted [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) source register now includes **28 unique CVEs**: **26** with scoped evidence of existing fixes in the pinned beta and **2** genuinely absent from the original beta (transplanted to the isolated, independently reconciled security build). These are source verifications, not a complete audit of Mozilla's extensive 159 advisory or proof of general exploit resistance. The companion JSON contains every examined code/test file's full Git blob SHA at Mozilla's fix-result commit, Mozilla's exact 159.0b5 and 159 stable release tags, and Vulpra `main` at `a15ad617`.

- **CVE-2026-117878 / Bug 2075431 — IndexedDB use-after-free.** [Mozilla fix `7277b62`](https://github.com/mozilla-firefox/firefox/commit/7277b624f1d9b70f22275ea850bd34c59c001a40) changes `dom/indexedDB/ActorsParent.cpp` to use a release-enforced check and consistent database path handling. The single changed code file's **exact upstream fix-result Git blob** (`05f7d8a0…`) matches the pinned beta, stable 159 and Vulpra. A later same-bug refactor was not independently evaluated; no runtime crashtest was executed.
- **CVE-2026-117879 / Bug 2075432 — table continuation border-collapse boundary error.** [Mozilla relanding `a8d29a5`](https://github.com/mozilla-firefox/firefox/commit/a8d29a532006f82dc09ff167a004105347dc85a8) touches two code files and an original WPT printing crashtest. All **3/3** blobs are identical between beta/stable/Vulpra; **2/3** exactly match the selected commit's postimage. The nonidentical `nsTableFrame.cpp` still contains the protective continuation-aware `IsBorderCollapse()` and `SetBorderCollapse()` logic. Crashtest present in source, not run.
- **CVE-2026-117880 / Bug 2075996 — XML pretty printer use-after-free.** [Mozilla fix `01c4f78`](https://github.com/mozilla-firefox/firefox/commit/01c4f7862c6ba1fd4f2629a7c633c6bd6fb456d9) touches **6** code/test paths; all **6/6** match beta/stable/Vulpra, **5/6** also the selected commit's postimage. The nonidentical `nsXMLContentSink.cpp` retains the precise `mDocument->GetRootElement() != mDocElement` early-return guard, examined in Vulpra source; both upstream HTML crashtests, their SJS fixture and manifest are source-present. No real-browser replay.
- **CVE-2026-117884 / Bug 2076410 — Networking stream-cleanup use-after-free.** [Mozilla fix `bf319dd`](https://github.com/mozilla-firefox/firefox/commit/bf319ddf6e5efd9db78ff1686c1580d62e402e27) modifies one `dom/fetch/FetchUtil.cpp` file: **1/1 exact fixed-result Git blob** across beta, stable, Vulpra. No runtime exploit probe.

**Status unchanged:** Security maintenance remains open pending a complete relevant advisory/delta review, suitable maintenance/update cadence and release acceptance. Branch `security/firefox-159-postbeta-hotfixes` retains the two independently tested transplanted fixes without changing the M3 baseline; do not silently merge, prune or declare the browser security-current.

## High-impact WebRTC and JavaScript GC security-patch series (2026-11-04)

Two further entries in [Mozilla's Firefox 159 high-impact advisory](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) were independently traced to their actual upstream Git commit sequences and compared across **Firefox 159.0b5**, **Firefox 159 stable** and **Vulpra `main` at `ba1a45e`**. Each examined file's full Git object SHA, and its source-result relationship to the relevant upstream commit, is recorded in the machine-readable JSON crosswalk.

- **CVE-2026-118006 / Bug 2074202 — WebRTC signaling privilege escalation through media-transport lifecycle use-after-free.** Upstream remediation commits [`3929ca6`](https://github.com/mozilla-firefox/firefox/commit/3929ca6ec195aa7dde0fd4a41f4a329a808093a9), [`6e7cf87`](https://github.com/mozilla-firefox/firefox/commit/6e7cf87d85e7518749db2283fb513a5b0db84af9), and later formatting [`5b25d01`](https://github.com/mozilla-firefox/firefox/commit/5b25d01db35b55164f9ff218807bc3fcb80213f8) affect **11 unique tracked paths**, including the STS shutdown API, WebRTC handler code, tests and build manifests. All **11/11** beta files have **identical Git object SHAs** to stable 159 and Vulpra. **7/11** match their *last selected upstream commit* postimages; the other four differ without release-to-beta drift. The specific refcount/lifecycle-decoupling and shutdown implementation appears in upstream patches. No runtime WebRTC exploit reproduction was executed.
- **CVE-2026-118007 / Bug 2075296 — JavaScript GC use-after-free, cross-zone symbol references.** The full upstream ten-part sequence ([part 1](https://github.com/mozilla-firefox/firefox/commit/febb26bdcf66da42606dba79d9461e009fe00d3c) through [part 10](https://github.com/mozilla-firefox/firefox/commit/427c9a61347c910ebe2553ce8476c6cbc1413650), all ten commit SHAs in the JSON register) touches **74 distinct tracked paths** spanning JS runtime, GC, DOM and XPConnect code, cross-zone regression tests and debugger support. All **74/74** beta objects have **identical SHAs** in stable 159 and Vulpra; **65/74** match their last selected upstream series-commit postimages. The nine nonmatching selected postimages have the *same* resulting source across both Mozilla release tags and Vulpra, not an observed Vulpra-only omission. No GC exploit test or native JS regression suite was run.

**Scope:** The audited register now contains **30 unique CVEs**: **28** with selected source-level evidence of existing fixes in the original pinned beta and **2** confirmed missing there, transplanted only on the isolated security branch. Cross-release source identity for these touched paths is strong inclusion evidence, but not the same as original patch ancestry, all feature-state runtime safety, an exhaustive advisory audit, or a current security-update program.

A [Git-source object checker](../../ci/security-159-check-source-crosswalk.sh) now implements a fail-closed local `jq`/Git verification of those **85** source path identities and register invariants, without a browser rebuild. **Its execution in CI is still unverified**: GitHub's Contents/Tree API repeatedly timed out while attempting to add the associated workflow in this large repository. Do not count a verifier CI pass or claim release readiness until an actual workflow executes and passes.

## Further DOM and layout lifetime fixes: 117881, 117882, 117883 (2026-11-04)

The three high-impact fixes below were traced from the [Firefox 159 advisory](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) to actual Mozilla upstream patch commits and compared path-by-path against **Firefox 159.0b5**, **Firefox 159 stable**, and Vulpra `main` at `e4f289d2`. The register now has **33 distinct CVEs** (31 scoped source-positive findings; two known original-beta misses addressed only on the isolated security branch).

- **CVE-2026-117881 / Bug 2076267 — DOM NodeIterator use-after-free.** [Fix `26da06e`](https://github.com/mozilla-firefox/firefox/commit/26da06ebb689a513d38cb6a8d373c6f85c01db68) touches `dom/base/NodeIterator.{cpp,h}`. Both **2/2** source blobs exactly match the selected patch-result Git object SHA in beta, stable and Vulpra. Vulpra's `NodePointer` uses `nsCOMPtr<nsINode>` for strong ownership. No targeted runtime crashtest executed.
- **CVE-2026-117882 / Bug 2076268 — generated-content counter / CSS containment use-after-free.** [Fix 1 `84edf83`](https://github.com/mozilla-firefox/firefox/commit/84edf83684a29ceb7fbcbb1f3061dae64f830b2c) and [fix 2 `b0af5bf`](https://github.com/mozilla-firefox/firefox/commit/b0af5bf7cd945a4cdced2d13f554b9026931ca1b) touch **7** code/WPT fixture paths. All **7/7** match beta/stable/Vulpra; **6/7** exactly match their selected upstream commit's postimage. The remaining `nsCSSFrameConstructor.cpp` differs but retains the `RefPtr<nsAtom> mCounterListName` ownership fix. Three original WPT CSS-containment crashtest files exist but were not replayed.
- **CVE-2026-117883 / Bug 2076271 — HTML stream parser executor use-after-free.** [Fix `cc7a5b8`](https://github.com/mozilla-firefox/firefox/commit/cc7a5b83a2d85a767c4f16dd61a23af8bcd080d8) touches `dom/xhr/XMLHttpRequestMainThread.cpp` and `parser/html/nsHtml5StreamParser.cpp`, with **2/2 exact fix-postimage Git blobs** across beta/stable/Vulpra. Vulpra's cycle collection unlink logic calls `Terminate()` and preserves executor references until the parser is done. No exploit regression was run.

The source guard added to the existing security evidence workflow ([integration `1abc238`](https://github.com/sguzman/vulpra/commit/1abc2380e8c5146da2f308879b73e6ad0a1dca2f), [source-change triggers `e4f289d`](https://github.com/sguzman/vulpra/commit/e4f289d2be811a231e87b47f6bfc50ec8cdbc023)) covers the separate **85 WebRTC/JavaScript GC files** for CVE-2026-118006 and CVE-2026-118007. Its first complete CI run and Actionlint passed; the source-trigger expansion also passed its independent workflow and Actionlint. The newly audited three CVEs are not added to the 85-path guarded cohort merely by being in the register.

## Nine more high-impact source checks and general CI coverage (2026-11-04)

[MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) was checked against the upstream Mozilla fix commits, the exact pinned `FIREFOX_159_0b5_RELEASE` tree, `FIREFOX_159_0_RELEASE`, and Vulpra `main`. **Nine distinct new high-impact CVEs** have source-positive evidence in [the Git blob register](./SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json):

| CVE | Mozilla bug | Scope and fixed-source evidence |
| --- | --- | --- |
| **CVE-2026-117885** (Grid UAF) | 2076983 | Two relevant paths equal beta/stable/Vulpra, one matching selected relanding postimage; Grid measurement code contains guarded cached-property lookup and post-reflow refresh, original crashtest only source-present |
| **CVE-2026-117887** (DOM table-cell UAF) | 2077385 | One exact upstream postimage; `CellIndex()` retains its row with `RefPtr` |
| **CVE-2026-118010** (Accessibility UAF) | 2077770 | One source path identical across beta/stable/Vulpra but different from selected upstream postimage; `mARIAOwnsHash` relocation-removal guard confirmed |
| **CVE-2026-117896** (DOM form-submit UAF) | 2079032 | Two exact upstream fix postimages; weak submit-element pointers replaced with `RefPtr` |
| **CVE-2026-117897** (Table bounds) | 2079036 | Three exact upstream postimages including the original border-collapse crashtest |
| **CVE-2026-117898** (JIT UAF) | 2079040 | Six source paths identical across the three refs, three exact postimages; `StringToAtom` has a distinct `result: StringId` operand, upstream jit-test present but not executed |
| **CVE-2026-117899** (HTTP/2 UAF) | 2079046 | Two exact upstream postimages; `CleanupStream` holds `RefPtr<Http2Session>` |
| **CVE-2026-117900** (HTML Editor UAF) | 2079053 | One exact upstream postimage; rejects nodes from different documents |
| **CVE-2026-117901** (screen-orientation UAF) | 2079054 | One exact upstream postimage; retains responsible `Document` via `RefPtr` |

**Important mapping correction:** Mozilla's **CVE-2026-117886** is a separate *Graphics: Text / Bug 2077162* vulnerability. The HTML form fix belongs to **CVE-2026-117896** and is recorded under its proper identifier. **117863 remains unverified by this source register**. Graphics: Text / CVE-2026-117886 is separately addressed in the OTS source audit below. A source comparison does not prove exploit rejection.

**Audit state:** 42 distinct CVEs covered by scoped source checks, of which **40** have evidence of their fixes already present in the pinned beta, plus **2** originally absent in that beta (`CVE-2026-117860` and `CVE-2026-120572`) and independently tested on the separate security branch. This is **not** complete MFSA 2026-118 coverage. MFSA 2026-123 (Firefox 159.0.1) lists `CVE-2026-120572` as its single reported high-impact fix, already included in the isolated patched source but not merged or released.

### CI source-integrity hardening

The previous WebRTC/GC-specific guard verified only 85 blobs across two CVEs. [Verifier expansion `3907a2f`](https://github.com/sguzman/vulpra/commit/3907a2f57e191ef4e49321f45014d40d9b93fa50) now checks **all 40 source-positive entries, 206 documented path-to-Git-object claims** (204 distinct paths), while retaining explicit WebRTC/GC cohort invariants. The register also had one 39-character XML pretty-printer SHA copied in error; [correction `2ad58d0`](https://github.com/sguzman/vulpra/commit/2ad58d05da2a197164599ae92cb4755166dd9dbd) repaired the exact previously verified 40-character Git object identifier, and the new verifier rejects truncated hashes.

[Workflow expansion `af2f414`](https://github.com/sguzman/vulpra/commit/af2f414d448b3b2d07f1a8ec492fc39bc443e43e) runs that check for changes to every top-level source/test directory represented in the currently audited paths, and additionally requires failure on forged non-WebRTC evidence and truncated hashes. These are Git-object source-integrity tests, **not** compiled binary or real-browser security tests. The native security branch, M3 pruning baseline and release acceptance remain unchanged.

## OpenType Sanitizer Graphics: Text and complete high-impact denominator (2026-11-04)

- **CVE-2026-117886 / Bug 2077162 — Graphics: Text boundary conditions:** Verified all **6/6** final touched OpenType Sanitizer source/configuration paths at exact Git-blob identity between upstream's final vendoring and local-patch re-apply series, Firefox 159.0b5, Firefox 159 stable and Vulpra `main`. Mozilla commits [`f3afc60`](https://github.com/mozilla-firefox/firefox/commit/f3afc6070391e920c60a0b6212aa44351bff428f) (vendor tip), [`81cf801`](https://github.com/mozilla-firefox/firefox/commit/81cf801eb5c4d13d9eda9548f796dabf9836f89a) (obsolete local CFF patch removal), and [`34ae62a`](https://github.com/mozilla-firefox/firefox/commit/34ae62af242280ddafd049af823fa6ed3bcafc7b) (re-apply local OTS patches). The removed `gfx/ots/ots-cff-charstring-ops-limit.patch` is absent from all three references. `gfx/ots/moz.yaml` pins upstream OTS to `6540e90426c17de7ddcae650409a9af5a450ea7a`. **No crafted-font exploit or sanitizer runtime check was run.**
- **Official high-impact release scope:** [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) enumerates **108 high-impact CVEs**: consecutive IDs `CVE-2026-117860` through `CVE-2026-117954` (95), and `CVE-2026-118005` through `CVE-2026-118017` (13). Of these, the register has **42** scoped source-audited entries (41 source-positive in the original pinned beta; one originally missing, `117860`, transplanted only on the isolated security branch). **66 high-impact CVEs remain unaudited**: this means *unknown source/patch status* in this audit, not evidence of 66 missing fixes.
- **Follow-up security release:** [MFSA 2026-123](https://www.mozilla.org/en-US/security/advisories/mfsa2026-123/) published for Firefox 159.0.1 includes its sole high-impact `CVE-2026-120572`, already transplanted and native-reconciled only on the isolated branch. Thus **43 / 109** high-impact advisory CVEs have scoped source/patch evidence across these two releases, with **66 still unreviewed**, subject to later advisory changes or platform applicability.
- **Fail-closed CI:** [`4c1b719`](https://github.com/sguzman/vulpra/commit/4c1b7197e9ac9b3737970acf3f6b57be6e3606ad) extends the crosswalk checker to validate the entire pinned advisory denominator, the independent 159.0.1 item and the currently **41** source-positive classifications with **212** path-to-source-hash assertions (210 distinct paths). [`28f9296`](https://github.com/sguzman/vulpra/commit/28f9296ee1ed961f709e4001aa9b04e1e9894c23) adds two explicit negative fixtures for CVE omissions in either advisory; the five earlier hash/postimage/duplicate-path negative fixtures remain. A green source hash gate is **not** a complete vulnerability regression suite, workstation acceptance or a new browser build.

**Priority:** Continue verifying unaudited applicable MFSA 2026-118 high vulnerabilities (especially uninitialized-memory `CVE-2026-117863` / Bug 2056783, whose original patch landing was not found by GitHub commit search), review platform applicability, establish a security-update and release process, and perform native target EndeavourOS/Hyprland QA. The isolated maintenance branch must not be merged or released on source-audit evidence alone.

### Accepted source-guard CI evidence (2026-11-04)

- [Verifier `6c7da38`](https://github.com/sguzman/vulpra/commit/6c7da38ac263d749839f17bce7ffd5f3cf3cff80) checks that the explicitly removed `gfx/ots/ots-cff-charstring-ops-limit.patch` remains absent from the tracked source tree.
- [Workflow `7a97b79`](https://github.com/sguzman/vulpra/commit/7a97b791f3694299d0e71e223009c0bad2d8f66f) adds a forged removal-claim fixture, alongside the previous seven SHA, path, upstream-postimage and advisory-coverage negative tests.
- **[Security source and native-evidence reconciliation run 41941692371](https://github.com/sguzman/vulpra/actions/runs/41941692371): SUCCESS**, including the **41-CVE / 212-path** source guard, **8/8** deliberately corrupted evidence rejection tests and independent prior native-build reconciliation. **[Actionlint run 41941692237](https://github.com/sguzman/vulpra/actions/runs/41941692237): SUCCESS**.
- This certifies only recorded source objects, declared advisory scope and previously bounded native-evidence reconciliation—not 66 still-unaudited high-impact CVEs, exploit-rejection tests or a workstation-ready release. The isolated security branch remains unchanged.

## Further source-verified Firefox 159 high issues and audited worklist (2026-11-06)

Source-level comparison of [Mozilla's MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) and its upstream fix commits, **Firefox 159.0b5**, **Firefox 159 stable**, and Vulpra `main` at `74238c0` identified eight more high-impact affected-code cohorts. Full SHA-1 Git blobs for every relevant affected file, upstream patch-result identifiers and provenance notes are in [the machine-readable register](./SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json). The following verification is strictly scoped source presence, not a native memory-safety or browser regression pass:

- **CVE-2026-117888 / Bug 2078649 — Canvas2D uninitialized memory.** [Mozilla `b5a7d53`](https://github.com/mozilla-firefox/firefox/commit/b5a7d53b596825c7ceeb35307d205ce8c8867341) touches **7** canvas/graphics and translator paths; **7/7** exact beta/stable/Vulpra source identities, **4/7** original selected fix postimage hashes, other three shared tagged-release revisions. No Canvas2D memory-sanitizer test.
- **CVE-2026-117894 / Bug 2078983 — WebRTC signaling bounds.** [Mozilla `631b21b`](https://github.com/mozilla-firefox/firefox/commit/631b21b70f19e626670b746fbe8b4c913a301f93) has **1/1 exact fix-result blob** in beta/stable/Vulpra. The encoded-frame destructor no longer calls `DetachData()`.
- **CVE-2026-117895 / Bug 2078994 — DOM fullscreen lifetime.** [Mozilla `272c1e4`](https://github.com/mozilla-firefox/firefox/commit/272c1e4ec390c32e10e9333894b650feffbe2310) modifies `dom/base/Document.cpp`. The selected upstream patch-result differs from the exact **beta/stable/Vulpra common source blob**; no independent exploit-guard execution or original-patch ancestry claim.
- **CVE-2026-117913 / Bug 2079252 — SVG text lifetime.** [Mozilla `7f7851f`](https://github.com/mozilla-firefox/firefox/commit/7f7851f753201ba458cdd5a1750b9e5290cc036a) has **3/3 exact postimage source/test hashes**; Vulpra retains `RefPtr<const gfxTextRun> textRun` and Mozilla's original `layout/svg/crashtests/2079252.html` plus manifest. Test source is present, not executed.
- **CVE-2026-117915 / Bug 2079255 — block/inline reflow boundary condition.** [Mozilla `84cec52`](https://github.com/mozilla-firefox/firefox/commit/84cec52ebaf55d3b51ac86c0853163a71d6310d6) touches **2** paths; both beta/stable/Vulpra identical, original WPT `block-break-before.html` exact patch-result hash, `nsBlockFrame.cpp` further revised between selected commit and tagged beta. WPT crashtest not run.
- **CVE-2026-117918 / Bug 2079676 — OffscreenCanvas lifetime.** [Mozilla `b3cb7d1`](https://github.com/mozilla-firefox/firefox/commit/b3cb7d1aba25441b8248bc1eeaf74e2994acdee3) modifies **2/2** files that exactly match upstream postimage/beta/stable/Vulpra.
- **CVE-2026-117919 / Bug 2079677 — fieldset/legend mutation lifetime.** [Mozilla `5d090af`](https://github.com/mozilla-firefox/firefox/commit/5d090afb26d21aca1decae79c440c498705f1c21) modifies **1/1 exact upstream fix-result code file**, beta/stable/Vulpra.
- **CVE-2026-117920 / Bug 2079681 — HTML parser mutation observer lifetime.** [Mozilla `2f2d052`](https://github.com/mozilla-firefox/firefox/commit/2f2d052fb8b8f7a2737e6391c545c3f59c6b14f3) has **1/1 exact fix-result code file** at each source ref.

**High-impact audit now 50/108** from MFSA 2026-118: **49** source-positive in the original pinned beta, **1** confirmed original-beta missing but transplanted in the separately tested maintenance branch (`CVE-2026-117860`), **58** not yet source-audited. MFSA 2026-123 (`CVE-2026-120572`) is separately addressed on the isolated branch, totaling **51 individually reviewed high CVEs across both advisories**. These ratios are *audit progress only*, not the fraction of deployed fixed vulnerabilities. There has been no new Vulpra native browser build, exploit-rejection test, source pruning, branch merge, or release.

**Restricted upstream issue:** `CVE-2026-117863` / Mozilla Bug 2056783 is high-impact uninitialized Audio/Video memory. The unauthenticated public Bugzilla page returns access denied, and Mozilla's public GitHub commit search for that literal bug number yielded no patch. Its status remains **unverified**; it must not be counted as either fixed or missing.

Mozilla's [published security advisory index](https://www.mozilla.org/en-US/security/advisories/) was checked 2026-11-06 and still listed **MFSA 2026-123 / Firefox 159.0.1** as the latest desktop Firefox security advisory. This check is not continuous update monitoring.

The existing fail-closed source workflow now checks **49 source-positive CVEs with 230 source path hash claims across 227 distinct files**, plus all previously required negative fixtures. [Commit `3e97d09`](https://github.com/sguzman/vulpra/commit/3e97d09ecdec4cddb5710022fc43c1bc4f6529bb) adds a bounded machine-readable **remaining-CVE audit worklist** artifact with the full set of unreviewed CVE IDs and explicit blockers, while preserving `security_release_ready: false`. CI success or a green worklist is *not* a Firefox build/feature test or a release acceptance decision.
