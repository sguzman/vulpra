# M3 native link-input and GTK/Wayland loader ordering protocol

**Accepted historical physical-package preflight:** [GitHub Actions 40936431756](https://github.com/sguzman/vulpra/actions/runs/40936431756) **PASSED**. Its bounded JSON evidence artifact `m3-native-link-archive-preflight` (ID **12924836902**) independently verified the normal Vulpra archive's SHA-256 and `libxul.so` at **189,486,920 bytes**, plus the actual packaged `dependentlibs.list`. The source archive came from native build [40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401), compiled source `1683ca67b69389a879717bcd537772c3b40624b6`. Five negative parser/order fixtures passed. No old binary was executed.

## Physically packaged native preload order

The actual historical `dependentlibs.list` contains, in order:

`libnspr4.so` → `libplc4.so` → `libplds4.so` → `libmozsandbox.so` → `libgkcodecs.so` → `liblgpllibs.so` → `libnssutil3.so` → `libnss3.so` → `libsmime3.so` → `libmozsqlite3.so` → `libssl3.so` → **`libmozgtk.so`** → **`libmozwayland.so`** → `libxul.so`.

This **GTK-before-Wayland order is deliberate**, not an optimization opportunity. `toolkit/library/moz.build` comments explain that preloading `mozgtk` before `mozwayland` allows GTK's `libwayland-client` resolution to take precedence when GTK uses Wayland. Swapping these libraries can affect native widget behavior. The new inspector refuses a reversed order and refuses unbounded or duplicate loader names.

## The current-source native build acceptance contract

The new [single normal source-matched build workflow](https://github.com/sguzman/vulpra/actions/workflows/m3-source-matched-native-link.yml) checks out one exact source SHA, executes `./mach configure` and captures generated flags, then builds/packages **normal** Vulpra with optional omissions **off**.

On completion, it must independently checksum the staged normal package; record the original generated `toolkit/library/build/libxul_so.list` compiler/link response input list, its hash and object count; compare native `dist/bin/dependentlibs.list` with the packaged copy; hash compiled and packaged `libxul.so`; inspect all packaged ELF `DT_NEEDED` declarations; and run private Weston Wayland surface, localhost navigation/JS, isolated WebExtension/profile and Nimbus smokes.

The source-side basis for the linker response list is `python/mozbuild/mozbuild/backend/recursivemake.py` and `backend/common.py`: Mozilla's RecursiveMake backend uses `_make_list_file` for linked objects in complicated shared libraries, producing a response file consumed by the linker. The **response file enumerates linker inputs**, but is **not a full resolved linker map** and cannot by itself attribute section bytes to optional source features or predict compressed savings.

## Source-matched normal native build — verified compile and runtime (2026-10-29)

The [exact-source normal build 40935344279](https://github.com/sguzman/vulpra/actions/runs/40935344279) **PASSED all compiler, package, ELF inventory, and packaged-browser Wayland/JS/WebExtension/profile/Nimbus runtime steps**. Its compiled source is `3f9945cbdb4f6ea1bd75c3cf5127e58d72a9762f`, **not the later documentation HEAD**. The bounded original evidence artifact is **12927213408**.

| Source-pinned real output | Observation |
| --- | ---: |
| Generated `libxul_so.list` linker object paths | 2,435 |
| Link response SHA-256 | `3e1926f4674246622013393366071c80ca2b492afc15463e4a92eb17e1746126` |
| Normal `tar.xz` package bytes | 87,147,080 |
| Normal package SHA-256 | `d1eb3cb1ce528bdc47d51df290f1141a8f626f716b0d088a30577996ab6c480b` |
| Packaged `libxul.so` logical bytes | 189,486,696 |
| Packaged `libxul.so` SHA-256 | `66bb9232d84fefd2d97a8de78e576cd528a6216c3f66a4b6014f443e68fc1df6` |
| Original linked `dist/bin/libxul.so` SHA-256 | `79fa6d56d9efd81afa7dab19b4456dce83fce9c640acccc0bf4221597b4af6b3` |
| Regular packaged ELF members / direct dependency edges | 28 / 268 |
| Native GTK-before-Wayland preload order | Passed |
| Real packaged Wayland/JS/WebExtensions/Nimbus | Passed |

**Independent acceptance is still pending.** The first [reconciliation 40942832386](https://github.com/sguzman/vulpra/actions/runs/40942832386) rejected the correctly formed 40-hex Git source SHA because the checker expected a 64-hex SHA-256. The validator now distinguishes those identifiers, with [source-only regression 40944321002](https://github.com/sguzman/vulpra/actions/runs/40944321002) passing. A second substantive issue is that **the compiled and packaged `libxul.so` hashes genuinely differ**. It would be wrong to override their values or assert equality.

Mozilla's source gives a plausible, testable transformation: `toolkit/mozapps/installer/packager.py` uses `PackagerFileFinder(..., find_executables=True)`, `mozpack.files.ExecutableFile.copy` may run `mozpack.executables.strip` and `elfhack`, and the resulting staged ELF is archived by `mach package`. This proves a packaging **mechanism**, not that it explains the particular observed SHA mismatch.

To prove the exact relationship rather than guess, the follow-up source-pinned workflow [40944392090](https://github.com/sguzman/vulpra/actions/runs/40944392090) was initiated with a disposable `ExecutableFile.copy` replay. Acceptance requires hashing the original linked library before and after the replay, hashing the independent staged library, repeating the same configured strip/elfhack transformations into a temporary `libxul.so`, and matching its SHA-256 to the actual checksum-verified archive member. Any unexplained discrepancy must fail, and **no project progress or savings are credited until the full check passes**.

This extra provenance work is not a resolved linker symbol map, host transitive/dlopen dependency closure, feature-level byte attribution, or a source-matched lean/full size comparison. Keep all normal browser features and security protections.

## Independent post-build artifact acceptance

[Original source-only validator CI 40937413927](https://github.com/sguzman/vulpra/actions/runs/40937413927) **PASSED** with 14 deliberate negative fixtures. [Corrected validator CI 40940543316](https://github.com/sguzman/vulpra/actions/runs/40940543316) **PASSED** with **15 deliberately falsified native acceptances rejected**, plus a positive enriched-ELF fixture. The generic ELF census report has **no `workflow_run_id` field**: the pinned linker report supplies the run ID and the ELF record is independently bound by exact source commit, compressed package SHA-256, and compiled-versus-packaged `libxul.so` hash. If an ELF report does declare a run ID, a mismatch is rejected. This schema repair fixes a guaranteed false rejection without fabricating evidence or weakening identity and checksum checks. The [post-build evidence reconciliation workflow](https://github.com/sguzman/vulpra/actions/workflows/m3-native-link-evidence-reconcile.yml) listens for successful completion of the exact-source native build. It does **not** invoke a new Firefox compilation; it downloads only the completed run's bounded evidence artifact and verifies that the following all agree:

- The original GitHub Actions run genuinely concluded successfully and its head SHA matches all three separate reports: generated configuration, native build link inputs and package-wide ELF census.
- The SHA-256 of the **compiled** `libxul.so` equals the checksum of `libxul.so` actually nested in the staged browser package **and** the ELF graph record; the full staged package digest matches the original `.sha256` sidecar and the locality/extension test reports.
- The exact-source configured browser retains GTK, Wayland/X11, sandbox, Sync, Normandy and DevTools, with the normal ASRouter promotion modules left present. The generated `config.statusd` snapshot's `native_browser_compiled:false` field is phase-local, describing its configure-only step, and **does not** invalidate a separately successful later native compilation.
- The browser's actual `dependentlibs.list` preserves `libmozgtk.so` before `libmozwayland.so`, and Wayland, JS localhost navigation, isolated Firefox profile, WebExtension lifecycle and Nimbus report passes.
- The evidence must explicitly **deny** unsupported conclusions: a complete resolved linker symbol map, a valid lean/full compression pair, and approved further source deletion.

A green self-test of this reconciler is **not** a completed native acceptance. The listener must receive and validate a **successful real full build** before the recorded state advances. No document or source-only regression can manufacture those binary/runtime facts.

**Evidence discipline:** no completion is claimed until the full native run is green with the required link-input artifact and runtime gates. The existing historical preflight proves only the *older* package's physical preload ordering. A new source-matched build can strengthen the native/build map without authorizing any feature removal or upgrading M3 until its whole acceptance criteria are met. No current-main binary or new compiled gain is implied by this protocol.

**M3 2/6 (33%); overall 44%, Δ 0 pp.**
