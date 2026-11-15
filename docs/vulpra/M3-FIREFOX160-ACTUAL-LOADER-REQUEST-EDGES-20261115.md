# Firefox 160: actual native glibc loader request and initialization evidence (2026-11-15)

## Accepted source-bound runtime observations, not global dynamic dependency closure

The [real compiled browser loader-observation CI **43743231236 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43743231236) reused the exact archived, unchanged Firefox 160 Vulpra native browser, launched it in an independent disposable Ubuntu 24.04 headless WebDriver workload, and observed glibc `LD_DEBUG=libs,files` request and initialization metadata. The small [std-only Rust inspector](../../ci/m3-firefox160-native-loader-request-edges.rs) parsed only bounded numeric-PID trace files from that run. A loader request edge is classified as **initialization-confirmed only if the same PID trace also contains a matching glibc `calling init:` event for its target**. Merely requested/unconfirmed names are retained separately.

**Exact pinned provenance:** Mozilla Firefox 160 release source `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`; Vulpra's independently assembled 28-overlay Git source tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`; full original Firefox160 native package SHA-256 `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`. The compiled browser was originally produced by [CI 43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940) and its exact archive/source proof preserved by [CI 43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827). CI verified both producer identities, original source-tree attestation, native archive sidecar and exact SHA before staging only under a temporary Actions checkout `.git`. No Firefox source compilation occurred in this session.

### What the actual browser showed

| Actual bounded glibc observation | Result |
| --- | ---: |
| All numeric-PID loader trace files examined | **8** |
| PID traces with actual `libxul.so` initialization | **2** |
| Distinct initialized native provider basenames across those traces | **94** |
| Distinct `needed by` edges to initialized targets | **80** |
| Distinct `dynamically loaded by` edges to initialized targets | **18** |
| Distinct dynamically requested names without same-trace init confirmation | **16** |

The two Firefox-containing traces included `libxul.so` and `libc.so.6` initialization. The same real browser lifecycle also passed JavaScript/HTTP 302/DOM, temporary WebExtension installation, content script/background messaging/`storage.local`, self-signed HTTPS denial, Nimbus initialization, uninstall and preservation of independent Firefox profiles.

Four important **glibc-reported, initialization-confirmed** dynamic request relationships were `libnspr4.so → libsoftokn3.so`, `libnspr4.so → libfreeblpriv3.so`, `libnspr4.so → libmozavcodec.so` and `libnspr4.so → libmozavutil.so`. Additional real observed dynamic relationships included `vulpra → libxul.so`, `vulpra → libmozwayland.so`, `vulpra → libnss3.so` and packaged startup libraries. **These are glibc requester/target labels, not directly attributed compiled source functions, stack traces or proof of the calling high-level feature.** In particular, the `vulpra` loader origin may reflect process launcher behavior.

The 16 **not-init-confirmed** names were 14 FFmpeg candidates (`libavcodec-ffmpeg.so.56` through `.58`, and `libavcodec.so.53` through `.63`), plus `libnssckbi.so` and `libpulse.so.0`. Lack of an initialization event **must not** be promoted into a proven failed `dlopen`, absence on the machine, broken audio/video, or successful fallback. These are *exactly what glibc reported as requests in the bounded captured browser traces* and may involve attempts, alternate providers or other process/feature conditions.

The original real loader evidence is `firefox160-actual-initialized-loader-request-edges-not-dlopen-closure` (artifact **14173676100**), containing only sanitized provider basenames and requester/target pairs. All raw PID-specific paths, process identifiers, symbol names, environment details, profile data and loader logs were discarded, not archived.

### Independent runtime, package and symbol-binding reconciliation

[**Independent CI 43743788875 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43743788875) used the strict [crosswalk](../../ci/m3-firefox160-real-loader-and-bindings-crosswalk.jq) and separately authenticated:

- The exact 28-native-ELF/268-direct-`DT_NEEDED` package graph, [CI 43730900702](https://github.com/sguzman/vulpra/actions/runs/43730900702).
- Earlier **actual** `libxul.so` default/eager runtime glibc symbol bindings and 45 sanitized provider basenames in both workloads, [CI 43741731639](https://github.com/sguzman/vulpra/actions/runs/43741731639).
- The new actual initialized-loader request report, [CI 43743231236](https://github.com/sguzman/vulpra/actions/runs/43743231236).

It required exact source and native archive SHA parity, conservatively scoped flags, 94/80/18/16 measured sets, exact import-relevant NSS/FFVPX edges, unique/safe request names, proper target initialization classification, and that the 45 bound provider basenames from the **separate** runtime workload belong to the new initialized-name set except for the executable basename `vulpra`. **11/11 deliberately mutated source/byte/count/edge/init/privacy/completion reports were rejected.**

The initial comparison [CI 43743658531 failed](https://github.com/sguzman/vulpra/actions/runs/43743658531) because jq's generic JSON-object sort uses a different key order than Rust's source/target tuple sort. The [corrected verifier commit `96bb9ae`](https://github.com/sguzman/vulpra/commit/96bb9aecf189b07e058a37091e51f05d8917b38c) checks explicit `(requester, target)` tuples; the verified original runtime output was **not changed** to make the comparison pass. The independent accepted report is `firefox160-real-loader-and-libxul-binding-crosswalk-not-m3-closure` (artifact **14173602490**), downloaded and inspected after the green run.

### Remaining M3 dependency-mapping blockers

The 80 observed `needed by` edges and 268 original package `DT_NEEDED` declarations are different populations; their counts cannot be subtracted to infer uncovered ELF dependencies or feature removability. Likewise the 18 initialized dynamic request relations are not every conditional loader call, and source ownership/actual machine call arguments, delayed/absent `dlopen` and `dlsym`, all Rust/C++ and generated FFI edges, complete fallback/activation of 18 protected features, security-current readiness and hardware-specific Arch/Wayland/GPU operation remain **unproven**.

No pruning, root feature removal, default feature disable, compiled browser rebuild, host package installation, target user desktop access, original Firefox profile change, PR merge or public release occurred. PR #6 stays draft and issues #8/#9 remain unresolved.

**Progress:** overall **61% (Δ +0 percentage points)**, M3 **83% (5/6)**, sixth dependency gate OPEN. Next work should use these observed NSS/FFVPX and non-initialized FFmpeg/Pulse name rows as source/feature attribution *candidates* for separately authenticated exact Firefox160 source and bounded protected-fallback runtime tests, never as deletion instructions.
