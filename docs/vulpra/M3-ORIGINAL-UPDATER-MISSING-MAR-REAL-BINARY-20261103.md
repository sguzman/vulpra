# M3 — Original compiled Linux updater executes and rejects a missing MAR (2026-11-03)

## Accepted source-pinned native result

[**Original updater missing-MAR native CI 41733351456 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41733351456), job `126256100640`, sanitized artifact **13276607606** (`m3-original-updater-missing-mar-replay`), downloaded and inspected as an 815-byte ZIP containing a 1,390-byte JSON report. The source was pinned at `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, and the exact precompiled full-normal Vulpra archive was checked against SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` before extracting and executing the packaged original `/original/updater` ELF.

Unlike prior standalone `updater --channels-allowed` diagnostics, this test ran the actual original updater's **Linux staging-error path** with the **same seven native arguments** previously observed at the real browser-owned `fork`/`execv` launch boundary in [source-pinned CI 41731162834](https://github.com/sguzman/vulpra/actions/runs/41731162834). The arguments were the original `updater` executable, `3` (argument version), `/original/updates/0` (private patch directory), `/original` (installation directory), `/original/updated` (disposable staging target), `first` (first invocation), and `-1` (stage rather than restart/apply). The updater was executed **directly by CI**, not by the original browser during *this* run. Combining the two distinct test outcomes must not be described as a single browser-launched, successfully executed updater.

### Exact accepted native failure

The test created a temporary update fixture with `updates/0/update.version = null` and `updates/0/update.status = pending`; **no `update.mar` file existed**. The installed original package was mounted read-only. Both the patch directory and an initially empty `/original/updated` staging target were separate writable **ephemeral nested mounts**, so the updater could perform its required setup without modifying the original installed browser or any persistent system path.

The actual packaged updater:
- **Executed and returned process exit code `1`**, a non-success result.
- Changed the disposable update status from `pending` through the original updater path to exactly **`failed: 6`**.
- Matched immutable `toolkit/mozapps/update/updater/archivereader.cpp::ArchiveReader::Open`: a failed `mar_open` yields `READ_ERROR`. Immutable `toolkit/mozapps/update/common/updatererrors.h` defines `READ_ERROR 6`, and original `updater.cpp::WriteStatusFile(int)` formats `failed: %d`.
- Left **no MAR archive** and left the separately mounted staging directory **empty**. It did not install an update or launch any callback application.
- Passed before/after SHA-256 checks for the original precompiled `vulpra` and `updater` executables, with the installation mounted read-only and no original browser source files altered.
- Ran with Docker `--network none`, `--read-only`, all Linux capabilities dropped, private rootless-user mapping, temporary HOME and no host display/device/browser profile. The updater was constrained by a per-process timeout; raw stdout/stderr, logs, process arguments, PIDs and temporary paths were never uploaded.

The saved report explicitly includes `original_compiled_updater_actually_executed=true`, `updater_invoked_by_disposable_ci_replay_not_original_browser=true`, `original_updater_exit_code=1`, `actual_original_update_status="failed: 6"`, `original_staging_target_remained_empty=true`, `browser_controlled_actual_updater_exec_proven=false`, `native_update_success_proven=false`, `source_pruning_authorized=false`, and `native_bytes_saved=0`.

The CI's validator rejected **11/11 deliberately forged summary variants**, including forged successful execution status, missing-MAR violation, false browser ownership, non-read-only installation, false staged-target emptiness, bad source archive hash, and invented source-pruning authorization.

### Earlier failed trials and why the fixture changed

[CI 41732749770](https://github.com/sguzman/vulpra/actions/runs/41732749770) and [diagnostic CI 41732946115](https://github.com/sguzman/vulpra/actions/runs/41732946115) failed because the original package mount was read-only **and the `/original/updated` staging destination did not exist or could not be created**. The updater returned `1`, but the status remained **`applying`**—it failed earlier at the stage-directory creation check, not at `ArchiveReader::Open`. These runs were correctly rejected as evidence for missing-MAR archive handling.

The correction created a **separate, empty writable nested `/original/updated` mount**, leaving the original package installation read-only. The original updater then reached the missing-MAR archive-open path and produced exactly `failed: 6`. This fixture change tests the original source's genuine failure behavior rather than relaxing the expected failure result.

## Boundaries and next coverage

**Established:** the genuine original native `updater` ELF, using the source-declared seven Linux staging arguments, executes in isolated Arch Linux and properly rejects an absent MAR file with `READ_ERROR=6`, while keeping original installed binaries unchanged and performing no installation. Together with the **separate** earlier browser-controlled updater `execv` attempt test, this covers two adjacent portions of the updater path without claiming end-to-end integration.

**Not established:** the original browser actually spawning and running the updater to completion in a single uninterrupted process tree; real MAR payload parsing and signature verification; full staged installation or rollback; restart/apply behavior; normal user-driven or automatic update behavior; success on EndeavourOS/Hyprland, on physical hardware, or across every optional native dependency/feature. This controlled missing-MAR **failure** is not a green light to remove the updater or any dependency. No original source pruning or native byte savings occurred.

The expensive workflow `.github/workflows/m3-original-updater-missing-mar-replay.yml` was restored to **manual-only `workflow_dispatch`** after accepted CI and workflow lint. **Overall Vulpra 61%; M3 5/6=83%; delta +0 percentage points.** The sixth full source/build/feature/FFI/conditional-native-dependency closure gate remains **OPEN**.
