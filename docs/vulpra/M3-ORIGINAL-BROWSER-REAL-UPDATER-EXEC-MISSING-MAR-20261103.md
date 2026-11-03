# M3 — Uninterrupted original browser → real packaged updater exec → missing-MAR failure (2026-11-03)

## Accepted native integration result

[**Source-pinned original browser → actual original native updater CI 41736108218 PASS**](https://github.com/sguzman/vulpra/actions/runs/41736108218), job **126265618147**, sanitized artifact **13278473269**, `m3-original-browser-updater-real-elf-chain`. The artifact was independently downloaded and inspected: one **2,678-byte JSON** report (ZIP 1,158 bytes). Original compiled package source pinned to `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, source-validated archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The test compiled **only its separate CI-only Rust observer/interposer**, not Vulpra or its updater: both original packaged ELF files remained unchanged, authenticated and read-only.

**New fact established:** one *genuine original compiled browser process*, running in a disposable private Weston/Arch Linux namespace, invoked its original `nsIUpdateProcessor.processUpdate()` through privileged browser XPCOM; the source-declared Linux `fork`/staging `execv` was forwarded to the **actual original `/original/updater` binary**, which successfully entered its ELF loader, still had the **original browser as its parent** and a kernel-visible command line matching all seven original staging arguments, and then recorded **`failed: 6`** against a deliberately **absent `update.mar`** file.

This is different from the two previously accepted adjacent native tests: [41731162834](https://github.com/sguzman/vulpra/actions/runs/41731162834) verified **browser-owned `execv` intent but denied execution**; [41733351456](https://github.com/sguzman/vulpra/actions/runs/41733351456) executed the **real updater separately from CI**, without browser parentage. This new test joins both behaviors **in one uninterrupted browser-owned process tree**; the original updater truly ran, then failed in its intended absence-of-MAR code path. It does **not** attempt or prove a successful installation.

## Actual original source-defined staging path

- The original compiled browser starts directly with a newly created private profile, and `geckodriver --connect-existing` attaches to that live original browser. No installed Firefox or Vulpra instance is used.
- Original `nsXREDirProvider::GetUpdateRootDir` returned precisely **`/original`** from inside the original browser. Synthetic fixture files `/original/updates/0/update.version` containing `null` and `/original/updates/0/update.status` containing `pending` were created **only after the browser had started**.
- Original `nsUpdateDriver.cpp::ProcessUpdates` selects the staging branch and `ApplyUpdate` constructs the seven Linux arguments `/original/updater`, `3`, `/original/updates/0`, `/original`, `/original/updated`, `first`, `-1`. The original browser then forks and calls `execv` with these values.
- The original native `updater.cpp` and `archivereader.cpp` both run unmodified. `ArchiveReader::Open` calls `mar_open`; absent MAR yields source-defined `READ_ERROR` (= **6** in original `updatererrors.h`); `updater.cpp` records **`failed: 6`** in the **disposable update fixture**.
- The original browser remained running and WebDriver-responsive afterward, verified by an in-browser chrome-context expression in the **same session**.

## Two distinct native process witnesses

The extra CI-only Rust `LD_PRELOAD` library `ci/m3-original-browser-updater-execv-forward-guard.rs` is *test instrumentation*, not a patched Vulpra executable, source edit or replacement helper. Its interposed `execv` **fails closed for every other intercepted command**, and forwards only the exact source-pinned original browser executable's seven-argument staged updater command to libc `execve`. The first sanitized witness establishes the original browser owner, exact updater target and argument shape, and a pre-exec marker; by itself this witness proves only intent/forwarding, not execution.

The **second witness** runs as an **ELF load-time initializer within the actually executed original updater process**. Before the updater application's logic runs, it checks:

1. `/proc/self/exe` is exactly the **original packaged `/original/updater`**, not another process or a fake helper.
2. The **kernel-visible** `/proc/self/cmdline` matches the seven original source-declared staging arguments.
3. `/proc/<parent>/exe` resolves to the **original packaged `/original/vulpra`** browser binary.
4. The original browser's separately emitted pre-exec marker already exists; `update.mar` does **not** exist.

Only the authentically executed original updater can emit the second marker. Nothing is inferred from a WebDriver disconnect or the first marker alone. The observed real status **`failed: 6`**, exact source-bound and read from the private update fixture, is required *in addition to* both witnesses. The original library code never fabricates a replacement updater or calls the original updater independently from CI. No raw PIDs, kernel command lines, report paths, source files, logs, browser profile data or crash dumps were included in the sanitized artifact.

## Isolation and enforcement

Original source and complete precompiled full-normal archive were authenticated before execution. The original browser package, including its real `vulpra` and `updater` ELF files, was mounted **read-only**, with independent before/after SHA-256 verification of both original executables. The only writable paths that relate to updating were **two newly created, nested, disposable mounts**: `/original/updates` for the synthetic status/version fixture and `/original/updated` for the empty staging destination. The staging destination remained **empty**; no MAR payload was provided, fetched, or created; no callback was supplied; an install could not write to the original package. The test ran in a disposable Docker `--network none`, `--read-only`, capability-dropped Arch/Weston runtime, with temporary HOME/profile and no host desktop/device/user profile mounts.

Original package files remain unchanged, **0 native bytes saved** and **no source pruning authorized**. Success required the actual updater's source-defined **failure** response, not a successful update.

**Test validation:** 2/2 Rust guard tests passed; **12/12 deliberately forged sanitized report mutations** were rejected (forged ELF parent/executable identity, changed source arguments, invented update success, wrong archive SHA, missing-MAR violation and false pruning authorization). The first native CI [41735949053](https://github.com/sguzman/vulpra/actions/runs/41735949053) failed during CI guard compilation due to Rust unsafe-expression grouping; corrected at commit `5aeb3afd42427183af3e52f238d0688079be4200` before the accepted native run.

## Precisely established and still open

**Established:** in an isolated instrumentation-assisted test using the **unchanged original binary artifacts**, the source-defined original browser staging path genuinely forks, executes the original updater ELF, and reaches the actual source-defined missing-MAR failure code, with the browser remaining responsive and no installation taking place. This is a **true original browser-controlled updater execution chain**, not just a simulated launch or a pair of independent CLI probes.

**Not established:** normal background or user-initiated updater behavior without deliberate XPCOM orchestration; uninstrumented production loader behavior; a valid/cryptographically verified MAR, download, successful staging/apply/switch, update rollback, updater restart callbacks or software installation; target EndeavourOS/Hyprland hardware parity; complete rare-feature/build/FFI/conditional native loader dependency closure; source-pruning safety. The sixth M3 gate remains open. No package-size reduction has been claimed.

Workflow `.github/workflows/m3-original-browser-updater-real-elf-chain.yml` was returned to **manual-only `workflow_dispatch`** after the original compiled native CI passed. **Overall Vulpra 61%; M3 5/6 acceptance gates = 83%; session delta +0 percentage points**. The evidence closes a specific previously unproven updater execution boundary, not the entire native dependency-closure milestone.
