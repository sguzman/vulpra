# M3 — Original seven feature-only ELF native loader candidates (2026-11-02)

## Actual compiled and real runtime evidence

[**Corrected CI 41523391875 PASS**](https://github.com/sguzman/vulpra/actions/runs/41523391875), artifact **13177249683** independently downloaded and inspected. The new read-only `ci/m3-original-feature-only-native-loader-candidates.jq` joins three authenticated, previously independently successful original-Vulpra evidence sets:

1. Original full-normal package compiled **27 non-`libxul.so` ELF selected-loader API import/branch census**, [CI 41350581069 PASS](https://github.com/sguzman/vulpra/actions/runs/41350581069).
2. Original compiled **28-ELF source/Ubuntu/Arch loader and seven selected-feature-only runtime requester matrix**, [CI 41515803526 PASS](https://github.com/sguzman/vulpra/actions/runs/41515803526).
3. Original isolated graphical native workload **21 actually observed dynamic-loader relationships**, [CI 41522017287 PASS](https://github.com/sguzman/vulpra/actions/runs/41522017287).

All three report original compiled source commit `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and the SHA-256 of the independently archived full-normal native browser `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The new check authenticates the successful workflow runs, their exact Git heads and actual artifact names before reading them. Negative tests reject a forged source/package hash, a changed compiled `libonnxruntime.so` branch count, and a forged feature-only-versus-startup classification.

The **initial attempt 41523205211 failed at jq expression parsing**; it was corrected in commit `274db808` and the corrected CI **passed**. Neither failure nor this fix is counted as a new native browser compilation or M3 gate completion.

## Compiled binary-specific loader evidence

The seven original regular ELF binaries below are **all observed as native symbol-binding requesters in the separately executed feature-specific workloads**, but none was a requester/target in the selected original startup graphical dynamic-request trace. This negative is intentionally narrow and does not indicate that the features are unneeded.

| Original packaged binary | Exact original build owner | Selected compiled loader API imports | Direct named loader API branches |
| --- | --- | --- | ---: |
| `crashreporter` | `toolkit/crashreporter/client/app/moz.build` | `dlopen` | **0** |
| `libclearkey.so` | `media/gmp-clearkey/0.1/moz.build` | none in selected census | **0** |
| `libmozinference.so` | `config/external/mozinference/moz.build` | none in selected census | **0** |
| `libonnxruntime.so` | `toolkit/components/ml/moz.build` | `dlopen` | **1** |
| `pingsender` | `toolkit/components/telemetry/pingsender/moz.build` | `dlopen` | **6** |
| `updater` | `toolkit/mozapps/update/updater/moz.build` | none in selected census | **0** |
| `vulpra-bin` | `browser/app/moz.build` | `dlopen` | **1** |
| **Seven selected-feature-only ELF binaries** | **All seven pinned source owners matched** | **Four ELF importers** | **8 branches in three binaries** |

The original `crashreporter` `dlopen` import with **zero selected named direct calls** is not a contradiction: the original stripped-ELF GOT/indirect loader analysis separately identified an indirect `dlopen` branch. This bounded census only counts selected import and named-direct branch patterns, not all direct/indirect calls. All seven source-owner manifests, per-file original direct `DT_NEEDED` counts and independent Ubuntu/Arch native loader provider lists were checked against the compiled evidence.

### Next meaningful runtime acceptance

The main untested compiled loader paths include the one **real direct `dlopen` branch in original `libonnxruntime.so`** and the six in the original `pingsender` ELF; the current combined observation does **not** establish whether those exact calls execute in a targeted workload, their runtime library argument values, fallback behavior or actual library success/failure. A source-pinned, isolated opt-in feature-specific test of one such path would extend runtime evidence further than repeating the original graphical startup.

Preserve security-critical crash reporting, update, DRM and account/network behaviors. A compiled loader import is not a statement of necessity, and absence from a startup trace is not dead-code evidence. The current tests did **not** execute a new original binary, recompile a browser, alter a real Firefox installation or profile, authorize source deletion, or report any new byte savings.

**M3 sixth gate remains OPEN: 5/6 = 83%. Vulpra overall = 61%. Session Δ +0 percentage points.**
