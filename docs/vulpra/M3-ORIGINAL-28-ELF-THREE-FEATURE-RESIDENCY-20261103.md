# M3 — Original 28-ELF per-file build/loader census vs three live browser workloads (2026-11-03)

## Accepted four-run source-pinned reconciliation

**[Cross-artifact native-evidence CI 41717623238 PASS](https://github.com/sguzman/vulpra/actions/runs/41717623238)**, job `126201699212`, artifact **13271241007** (`m3-original-28-elf-three-browser-workload-residency`), and [workflow lint **41717623231 PASS**](https://github.com/sguzman/vulpra/actions/runs/41717623231). No new native browser workload was run in this join-only workflow. All four independently accepted original artifact-producing runs were authenticated by exact GitHub run ID, successful conclusion, and head commit before downloads; every report also had to match original source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.

| Evidence | Accepted source | What was actually measured |
| --- | --- | --- |
| Original 28 native packaged ELF source/build owners + Ubuntu/Arch glibc provider lists | [41515803526](https://github.com/sguzman/vulpra/actions/runs/41515803526), artifact `13175133359` | Exactly 28 per-file owners and 268 direct `DT_NEEDED` edges resolved on both platforms; **metadata only**, not an application-run residency census |
| Private original Vulpra Arch/Weston graphical startup | [41658199812](https://github.com/sguzman/vulpra/actions/runs/41658199812), artifact `13240906966` | Original-process sampled runtime `/proc/maps` host/package library names, with a committed private Wayland frame and native loader initializers |
| Actual original Vulpra clicked WebAudio `pulse-rust` stream into a private null sink | [41714793962](https://github.com/sguzman/vulpra/actions/runs/41714793962), artifact `13270336382` | A during-stream original-process map, with separate non-`LD_PRELOAD` glibc `libpulse` symbol/provider bindings |
| Actual original Vulpra USB WebAuthn no-device negative attempt | [41712441426](https://github.com/sguzman/vulpra/actions/runs/41712441426), artifact `13269210009` | A during-attempt original-process map, with source/archive-pinned and device/inode-checked mapped `libudev` SHA-256 fingerprint |

The new independent `ci/m3-original-browser-feature-residency-28-elf.jq` maps each of the **28** original ELF identities and owner manifests to whether that exact basename was resident in each of those **three separate real-browser snapshots**; it does not equate glibc `--list` providers with mapped runtime dependencies or assume every ELF is loaded on startup. The source-authenticated sanitized crosswalk found:

| Measurement | Result |
| --- | ---: |
| Original packaged ELFs in manifest | **28** |
| Original packaged ELFs mapped during Wayland startup sample | **19** |
| Original packaged ELFs mapped during live WebAudio sample | **18** |
| Original packaged ELFs mapped during USB WebAuthn attempt sample | **18** |
| Unique packaged ELFs mapped in at least one of the three workloads | **19** |
| Packaged ELFs **not observed in these samples** | **9** |
| Distinct mapped **host library filename basenames** across the three samples | **94** |
| Accepted negative mutations rejected | **6/6** |

The nineteen original packaged ELF basenames resident in at least one sample were: `libfreeblpriv3.so`, `libgkcodecs.so`, `liblgpllibs.so`, `libmozavcodec.so`, `libmozavutil.so`, `libmozgtk.so`, `libmozsandbox.so`, `libmozsqlite3.so`, `libmozwayland.so`, `libnspr4.so`, `libnss3.so`, `libnssutil3.so`, `libplc4.so`, `libplds4.so`, `libsmime3.so`, `libsoftokn3.so`, `libssl3.so`, `libxul.so`, `vulpra`.

The nine **not observed in these particular browser samples** were `crashhelper`, `crashreporter`, `gfxtest`, `libclearkey.so`, `libmozinference.so`, `libonnxruntime.so`, `pingsender`, `updater`, and `vulpra-bin`. These are **not proven unused**: earlier selected-feature / startup native requester tests had previously observed binding evidence for **all 28 original requesters** in bounded *other* workloads. Separate helpers and features cannot be judged solely from these three ordinary original-browser snapshots.

The WebAudio mapped host file included `libpulse.so.0.24.3`; USB WebAuthn included `libudev.so.1.7.15`. They are host files, **not members of the 28 packaged ELF matrix**. The 94 distinct host basenames are a cross-workload filename union in one ephemeral Arch userspace, **not** a statement that all 94 are simultaneously mapped, mutually unique file identities, required by all features or resolved ABI providers. The glibc Pulse binding test itself has 312 native binding events and 197 distinct `pa_*` names; these bindings do not supply a complete FFI call stack.

## Rejected actual-evidence corruptions and limits

All six mutations to real archived reports were independently rejected: duplicated 28-ELF row identity, mismatched original GUI archive fingerprint, missing real PulseAudio mapped backing file, forged WebAudio playback witness, missing mapped USB `libudev` backing file, and corrupted mapped `libudev` SHA-256. Original external source/archive identity, bounded safe library basenames, original-browser process-only mapping flags, exact feature evidence flags, and no-pruning declarations were checked.

**No causal inference from a simple set union:** browser process samples were taken in separate container runs; `/proc/maps` may miss transient mappings. The tests cannot establish which call or feature caused an individual mapping, complete `dlopen` paths, all FFI symbol versions, all launched helper executables, production Hyprland behavior, or the full 28-ELF build/source/runtime/feature graph. Crucially, **absence from these three bounded workloads does not authorize deletion**. No code or packaged ELF was removed, no native bytes were saved, and the sixth M3 gate remains open: **M3 5/6 = 83%; Vulpra overall 61%; change +0 pp**. The join-only workflow was restored to `workflow_dispatch` after successful CI.

The next useful coverage is to pair the nine as-yet-unmapped members with their **separately accepted real native feature-specific activation evidence** (ONNX, ClearKey, media and helper paths) and explicitly distinguish library mapping, runtime symbol resolution, and true executable launch rather than treating these unobserved samples as absence.
