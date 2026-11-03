# M3 — Genuine browser-owned original pingsender resolves real libcurl and all 14 source APIs (2026-11-03)

## Accepted native observation

**Source-pinned original native CI [41739731454 PASS](https://github.com/sguzman/vulpra/actions/runs/41739731454)**, job **126277925092**. Sanitized artifact **13280597614**, `m3-original-browser-pingsender-libcurl-no-egress`, independently downloaded and inspected: a single **2,109-byte JSON** report (ZIP **953 bytes**). Original unchanged source SHA **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**; original fully compiled normal package archive SHA-256 **`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**. The original packaged `vulpra` and `pingsender` ELF files were verified before and after by SHA-256, and the entire installation was mounted read-only.

**Observed in the same authentic source-pinned execution chain:** a running original compiled Vulpra browser launched its **original packaged `pingsender` executable** using the source-defined `TelemetrySend.testRunPingSender` method and original `nsIProcess.runAsync`. A CI-only Rust observer loaded into the *real original child executable* first authenticated its `/proc/self/exe`, exact three kernel-visible arguments (executable, synthetic localhost URL, synthetic temporary JSON file) and original compiled browser parent. Within that child, its original compiled source then invoked **`dlopen`** on one of its six Linux source-defined `libcurl` sonames; glibc returned a **non-null native library handle**. The original compiled `CurlWrapper::Init` next invoked **all 14 source-defined `dlsym` calls** on that *same handle*, with **non-null returned function pointers for all fourteen**.

This substantially extends [the previously accepted real browser-owned original pingsender ELF test](M3-ORIGINAL-BROWSER-PINGSENDER-REAL-ELF-NO-EGRESS-20261103.md), which established the process launch but not this in-child conditional loader and native ABI symbol-resolution path.

## Source-defined loader and exact symbol coverage

The original `toolkit/components/telemetry/pingsender/pingsender_unix_common.cpp` contains `CurlWrapper::Init`. Its Linux `libcurl` candidates are, in order: `libcurl.so`, `libcurl.so.4`, `libcurl-gnutls.so`, `libcurl-gnutls.so.4`, `libcurl.so.3`, `libcurl-gnutls.so.3`. Source asks for `dlopen(libname, RTLD_NOW)` until successful. The CI observer forwards the actual `dlopen` call to real glibc, and only records a non-null handle if the requested soname is in that exact original-source set. It does **not** manufacture a library or return dummy function pointers.

The **nine required native function symbols**, all source-defined and verified non-null by real glibc `dlsym`, were:

`curl_easy_init`, `curl_easy_setopt`, `curl_easy_perform`, `curl_easy_getinfo`, `curl_slist_append`, `curl_slist_free_all`, `curl_easy_strerror`, `curl_easy_cleanup`, and `curl_global_cleanup`.

The **five optional URL helper symbols**, also observed as non-null under this particular Arch libcurl runtime, were:

`curl_url`, `curl_url_set`, `curl_url_get`, `curl_free`, `curl_url_cleanup`.

The code makes the important distinction that the optional helpers may be unavailable on other host libcurl versions, with a fallback URL parser. This test **does not** establish the fallback path on an older library. Resolving `curl_easy_perform` as a non-null pointer is **not evidence of a successful HTTP request**, and the report explicitly states that even invocation of `curl_easy_perform` is not independently established by this observer.

## Why the evidence identifies the real process

- The browser launched unchanged `/original/vulpra` directly in a disposable Arch Linux + private Weston/Wayland container, with temporary HOME/profile. A local WebDriver client attached to the already-running browser. Original `TelemetrySend.sys.mjs` called `nsIProcess.runAsync` on the true packaged `pingsender`.
- A **test-only Rust `LD_PRELOAD` library**, `ci/m3-original-browser-pingsender-libcurl-dlsym.rs`, is inherited by the subprocess. Its ELF initializer marks itself eligible **only if** the exact original `/original/pingsender` executable is running, has original `/original/vulpra` as parent, and carries only the source-fixed localhost/payload arguments.
- Its `dlopen` and `dlsym` interposers forward to glibc through `dlvsym` (using glibc `GLIBC_2.34` symbol version), rather than simulating success. They track one genuine successful `libcurl` handle and a fixed 14-symbol bitset; a sanitized witness is emitted *only after* all 14 original `dlsym` calls on that same handle returned non-null.
- The actual browser remains responsive after the synthetic child run, the synthetic input file remains present, and the original packaged browser/pingsender ELF checksums still match.
- Four Rust tests passed, including original argument shape, the exact six permitted loader candidate names, unique 14-symbol set, and bounded report claims. **13/13 deliberately forged JSON evidence mutations** were rejected, covering source/archive provenance, parent ELF identity, missing native loader proof, the 14-symbol count, inaccurate claims of successful telemetry/complete graph closure and invented pruning authority.

The original source/build itself is **not edited or recompiled**; only this separate CI instrument is compiled. The tracing is instrumented behavior, **not** an uninstrumented production call-stack trace.

## Privacy, limitations and remaining gate

Network isolation was strict: Docker `--network none`, a private loopback only for local WebDriver and no listener on the fixed localhost:9 destination. The synthetic JSON file contained only static test data; no real telemetry ping, private user data, credentials, host devices, or existing profile were supplied. The actual browser-side `datareporting.healthreport.uploadEnabled` was observed **false** before invoking the test-only sender. Independently, `toolkit.telemetry.enabled` remained **true** in this build even when the isolated test profile attempted to set it false; this is a separate *collection* preference, not proof of upload permission. The test never claims all telemetry collection is disabled.

**Established:** the source-defined original browser-owned process truly loads the original `pingsender` ELF, which itself calls genuine `dlopen` to load a real host `libcurl` handle and resolves all **9 required + 5 optional** source-defined function pointers using original `dlsym` calls, in one no-egress test.

**Not established:** actual successful upload, network HTTP request, normal user policy or shutdown dispatch, full execution of all fourteen native functions, fallback behavior without the five optional helpers, every possible host libcurl implementation, all indirect/transitive loader or FFI paths, current target workstation/hardware parity, complete source/build/feature dependency mapping, or permission to delete original source. The exact host libcurl soname selected and provider ELF SHA were not recorded in this bounded witness; it shows a match to the pinned candidate set rather than inventing a specific provider identity.

Earlier original browser-owned `pingsender` CI **41738630382** had already proven the ELF execution but not the lazy loader ABI path. This dedicated original compiled native CI **41739731454** passed, its sanitized artifact was independently inspected, and the workflow was returned to **manual-only `workflow_dispatch`** afterward. **M3 remains 5/6=83%, Vulpra overall 61%, session Δ+0 percentage points**. No source removed, no native binary bytes saved.
