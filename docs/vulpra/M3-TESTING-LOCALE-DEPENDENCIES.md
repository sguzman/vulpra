# M3 source-pinned testing, WebDriver, and localization dependency crosswalk

**Status:** read-only build/source boundary audit, accepted by [GitHub Actions 40922064826](https://github.com/sguzman/vulpra/actions/runs/40922064826). Its downloadable bounded JSON artifact, `m3-testing-localization-boundaries` (ID 12918038936), records exact Git commit, source paths, line numbers and unique anchors. The audit rejects **17 deliberately broken source dependencies** and verifies **14 bounded build relationships**. It does **not** evaluate the generated dependency graph, compile, execute the browser, delete source or estimate package savings.

## Protected or independently conditional source

| Scope | Source-verified boundary | Decision |
| --- | --- | --- |
| Root build | `moz.build` includes `python`, `testing`, and `third_party/python` unconditionally in the selected app graph. | Retain build/bootstrap source |
| Testing build support | `testing/moz.build` always lists `manifest`, `mozbase`, `mozharness`, and Python unittest metadata. | Retain; disabling tests ≠ deleting these trees |
| Remaining Android-test manifest | `testing/moz.build` references `android-test/tests/python.toml` whenever `JS_STANDALONE` is false. | Conditional; separate unsupported-platform cleanup review |
| Browser entrypoint | `browser/app.mozbuild` includes shared toolkit; `browser/moz.build` includes locale source and screenshots test metadata. | Retain build entrypoint and locale |
| WebDriver and Marionette | `toolkit/toolkit.mozbuild` includes remote, Firefox UI, Marionette and telemetry Marionette paths under `ENABLE_WEBDRIVER`, independently of `ENABLE_TESTS`. | Preserve accepted WebDriver behavior |
| Geckodriver | A separate `MOZ_GECKODRIVER` branch excludes TSAN/fuzzing; does not equal the WebDriver config gate. | Conditional; audit independently |
| Test suites | WPT, Mochitest, xpcshell, testing profiles and modules are grouped under `ENABLE_TESTS`. | Conditional; do not confuse with always-wired support |
| WebDriver packaged chrome | `browser/installer/package-manifest.in` includes remote-agent chrome under `ENABLE_WEBDRIVER`. | Preserve actual package runtime |
| Browser Fluent and l10n registry | `browser/moz.build`, `browser/locales/moz.build`, `jar.mn`, and `l10n-registry.manifest` wire browser translations and registry. | Retain default locale infrastructure |
| Toolkit locale and defaults | `toolkit/moz.build`, toolkit locale `jar.mn`, registry and generated `multilocale.txt`/`default.locale` are wired. | Retain generated metadata |
| Packaged locale contents | Browser package manifest includes both localization roots, dictionaries, and `default.locale`. | Retain until package-member evidence |
| Language repacks | Browser locale Makefile uses toolkit `l10n.mk`, per-language l10n staging, and langpack target. | Measure separately from default tarball |
| Branding fallback | Browser l10n configuration still references upstream official/legacy branding and toolkit locale inclusion. | Audit substitutions before removal |
| Updater locale source | `browser/locales/moz.build` has a `MOZ_UPDATER`-guarded generated `updater.ini` referencing a Windows-installer source. | Conditional; filename-based pruning is unsafe |

## Implications and next evidence gates

This audit **rules out blanket source deletion of `testing/` or `locales/` based solely on disabling tests or shipping en-US by default.** It also distinguishes core remote-debugging behavior from optional test suites, and browser-distributed translations from separately built language packs.

There are still real optimization questions: what conditional fixtures never enter Vulpra's *normal* Linux build; which locale assets are actually shipped by the checksum-verified package; whether any retained legacy translation entries are unused after a safe fallback is implemented; and what extra build tools remain for a local `mach` workflow.

Before any removal: evaluate the generated manifest/build graph, obtain exact source/path reachability, preserve tooling/translation/branding fallbacks, run an isolated native build and repeat Wayland, JS/navigation, WebExtension, WebDriver, startup/profile and package verification. Compare independent source-matched package members and compressed archive bytes; negative or nondeterministic savings are valid results.

**Accounting:** This closes a *bounded evidence subtask*, not the roadmap's entire feature/build/binary/platform mapping gate. Broad M3 remains **2/6 (33%)** and overall Vulpra **44% (Δ 0 pp)**. No binary saving, package omission or new native-runtime evidence is inferred.
