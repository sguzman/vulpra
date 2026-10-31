# M3 — Original native inference and ClearKey actual binding observations (2026-10-31 UTC)

## Verified evidence

[**Combined original compiled no-egress C API runtime binding run 41164226000 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41164226000), with [workflow lint 41164225994 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/41164225994). The new audit authenticates the same original full-normal source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and compiled Vulpra tar.xz archive SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`, checks both original ELF C API exports, and invokes the two existing protected Rust native probes in *separate* no-network-egress namespaces with disposable HOME directories.

Both original C API diagnostic routines succeeded: `libmozinference.so` uses the existing protected production-linked llama C API, with no model or inference; `libclearkey.so` checks only invalid CDM interface version rejection, with no DRM keys, playback or decryption. A small Rust/std-only auditor `ci/m3-native-original-feature-module-bindings.rs` inspected bounded glibc `LD_DEBUG=versions,bindings` traces and emitted sanitized provider basenames and counts. The original independent version-check workflows remained functional after introducing the opt-in test instrumentation: [mozinference 41164158039 PASS](https://github.com/sguzman/vulpra/actions/runs/41164158039), [ClearKey 41164161227 PASS](https://github.com/sguzman/vulpra/actions/runs/41164161227).

The successful combined [source-authenticated CI artifact](https://github.com/sguzman/vulpra/actions/runs/41164226000) reports:

| Original native module | Native traces with bindings | Observed normal-symbol binding events | Distinct symbol/provider pairs | Observed provider basenames |
|---|---:|---:|---:|---:|
| `libmozinference.so` | 1 | 184 | 182 | 5 |
| `libclearkey.so` | 1 | 71 | 70 | 4 |
| **Sum** | **2** | **255** | **252** | — |

These are *actual glibc loader binding observations* on Ubuntu 24.04, rather than the previously established static imported-symbol or GNU version-identity inventories. The observed events are bounded to the two successful diagnostic C API invocations and do not establish complete module coverage or every relocation path.

## Scope and exclusions

These observations complement—but must not be conflated with—the earlier [original `libxul.so` headless runtime binding result](M3-ORIGINAL-NATIVE-LIBXUL-RUNTIME-BINDINGS-20261031.md) and [three original protected auxiliary binding results](M3-ORIGINAL-NATIVE-AUXILIARY-RUNTIME-BINDINGS-20261031.md). Five *additional* protected compiled module requesters were examined across the two new CI workstreams: 797 original crash/update auxiliary binding events and 255 original inference/ClearKey binding events, totaling 1,052 events (not 1,052 unique imported symbols). The three auxiliary and two C API tests use **distinct** original ELF requester basenames, but their provider library sets overlap.

No raw loader logs, symbol names, PIDs, filesystem paths, user profiles, models, media or keys were uploaded. No new source removals, browser source changes, installed profile changes or size savings were made. Full lazy/transitive runtime coverage, genuine feature workflows, source/build ownership and the overall M3 dependency closure remain **unverified**.

**Progress: M3 5/6 gates (83%); overall Vulpra 61%; session delta +0 percentage points.**
