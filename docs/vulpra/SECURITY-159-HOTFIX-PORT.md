# Vulpra 159 post-beta security source port (separate, unaccepted branch)

## Scope
This **isolated maintenance branch** transplants the exact Mozilla upstream fix-result content of two confirmed missing source patches onto the original Vulpra main commit `b100f0ba13b62021544bc5cf5a9a75b810447427`:
- CVE-2026-117860 / Bug 2046558, 14 existing code files, upstream fix `9a2dc53c369c7ae5172018b35988e1d2ffeff402` (Firefox 159).
- CVE-2026-120572 / Bug 2079035, three existing code files plus the original upstream regression crashtest, fix `603a78af8401f8f30c388b3fa330589e35d8b727` (Firefox 159.0.1).

All **17 existing Vulpra source files matched the respective upstream fix's parent-commit Git blob exactly** before this port. Each replacement file was fetched from the upstream fix-result commit and its Git blob ID independently checked against the archived 159 beta-to-fixed SHA crosswalk.

The [machine-readable port manifest](SECURITY-159-HOTFIX-PORT.json) records every preimage, expected postimage, source commit and fixture blob. [CI source-integrity preflight](../../ci/security-159-postbeta-port-check.sh) checks those actual blobs without downloading a browser or making runtime claims.

## Security limits and acceptance blockers
This is **source integration, not accepted remediation**. It has not been compiled as a patched full browser, and the upstream crashtest has not run in that browser. No claim is made about native link compatibility, Firefox 159.0.1 completeness, other advisory issues, browser-level exploit rejection, sandbox, certificates, all target-platform dependencies or release readiness. The main M3 comparison remains frozen and unmodified.

Before considering integration into the main browser or ordinary/sensitive/public use:
1. Audit outstanding upstream advisory fixes and prefer a comprehensive maintained upstream baseline rather than treating these two transplanted fixes as sufficient.
2. Compile a **separate** source-pinned full normal Vulpra from this maintenance branch; run the upstream regression and security-specific tests.
3. Independently verify real packaged-browser Wayland, JavaScript navigation, WebExtensions, Nimbus, profile isolation, strict certificate rejection, and protected-feature regressions.
4. Verify source/package hashes, target EndeavourOS/Hyprland ABI and performance, and release documentation. Only then consider merging or replacing the frozen-M3 experimental build.

**Progress remains overall 61%, M3 5/6 gates (83%).** No test or milestone credit is assigned to source transplant alone.

## Native build and strict certificate-test result (2026-11-04 UTC)

[Native run 41869946133](https://github.com/sguzman/vulpra/actions/runs/41869946133) **compiled the actual isolated patched browser**, packaged it, independently checked ELF/source/package linkage, launched an isolated Wayland/Weston browser, rendered a localhost screenshot, and executed WebDriver JavaScript navigation through the final DOM. The smoke stopped on the **test harness's overly strict requirement that the WebDriver insecure-certificate error have a nonempty message**. The actual response was **HTTP 400, error `insecure certificate`, message `""`**, which demonstrates certificate rejection, but the total CI result was **failure** and later WebExtension/Nimbus acceptance was not reached.

The unmodified Vulpra browser baseline's [native run 41879471492](https://github.com/sguzman/vulpra/actions/runs/41879471492) subsequently **passed** the corrected WebDriver W3C parser and complete normal runtime checks, with independent [evidence reconciliation 41894896825](https://github.com/sguzman/vulpra/actions/runs/41894896825) **passed**. This maintenance branch now imports **the same, already CI-verified parser**: exact HTTP 400, `value.error == "insecure certificate"`, and a present (possibly empty) string message, retaining `acceptInsecureCerts=false`, the untrusted local fixture and private test profile. The upstream security-patch code blobs remain unchanged.

**The security-patched branch still requires its own complete native packaged-browser smoke to pass on the corrected harness.** Full upstream security maintenance, upstream crashtest execution, and release readiness remain open. M3/overall percentage unchanged.


## Host runner capacity failure and bounded swap allocation (2026-11-04 UTC)

[**Security native run 41908949996**](https://github.com/sguzman/vulpra/actions/runs/41908949996) **failed at the pre-build disk-capacity guard** after successful source-integrity self-checks, independent linked-loader examiner compilation and tests, and full configure substitution capture. The original workflow asserted `/mnt` had **strictly more than 24 GiB + 8 GiB free** without logging its measured capacity; the assertion failed. The actual browser compilation did **not** begin. No security-code or WebDriver problem was observed in this run.

The security-branch-only native workflow now calculates actual `/mnt` available bytes, reserves an **8 GiB minimum compilation/output headroom**, and allocates the remaining available whole-GiB swap bounded to **8–24 GiB**, logging the allocation and activated swap. If even the minimum requirement is unavailable, or allocation/activation fails, the CI still **fails closed** rather than attempting a nominal success without memory protection. This does **not** change Mozilla source code, the frozen main M3 comparator, target user's machine, package options, or the strict TLS WebDriver requirement. It enables genuine native acceptance on hosted runners with modestly smaller scratch disks, with no claim of guaranteed build completion or equivalent memory performance.

A dedicated [source+runtime reconciliation workflow](../../.github/workflows/security-159-hotfix-evidence-reconcile.yml) is now installed on default `main` and listens for successful native security-branch builds. It independently checks all **17 exact patched-source postimage hashes**, the original regression fixture, immutable manifest, and real source-bound package/TLS/runtime reports. Its fixtures and workflow lint ran successfully on the initial main-source push, but it has **not** yet accepted a successful patched native browser build. All security/release milestones remain open.
