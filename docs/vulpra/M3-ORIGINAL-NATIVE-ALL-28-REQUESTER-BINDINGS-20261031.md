# M3 — All 28 original compiled ELF requesters witnessed in bounded glibc symbol-binding workloads (2026-10-31 UTC)

## Exact source/run provenance

The original native Vulpra Firefox 159.0b5 full-normal compiled archive from source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, was authenticated before executing native code. Neither the installed browser nor any existing user profile was touched.

- [Original alternate `vulpra-bin` actual bindings 41205746021 — PASS](https://github.com/sguzman/vulpra/actions/runs/41205746021): two independent real native private Weston 10-second graphical/liveness frames, the second observed with `LD_DEBUG=versions,bindings`. Original `vulpra-bin` yielded **534 normal-binding events**, **173 distinct symbol/provider pairs**, **8 provider basenames**, **3 PID traces**. The compatibility launcher was disposable and never replaced the installed launcher. The graphical harness's trace-mode guard required an explicit, narrowly added `versions,bindings` option; original harness acceptance checks passed afterward. No acceleration or network-namespace isolation is asserted.
- [Ten distinct source-pinned original native requester union 41206028051 — PASS](https://github.com/sguzman/vulpra/actions/runs/41206028051): **8,394 binding events**, **4,520 distinct requester/symbol/provider combinations**, **51 unique provider basenames** across ten separately witnessed original ELF requesters. [Lint 41206028055 PASS](https://github.com/sguzman/vulpra/actions/runs/41206028055).
- [Original `libxul.so` default vs `LD_BIND_NOW=1` 41205847048 — PASS](https://github.com/sguzman/vulpra/actions/runs/41205847048): the original native New Tab smoke passed both times. Both modes observed **6,328** libxul normal-symbol binding events, **2,862** distinct symbol/provider pairs and two requester PID traces; **delta 0** for both counts. This particular workload yielded no *additional counted* normal-symbol bindings under forced eager PLT resolution. It does **not** prove that all lazy or future-dlopen bindings have been exercised or that the precise symbol sets are identical. The reports omit symbol names, and the browser's runtime events can be duplicated.
- [Original entire regular-ELF package live requester census 41206231047 — PASS](https://github.com/sguzman/vulpra/actions/runs/41206231047): extracted exactly **28 regular original packaged ELF members**, checked unique basenames with `readelf -h`, and used them as a strict allowlist for the unchanged original headless New Tab runtime. The bounded std-only Rust parser found glibc normal-symbol bindings from **21/28** original requester basenames, with **13,501 events**, **6,463 distinct requester/symbol/provider combinations**, **51 provider basenames**, across **4 real PID traces**. Only sanitized per-original-requester aggregate data was preserved. [Lint 41206231056 PASS](https://github.com/sguzman/vulpra/actions/runs/41206231056).

## Independent verification: every original packaged ELF requester has actual binding evidence

[**Independent exact source/run-pinned 28-requester reconciliation 41206458805 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41206458805); [global workflow lint 41206458799 PASS](https://github.com/sguzman/vulpra/actions/runs/41206458799). The verifier authenticated the exact successful run IDs/head commits and checked the **same** original native package/source fingerprint for the 21-requester startup census and ten-requester feature-test union. It independently verified report schemas, source/negative-evidence flags, safe unique requester/provider names, exact per-requester event/pair arithmetic and the inventory set equality.

| Evidence scope | Number of original ELF requester basenames |
|---|---:|
| All original packaged regular ELF members inventoried | **28** |
| Observed binding as requester in one headless New Tab run | **21** |
| Observed in separately verified guarded / graphical feature workloads | **10** |
| Requester basenames overlapping both sources (`crashhelper`, `gfxtest`, `libxul.so`) | **3** |
| **Distinct original ELF requesters with actual binding evidence in at least one workload** | **28 / 28** |
| Distinct observed provider basenames, union across both sources | **56** |

All seven original ELF files not observed as requesters during the package-wide headless startup have independently evidenced normal-symbol binding events:

`crashreporter`, `libclearkey.so`, `libmozinference.so`, `libonnxruntime.so`, `pingsender`, `updater`, `vulpra-bin`.

The individual censuses overlap; **do not add** their 13,501 and 8,394 event counts or distinct-pair totals into a purported unique whole-package binding total. Distinct provider basenames are reconciled as a set, not summed.

## Explicitly *not* proven

Witnessing at least one real normal-symbol binding from each original ELF requester does **not** prove every declared imported symbol, all GNU relocations, direct and transitive `DT_NEEDED` loader closure, future `dlopen`, delay/lazy binding paths, each feature's runtime integration, source/build artifact ownership on the current source, or target Arch/Hyprland compatibility. Guarded crash/update tests are diagnostic-only, ClearKey negative-only, ML C APIs did not perform model inference, and private Weston tests are not GPU acceleration certification.

There were **no source deletions, production browser modifications, installed-profile changes, safe-pruning authorizations or package-size savings**. This is a completed, evidence-backed *original ELF requester-observation preparatory task*, not the sixth M3 acceptance gate.

**Progress: M3 5/6 (83%), Vulpra overall 61%, session delta +0 percentage points.**
