# Real source-matched packaged Vulpra optional-provider denial — accepted 2026-11-09 UTC

## Native browser and independent evidence

**Full native browser build and runtime:** [M3 Source Matched Native Link Inputs and Runtime #42546880350 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42546880350), source commit `d7bf1cb73b384df047871d6b8c608312eb6cb5b4`. This was the **actual full normal Rust/C++ Vulpra build**, its normal package and private Weston/Wayland smoke, localhost screenshot, WebDriver JS redirect, temporary WebExtension, Nimbus, original-profile isolation, and ordinary-trust self-signed localhost TLS rejection; all passed.

**Normal package:** `vulpra-local-m3-native-link-ci.tar.xz`, 87,158,608 compressed bytes, SHA-256 `200c220ed657b4f3ddd0608a815e0c4d17077fb40c301f8cbae03c1c1a37a959`. The source-bound package contains 28 ELF members / 268 direct `DT_NEEDED` edges; the unstripped native `libxul.so` has SHA-256 `3b7f15ae0d8ab44ac241631e902267024773130dfad43dc1cbbde9701eee8aa9`. This SHA is for the **built unstripped** ELF, not the package-transformed `libxul.so`. Existing normal Rust archive, direct-branch and loader reports also passed.

**Independent native reconciliation:** [#42551783346 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42551783346), [artifact 13645911755](https://github.com/sguzman/vulpra/actions/runs/42551783346/artifacts/13645911755), independently authenticated source SHA, normal package hash, full normal runtime, Rust archive owner/linked ELF proof, three C++→Rust XPCOM direct branches, crashhelper Rust archive/FFI branch and ordinary TLS rejection. It *does not* claim full member-selection or conditional dynamic dependency closure.

**Original packaged-browser provider-denial report:** [artifact 13645288941](https://github.com/sguzman/vulpra/actions/runs/42546880350/artifacts/13645288941), `m3-packaged-provider-denial-runtime.json`. The artifact ZIP was downloaded and parsed independently, and its source and package hashes match the full native normal package and separate reconciliation.

## Actual real packaged browser results

The source-matched packed browser was relaunched in three *disposable headless localhost screenshot* modes with the bounded C `LD_PRELOAD` optional-provider interposer. The native executable was instrumented (three `ATTACHED browser-process` witnesses in every mode), and the shim denied matching real `dlopen`/`dlmopen` library requests by substituting a deliberately nonexistent library name. It did not change system libraries or the normal Firefox profile.

| Optional provider group | Browser-process attachment witnesses | Observed matching denied calls | Real private localhost browser screenshot |
| --- | ---: | ---: | --- |
| GBM/DRM, `libgbm.so.1`/`libdrm.so.2` | 3 | **0** | **Passed**, but no matching missing-provider branch exercised |
| VA-API, `libva.so.2`/`libva-drm.so.2` | 3 | **0** | **Passed**, but no matching missing-provider branch exercised |
| FFmpeg versioned `libavcodec.so.*`/`libavcodec-ffmpeg.so.*` | 3 | **14** | **Passed after observed FFmpeg loader denials** |

**Precisely accepted:** the **actual normal packaged Vulpra process attempted 14 selected FFmpeg library loads that were returned as loader failures**, and the browser remained able to render its localhost screenshot afterward. The source-matched FFI/native run and package identity are real, not synthetic. The screenshot test, however, contains **no explicit video playback, H.264 decode, or software decoder feature acceptance**, so a successful screenshot is *not* software codec fallback proof.

**Precisely untested:** the headless GBM and VA-API modes logged **zero matching attempted loads**, not 0 failed assertions. They confirm only that an instrumented browser with these opt-in denial settings could render the simple headless screenshot **without invoking the selected APIs**. This is not evidence of safe missing-GBM or missing-VA-API fallback. The existing normal private Weston/Wayland graphical smoke passed in the **baseline** unmodified provider environment; the separate [graphical provider-denial wrapper](../../ci/m3-smoke-packaged-wayland-provider-denial.sh) was prepared and lightweight-linted but is **not connected to this native run**.

## Separate fail-closed verification

The [read-only exact-source provider reconciliation workflow #42552316905 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42552316905) independently authenticated the completed native run and separate native reconciler through GitHub's run API, downloaded **three original named artifacts**, and verified:

- The exact native source SHA and normal packaged archive SHA.
- Ordinary private browser runtime and the accepted 28/268 ELF/loader counts from the *separate* normal native reconciliation.
- Three actually attached and successful browser screenshots, with observed denial calls **GBM 0, VA-API 0, FFmpeg 14** and matching no-hit coverage flags.
- **26/26 forged original source, package SHA, run ID, screenshot, process-attachment, denied-event, false GBM/VA-API coverage, falsely closed linker/FFI and release authorization states rejected**.

The two files of the conservative verifier are [source-joined jq filter](../../ci/m3-packaged-optional-provider-reconcile.jq) and [26 tamper-check tests](../../ci/tests/m3-packaged-optional-provider-reconcile-tests.sh). [Independent accepted artifact 13645627305](https://github.com/sguzman/vulpra/actions/runs/42552316905/artifacts/13645627305) was separately downloaded and its JSON parsed; [workflow lint #42552316907 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42552316907). The first [workflow attempt #42552273539](https://github.com/sguzman/vulpra/actions/runs/42552273539) failed early from a malformed GitHub token expression; this was corrected in [`c2b929a`](https://github.com/sguzman/vulpra/commit/c2b929aa3216f393eb155dcbfad2ffc5044b3574). Earlier failure is not counted as success.

## Remaining M3 work and non-claims

To test GBM and VA-API dynamically, **exercise actual feature-triggering workloads** under source-matched packaged Linux Vulpra; a simple headless screenshot never requested either provider. To establish display fallback, use a real private Weston/Wayland compositor test with a matching *observed* denial and a committed graphical surface, ideally moving on to targeted DMA-BUF, GPU and video playback tests with explicit logs. The prepared graphical harness alone is not an executed test. The remaining full conditional and indirect dynamic dependencies require separate per-feature and per-process coverage.

Do **not** infer Safe Browsing, sandbox policy enforcement, complete linker-member selection, all Rust/C++ FFI edges, all host/dlopen dependencies, video decode fallback, target EndeavourOS/Hyprland parity, recoverable feature-by-feature bytes, or normal browsing release readiness. The `Security 159 Hotfix Native Evidence Reconciliation` workflow returned an overall successful conclusion for its general check, but its specialized jobs were skipped in that run; it is **not evidence that the separate security hotfix branch has been merged or fully validated**.

**M3 gate six remains OPEN (5/6 gates, 83%). Overall 61%, Δ +0 percentage points.** No new source pruning, host changes, security merge or release.
