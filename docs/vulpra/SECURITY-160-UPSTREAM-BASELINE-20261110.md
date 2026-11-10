# Firefox 160 upstream security release — verified release boundary (2026-11-10)

**Status: security-update planning only. Neither current Vulpra main nor the two-fix security staging branch is security-current. No source-engine rebase or target-machine build has been performed here.**

## Authenticated public source and advisory

- [Mozilla MFSA 2026-125](https://www.mozilla.org/en-US/security/advisories/mfsa2026-125/) announced **2026-11-10**, marked **high impact**, and says **fixed in Firefox 160**. The advisory contains numerous high-impact defects across graphics/WebRender, DOM/Navigation, sandbox escapes, networking, storage, media, WebExtensions and other systems. Do not assert that the pinned Vulpra beta lacks *every* listed patch without source-level applicability checking; the existing Firefox 159 audit found many upstream patches already present in the beta.
- Exact public upstream Mozilla source Git tag `FIREFOX_160_0_RELEASE` resolves to **`2887d9de1f69c0e9776413da80e7ba0d1225dd9b`**, verified via [GitHub's upstream tag ref](https://github.com/mozilla-firefox/firefox/tree/FIREFOX_160_0_RELEASE) and its commit record.
- Pinned Vulpra ancestor `FIREFOX_159_0b5_RELEASE` resolves to `34ac0671eb25f31f8c56ace36e1c413dd471eb8d`; upstream `FIREFOX_159_0_1_RELEASE` resolves to `6181e6b5f28a8fbae1d5c3ef6f6626b5a2180213`.
- GitHub compare `159.0b5...160` reports **ahead 11,016, behind 0, merge-base exactly `34ac0671`**. Compare `159.0.1...160` reports **ahead 4,089, behind 0, merge-base exactly `6181e6b5`**. Both compare responses expose only the first **300 changed file records**, so those are **not comprehensive changed-file inventories**. These commit counts cover all upstream work, not only security fixes. Do not equate them with CVE counts or work hours.

## Current Vulpra checkpoint and limits

Current project `main` was source-tested on EndeavourOS/Hyprland at `2006922502b6d27a7d89e56662530726441d8b45`; the user completed a successful compiled native rebuild, checksum-verified package smoke, graphical Google compatibility on fresh settings, and persistent QA profile restoration. **Those passes are functional QA, not a security audit.**

Two post-beta Firefox 159 fixes were independently transplanted by exact upstream Git blob IDs onto current main in [`security/159-0-1-on-current-main`](https://github.com/sguzman/vulpra/tree/security/159-0-1-on-current-main), covering **CVE-2026-117860** and **CVE-2026-120572** (17 code files, one original CSS regression fixture). Candidate [source-integrity CI 42896677968 PASS](https://github.com/sguzman/vulpra/actions/runs/42896677968); no integration into `main`. Two very early candidate native CI failures were shallow-checkout ancestry-test failures **before compiling** and do not establish a browser or security patch regression. The candidate's full native/runtime test and independent reconciliation must still pass before any rollout.

## Recommended full-upstream update acceptance contract

1. **Maintain separate baselines:** immutable `upstream-base` for original provenance; keep the original exact-source M3 comparison browser/package and the owner's working Vulpra build unchanged. Create a new isolated upstream-release upgrade branch using the **exact authenticated Firefox 160 tree**; do not overwrite existing source trees, erase local build artifacts, or prematurely merge 11,016 upstream commits to project main.
2. **Track Vulpra-specific deltas:** independently preserve application basename/branding, `general.useragent.compatMode.firefox=true` in Vulpra's browser defaults (without a global UA override), app/profile separation, and established launch/package/test contracts. Revalidate each delta against the *new upstream code*; don't assume old paths/API contracts or overlay whole old files.
3. **Security ledger:** enumerate Mozilla's Firefox 160 advisory by CVE, severity, affected code area, upstream landed fix, and exact beta versus Firefox 160 patch-result evidence. Explicitly distinguish verified already present, verified missing, divergent/conditional applicability and blocked-public-source cases. Track Firefox 159.0.1 as already superseded by the full 160 baseline, not a replacement for it.
4. **Full native build and acceptance:** configure/build/package an independent normal (not artificially minimized or headless-only) browser at one source commit. Assert exact source and package SHA, Wayland graphics, WebDriver JS navigation, WebExtensions, Nimbus, private profile, strict self-signed localhost certificate rejection, original upstream regressions, protected feature activation, loader/FFI and media boundaries. Recheck security sandbox/Safe Browsing/update functionality; the existing bounded tests do not prove full effectiveness.
5. **Do not claim public or sensitive-use readiness** until all security-review and maintenance policy gates pass, including a repeatable cadence when upstream releases again. Make no extrapolations from source-only integrity or an old CI pass.

Next engineering action: finish the independent **current-main 159 hotfix candidate's native/runtime CI**, then begin a *separate* Firefox 160 baseline migration effort. The verified local QA binary/profile remains usable as an isolated experimental testbed only, not a substitute for maintained production Firefox.

**Project progress remains overall 61% (Δ+0 pp), M3 5/6 = 83%.** This research and staging do not close M3 dependency/FFI gate six or any security-current/release gate.

## Initial authenticated high-impact Firefox 160 patch-presence crosswalk (2026-11-10)

Four advisory issues were compared **file by file** against (a) the exact Mozilla landed-fix Git commit, (b) tagged \`FIREFOX_159_0b5_RELEASE\`, (c) tagged \`FIREFOX_160_0_RELEASE\`, and (d) Vulpra's current \`main\`. This is a **bounded source audit**, not a complete advisory review or exploit regression.

| Mozilla issue | Source files verified against 159 beta | 160 comparison |
| --- | ---: | --- |
| CVE-2026-124853 / Bug 2058035 — Graphics: Text sandbox escape | 2/2 identical pre-fix in Vulpra | Both files in 160 exactly equal landed fix \`94db1bf\` |
| CVE-2026-124854 / Bug 2060230 — DOM Navigation privilege escalation | 1/1 identical pre-fix in Vulpra | 160 file exactly equals landed fix \`0caf08d\` |
| CVE-2026-124856 / Bug 2072437 — HTTP boundary conditions | 2/2 identical pre-fix in Vulpra | Header exactly equals landed fix \`5bc7f7a\`; .cpp was further modified in 160 and **does not** equal the landed-fix blob, so this comparison alone cannot attest to every protective hunk in the final file |
| CVE-2026-124902 / Bug 2083629 — media same-origin policy race | 1/1 identical pre-fix in Vulpra | 160 source file exactly equals landed fix \`e696700\` |

[Machine-readable six-path crosswalk](SECURITY-160-INITIAL-PATCH-GAPS-20261110.json) includes original source, landed-fix and release SHA-1 Git blob IDs, fix commit IDs, and explicit negative acceptance flags. The [read-only verifier](../../ci/security-160-spotcheck.sh) independently pins all six recorded hashes to known public-source evidence and checks real Vulpra source via \`git hash-object\`, including [12 deliberately forged source/advisory/acceptance test inputs](../../ci/tests/security-160-spotcheck-tests.sh). [**CI 42902208277 PASS**](https://github.com/sguzman/vulpra/actions/runs/42902208277); [workflow lint **42902208263 PASS**](https://github.com/sguzman/vulpra/actions/runs/42902208263); [local-recovery guard **42902208308 PASS**](https://github.com/sguzman/vulpra/actions/runs/42902208308).

**Critical limits:** These findings support verified source-patch gaps for four selected high-impact CVEs, not the status of any unreviewed CVE. Source-change presence is not proof of exploitability. The CI tests do **not** exercise a native browser or make Vulpra security-current. All six Vulpra sources remain unchanged, and the user's existing QA installation and profile are untouched.
