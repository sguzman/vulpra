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
- `ci/tests/security-160-safebrowsing-keyfile-stage-tests.sh` uses a **synthetic, nonfunctional fixture**, checks private staging and no fixture-byte leaks in logs or config and rejects nine negative cases: missing source, existing output, destination outside runner temp, symlink input, checkout input, group-readable input, short input, multiline input and duplicated key option.
- [Lightweight contract CI 43251497812 PASS](https://github.com/sguzman/vulpra/actions/runs/43251497812). Does not compile Firefox or contact Google. The installed browser, profiles, `main` and existing native build workflows are unchanged.

## Remaining acceptance order

1. **Provider and distribution authorization**: select an eligible provider, confirm license/terms, key ownership, attribution/privacy disclosures, expected usage quotas, whether a distributable embedded client credential is permitted, and any agreement required.
2. **Secure CI provisioning and release hardening**: in a separately authorized native build, obtain controlled provider key material through restricted CI secrets, generate ephemeral files and an isolated mozconfig with the staging helper, and prevent key values from appearing in logs/source/uploaded artifacts; account explicitly for possible extractability from the *distributed binary*.
3. **Native runtime configuration**: rebuild a new candidate only with approval, then re-run the existing read-only classifier readiness gate against the *new*, source-provenance-pinned package, without WebDriver disabling production protections.
4. **Provider-backed behavior**: prove actual list freshness/update/classification, controlled provider-sanctioned test warning, download protection and regression handling without sending real malicious URLs.
5. **Release review**: finish Mozilla advisory coverage, sandbox/egress and profile-safety checks, disclosure/attribution, QA and package/update strategy; only then reconsider PR #6's draft hold and `release_ready=false` / `security_current=false`.

**Progress:** no milestone acceptance credit from CI-only staging. Overall 61%, M3 83% (5/6); issue #8 and draft PR #6 remain open.
