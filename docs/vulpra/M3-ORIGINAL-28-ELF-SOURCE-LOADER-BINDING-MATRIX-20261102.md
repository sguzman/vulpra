# M3 — Original packaged 28-ELF source, loader and runtime-binding matrix (2026-11-02)

## Independently verified per-ELF Arch versus Ubuntu native providers (2026-11-02)

The original source-pinned full-normal browser was **not rebuilt**. [**Actual isolated Arch native glibc loader CI 41515240015 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41515240015), [**workflow lint 41515238477 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41515238477), and separately downloaded/inspected artifact **13174887436**. A corrected reporting boundary now preserves each of the **28 actual original ELF per-file Arch `ld-linux-x86-64.so.2 --list` provider basenames** previously calculated but omitted from the archived report. It rechecks per-file `DT_NEEDED` and provider counts against the global totals and rejects two deliberately corrupted original-report variants. The real native Arch snapshot reported image identity `sha256:e6e8decde3fa6f8f856e65aca051e221c9c938bdd3c3c5678b1e18c173e2e87f` and userspace glibc `2.44+r50+g1848099f063e-1`.

[**Separate cross-platform independent reconciliation CI 41515803526 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41515803526), [**lint 41515803766 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41515803766), artifact **13175133359**, also downloaded/inspected. It joins those new actual per-original-ELF Arch provider lists to the already accepted [**28-ELF source/Ubuntu/runtime matrix 41513030899**](https://github.com/sguzman/vulpra/actions/runs/41513030899). Inputs were authenticated by immutable source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and full-normal compiled archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The independent crosswalk verifies every binary identity and **all 28/28 per-file original direct-needed counts match** across Ubuntu and Arch. In the two real loader snapshots, **268/268** direct SONAME declarations resolved in each environment, with **586 Ubuntu vs 584 Arch** per-ELF loader-provider occurrences. Global provider-name unions are **91 Ubuntu / 90 Arch**, of which **81 shared**, **10 Ubuntu-only**, and **9 Arch-only**. These are names observed in glibc `--list` metadata, **not actual libraries used at runtime**.

The machine-readable artifact preserves **complete source ownership and both provider-name sets for every individual ELF**. Counts below summarize the original immutable package on the two CI userspaces. **Providers** include direct and transitively loader-listed libraries, plus interpreter/vDSO entries when listed. **Ubuntu-only / Arch-only** are unique to that particular file's loader-listed set, not files absent from or unsupported on a distribution.

| Original packaged ELF | Direct (both) | Ubuntu providers | Arch providers | Ubuntu-only | Arch-only |
| --- | ---: | ---: | ---: | ---: | ---: |
| `crashhelper` | 7 | 8 | 8 | 0 | 0 |
| `crashreporter` | 13 | 73 | 73 | 10 | 10 |
| `gfxtest` | 28 | 74 | 73 | 10 | 9 |
| `libclearkey.so` | 10 | 16 | 16 | 0 | 0 |
| `libfreeblpriv3.so` | 6 | 8 | 8 | 0 | 0 |
| `libgkcodecs.so` | 5 | 7 | 7 | 0 | 0 |
| `liblgpllibs.so` | 6 | 7 | 7 | 0 | 0 |
| `libmozavcodec.so` | 8 | 13 | 13 | 0 | 0 |
| `libmozavutil.so` | 10 | 12 | 12 | 0 | 0 |
| `libmozgtk.so` | 4 | 70 | 71 | 10 | 11 |
| `libmozinference.so` | 7 | 8 | 8 | 0 | 0 |
| `libmozsandbox.so` | 10 | 12 | 12 | 0 | 0 |
| `libmozsqlite3.so` | 4 | 6 | 6 | 0 | 0 |
| `libmozwayland.so` | 2 | 4 | 4 | 0 | 0 |
| `libnspr4.so` | 3 | 5 | 5 | 0 | 0 |
| `libnss3.so` | 7 | 9 | 9 | 0 | 0 |
| `libnssutil3.so` | 6 | 8 | 8 | 0 | 0 |
| `libonnxruntime.so` | 7 | 8 | 8 | 0 | 0 |
| `libplc4.so` | 3 | 6 | 6 | 0 | 0 |
| `libplds4.so` | 3 | 6 | 6 | 0 | 0 |
| `libsmime3.so` | 8 | 10 | 10 | 0 | 0 |
| `libsoftokn3.so` | 8 | 11 | 11 | 0 | 0 |
| `libssl3.so` | 8 | 10 | 10 | 0 | 0 |
| `libxul.so` | 49 | 90 | 89 | 10 | 9 |
| `pingsender` | 7 | 8 | 8 | 0 | 0 |
| `updater` | 25 | 81 | 80 | 10 | 9 |
| `vulpra` | 7 | 8 | 8 | 0 | 0 |
| `vulpra-bin` | 7 | 8 | 8 | 0 | 0 |
| **28 original ELF files** | **268** | **586** | **584** | **Per-file counts; not additive names** | **Per-file counts; not additive names** |

Five ELF files have differing provider-name sets in these specific CI environments: **`crashreporter`, `gfxtest`, `libmozgtk.so`, `libxul.so`, and `updater`**. The global ten Ubuntu-only names and nine Arch-only names belong to these real test environments; **a name difference is not evidence of a missing dependency, unused feature, or permission to prune a security component**. The initial artifact's per-file Arch mapping was explicitly unknown rather than inferred; this new independent original-source Arch test now resolves that *bounded metadata* gap.

**Still unproven:** Actual feature execution across all 28 paths, arbitrary future/conditional `dlopen` calls and full symbol-accurate transitive load graph, generated Ninja/Cargo feature ownership, the real EndeavourOS/Hyprland workstation, hardware, unrestricted production networking, and safe code deletion. The browser was not launched or installed by these two new tests. **M3 remains 5/6 (83%); overall Vulpra 61%; session Δ +0 pp. No source removals or new package-size savings.**

## Verifiable result and exact provenance

[**Independent read-only CI 41513030899 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41513030899), [**GitHub Actions workflow lint 41513031183 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41513031183). **Artifact 13174097102**, `m3-original-28-elf-feature-loader-binding-matrix.json`, independently downloaded and inspected. The report was produced entirely from five previously successful, immutable, source- and archive-authenticated GitHub Actions evidence artifacts; no new Firefox build, browser run, package modification or user profile access was performed.

The five inputs all refer to immutable original Firefox/Vulpra source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and actual full-normal packaged browser SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`:

| Source of independent evidence | Original CI | Exact coverage |
| --- | --- | --- |
| Per-ELF source build manifest anchor | [41209703132](https://github.com/sguzman/vulpra/actions/runs/41209703132) | Original `moz.build` / NSS `manifest.mn` declaration path, line and declaration class for 28/28 |
| Ubuntu glibc `--list` metadata | [41207364061](https://github.com/sguzman/vulpra/actions/runs/41207364061) | 268/268 direct DT_NEEDED names, 586 per-ELF provider occurrences, 91 distinct provider basenames |
| Isolated Arch userspace glibc `--list` | [41211418491](https://github.com/sguzman/vulpra/actions/runs/41211418491) | 268/268 direct names, 90 distinct provider basenames across all 28 binaries |
| Original native symbol-binding requester union | [41206458805](https://github.com/sguzman/vulpra/actions/runs/41206458805) | 28/28 original ELF requester basenames witnessed in at least one bounded workload |
| Separate selected-feature native binding workloads | [41206028051](https://github.com/sguzman/vulpra/actions/runs/41206028051) | 10 exact requester names across seven bounded native workloads |

The new verifier `ci/m3-original-28-elf-feature-loader-binding-matrix.jq` requires the **same exact sorted 28-name inventory** across source, Ubuntu, Arch and runtime witnesses, exact 10-name selected-workload subset, and the seven feature-only requester identities. It independently sums and checks all 28 original direct dependency counts and per-ELF Ubuntu provider occurrences. CI rejects mutated archive provenance, inconsistent selected-workload sets and altered per-binary direct-dependency counts. This is a cross-artifact reconciliation of independently obtained evidence, not a new test of production runtime behavior.

## Original source and measured native dependency matrix

Each line below corresponds to one original regular packaged ELF file. **Direct** = original `DT_NEEDED` count in that ELF; **providers** = Ubuntu glibc `--list` provider-basename count for that ELF **including transitive loader-listed providers**, not a count of libraries a feature actually called. **Workload** describes the bounded real-symbol-binding evidence: **Startup** = observed in headless-startup evidence but not the ten selected-feature requester set; **Both** = startup plus selected-feature tests; **Feature** = only in selected-feature tests. `Startup` does **not** mean no other feature ever uses the binary.

| Original ELF | Original source build declaration | Direct | Providers | Workload |
| --- | --- | ---: | ---: | --- |
| `crashhelper` | `toolkit/crashreporter/crash_helper/moz.build` | 7 | 8 | Both |
| `crashreporter` | `toolkit/crashreporter/client/app/moz.build` | 13 | 73 | Feature |
| `gfxtest` | `toolkit/xre/gfxtest/moz.build` | 28 | 74 | Both |
| `libclearkey.so` | `media/gmp-clearkey/0.1/moz.build` | 10 | 16 | Feature |
| `libfreeblpriv3.so` | `security/nss/lib/freebl/manifest.mn` | 6 | 8 | Startup |
| `libgkcodecs.so` | `config/external/gkcodecs/moz.build` | 5 | 7 | Startup |
| `liblgpllibs.so` | `config/external/lgpllibs/moz.build` | 6 | 7 | Startup |
| `libmozavcodec.so` | `media/ffvpx/libavcodec/moz.build` | 8 | 13 | Startup |
| `libmozavutil.so` | `media/ffvpx/libavutil/moz.build` | 10 | 12 | Startup |
| `libmozgtk.so` | `widget/gtk/mozgtk/moz.build` | 4 | 70 | Startup |
| `libmozinference.so` | `config/external/mozinference/moz.build` | 7 | 8 | Feature |
| `libmozsandbox.so` | `security/sandbox/linux/moz.build` | 10 | 12 | Startup |
| `libmozsqlite3.so` | `config/external/sqlite/moz.build` | 4 | 6 | Startup |
| `libmozwayland.so` | `widget/gtk/mozwayland/moz.build` | 2 | 4 | Startup |
| `libnspr4.so` | `config/external/nspr/pr/moz.build` | 3 | 5 | Startup |
| `libnss3.so` | `security/nss/lib/nss/manifest.mn` | 7 | 9 | Startup |
| `libnssutil3.so` | `security/nss/lib/util/manifest.mn` | 6 | 8 | Startup |
| `libonnxruntime.so` | `toolkit/components/ml/moz.build` | 7 | 8 | Feature |
| `libplc4.so` | `config/external/nspr/libc/moz.build` | 3 | 6 | Startup |
| `libplds4.so` | `config/external/nspr/ds/moz.build` | 3 | 6 | Startup |
| `libsmime3.so` | `security/nss/lib/smime/manifest.mn` | 8 | 10 | Startup |
| `libsoftokn3.so` | `security/nss/lib/softoken/manifest.mn` | 8 | 11 | Startup |
| `libssl3.so` | `security/nss/lib/ssl/manifest.mn` | 8 | 10 | Startup |
| `libxul.so` | `toolkit/library/moz.build` | 49 | 90 | Both |
| `pingsender` | `toolkit/components/telemetry/pingsender/moz.build` | 7 | 8 | Feature |
| `updater` | `toolkit/mozapps/update/updater/moz.build` | 25 | 81 | Feature |
| `vulpra` | `browser/app/moz.build` | 7 | 8 | Startup |
| `vulpra-bin` | `browser/app/moz.build` | 7 | 8 | Feature |
| **TOTAL** | **28 original packaged ELFs** | **268** | **586** | **18 Startup / 3 Both / 7 Feature** |

The machine-readable original report additionally retains the **original declaration class and guard-present flag for each ELF** and the complete **Ubuntu provider-basename list for each ELF**, not reproduced in full here. These class labels reflect source declaration syntax, not evaluated guard branches or a verified feature's runtime use. The Arch evidence is **global** to the original 28 ELFs; there is **no independently archived per-ELF Arch provider set**, so the matrix explicitly records `arch_direct_needed_resolved_per_elf: null` for every row rather than manufacturing a per-binary Arch map.

## Consequences and remaining gate

This crosswalk is useful for triage: **seven original binaries invisible to headless startup were separately witnessed in selected-feature workloads**, including crash reporting, updates, DRM ClearKey and optional inference. None of those seven qualifies as unused merely from a basic startup test. `libxul.so`, `gfxtest` and `crashhelper` appear in both sets. The other 18 have bounded startup-binding evidence, but were not necessarily tested across all feature modes.

The native code, security, packaging and removal boundaries remain strict. This **does not prove** complete generated-build ownership, source-line-to-feature reachability, all future/conditional `dlopen` targets, complete or per-binary Arch transitive provider edges, an uninstrumented user EndeavourOS/Hyprland deployment, actual service/account/network behavior, or that any function/library may safely be deleted. It measures **zero new source removals and zero new saved bytes**; all protected security, sandbox, sync, update and crash machinery is retained.

**M3 gate six remains OPEN: 5/6 = 83%. Vulpra overall remains 61%, session Δ +0 percentage points.** This is accepted as a new *per-original-ELF consolidated dependency and runtime-evidence mapping subtask*, not a claim of whole-graph closure.
