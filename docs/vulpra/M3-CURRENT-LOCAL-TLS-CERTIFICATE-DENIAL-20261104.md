# M3 — Current native Vulpra self-signed local TLS rejection (2026-11-04 UTC)

## Purpose

The [18-feature protected acceptance matrix](M3-PROTECTED-FEATURE-ACTIVATION-MATRIX-20261104.md) identifies certificate failure behavior as unverified on the actual newly compiled browser. The existing [packaged local WebDriver / WebExtension smoke](../../ci/smoke-webextension-package-local.py) has now been extended in the **existing Python CI module**, retaining its original JavaScript, extension, Nimbus and disposable-profile tests.

The new check generates a **one-day ephemeral self-signed localhost certificate** with OpenSSL and serves a known HTML page on a private loopback HTTPS listener. The test client first proves that the fixture serves the page using a **test-only unverified context outside the browser**, then proves the ordinary system TLS client rejects that same certificate chain. The actual source-built, checksum-staged Vulpra browser runs with a disposable HOME and a separate geckodriver profile; the WebDriver `acceptInsecureCerts=false` capability must be confirmed from the session response. Navigating that same self-signed TLS origin **must fail** with a W3C HTTP-error result whose JSON `value.error` is exactly `insecure certificate` and whose message is nonempty. Any success, timeout, transport error, unrelated WebDriver error or malformed JSON fails the test.

The temporary certificate and key never enter a browser trust store or the repository. No security preference is relaxed; no real account, network destination, installed Firefox Developer Edition profile or browser binary is intentionally modified. The local fixture client deliberately bypasses trust **only** to establish the server is functioning; the WebDriver browser may **not** bypass it.

## Testable verification and boundaries

The new `--self-test-cert-parser` command runs **16 malformed/error-status fixtures** with no geckodriver or browser. It is separately checked by [the lightweight fixture workflow](../../.github/workflows/m3-current-certificate-denial-fixtures.yml); successful parser fixtures do not prove real certificate rejection. The **full source-matched normal native workflow** must also execute the newly extended packaged WebDriver smoke and preserve its bounded nested `security.local_untrusted_tls_denial` report alongside the original seven native evidence files. The existing successful native-build reports predate this code and do not count.

**Not tested by this subtask:** real Safe Browsing blocklists/updates, certificate revocation, forged certificate pinning, CA store/system trust modification, active MITM, OCSP, arbitrary public HTTPS servers, child process sandbox denial, absence of background egress, all error paths, real target EndeavourOS/Hyprland GPU/ABI parity, or source-removal safety. This is one real, isolated native security **negative path**, not the M3 sixth-gate closure.

**At authoring:** fixture verifier and real post-build native browser test are pending fresh CI acceptance. **Overall 61%, M3 5/6=83%, Δ+0 pp.**

## Independent linked-package and WebDriver certificate evidence (new verification stage)

A second [read-only cross-report jq validator](../../ci/m3-current-local-tls-native-evidence.jq) requires **trusted, externally verified run ID and compiled source commit SHA** plus the real downloaded `m3-native-link-inputs.json`, `m3-localhost-acceptance.json` and `webextension-smoke-*.json`. It binds the native link report to the compressed archive SHA in the localhost screenshot report, and validates the original WebDriver/extension/Nimbus/profile evidence before accepting the **exact nested TLS-denial record**. The verifier explicitly rejects fabricated Safe Browsing, process-sandbox, absence-of-network-egress, source-pruning, full linker and workstation claims.

The [independent metadata-only shell fixture suite](../../ci/tests/m3-current-local-tls-native-evidence-tests.sh) has **26 deliberately forged report mutations**, including mismatched run/source/archive, missing or falsified TLS evidence, enabled certificate bypass, incorrect errors, missing real runtime checks and unsupported broad safety assertions. Its [lightweight GitHub Actions workflow](../../.github/workflows/m3-current-local-tls-native-evidence-fixtures.yml) does **not** download or execute Vulpra. It must pass separately, then the same jq verifier must be run on the actual source-pinned native artifact when that native build completes; synthetic fixtures never stand in for browser runtime.

The actual full-native workflow run [41853893418](https://github.com/sguzman/vulpra/actions/runs/41853893418) is currently being evaluated. Until its source-bound packaged-browser security report is verified, neither a genuine browser TLS-denial success nor a new completed M3 acceptance test is claimed. **M3 5/6=83%, overall 61%, Δ+0 pp.**

## Independent fixture CI accepted (2026-11-04 UTC)

[**Cross-report fixture run 41857184152 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41857184152) executed the checked-in jq verifier and the 26 deliberate metadata mutations without compiling or starting Firefox. The job log explicitly confirmed **26/26 forged cross-report claims rejected**. [**Workflow lint 41857184260 SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/41857184260) accepted the new lightweight workflow.

**Important distinction:** the standalone verifier *code and its metadata-only fixtures* are now accepted. Its test inputs were synthetic and did **not** authenticate a real browser TLS-denial response. Full-current native run [41853893418](https://github.com/sguzman/vulpra/actions/runs/41853893418) is still compiling; the genuine packaged-browser certificate result, independently downloaded ZIP integrity and three actual report join remain **pending**. The earlier accepted native runs predate this test. No new M3 gate credit; **overall 61%, M3 83% (5/6), Δ+0 pp**.
