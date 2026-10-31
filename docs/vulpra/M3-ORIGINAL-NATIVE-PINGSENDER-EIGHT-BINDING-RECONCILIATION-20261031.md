# M3 — Original pingsender runtime bindings and eight-requester reconciliation (2026-10-31 UTC)

## Native pingsender evidence

[Original source-pinned pingsender synthetic-loopback normal-symbol binding workflow 41165514106 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165514106), [workflow lint 41165514055 PASS](https://github.com/sguzman/vulpra/actions/runs/41165514055). The exact original compiled Vulpra tarball is SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` from source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`.

The existing pingsender no-egress fixture was reused with strictly opt-in `LD_DEBUG=versions,bindings`, with the original compiled `pingsender` executable. The fixture first rejected a forbidden numeric-host request and preserved its synthetic input, then used one permitted literal-localhost compressed POST and deleted only that synthetic input on success, with a private HOME and no external network interface. Real user telemetry was not sent. The original version-only pingsender regression [41165489495 PASS](https://github.com/sguzman/vulpra/actions/runs/41165489495) remained unchanged and passing.

The bounded std-only Rust source-pinned observer exported only safe loader provider basenames and counts: **170 normal-symbol binding events, 170 distinct symbol/provider pairs, 5 provider basenames, one real original `pingsender` PID trace**. It does **not** imply full telemetry life-cycle correctness, network functionality outside the synthetic namespace or safe deletion of pingsender.

## Independent eight-requester union

[Independent seven-plus-pingsender binding reconciliation 41165593539 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41165593539). The original three prior successful source-authenticated native report workflows remain pinned; the new `pingsender` report is authenticated by exact fourth workflow run and head SHA. The new `ci/m3-original-real-binding-eight-requester-union.jq` fails closed on source/archive mismatch, raw/symbol-export flags, synthetic-loopback policy, requester duplication, malformed provider names, inconsistent group totals or unexpected counts.

| Original ELF requester group | Observed normal-symbol binding events | Distinct requester/symbol/provider combinations |
|---|---:|---:|
| `libxul.so` headless original browser | 6,328 | 2,862 |
| `crashhelper`, `crashreporter`, `updater` protected diagnostic routes | 797 | 760 |
| `libmozinference.so` guarded C API | 184 | 182 |
| `libclearkey.so` invalid-version C API | 71 | 70 |
| `libonnxruntime.so` guarded C API | 246 | 244 |
| `pingsender` synthetic localhost-only gzip POST | 170 | 170 |
| **Eight distinct original ELF requesters** | **7,796** | **4,288** |

The independent reconciler verified **50 distinct observed provider basenames** across five evidence reports. The 4,288 number is a requester-qualified distinct combination sum; repeated events may count multiple times in the 7,796 figure. This is **not** complete imported symbol coverage and is not a proportion of the original 28 packaged ELF modules exercised over all possible paths.

No production Vulpra, package, installed Firefox Developer Edition/profile, user data, real network telemetry, source removals or bytes saved. Complete lazy/transitive dynamic dependencies, all features, Arch/Hyprland ABI and feature/build ownership remain unverified.

**M3 5/6 gates (83%); Vulpra overall 61%; session Δ0 percentage points.**
