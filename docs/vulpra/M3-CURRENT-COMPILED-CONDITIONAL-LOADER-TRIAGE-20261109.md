# Source-bound conditional native loader caller triage — 2026-11-09 UTC

**Accepted bounded audit:** [conditional native loader CI **42542717525 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42542717525), [artifact **13642360260**](https://github.com/sguzman/vulpra/actions/runs/42542717525/artifacts/13642360260), [workflow lint **42542717430 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42542717430). The real output archive was downloaded and its JSON checked independently at this checkpoint.

**Original compiled evidence:** [source-matched full normal native build **42507965586 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42507965586), exact source commit `bd2499aeadce0368faa8b717b0e8a17e9c9dc317`, and [independent full-native reconciliation **42513861084 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/42513861084). This triage workflow re-authenticates **both GitHub run identities**, downloads their actual artifacts, joins the generated package and runtime report with the **same source and unstripped compiled `libxul.so` SHA-256**, and rejects **33/33 forged source, hash, loader, feature-closure, and package states**. The workflow is **read-only** and compiles no new browser.

## Actual compiled source-bound loader census

- Unstripped linked `libxul.so` SHA-256: `d54e429bd40a7567fa81e34174f661aec443485ca7fe18997cb665e4cbccd987`. This is **not** the shipped/stripped `libxul` SHA.
- Source-linked normal package SHA-256: `965171f3e6cb90004a24683b38df99e27bb93e3514dbd382dd48e96b3290668b`, with 28 packaged ELF files / 268 direct `DT_NEEDED` edges.
- Full bounded **direct** loader API census: **73 branches / 47 distinct caller–API–branch-kind records**. It includes only recognized direct `call` and tail `jmp` targets to selected NSPR/Linux loader entrypoints in this **one** current compiled `libxul.so`.
- High-priority targeted subset: **12 exact compiled caller records / 19 direct machine branches**, not all 47 records. The 19 are not extra branches beyond the 73.

| Scoped actual native caller witness | Direct branches | Next uncovered activation/error-path check |
| --- | ---: | --- |
| FFmpeg runtime init | 1 | Alternative codec/library selection and missing-codec fallback |
| ONNX API entry | 1 | Provider presence, absence and model-runtime failure |
| Llama runtime linker | 1 | Model/backend presence, absence and failure |
| DRM library loader | 1 | DRM/graphics host-library availability |
| GMP child preloader | 1 | Plugin child preload allowlist and failure |
| GMP plugin loader | 1 | Plugin presence, missing/unsigned plugin and fallback |
| VA-API wrapper | 2 | Driver/discovery and software-video fallback |
| GBM widget backend | 2 | GBM/Wayland provider and fallback |
| PulseAudio cubeb backend | 1 | PipeWire/Pulse library availability and audio fallback |
| GSSAPI auth provider loader | 6 | Kerberos/GSS provider variants and unavailable service |
| GSSAPI flagged loader variant | 1 | Alternate auth-provider loader mode |
| libsecret credentials loader | 1 | Credential-store presence, permissions and fallback |

The named categories are **caller-symbol-derived leads**, not inferred proof of the specific dynamic library filename passed at runtime. In particular, the mere presence of a compiled loader branch does not prove that the containing feature was activated, the requested library existed, the call succeeded, or the alternate path remained functional.

## Exact evidence scope and next actions

The independently checked [source-bound classifier](../../ci/m3-current-conditional-loader-triage.jq), its [33 negative checks](../../ci/tests/m3-current-conditional-loader-triage-tests.sh) and [read-only workflow](../../.github/workflows/m3-current-conditional-loader-triage.yml) all **retain false** for actual library argument/dlsym target resolution, indirect loader calls, other packaged ELF callers, conditional runtime exercise, target EndeavourOS/Hyprland parity, complete dependency/FFI closure, pruning and release approval.

**Next useful audit:** begin with FFmpeg, VA-API, GBM/PulseAudio, GMP, ONNX/Llama and auth/credential paths. For each, source-pin the library-name expression and conditional guard, then exercise both present/missing-provider outcomes with an isolated profile and no real credentials or user data. Additional compiled ELFs, indirect native calls and fallback coverage require separate observations; no safe feature omission may be inferred from this direct-caller sample.

**Overall 61% (Δ+0 pp); M3 5/6 gates, 83%.** This is a newly independently accepted *bounded risk-triage subtask*, not closure of the sixth gate, not native package savings, and not normal-browsing release readiness.
