# M3 — Independent original six-native-requester real symbol-binding union (2026-10-31 UTC)

## Verified reconciliation

[**Independent source-pinned six-requester reconciliation 41164427049 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41164427049). The CI verifier authenticates three previously successful **original compiled Vulpra** binding-evidence workflows by exact GitHub run ID, success status and recorded head SHA:

- `libxul.so` headless/private browser binding run [41162866013](https://github.com/sguzman/vulpra/actions/runs/41162866013).
- Protected crashhelper, crashreporter and updater diagnostic-only binding run [41164023607](https://github.com/sguzman/vulpra/actions/runs/41164023607).
- `libmozinference.so` and `libclearkey.so` original C API negative/synthetic-only binding run [41164244090](https://github.com/sguzman/vulpra/actions/runs/41164244090).

The follow-up run on corrected workflow commit `dad4d754` also [reconciled successfully (41164506186)](https://github.com/sguzman/vulpra/actions/runs/41164506186), and [global workflow lint passed (41164506173)](https://github.com/sguzman/vulpra/actions/runs/41164506173). The first lint run 41164427047 had detected a ShellCheck warning for an unused retry-loop counter; the fix used the counter to bound download retries and did not alter the reconciliation inputs, parser logic or results.

Their four strictly parsed sanitized JSON reports share the authenticated original compiled source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and original archived binary SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The new `ci/m3-original-real-binding-six-requester-union.jq` independently validates source fingerprint, schema, exact requester identities, original scope/negative-evidence flags, complete per-member count arithmetic and sanitized provider basename spelling; CI fails closed on any unexpected total or provider set.

| Independent original compiled requester category | Normal-symbol binding events | Distinct requester/symbol/provider combinations |
|---|---:|---:|
| Headless browser `libxul.so` | 6,328 | 2,862 |
| Auxiliary executables `crashhelper`, `crashreporter`, `updater` | 797 | 760 |
| `libmozinference.so` production-linked diagnostic C API | 184 | 182 |
| `libclearkey.so` invalid-version diagnostic CDM C API | 71 | 70 |
| **Reconciled total** | **7,380** | **3,874** |

Exactly **6 distinct original ELF requester basenames** and **48 unique observed provider basenames** across the separate workloads were verified. The 3,874 distinct requester/symbol/provider combinations count is the sum of per-original-requester distinct pairs and remains well-defined because the six requester basenames are distinct. The 7,380 raw normal-symbol binding events include permitted repeated bindings across PID traces; they are not 7,380 unique imported symbols.

## Limits and isolation

This reconciliation used only the **pre-sanitized CI reports**, not raw dynamic loader logs. It does not newly execute any binaries, compare private browser data, or publish absolute paths, symbol names, PID data or profile contents. It does not prove that all six modules exercised every relocation; it does not cover the other 22 original ELF files, complete transitively/lazily loaded providers, feature/build ownership, genuine crash/update workflows, real ML inference or DRM playback, Linux Arch/Hyprland ABI compatibility, or any safe file-removal decision. Previous 519/519 GNU version *identity* coverage and 2,153 static unversioned imported-symbol inventory remain separate metrics.

No production/browser code, installed Firefox Developer Edition profile, or source removal changed, and no compressed package size savings are asserted.

**Progress remains overall 61%, M3 5/6 gates (83%), Δ0 percentage points.**
