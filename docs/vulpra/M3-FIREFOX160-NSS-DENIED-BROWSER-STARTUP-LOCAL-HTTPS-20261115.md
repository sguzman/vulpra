# Firefox 160: actual browser startup and local HTTPS with softoken / FreeBL unavailable

**Date:** 2026-11-15. **Result:** Source-authenticated, **real original Firefox 160 browser/WebDriver** failure observations for opt-in NSS provider denials; independent falsification **16/16** passed. **Not** successful cryptographic fallback, comprehensive TLS certification, permission to prune original NSS libraries or full M3 dependency-gate closure.

## Exact original source, package and independent controls

The successful [real original Firefox 160 browser startup and loopback HTTPS run **43761905154**](https://github.com/sguzman/vulpra/actions/runs/43761905154) reused precisely the original compiled Firefox160 Vulpra native browser package preserved by [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827), originally built by [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940):

- Official Mozilla Firefox 160 source commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`.
- Complete assembled Vulpra candidate with 28 authenticated source overlays: tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Identical preserved original compiled archive SHA-256: `530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`.
- Original Firefox160 native producer commit `0624235fdc956ab18af3c3f310b3588ca72fff61`.
- Six NSS loader/manifest Git blobs in the real-browser CI authenticated against official Mozilla source, plus previous [ten-blob NSS/FFVPX ownership proof 43745057569](https://github.com/sguzman/vulpra/actions/runs/43745057569) showing **no overlap** with Vulpra's 28 source overlays.
- Independent original packaged NSS API failure/guard verifier [43760419551](https://github.com/sguzman/vulpra/actions/runs/43760419551) had established actual `NSS_NoDB_Init`, `PK11_GenerateRandom`, `NSS_Shutdown`, original `libnss3.so` symbols and actual mapped `libsoftokn3.so` / `libfreeblpriv3.so` behavior. That prior result is independently included in the new reconciliation.

No browser rebuild, system NSS removal/replacement, installed extension/profile modification, workstation access, PR merge or native source pruning occurred.

## Actual packaged browser WebDriver test

A new [standard-library Python WebDriver probe](../../ci/m3-firefox160-browser-nss-local-tls-replay.py) launched the **native archived Firefox ELF executable** through SHA-256-verified GeckoDriver `v0.37.1` in four separate disposable CI sessions: baseline, `nss_softoken`, `nss_freebl`, and `nss_both`. The exact library-denial [C interposer](../../ci/m3-deny-optional-native-providers.c) used `LD_PRELOAD` only in the opted-in modes, targeting native `dlopen`/`dlmopen` requests from the real Firefox process to the exact allowlisted provider names. The real browser-process **attachment witness** was required as well as actual denied-load count.

Every mode received its own temporary `HOME`, WebDriver profile and `profiles.ini` sentinel. Only ephemeral `127.0.0.1` HTTP and HTTPS servers were used. The HTTPS server presented a freshly generated, deliberately **self-signed, untrusted** localhost test certificate. Its health was checked outside Firefox, the default system TLS client independently **rejected** the certificate, and WebDriver capabilities requested `acceptInsecureCerts=false`. No certificate trust was installed, no browser certificate override was configured, and no external site or user credential was contacted.

The baseline was required to create a real Firefox WebDriver session, navigate local HTTP, execute JavaScript and receive a strict **`insecure certificate` WebDriver error** on self-signed HTTPS. The denied modes were *not required to survive*: the harness categorizes session failure, successful session with normal local navigation, local certificate failure, or timeouts separately. Actual native denial logs and GeckoDriver logs/PIDs/pathnames were never exported; only predefined counts, fixed WebDriver error classes and booleans were retained. Temporary original-profile sentinels were byte-verified unchanged.

### Verified real browser results

| Observed original Firefox 160 state | Baseline | Softoken denied | FreeBL denied | Both names targeted |
| --- | --- | --- | --- | --- |
| GeckoDriver ready to receive requests | **Yes** | **Yes** | **Yes** | **Yes** |
| Native `libsoftokn3.so` loads actually denied | 0 | **2** | 0 | **2** |
| Native `libfreeblpriv3.so` loads actually denied | 0 | 0 | **3** | **0** |
| Interposer actually attached to real browser process | Not enabled | **2 attachment witnesses** | **2** | **2** |
| Firefox WebDriver session created | **Yes** | **No** | **No** | **No** |
| WebDriver startup result | `session_created` | `session not created` | `session not created` | `session not created` |
| Actual localhost HTTP document navigation and JavaScript | **Pass** | Not reached | Not reached | Not reached |
| Local self-signed HTTPS certificate handling | **Strictly rejected as insecure** | Not reached | Not reached | Not reached |
| Disposable profile sentinel unchanged | **Yes** | **Yes** | **Yes** | **Yes** |

**Interpretation:** GeckoDriver itself started in every mode, but the browser did **not** establish a usable WebDriver session under either individually denied NSS cryptographic provider. This corroborates the earlier actual packaged NSS C API result: both providers are necessary for successful NSS initialization in the tested configuration. It is deliberately more precise than claiming the full Firefox process never launched—the observable failure is **session creation rejected**, with genuine provider-load denial evidence.

The combined `nss_both` allowlist does **not** imply that both libraries were requested: **two softoken loads were denied, but there was no FreeBL load request** after softoken failure. Neither the native API test nor the browser test fabricates a FreeBL denial in that mode.

**Crucial HTTPS boundary:** No NSS-denied browser achieved a WebDriver session, so the test did **not** establish any HTTPS handshake, successful or unsuccessful, in those denied browser modes. In the baseline, it specifically established proper rejection of an **untrusted self-signed** local certificate, **not a successful trusted TLS handshake** or general TLS security compliance.

Original bounded native-browser artifact: `firefox160-original-nss-denied-browser-local-https-no-full-TLS-closure`, ID **14180491829**. The exact ZIP was downloaded and inspected to verify all four session outcomes, native counts, error categories, unchanged private profile sentinels and explicit false completion claims.

### Independent native-NSS/source/browser reconciliation

[Independent evidence-only CI **43762347874 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43762347874) authenticated by full exact commit SHA, branch, workflow name, conclusion and non-expired artifact:

1. [Original source-attested NSS C API failure crosswalk 43760419551](https://github.com/sguzman/vulpra/actions/runs/43760419551), artifact **14179499567**: exact original source/packaged NSS baseline, provider ownership, actual 2 softoken and 3 FreeBL isolated native API denials, combined 2 softoken / zero FreeBL denials, and guarded C API initialization failure.
2. [Actual archived Firefox 160 browser startup/local HTTPS replay 43761905154](https://github.com/sguzman/vulpra/actions/runs/43761905154), artifact **14180491829**: exact same original native archive, strict local certificate rejection in baseline, native real browser-process NSS denial, all three denied WebDriver sessions rejected, all disposable profiles preserved.

The strict [independent jq verifier](../../ci/m3-firefox160-nss-browser-local-https-source-crosswalk.jq) requires exact archive/source IDs and all observed failure-specific counts and conditions. **All 16/16 forged source, checksum, baseline initialization, NSS denied-load, strict HTTPS error, WebDriver session, untouched-profile and false-security/completion records were rejected.**

Its final accepted bounded artifact, `firefox160-source-attested-real-nss-browser-startup-https-failures-not-full-TLS`, **ID 14181176310**, was downloaded and inspected. The first attempted browser CI [43761751575](https://github.com/sguzman/vulpra/actions/runs/43761751575) failed **before opening Firefox** because the new Python fixture shadowed its `http` module variable; this was corrected in `ed213726d`. Only [the successful 43761905154 replay](https://github.com/sguzman/vulpra/actions/runs/43761905154) is used as native browser evidence.

## What remains open

NSS FreeBL and softoken **cannot safely be removed** based on these observations: losing either prevented native NSS initialization **and** real browser WebDriver session creation in this controlled environment. Neither a working alternative crypto provider nor a graceful user-visible browser fallback has been established.

This test does **not** validate a completed trusted-origin TLS handshake, every PKCS#11/FIPS/provider configuration, real network/HTTPS behavior, Safe Browsing, Gecko security sandbox and updater behavior, actual EndeavourOS/Hyprland NVIDIA/iGPU user hardware, individual disassembled direct `dlopen` or `dlsym` callsites, or complete generated/C++/Rust FFI dependency closure. It confers no source-pruning, release or merge permission.

**Project status unchanged:** M3 sixth native dependency/FFI/conditional-feature gate **OPEN**, **5/6 = 83%**; Vulpra overall **61%**, this session **Δ +0 percentage points**; [draft PR #6](https://github.com/sguzman/vulpra/pull/6) remains open and unmerged. A useful next *distinct* security experiment is trusted, pinned local TLS negotiation with a temporary test-only CA/profile in baseline, or controlled PKCS#11/FIPS coverage, preserving strict no-user-profile/no-system-certificate changes.
