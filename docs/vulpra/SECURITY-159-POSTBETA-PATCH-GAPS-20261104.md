# Firefox 159 post-beta security patch-presence audit — 2026-11-04 UTC

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

## Two separately verified 159 advisory fixes already present in the beta

**Do not classify every Firefox 159 advisory as a missing Vulpra fix.** The official Mozilla [MFSA 2026-118](https://www.mozilla.org/en-US/security/advisories/mfsa2026-118/) also covers two high-impact issues whose actual upstream patches were already integrated before the frozen beta:

| Advisory issue | Upstream code fix and Git ancestry | Current Vulpra verification |
| --- | --- | --- |
| **CVE-2026-117861** / Bug 2053240 — sandbox escape, DOM Navigation | [Mozilla commit `2335ef39`](https://github.com/mozilla-firefox/firefox/commit/2335ef39b6a42febce70ac44e61453a75844c73b), with upstream compare `merge_base_commit` **equal** to that fix when comparing fix → `FIREFOX_159_0b5_RELEASE`; therefore direct ancestor of the beta | **10/10** existing code files from that fix still have the exact same Git blob SHA on current Vulpra `main` as the original tagged beta |
| **CVE-2026-117862** / Bug 2054644 — privilege escalation, HTTP networking cache | [Mozilla commit `b61c80e`](https://github.com/mozilla-firefox/firefox/commit/b61c80e501f1d8fab7643c928709baa502f7cd66), also authenticated as a direct ancestor of `FIREFOX_159_0b5_RELEASE` via Git comparison merge base | **6/6** code files touched by the fix have identical beta/current Vulpra Git blobs; all six also have identical beta/Firefox 159 stable Git blobs |

This finding is **positive evidence of upstream patch inclusion and retained source code**, not independent exploit testing or complete security readiness. It is independent of the **two genuinely missing** patches above. The exact 16 file SHA values and upstream parent commits are recorded in the [machine-readable audit](SECURITY-159-POSTBETA-PATCH-GAPS-20261104.json), with verified provenance `main` at `d96d1147`.

This 4-CVE spot audit classifies **two confirmed missing patches** and **two confirmed included-before-beta fixes**; **other MFSA 2026-118 cases remain unaudited**, and the separate full-security-maintenance issue remains open. No patch files, frozen comparison source or browser profiles were modified.

## Scope and required continuation

**These two exact upstream patch changes are missing.** The audit does not prove that the corresponding exploit is reachable in every Vulpra configuration, that a missing patch necessarily makes a specific user action exploitable, or that other Mozilla security fixes are missing or present. Do not extrapolate these two findings to an exhaustive CVE inventory. Some upstream fixes may predate the beta; others may require applicability/patch-review rather than cherry-picking.

**Security-maintenance issue [#3](https://github.com/sguzman/vulpra/issues/3) remains open and becomes a concrete blocker to routine or public use.** Prior successful native M2/M3 rendering, navigation, extension, Nimbus, TLS-negative fixtures and package checks are not a substitute for upstream security maintenance. Until a newly security-patched source is built and independently tested, keep using an updated production browser for ordinary or sensitive browsing.

Next: audit the remaining MFSA 2026-118 and 2026-123 fixes for applicability and patch presence; prepare a **separate source-maintenance upgrade** (prefer an appropriately recent upstream patched release over blind cherry-picking), preserve Vulpra branding/security/extension/profile assumptions and the immutable M3 original package, run full source-pinned native build and security/runtime acceptance, and only then reconsider use/release readiness.

No upstream source files changed, no original comparison package modified, no installed Firefox Developer Edition or its profiles touched. This security review does **not** close the broad M3 feature/FFI dependency gate or claim package savings. **Overall 61%; M3 5/6 (83%); Δ+0 pp.**
