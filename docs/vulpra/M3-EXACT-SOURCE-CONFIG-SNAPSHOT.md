# M3 exact-source current Linux configure-only snapshot

**Successful source-matched `mach configure`:** [GitHub Actions 40932179859](https://github.com/sguzman/vulpra/actions/runs/40932179859), run SHA **`74e390f8f27ba705fbf26aa4750a21f0929a6ae8`**, generated-config artifact **12924085624**. Local parser fixtures also passed (nine checks). The CI job checked out this exact SHA, bootstrapped native configure prerequisites, ran `./mach configure` with `ci/mozconfig-linux-m3-baseline`, and recorded selected actual `config.statusd/substs` values. **No `./mach build`, `./mach package`, native browser runtime or removal experiment was invoked.**

The [machine-readable snapshot](M3-EXACT-SOURCE-CONFIG-SNAPSHOT.json) reproduces the **25 allowlisted scalar values actually printed in that job**. The downloadable original Actions artifact is primary evidence.

## Observed substitutions

| Key | Exactly observed generated value |
| --- | --- |
| `MOZ_BUILD_APP` | `"browser"` |
| `MOZ_WIDGET_TOOLKIT` | `"gtk"` |
| `OS_TARGET` | `"Linux"` |
| `MOZ_APP_BASENAME` | `"Vulpra"` |
| `MOZ_APP_NAME` | `"vulpra"` |
| `MOZ_APP_VERSION` | `"159.0"` |
| `MOZ_DEVTOOLS` | `"all"` |
| `MOZ_WAYLAND`, `MOZ_X11` | Each `"1"` |
| `MOZ_SANDBOX`, `MOZ_CRASHREPORTER` | Each `"1"` |
| `MOZ_SERVICES_SYNC`, `MOZ_SERVICES_HEALTHREPORT` | Each `"1"` |
| `MOZ_NORMANDY`, `MOZ_UPDATER` | Each `"1"` |
| `MOZ_HAS_REMOTE`, `ENABLE_WEBDRIVER` | Each `"1"` |
| `VULPRA_NO_ASROUTER_PROMOS` | **Recorded empty string `""`**, normal/unomitted case |
| `ENABLE_TESTS`, `MOZ_GECKODRIVER` | **Absent** selected generated files, value not inferred |
| `MOZ_TELEMETRY_REPORTING`, `MOZILLA_OFFICIAL` | **Absent** selected generated files, value not inferred |
| `MOZ_APPSERVICES_IN_TREE`, `MOZ_BROWSER_BRANDING`, `MOZ_CONFIGURE_TRUSTED_PROXY` | **Absent** selected generated files, value not inferred |

**Important:** `"1"` is the actual generated JSON string, not a Python boolean. `""` is an actual recorded empty string. *Absent* means the selected `config.statusd/substs` file did not exist, **not** `false`, disabled, uncompiled, or safely removable. Values outside the whitelist were deliberately not captured. Do not infer an absence of telemetry, geckodriver, test libraries, or any other code from a missing substitution.

## Comparison with the archived native binary

The older **compiled** normal package was built at source commit `1683ca67b69389a879717bcd537772c3b40624b6` by [workflow run 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401); its workflow HEAD was a different commit. [Historical selected configure assertion provenance](M3-HISTORICAL-BUILD-CONFIG-PROVENANCE.md) verified that specific run's selected flags. [Archive-wide ELF graph](M3-NATIVE-PACKAGE-ELF-GRAPH.md) measured its **28 ELF members and 268 direct `DT_NEEDED` edges**.

The **current configure-only** run above is a *different* source revision. Its generated flags cannot be described as the original packaged binary's build settings, and the old ELF section sizes cannot be directly assigned to the configured current source. Further commits to roadmap or CI docs also mean the snapshot is pinned to `74e390...`, not whatever main points at later.

## Next justified acceptance boundary

To establish a **current compiled native** feature-level link map, a full source-matched Linux build must preserve its *own* generated flags, linker/map records, exact build source and final package hashes. Before candidate removal, feature callers, language/Remote Settings startup fallbacks, security/privacy and Wayland/JS/WebExtension regression gates must pass. That is substantially more work than a configure-only run and has **not** been claimed here.

This closes the previously missing **exact-source generated-configuration subtask**, but not the entire M3 feature and binary dependency gate. **M3 remains 2/6 (33%), overall Vulpra 44%, Δ 0 pp.**
