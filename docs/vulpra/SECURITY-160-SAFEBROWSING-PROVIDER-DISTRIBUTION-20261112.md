# Firefox 160 Safe Browsing provider and credential distribution review

**Status (2026-11-12): BLOCKED — provider authorization, working credential, native proof and release permission not established.** This is engineering and policy triage, not legal authorization.

## What the native evidence says

- The exact-source Firefox 160 Vulpra archive passed the corrected real-browser effective phishing/malware/download preference, URL-classifier-service and table-registration checks after opting out of WebDriver's security-disabling recommended defaults (`remote.prefs.recommended=false`).
- The same browser **failed** `SafeBrowsing.checkGoogleSafeBrowsingKey('google5')`, and lacked effective v5 HTTPS list-update and hash-lookup URLs. [Failed-but-informative CI 43249363996](https://github.com/sguzman/vulpra/actions/runs/43249363996). Its non-secret diagnostic evidence is not provider-backed protection evidence.
- The build mozconfig `ci/mozconfig-linux` currently omits `--with-google-safebrowsing-api-keyfile`. The official Mozilla optimized mozconfig uses private Mozilla build material; Vulpra may not assume rights to those keys.

## Provider selection and applicable obligations

Firefox 160 has an existing Google Safe Browsing v5 integration. Reuse of that mechanism is a *technical candidate*, **not yet an authorized provider decision**.

- [Google Safe Browsing terms](https://developers.google.com/safe-browsing/terms): absent a separate agreement, Safe Browsing API use is **non-commercial only**; protected-user warnings require prescribed attribution/limitations; listed URLs require sufficiently fresh provider information. Confirm the actual app presentation and service terms before any deployment.
- [Google Safe Browsing usage guidance](https://developers.google.com/safe-browsing/reference/Appropriate.Usage): describes quota and non-commercial-use limits. [API v5 reference](https://developers.google.com/safe-browsing/reference) explains local list and remote lookup modes.
- [Google APIs Terms](https://developers.google.com/terms/): prohibit embedding developer credentials in an **open-source project**, require legitimate client credentials and impose other distribution/privacy obligations. A private CI secret protects repository/log handling, but **does not make an API key unrecoverable from a publicly distributed browser binary**. Distribution scope, client credential model, possible additional agreement, branding/attribution and provider permission need separate review.
- Google's commercial Web Risk offering is **not assumed to be a drop-in replacement** for the existing Firefox classifier. Any alternate provider needs an independently designed, tested integration and privacy/security review.
- Do not copy Mozilla, Arch or other browser/vendor credentials, commit literal keys, use dummy keys to bypass the runtime check, disable the classifier gate, or claim a completed security audit based on preferences alone.

## Implemented bounded build preparation — not activated in the browser

- `ci/security-160-safebrowsing-keyfile-stage.sh` accepts an already-provisioned, private, one-line provider keyfile via `VULPRA_SAFEBROWSING_KEY_SOURCE`; it requires `RUNNER_TEMP` and `GITHUB_WORKSPACE`, owner-only keyfile permissions, file-location and content-shape checks and a fresh destination directly inside the runner temporary directory. It copies the key with restrictive permissions and creates an ephemeral mozconfig pointing to it; it never prints key bytes.
- The script is **not called by the native build workflow**. There is deliberately no actual key or build-secret provisioning. Its shape/permissions checks cannot establish ownership, Google's authorization, key validity, safe binary distribution or effective threat-list protection.
- **2026-11-18 hardening:** The staging helper now additionally refuses to operate unless both `VULPRA_SAFEBROWSING_PROVIDER_USE_REVIEWED=1` and `VULPRA_SAFEBROWSING_BINARY_DISTRIBUTION_REVIEWED=1` are explicitly supplied by the person running a candidate build. They are **only deliberate operator attestations, never proof** that a provider approved Vulpra, that the distribution agreement permits embedded credentials, or that keys stay confidential in shipped binaries. No CI/release build sets those variables.
- The helper additionally requires a keyfile owned by the runner user with link count exactly one, rejects missing environment variables with a controlled error, and never prints key bytes. `ci/tests/security-160-safebrowsing-keyfile-stage-tests.sh` uses a **synthetic, nonfunctional fixture** and now rejects fourteen negative cases including absent/nonaffirmative review flags and hardlinked key material. Earlier nine-case evidence remains historical. This does not add threat intelligence or establish provider suitability.
- [Original lightweight contract CI 43251497812 PASS](https://github.com/sguzman/vulpra/actions/runs/43251497812) tested the earlier nine-case contract; [expanded fourteen-case CI 44344915660 PASS](https://github.com/sguzman/vulpra/actions/runs/44344915660), including missing/false operator reviews, source hardlinks, original keyfile safety negatives. No Firefox compilation or Google contact, and no installed browser, profile, `main` or existing native build workflow changes.

## Responsibility boundary: phishing protection is not identity management

The inherited Gecko Safe Browsing classifier is a **separate, narrowly scoped security consumer** of phishing/malware/download threat data. It does **not** justify browser-owned logins, password vaults, Mozilla/Google accounts or Firefox Sync, and should never introduce such dependencies. Credential autofill and sync are orthogonal integration choices (e.g., an external password-manager extension with a user-selected server), not a requirement of any threat-list provider.

For potential provider-backed operation, review **exact outbound disclosure** in URL-list updates, prefix/hash confirmation, executable-download metadata/reputation requests, failure behavior, provider telemetry and required warning attribution. Any local/self-hosted provider is an implementation proposal only until data provenance, update cadence, safe URL matching and coverage are independently evaluated; merely proxying or caching a third-party feed may still be subject to provider terms. Do not disable Gecko threat detection as a shortcut to meeting independence goals.

## Remaining acceptance order

1. **Provider and distribution authorization**: select an eligible provider, confirm license/terms, key ownership, attribution/privacy disclosures, expected usage quotas, whether a distributable embedded client credential is permitted, and any agreement required.
2. **Secure CI provisioning and release hardening**: in a separately authorized native build, obtain controlled provider key material through restricted CI secrets, generate ephemeral files and an isolated mozconfig with the staging helper, and prevent key values from appearing in logs/source/uploaded artifacts; account explicitly for possible extractability from the *distributed binary*.
3. **Native runtime configuration**: rebuild a new candidate only with approval, then re-run the existing read-only classifier readiness gate against the *new*, source-provenance-pinned package, without WebDriver disabling production protections.
4. **Provider-backed behavior**: prove actual list freshness/update/classification, controlled provider-sanctioned test warning, download protection and regression handling without sending real malicious URLs.
5. **Release review**: finish Mozilla advisory coverage, sandbox/egress and profile-safety checks, disclosure/attribution, QA and package/update strategy; only then reconsider PR #6's draft hold and `release_ready=false` / `security_current=false`.

**Progress:** no milestone acceptance credit from CI-only staging. Overall 61%, M3 83% (5/6); issue #8 and draft PR #6 remain open.
