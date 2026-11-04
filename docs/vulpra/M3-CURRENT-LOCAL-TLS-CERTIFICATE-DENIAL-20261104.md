# M3 — Current native Vulpra self-signed local TLS rejection (2026-11-04 UTC)

## Purpose

The [18-feature protected acceptance matrix](M3-PROTECTED-FEATURE-ACTIVATION-MATRIX-20261104.md) identifies certificate failure behavior as unverified on the actual newly compiled browser. The existing [packaged local WebDriver / WebExtension smoke](../../ci/smoke-webextension-package-local.py) has now been extended in the **existing Python CI module**, retaining its original JavaScript, extension, Nimbus and disposable-profile tests.

The new check generates a **one-day ephemeral self-signed localhost certificate** with OpenSSL and serves a known HTML page on a private loopback HTTPS listener. The test client first proves that the fixture serves the page using a **test-only unverified context outside the browser**, then proves the ordinary system TLS client rejects that same certificate chain. The actual source-built, checksum-staged Vulpra browser runs with a disposable HOME and a separate geckodriver profile; the WebDriver `acceptInsecureCerts=false` capability must be confirmed from the session response. Navigating that same self-signed TLS origin **must fail** with a W3C HTTP-error result whose JSON `value.error` is exactly `insecure certificate` and whose message is nonempty. Any success, timeout, transport error, unrelated WebDriver error or malformed JSON fails the test.

The temporary certificate and key never enter a browser trust store or the repository. No security preference is relaxed; no real account, network destination, installed Firefox Developer Edition profile or browser binary is intentionally modified. The local fixture client deliberately bypasses trust **only** to establish the server is functioning; the WebDriver browser may **not** bypass it.

## Testable verification and boundaries

The new `--self-test-cert-parser` command runs **16 malformed/error-status fixtures** with no geckodriver or browser. It is separately checked by [the lightweight fixture workflow](../../.github/workflows/m3-current-certificate-denial-fixtures.yml); successful parser fixtures do not prove real certificate rejection. The **full source-matched normal native workflow** must also execute the newly extended packaged WebDriver smoke and preserve its bounded nested `security.local_untrusted_tls_denial` report alongside the original seven native evidence files. The existing successful native-build reports predate this code and do not count.

**Not tested by this subtask:** real Safe Browsing blocklists/updates, certificate revocation, forged certificate pinning, CA store/system trust modification, active MITM, OCSP, arbitrary public HTTPS servers, child process sandbox denial, absence of background egress, all error paths, real target EndeavourOS/Hyprland GPU/ABI parity, or source-removal safety. This is one real, isolated native security **negative path**, not the M3 sixth-gate closure.

**At authoring:** fixture verifier and real post-build native browser test are pending fresh CI acceptance. **Overall 61%, M3 5/6=83%, Δ+0 pp.**
