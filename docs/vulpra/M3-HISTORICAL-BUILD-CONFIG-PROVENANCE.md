# M3 original native build-configuration provenance

**Verified:** [CI 40931065344](https://github.com/sguzman/vulpra/actions/runs/40931065344) **PASSED** with ten deliberately invalid provenance fixtures rejected and [bounded JSON artifact 12923200919](https://github.com/sguzman/vulpra/actions/runs/40931065344). The audit fetched the *original* GitHub Actions run, job, source-pinned historical workflow file and compiled-source `mozconfig`, plus the job's original log. It did not run `mach`, rebuild Firefox, download or execute the package.

## The essential two-commit distinction

| Historical object | Immutable identifier |
| --- | --- |
| Successful original workflow run | `40567473401` |
| Original native job | `122412477192` |
| GitHub Actions **workflow/head** SHA | `341128fd6f640738ea2fbb0f674eb6319b249235` |
| **Actual browser source checked out and compiled** | `1683ca67b69389a879717bcd537772c3b40624b6` |
| Full normal native package artifact | `12767756929`, `m3-asrouter-promo-matched-baseline` |

The workflow run's commit and the compiled browser's commit are **different on purpose**. The historical workflow explicitly checks out the candidate's older exact source, asserts `git rev-parse HEAD == CANDIDATE_SHA`, configures, builds and packages that revision, then preserves the verified archive. Treating the workflow-head SHA as the browser's source SHA is factually wrong.

## Selected generated configure values that historical CI actually asserted

All of the following assertions were present in the historical executable job recipe, echoed into the original job log, and followed by its successful configure gate, native compilation and packaging steps:

| Generated configure key | CI-asserted result |
| --- | --- |
| `MOZ_APP_BASENAME` | `Vulpra` |
| `MOZ_WIDGET_TOOLKIT` | `gtk` |
| `MOZ_DEVTOOLS` | `all` |
| `VULPRA_NO_ASROUTER_PROMOS` | Disabled or unset in normal package |
| `MOZ_SANDBOX` | Truthy |
| `MOZ_WAYLAND` | Truthy |
| `MOZ_SERVICES_SYNC` | Truthy |
| `MOZ_NORMANDY` | Truthy |

The log confirms actual `config.status` creation and separate success messages after source-matching, selected feature assertions and packaging. The exact-source `ci/mozconfig-linux-m3-baseline` **requested** `--disable-tests`, unofficial branding, `--with-app-basename=Vulpra`, sccache, one parallel build job, and a dedicated `obj-vulpra-linux-m3-baseline` object directory. These requested options are *not a dump of their generated value*.

**Do not overinterpret this**: the full `config.statusd/substs` directory was never saved in the package artifact. We therefore **cannot** recover the complete authoritative generated-config map from this historic archive. Neither the Git workflow YAML nor the ELF metadata fills that gap. In particular, no value outside the explicit passed generated assertions should be promoted to “confirmed compiled feature flags.”

## Remaining work

A new source-matched configure-only run could record the complete generated substitution manifest for its **own** source revision, without compiling the whole browser. That would prove what the current source *configures*, not that the old binary was compiled with those current settings. For a full reproducible linker/feature census, a source-matched compiled object tree and link-map evidence must be retained. No source pruning, native rebuild, archive delta, runtime or security acceptance was performed by this provenance audit.

**M3 remains 2/6 (33%), overall 44% (Δ 0 pp).**
