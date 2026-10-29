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

**Evidence discipline:** no completion is claimed until the full native run is green with the required link-input artifact and runtime gates. The existing historical preflight proves only the *older* package's physical preload ordering. A new source-matched build can strengthen the native/build map without authorizing any feature removal or upgrading M3 until its whole acceptance criteria are met. No current-main binary or new compiled gain is implied by this protocol.

**M3 2/6 (33%); overall 44%, Δ 0 pp.**
