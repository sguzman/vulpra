# M3 — Successful current-main native package and bounded runtime (2026-11-04 UTC)

[GitHub Actions native run **41749398233 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41749398233), job **126310425833**, completed at **01:35:46 UTC**. The real exact pruned source checkout **`d5cfdb360ec9c3f9d113b2dbcbddaed74f406dfd`** successfully ran Mozilla `./mach configure`, full `./mach build`, `./mach package`, staged checksum verification, native-ELF link/dependency provenance, and real packaged smoke. This was **not** the historical original source or a synthetic package.

## Independently inspected artifact

Run artifact **13287746750** (`m3-source-matched-native-link-evidence`) has **seven files**. Its downloaded ZIP SHA-256 was **`28a283993c808dd0783995808631109490a4bae8b04db088159be4a16c86f909`**. The artifact passed independent JSON/ZIP integrity, cross-report SHA/count and runtime-result checks.

| Current source-pinned observation | Result |
| --- | --- |
| Normal native archive SHA-256 | `9cc6b6bb106055d767a1117a216b673367cd91237ad7c41a50ae38bb2542661e` |
| Compressed archive / regular tar files | **87,154,324 bytes / 47** |
| Regular-file logical bytes | **339,566,140** |
| Actual packaged native ELFs | **28** |
| Direct `DT_NEEDED` edges / distinct dependency names | **268 / 50** |
| Generated `libxul` response-file object entries | **2,435 .o entries** (not the entire linker/Cargo/FFI graph) |
| Packaged `libxul.so` bytes / SHA-256 | **189,486,696** / `ea6cef291e3558e945902380cb7e19c4c99282d62e37c0d8543e6b0439d181e7` |
| Gecko native ELF packaging | `mozpack.files.ExecutableFile.copy` reproduced staged SHA on a disposable file; original linked and stripped SHAs intentionally differ |
| Native preload order | `libmozgtk.so` before `libmozwayland.so` |

Generated normal-browser flags retained GTK, Wayland, X11, sandbox, Sync, Normandy, DevTools, crash reporting, and updating. All three optional New Tab/promo source-omission flags were empty/unset; normal features were not conditionally excluded.

**Real compiled-package runtime smoke passed:** private Weston graphical Wayland buffer attach/commit with 10-second process lifetime and isolated profile; valid screenshot from loopback HTTP; WebDriver JavaScript `/start → /js-run → /page` and final DOM verification; temporary unsigned WebExtension install, content/background messaging, `storage.local`, and persistent uninstall across nine post-uninstall checks; Nimbus `ExperimentStore` and API readiness in a disposable browser chrome context. Existing Firefox profile sentinel remained unchanged.

## Acceptance boundaries

This is **genuine current-pruned-source compilation and bounded normal-browser runtime acceptance**. It closes the prior no-current-native-compile evidence gap, **not M3's entire sixth feature/build/dependency map gate**: full linker/Cargo/FFI and conditional `dlopen` branch/fallback closure, protected-feature activation/error-path matrix and true target EndeavourOS/Hyprland workstation parity remain open. The standalone ELF scanner marks `current_main_compiled_source_matched=false` because it cannot independently establish provenance; separate source-pinned workflow/build/link records establish it for this bounded test.

This run is an Ubuntu 24.04 CI test, not a production release or a target workstation run. No new source removed, no marginal size savings established, and no user installations or profiles changed. Corrected explicit-offline Weston CI [41750432275](https://github.com/sguzman/vulpra/actions/runs/41750432275) is separate and its result is not claimed here. **M3 5/6=83%, overall 61%, Δ+0 pp.**
