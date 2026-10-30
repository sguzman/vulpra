# M3 — Source-pinned newer full-native telemetry startup and opt-out protection

**Accepted actual full-native browser CI:** [41078909794](https://github.com/sguzman/vulpra/actions/runs/41078909794)
**PASS**, artifact **12988478342**.
[Workflow lint 41078909616](https://github.com/sguzman/vulpra/actions/runs/41078909616)
**PASS**. A second independent local-only diagnostic,
[41078951212](https://github.com/sguzman/vulpra/actions/runs/41078951212)
also **PASSED** (artifact **12987319790**). The duplicate workflow was
subsequently retired in [5198e17](https://github.com/sguzman/vulpra/commit/5198e170e3badbe65f4d03fbfae4ef0f2503e39d);
the retained source-pinned runner is
[`m3-newer-full-telemetry-native.yml`](../../.github/workflows/m3-newer-full-telemetry-native.yml).

## Verified native source and package

The package was **actually compiled from**
`b1482404dfb8b01342990ee99ea3df0f9756b5f7` in
[full-normal build 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527).
Both compilation and original packaging passed. The original native
`tar.xz` is **87,154,544 bytes**, SHA-256
`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.
The replay verifies its original checksum sidecar, source commit,
manifest, normal full-Normandy identity and physical New Tab
preservation before starting the browser.

The read-only test harness was checked out at this **exact compiled
source**, and six critical telemetry/controller/policy/transport Git
blobs were verified against the pinned SHA. An isolated temporary
`HOME`, Vulpra-only profile, `MOZ_DISABLE_NONLOCAL_CONNECTIONS=1`,
loopback-only HTTP receiver and pinned geckodriver prevented
access to personal browser profiles. Receiver request bodies, URLs,
ping IDs and telemetry payloads were not saved.

## Natural startup (without telemetry test initialization)

In a fresh normal startup session, `TelemetryController.testSetup()`
and the test sender override were **not** called.

| Time since normal startup | Sender ready |
| --- | --- |
| 0 seconds | No |
| 30 seconds | No |
| 75 seconds | **Yes** |

The sender resolved to the local receiver once initialized.
This is an observation of the deferred sender lifecycle, not a
production ping submission.

## Deliberately initialized local test session

The **separate** controlled test session used the browser's own
`TelemetryController.testSetup()` and explicit test endpoint.
Its locally observed request-type counts were:

| Local receiver request kind | Before FHR upload opt-out | After |
| --- | ---: | ---: |
| Synthetic ordinary `vulpra-probe` | 1 | **1** |
| Deletion-request | 0 | **1** |
| Other | 0 | 0 |

The user upload preference disabled ordinary submission; the
explicit deletion-request exception remained eligible. The
observer was fired, the master data-reporting policy switch
independently disabled eligibility, and the local receiver
reported **0 oversize**, **0 bad-framing** and **0 truncated**
requests. These were real packaged-browser policy methods and local
HTTP test requests, **not live production telemetry**.

## Scope and non-claims

1. No proof of public Mozilla telemetry server submission or server-side
   erasure of a user's data. The preserved deletion-request exception
   is a safety obligation, not a component safe to delete.
2. Test-mode `TelemetryController.testSetup()` is **not** normal
   production upload behavior. The natural-startup observation was
   intentionally conducted in a separate session.
3. Exact compiled source is `b1482404`, not every later commit on
   `main`. Six critical blob guards do not cover every transitive
   network/telemetry consumer.
4. No user profiles, credentials, identifying ping bodies, or
   remote recommendation/account services were involved.
5. No telemetry source or security module was removed; no compressed
   binary savings were measured. A future opt-in sender omission would
   require a much broader lifecycle, policy, crash, Glean and
   deletion-request acceptance suite.

**M3 remains 2/6 gates (33%), overall Vulpra 44%, Δ0 pp.**
