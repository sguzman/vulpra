# M3 measured native package footprint (historical source-pinned archive)

**Verified run:** [GitHub Actions 40924515578](https://github.com/sguzman/vulpra/actions/runs/40924515578) **PASSED** with [downloadable JSON evidence](https://github.com/sguzman/vulpra/actions/runs/40924515578). It independently checksum-verified and inspected the **full normal Vulpra** Linux archive retained from [run 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401). Original compiled source is **`1683ca67b69389a879717bcd537772c3b40624b6`**, which is not the current complete main revision. The updated workflow explicitly requires both the locale and native footprint reports before accepting success. No compiler, binary execution, source removal, profiler or comparative build was run.

## Real archive data

| Physical measurement | Bytes | Meaning |
| --- | ---: | --- |
| Complete `tar.xz` | **86,930,792** | One compressed distribution archive |
| Sum of outer tar regular-file lengths | **339,565,212** | Logical unpacked file bytes, not disk usage |
| `vulpra/libxul.so` | **189,486,920** | Individual native Gecko shared-library logical length |
| `vulpra/browser/omni.ja` | **54,911,514** | Browser-bundled resource ZIP logical length |
| `vulpra/omni.ja` | **48,049,596** | Root/toolkit resource ZIP logical length |

The two `omni.ja` sizes are ZIP container file sizes **inside** the outer compressed tarball. [The localized resource census](M3-PACKAGED-LOCALE-CENSUS.md) finds **6,300,493 bytes of selected uncompressed ZIP-entry payloads within those same containers**. Do not add ZIP-entry payload lengths to outer tar member lengths or compare their individual lengths directly against the tar.xz total.

## Engineering implications

- **Native Gecko dominates an important measured portion of the unpacked package.** The presence of `libxul.so` provides a concrete compiled target for future link-map and symbol/dependency analysis. It does not reveal how much of libxul belongs to any one optional feature or to C++, Rust, WebRender, NSS, etc.
- **Rust and native C/C++ remain integrated.** [The source crosswalk](M3-NATIVE-FEATURE-DEPENDENCIES.md) verifies gkrust and platform/native build dependencies; a path or feature flag is not a byte-level link attribution.
- **Resource bundles are another distinct surface.** Removing one JSX, Fluent, SVG or module source file may or may not change the compressed outer archive. Existing PromoCard/AdsFeed experiments measured their particular isolated trials separately; those results cannot be added to this package as if source revisions and build options matched.
- **This archive is historical.** It establishes an actual normal native package footprint at the pinned build source, not a current-main build or a source-matched lean-versus-full comparison. It says nothing new about startup, privacy, security, package installed disk blocks or RAM.

**Next gates:** source-matched native link map / `libxul` section inventory with configured build options, explicit candidate dependency closure, guarded native/full pair if warranted, and Wayland/navigation/JS/WebExtensions/Nimbus/locale/profile/privacy regression acceptance. We must not count the size of a shared library as potential recoverable bloat.

**Accounting:** evidence-only M3 subtask. **M3 2/6 (33%), overall 44%, Δ0 pp.** No new removals.
