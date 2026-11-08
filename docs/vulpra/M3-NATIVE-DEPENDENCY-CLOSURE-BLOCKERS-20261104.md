# M3 — Native dependency closure blocker register (2026-11-04 UTC)

## Accepted cross-evidence result

[**Source-pinned 28-ELF original native dependency blocker register CI 41745377006 PASS**](https://github.com/sguzman/vulpra/actions/runs/41745377006), job **126296929534**; independently downloaded and inspected sanitized artifact **13283765728**, `m3-native-closure-gap-register` (one **37,022-byte JSON** report, ZIP 3,126 bytes). The standalone fail-closed verifier is `ci/m3-native-closure-gap-register.jq`, invoked by `.github/workflows/m3-native-closure-gap-register.yml`. After acceptance, the workflow was restored to manual-only `workflow_dispatch`.

This is a **systematic account of what is and is not verified**, not a new original browser build, a new native code pruning experiment, or a claim of complete source/build/runtime closure. It uses the exact historical full-normal compiled original source commit **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`** and original archive SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**. The current candidate and progress ledgers are read directly from the workflow's `main` checkout and checked against their explicit acceptance state.

### Six joined, independently verified inputs

| Evidence input | Accepted native or source CI | Accounted coverage |
| --- | --- | --- |
| Original 28 packaged ELF source, Ubuntu+Arch glibc provider crosswalk | [41515803526](https://github.com/sguzman/vulpra/actions/runs/41515803526) | 28 original binary identities; all 268 direct `DT_NEEDED` declarations resolved in each of the **two bounded CI userspaces**; original compiled build owner and per-file loader providers |
| Seven selected-feature-only original ELF compiled direct-loader branches | [41523391875](https://github.com/sguzman/vulpra/actions/runs/41523391875) | The exact seven feature-only ELF names, four loader API importers and **eight selected named direct loader API branches** across `libonnxruntime.so`, `pingsender`, `vulpra-bin` |
| Original browser graphical bounded conditional loader edges absent from per-file loader lists | [41522017287](https://github.com/sguzman/vulpra/actions/runs/41522017287) | **21** actual dynamic requests, 18 for packaged original libraries and three for host libraries; distinct requesters `vulpra`, `libnspr4.so` and `libxul.so` |
| Current main vs exact original compiled source drift | [41210567100](https://github.com/sguzman/vulpra/actions/runs/41210567100) | **27** unique original ELF-owner source manifests and **14** protected feature-boundary source files byte-identical in the historical current checkout; **not** a full-tree equality assertion |
| Genuine browser-owned original `pingsender` → original `libcurl` → actual `curl_easy_perform` | [41741770814](https://github.com/sguzman/vulpra/actions/runs/41741770814) | Real original native execution and source-defined 14 native symbol resolutions, real `CURLE_COULDNT_CONNECT=7` with synthetic closed localhost and **no network egress**; no ordinary telemetry success claimed |
| Current 20-candidate source decision and M3 progress contracts | [candidate-decision CI](https://github.com/sguzman/vulpra/actions/workflows/m3-candidate-final-decision-ready.yml) | **13 keep**, **four accepted source-only removal categories**, **three conditional guarded compile categories**, **zero unclassified**; previously accepted 14,867 removed Git paths / 129,967,585 original Git blob bytes, **no new compiled package savings**, and M3 **5/6** |

All 28 rows in the sanitized report include original source manifest and declaration type; original Ubuntu and Arch direct dependency counts; number of loader-listed providers in each bounded environment; bounded runtime requester observation; whether it was one of the seven feature-only native binaries; its original compiled selected direct loader API branch count where applicable; and any of the **21** graphical dynamic-request edges attributed to that binary. Each row explicitly sets `all_possible_future_feature_and_ffi_dependencies_enumerated=false` and `safely_prunable_based_on_this_register=false`. This avoids the dangerous inference that a library absent from one graphical startup is unused.

The verifier cross-checks row sums to actual original 268 direct dependencies, seven exact feature-only identities, eight branch counts, the 21 bounded relationships, and the packaged-versus-host dynamic target classification. A first CI [41745204850](https://github.com/sguzman/vulpra/actions/runs/41745204850) **correctly failed the negative tests** because an altered per-ELF loader-branch count passed an incomplete aggregate check. The final verifier fixed this by checking row-summed branch counts and matching each observed dynamic target to either the original 28-file package set or one of the exact three independently listed host libraries, before [41745377006](https://github.com/sguzman/vulpra/actions/runs/41745377006) passed. **8/8** deliberately forged original evidence, source-drift, candidate and milestone input files were rejected by rerunning the complete reconciliation.

## Exact remaining blockers to the sixth acceptance gate

**Later-build context (not part of the original 41745377006 register):** two independent source-pinned current-pruned Linux normal builds and bounded runtime smokes have now passed, including the corrected explicit-offline Weston guard. Their independently reconciled source/link/package evidence is recorded in [M3 current native package acceptance](M3-CURRENT-MAIN-NATIVE-PACKAGE-20261104.md) and [the historical-vs-current actual ELF direct dependency comparison](M3-EXACT-TWO-NATIVE-BUILD-ELF-PARITY-20261104.md). The original read-only 28-ELF blocker JSON deliberately remains unmodified and must not be relabeled current-native evidence. The four blocker *categories* persist, but their evidence coverage has advanced.

| Blocker | What is still missing | Next defensible work |
| --- | --- | --- |
| **1. Current evaluated and linked build graph — partially addressed** | Subsequent source-pinned current-pruned normal builds [41749398233](https://github.com/sguzman/vulpra/actions/runs/41749398233) and [41750432275](https://github.com/sguzman/vulpra/actions/runs/41750432275) **both compiled, packaged and passed bounded native/Wayland/browser runtime CI**. The checked artifacts expose 2,435 `libxul` response-file object inputs, 28 packaged native ELFs and 268 direct declarations, but not the complete resolved Cargo/Rust archive member, symbol-to-source linker, or conditional FFI dependency graph. | Join the real current native linker/Cargo/archive/member and function-call boundaries with exact original protected source ownership; verify any residual indirect/conditional branches against real runtime witnesses. **Do not order another full build merely to establish that current source compiles.** |
| **2. Conditional native loader / FFI closure** | Original 268 `DT_NEEDED` edges are resolved on Ubuntu and Arch; 21 actual graphical dynamic edges, and the original `pingsender` → `libcurl` real function path are proven. They cannot enumerate every future feature's direct and indirect `dlopen`/`dlsym`/FFI branch or fallback. | Reconcile compiled references, evaluated build inputs and feature-specific activation evidence across **all** native owners, prioritizing unaccounted branches and their safe fallbacks rather than re-testing `pingsender`. |
| **3. Preserved-feature activation and safety** | The current selected feature tests are bounded and not an end-to-end validation of every DRM, media, crash/update, privacy, account, inference and alternate launcher behavior. | Establish a finite, explicit activation/safety acceptance matrix for each protected feature before omitting any source or binary; include negative/disabled and error paths where meaningful. |
| **4. Target workstation parity** | Arch in disposable CI is not the user's actual EndeavourOS/Hyprland workstation; it does not prove its GPU, library versions, audio, USB, desktop integration, or host runtime ABI. | After a current native build exists, perform isolated-profile read-only / opt-in tests on the real target, without changing installed Firefox or unrelated profiles, services or packages. |

The categories are **blockers**, not four newly passed acceptance gates. A complete future dynamic loader graph is an engineering assurance claim that must be scoped to a defined build and feature matrix; finite traces alone can never establish all possible future loads. The **current-pruned build/packaging/runtime existence gap has since been closed**, but the complete feature-oriented linker/Cargo/FFI/conditional route ownership map has not. Prioritize real current linked callsites and their safe feature fallbacks, not repeated current builds without a new scoped diagnostic purpose or another original-browser auxiliary-ELF probe. The source-matched compiled native loader-callsite collector from [commit `96454f7`](https://github.com/sguzman/vulpra/commit/96454f7a1fbe6b505af440c6c2c5fc91e798756d) subsequently **passed [current native CI 41762298450](https://github.com/sguzman/vulpra/actions/runs/41762298450)**. [The independently compared original/current reports](M3-LINKED-NATIVE-LOADER-CALLSITE-PAIR-COMPARISON-20261104.md) show **73/73 selected direct loader-call branches and 47/47 caller/API/kind rows preserved**, not indirect or conditional FFI closure. Later [source-matched 18-feature matrix CI 42254404008](https://github.com/sguzman/vulpra/actions/runs/42254404008) independently authenticated **ten/ten exact successful workflow identities**, while rejecting 14 forged provenance or milestone claims; the matrix still explicitly leaves 14 current runtime feature paths unverified. Therefore the four M3 blocker categories and final sixth-gate status remain unchanged.

## Safe completion accounting

This analysis ran as a read-only, source-pinned GitHub Actions crosswalk. It did **not** recompile or execute the original browser, touch installed Firefox or user profiles, delete any new source, change feature preferences, or save new native package bytes. Previously accepted non-Linux source-only pruning remains a separate historic result and must never be mistaken for changes in this iteration.

**Vulpra overall 61%, M3 debloating 5/6 (83%), session Δ +0 percentage points. Sixth M3 gate remains OPEN.** The machine-readable register has every original ELF row and all four explicit blockers so future steps can be selected and audited without re-deriving or overstating the existing evidence.


## Original/current compiled-source Rust/C++ FFI anchors — verified 2026-11-06 UTC

A new source-level parity register,
[M3-CURRENT-RUST-CXX-FFI-SOURCE-ANCHORS-20261106.json](M3-CURRENT-RUST-CXX-FFI-SOURCE-ANCHORS-20261106.json),
binds **11 exact original/current source/build files** to their Git blobs,
including XPCOM startup, gkrust staticlib, crashhelper C++ entrypoint,
Rust crash-helper export, Cargo declarations, native moz.build ownership and
generated cbindgen header declarations. The pinned original compiled source is
`b1482404dfb8b01342990ee99ea3df0f9756b5f7`; the successful current
compiled source is `96454f7a1fbe6b505af440c6c2c5fc91e798756d`,
from [native CI 41762298450](https://github.com/sguzman/vulpra/actions/runs/41762298450).
They are **distinct source revisions** even though these **eleven selected
files** retain identical Git blob IDs in both revisions and current `main`.

[**Source crosswalk CI 42259038308 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42259038308),
at [verifier commit `7b12ffe`](https://github.com/sguzman/vulpra/commit/7b12ffe5d9dfb2131b736a27ccb072f5f292460b),
independently authenticated **11/11 HEAD tracked Git objects**, **22/22
GitHub Contents API objects** at the exact historic original and compiled
current commits, and the successful run's exact workflow ID, head SHA, origin,
main branch and event. It rejected **25/25** deliberately falsified
source hashes/paths, FFI declarations, workflow identities and claimed M3
completion. It then compiled and executed the pre-existing std-only Rust
`ci/m3-static-rust-cpp-ffi-source-witness.rs` observer against these
source-identical inputs; its **2/2 unit tests passed**, and its bounded
source-structure report verified **three named Rust/C++ FFI exports** from
**two Rust staticlib roots**: `GkRust_Init`, `GkRust_Shutdown` in
`libgkrust.a` for `libxul.so`, and
`crash_generator_logic_desktop` from `libcrash_helper_server.a` for
`crashhelper`. These are **source declarations/call-site anchors**, not
newly authenticated machine branches in the compiled current ELF.

The first CI [42258667046](https://github.com/sguzman/vulpra/actions/runs/42258667046)
correctly failed: under a negated Bash function call, an earlier falsified
hash assertion was masked by the function's final successful row-count test.
[Correction `4d97b95`](https://github.com/sguzman/vulpra/commit/4d97b95eefd06b08938bf2ffd8b64ef0437057a3)
explicitly propagates every jq assertion failure. [Final CI 42259038308](https://github.com/sguzman/vulpra/actions/runs/42259038308)
passed all source, live GitHub and native-run identity checks. [Workflow
lint 42258667042](https://github.com/sguzman/vulpra/actions/runs/42258667042)
passed when the new workflow was introduced.

**Unresolved gate:** no new browser build was performed, no complete Cargo
archive-member or symbol-to-source linker map of the current native binary
was generated, indirect and conditional C++/Rust FFI and dlopen branches
are not fully enumerated, protected feature fallback behavior is not
complete, and no actual target EndeavourOS/Hyprland workstation acceptance
was performed. The three selected interfaces and eleven source paths cannot
justify removal of any additional source or compiled native binary. Product
M3 remains **83% (5/6 gates)**, overall **61%, delta +0 pp**.


## In-flight exact-current compiled gkrust archive/member proof — 2026-11-06 UTC

The preceding 11-path source-object parity establishes where three
Rust/C++ interfaces are declared, but **does not** identify which actual
current `libgkrust.a` archive members define them or verify the current
linked ELF. Previous successful exact-current full-native artifact
[41762298450](https://github.com/sguzman/vulpra/actions/runs/41762298450)
contains a SHA-256-linked unstripped `libxul.so` hash and 2,435 compiled
response-file object references, **but no raw Rust archive-member map**.
Reusing that small JSON artifact cannot produce missing member evidence.

A new std-only Rust observer
[`ci/m3-current-ffi-archive-members.rs`](../../ci/m3-current-ffi-archive-members.rs)
parses actual GNU `ar t` and streaming `nm` output, rejects missing or
duplicate text definitions, and emits only bounded `GkRust_Init` and
`GkRust_Shutdown` archive member names plus archive/unstripped ELF
SHA-256 identities. It explicitly prohibits any full linker/FFI map or
pruning claims. Real native ELF/archive fixture
[**CI 42263703373 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42263703373)
compiled and ran the observer, including 2/2 tests with a real C
compiler, GNU `ar`/`nm`, and invalid/missing symbol/ELF cases;
[workflow lint 42263703349 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42263703349).
This is **fixture acceptance only**, not actual Vulpra archive proof.

[Commit `83785b2`](https://github.com/sguzman/vulpra/commit/83785b264f232ea7c777abd0a0dd8511ef322ecc)
adds the observer after the preserved actual native build/packaging,
graphical Wayland/JS/WebExtension/Nimbus and existing current loader census
steps. It reads the exact build-generated
`obj-vulpra-linux-m3-baseline/toolkit/library/rust/libgkrust.a`, whose
relative path appears in the earlier full-native compiler log, and joins
its result to the already recorded, genuine linked `libxul.so` SHA-256.
It uploads a separate bounded report with no full binaries or raw symbols.
[**Source-matched full-native CI 42264023349**](https://github.com/sguzman/vulpra/actions/runs/42264023349)
was **in progress at this checkpoint**, with **no real compiled
current gkrust member report accepted yet**. There is no manual workstation
action, new omission, user-profile manipulation, release or additional
full build solely for compiler-existence proof.

A separate [read-only jq evidence
join](../../ci/m3-current-ffi-native-evidence.jq) now requires the
native run's exact source SHA/ID, real packaged/runtime pass, original
unstripped `libxul` hash, and the real FFI archive-member report to
agree. Its [**synthetic fixture CI 42264329875 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42264329875)
rejected **30/30** fabricated source/hash/member/FFI/runtime/pruning
records. Existing [native reconciliation workflow](../../.github/workflows/m3-native-link-evidence-reconcile.yml)
was extended in [`6c06472`](https://github.com/sguzman/vulpra/commit/6c06472e35719d596ac4a2cfc21a249783729a86)
to fetch the exact successful native run's separate FFI artifact and
reject missing or inconsistent evidence; independent lightweight
[**CI 42264455607 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42264455607)
and [**workflow lint 42264455613 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42264455613)
validated the contract. These green checks are **not** the pending
actual current-native compilation or FFI artifact acceptance.

This is deliberately a **two-symbol archive-definition census**, not
a complete linker selection/member-to-source graph, not
`crash_generator_logic_desktop` current native linkage, not all
conditional or indirect FFI/`dlopen` routes, and not actual
EndeavourOS/Hyprland hardware acceptance. The final M3 feature/build/
binary dependency gate remains **OPEN**; **M3 83% (5/6), overall 61%,
delta +0 pp**. No new source deletion or compiled-package savings.

### Actual previous linker-report compatibility acceptance — 2026-11-06 UTC

The existing 30-case synthetic jq contract was additionally run against a **genuine, externally authenticated** previous full-current compiled native link report from [workflow **41762298450**](https://github.com/sguzman/vulpra/actions/runs/41762298450), at exact source `96454f7a1fbe6b505af440c6c2c5fc91e798756d`. The read-only [compatibility replay](../../ci/tests/m3-current-ffi-real-link-compatibility.sh) independently checked the successful GitHub run's source/repository/workflow metadata, downloaded its existing `m3-source-matched-native-link-evidence` artifact, confirmed the linked source/ELF and native runtime acceptance, and exercised the unchanged [FFI evidence join](../../ci/m3-current-ffi-native-evidence.jq) with explicitly **synthetic** two-member FFI input tied to that authentic historic `libxul` hash. It then falsified that ELF hash and required rejection.

[**Compatibility CI 42267196487 PASS**](https://github.com/sguzman/vulpra/actions/runs/42267196487): authentic old native report accepted as a **report-format input**, forged linked ELF identity rejected, and all pre-existing **30/30** fake evidence fixtures rejected. [Workflow lint 42267195946 PASS](https://github.com/sguzman/vulpra/actions/runs/42267195946). **No actual FFI archive-member names or compiled-current binary edge were proven by this synthetic FFI replay.** Those remain dependent on the genuinely compiling [native workflow 42264023349](https://github.com/sguzman/vulpra/actions/runs/42264023349) and its later independent real-artifact reconciliation. The M3 sixth gate, protected feature fallbacks and target workstation acceptance remain open; overall 61%, M3 83%, delta +0 pp.


### Rust archive symbol-strength hardening — 2026-11-06 UTC

Review of the pending compiled-current FFI observer found that its original
`nm` filter accepted weak `W/w` symbol definitions as though they were
strong, source-owned Rust `#[no_mangle]` C ABI exports. The narrow audit
contract now rejects weak archive and linked-ELF definitions; the archive
must expose each selected symbol as strong global text `T`, while a linked
consumer may preserve a strong `T` or localize it to `t`.

The correction at [`2b22772`](https://github.com/sguzman/vulpra/commit/2b22772895a97892f61ccadb514b4c0146624daf)
passed parser-fixture [**CI 42272137547**](https://github.com/sguzman/vulpra/actions/runs/42272137547).
The further [`412d14c`](https://github.com/sguzman/vulpra/commit/412d14c097e81a0d48487865de2e21c1f049d20a)
added a **real C-compiled weak archive and weak final ELF** regression:
both the archive/ELF-only weak scenario and strong archive/weak ELF
scenario must fail; [**CI 42272211452 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42272211452),
2/2 Rust tests. Existing valid strong compiled fixtures remain accepted.

**Scope/time boundary:** The full current native workflow
[**42264023349**](https://github.com/sguzman/vulpra/actions/runs/42264023349)
was launched from `83785b264f232ea7c777abd0a0dd8511ef322ecc`,
*before* both symbol-strength hardening commits. The in-flight build uses
the earlier inspector and cannot be misrepresented as native acceptance of
the later strengthened rules. The newer tests cover compiler-produced
negative fixtures only. No newer real native Rust archive/ELF census had
completed at this checkpoint, no package source or installed desktop was
modified, and M3 stays **5/6 (83%)**, overall **61%**, Δ0 pp.


## Current compiled Rust archive audit failure and guarded retry — 2026-11-07 UTC

The full native CI [42264023349](https://github.com/sguzman/vulpra/actions/runs/42264023349)
for exact source `83785b264f232ea7c777abd0a0dd8511ef322ecc` **finished FAILURE**,
but the failure is isolated to the new *compiled gkrust archive-member
inspector*. The actual native `./mach build`, `./mach package`, package
hash/ELF/link-input reconciliation, Weston graphical 10-second render, local
WebDriver JS/HTTP/DOM, WebExtension install/messaging/storage/uninstall,
self-signed HTTPS rejection, Nimbus initialization, isolated profile
protection and **73 direct/47 distinct native loader callsite** census
all passed in the same job, according to its CI log. This is an independently
successful bounded browser build/runtime, **not an overall green workflow**.

The Rust FFI step emitted only
`FAIL: Missing compiled native input: No such file or directory (os error 2)`
and uploaded **no** FFI archive-member report. Its previous guard
`test -s "$rust_archive" && test -s "$libxul"` was incorrect under
`bash -e`: a false left side of an AND-list does not necessarily
terminate the shell when followed by more commands. The reported error
does **not** identify which native input path was missing, so assigning
the failure to a specific archive location or absence of the linked
library would exceed the evidence. The full-run failure correctly
triggered [independent reconciliation
42275954907](https://github.com/sguzman/vulpra/actions/runs/42275954907)
to **reject** the native workflow; its negative fixtures passed and its
success-only comparison was skipped.

The inspector now distinguishes missing archive versus missing consumer
ELF paths in error output
([source correction `011b55c`](https://github.com/sguzman/vulpra/commit/011b55ce50513070c6626e30d689199032bb4003)).
The new [strict source-local archive finder](../../ci/m3-locate-gkrust-archive.sh)
requires a nonempty unstripped `dist/bin/libxul.so`, prefers the
known normal-build `toolkit/library/rust/libgkrust.a` output when it is
a real regular file, otherwise accepts **exactly one** non-symlink
`libgkrust.a` in the built object directory, and rejects no match,
multiple matches, escaped symlinks and missing libxul. It never searches
the user's machine or selects a source tree outside the native CI objdir.

The finder, including real C compiler and GNU `ar` fixture tests, passed
[**42397419625 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42397419625)
with corresponding
[workflow lint 42397419634 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42397419634).
[Correction `fc362d0`](https://github.com/sguzman/vulpra/commit/fc362d0c8de7529554af6dc00f84e485714f73d8)
replaces the unreliable Bash AND-list with separately enforced
nonempty-file and non-symlink assertions; the exact selected compiled
archive and ELF then enter the previously reviewed Rust FFI observer.
It also prevents the initial bug from being counted as a successful audit.

A single corrected, source-matched full normal browser
[**CI 42397502966**](https://github.com/sguzman/vulpra/actions/runs/42397502966)
was started at `fc362d0` and was **in progress at this checkpoint**.
Its corrected real archive/ELF member evidence and independent subsequent
success-only reconciliation are **not yet accepted**; the old failed run
does not prove them. No direct action is required on the user's currently
unavailable EndeavourOS desktop. The existing downloaded browser/profile,
security branch, source files and user hardware remain untouched.
**M3 5/6 (83%), overall 61%, Δ0pp.**

## Successful current compiled Rust FFI artifact — accepted 2026-11-08 UTC

The corrected [source-matched full-native workflow 42397502966](https://github.com/sguzman/vulpra/actions/runs/42397502966) **SUCCEEDED** at exact source `fc362d0c8de7529554af6dc00f84e485714f73d8`, including a real complete normal native build, package, 28 packaged ELFs/268 direct DT_NEEDED edges, 2,435 recorded `libxul` object inputs, private Weston/Wayland rendering, WebDriver JS navigation, WebExtension lifecycle, Nimbus initialization and explicit self-signed TLS rejection. A real current-linked native-loader census also passed with **73 direct branches / 47 distinct caller/API/kind records**. The Rust FFI inspector ran after those checks and independently resolved the actual compiled archive at a **unique fallback** location inside the object directory (not the previous assumed direct output path).

The bounded [real compiled FFI report, artifact 13584709670](https://github.com/sguzman/vulpra/actions/runs/42397502966/artifacts/13584709670) contains:

- `libgkrust.a`: **1,463,257,954 bytes**, **313 archive members**, SHA-256 `38e1f778edf3b8e036b0c2a4302e294c71c4f9efb3821116434ee059aa5f1407`.
- Unstripped `libxul.so`: **2,590,378,712 bytes**, SHA-256 `5fc7db85c0469a60c362f81229de1c24ad5a32cfc4b3c5e76119409d68fa3a84`.
- The strong Rust archive definitions of **`GkRust_Init`** and **`GkRust_Shutdown`** are each unique, both in the **same observed compiled member**, `gkrust-970258c2b320f725.gkrust.4baad39560e1113c-cgu.0.rcgu.o`, and each has one corresponding native text definition in the actual unstripped `libxul.so`.

The separately completed [independent reconciliation CI 42401728599 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42401728599) downloaded the full-native evidence and the separate FFI artifact, authenticated exact source/run identity, linked ELF SHA and real runtime acceptance, and required the bounded FFI/closure flags. Its [reconciled artifact 13585657649](https://github.com/sguzman/vulpra/actions/runs/42401728599/artifacts/13585657649) confirms the same **313 member count, two symbol pairs, SHA-256s and explicit incomplete map**. Both ZIP artifacts were independently downloaded and inspected for this checkpoint. The exact machine-readable accepted record is [M3-REAL-CURRENT-GKRUST-ARCHIVE-ELF-FFI-20261108.json](M3-REAL-CURRENT-GKRUST-ARCHIVE-ELF-FFI-20261108.json).

**Accepted new evidence:** real compiled-current Rust staticlib *member ownership of two named C ABI exports* and corresponding real unstripped ELF definitions, tied to a successful current normal browser build and independent reconciliation. **Not established:** all 313 archive member selections and relocations; actual machine-call branches in current C++ callers; current crashhelper Rust export archive-to-ELF proof; other Rust FFI, indirect/conditional loader calls and dynamic dependency routes; 18-feature activation/error fallback completion; or target EndeavourOS/Hyprland parity. No further pruning, native byte-savings credit, security-branch merge or release. The sixth M3 dependency gate remains **open**, M3 **83% (5/6)** and overall **61%, delta +0 pp**. The prior run failure and its correction above remain accurate historical entries; only the corrected run is accepted.
