# Vulpra BYOB identity and password defaults

**Source implementation:** `browser/branding/unofficial/pref/firefox-branding.js` on `main`.  
**Status (2026-11-18): source contract, full Firefox 160 BYOB native compile/package, isolated default-pref behavior and independent synthetic extension-fill runtime acceptance PASS; real Bitwarden/Vaultwarden integration and release-security acceptance OPEN.**  
**Scope:** Vulpra-specific defaults only, not a browser-wide extension API change, account migration, or Firefox profile modification.

## Decision

Vulpra is a browser and should not implicitly own a user's account/password storage or require Mozilla/Google infrastructure for identity. The user-selected external password manager and sync services own those records. Vaultwarden is a compatible self-hosted Bitwarden server; its browser extension is a separate component that the user configures, not a new proprietary Vulpra account system.

Four **default-branch** settings were added to Vulpra's own unofficial branding preferences:

| Preference | Vulpra default | Scope |
| --- | --- | --- |
| `identity.fxaccounts.enabled` | `false` | No built-in Firefox Accounts/Sync integration enabled by default |
| `signon.rememberSignons` | `false` | Do not offer to save new website passwords into Firefox's built-in login manager |
| `signon.autofillForms` | `false` | Do not automatically fill previously saved Firefox passwords |
| `signon.generation.enabled` | `false` | Do not offer Firefox's built-in generated-password workflow |

These use `pref(..., false)`, **not** `lockPref`, `user_pref` or an invasive profile policy. An advanced user can consciously change settings. No password database, stored login, Firefox Sync state, browser profile or server is deleted/migrated. No secrets or Vaultwarden URL are built into Vulpra.

**Do not conflate this with security features.** Vulpra continues to require certificate validation, content process sandboxing, WebExtensions, WebAuthn/passkeys and a reviewed phishing/malware/download protection mechanism. Browser update/Remote Settings connections and other upstream services are separate review subjects; these four flags are **not a claim of zero Mozilla/Google network egress**.

## Tests and important limits

- [Source contract](../../ci/test-byob-pref-defaults.sh) requires exactly one ordinary `pref(..., false)` declaration for each key and rejects eleven synthetic source regressions, including missing, true, duplicate and locked variants, and a disabled phishing protection pref. [Lightweight CI](https://github.com/sguzman/vulpra/actions/workflows/qa-byob-defaults.yml) does not compile Firefox.
- [Mozilla's documented `DisableFirefoxAccounts` preference](https://firefox-admin-docs.mozilla.org/reference/policies/disablefirefoxaccounts/) confirms the account integration switch. [Mozilla's `OfferToSaveLoginsDefault` policy](https://firefox-admin-docs.mozilla.org/reference/policies/offertosaveloginsdefault/) documents the nonlocked password-save pref. The autofill and generation defaults need a compiled-browser regression test too.
- **Real Firefox 160 packaged-runtime acceptance passed:** an independent [artifact-only WebDriver replay 44359886859](https://github.com/sguzman/vulpra/actions/runs/44359886859) ran on the verified native binary built by [CI 44350848442](https://github.com/sguzman/vulpra/actions/runs/44350848442). It checked that all four BYOB prefs are **default and effective false, with no user-level override**. In the same disposable browser session, the phishing/malware/dangerous-download default and effective **feature flags stayed true without user overrides**. A temporary, loopback-only generic WebExtension **filled an actual synthetic localhost password field** containing a known fake string; the test verified empty-before, populated-after-install, and empty-after-uninstall/fresh-navigation states. Native JS/navigation, Firefox+Vulpra UA, strict TLS refusal, Nimbus and isolation passed. This **does not** test the real Bitwarden extension, a Vaultwarden endpoint, actual threat-list download/classification, or real login-save UI prompts. Do not use real personal Vaultwarden credentials for acceptance.
- **2026-11-18 Firefox 160 BYOB port:** An [independent source-tree CI proof](https://github.com/sguzman/vulpra/actions/runs/44348872684) accepted a distinct 28-file overlay candidate `c17d957eb58741df2855dc9b6c577be192315410`. Against the **original** immutable complete tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`, exactly **one** path changed: `browser/branding/unofficial/pref/firefox-branding.js` using `main`'s pinned BYOB blob `ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e`. All other Firefox/Vulpra source entries were preserved. This **does not rewrite the old candidate or its historical browser evidence**.
- [Native source-provenance build 44350848442 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/44350848442) compiled, checksummed, and smoke-tested the new Firefox 160 BYOB browser; real WebDriver preference/extension checks also passed. [Independent artifact-only replay 44359886859 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/44359886859) authenticated the source, producer SHA and archive checksum and added live synthetic extension password-field autofill plus protected threat-preference checks, without rebuilding Firefox. Its final fail-closed step verified the actual replay and uploaded proof. **These claims apply to the exact tested Firefox 160 candidate, not a new Firefox 159 main binary or the user's currently installed Vulpra.**
- This is independent of [Safe Browsing provider authorization](https://github.com/sguzman/vulpra/issues/8), [Firefox 160 security acceptance](https://github.com/sguzman/vulpra/pull/6), and the paused M3 source-pruning gate. None are closed by these defaults.

## Release criteria

**Accepted for the Firefox 160 BYOB candidate:** compiled default-branch preferences, generic independent WebExtension synthetic password-field fill, isolated profile preservation and protected local threat-feature switches. **Still to verify separately:** the actual Bitwarden extension against an authorized disposable/local Vaultwarden test service (never personal secrets), real browser login-prompt UX, chosen security provider with fresh threat updates and classification, sandbox behavior on the target host, maintenance/update distribution, and upstream-security advisory coverage. The Firefox 160 candidate stays a draft and is not approved for routine or sensitive browsing. Do not disable security controls merely to eliminate external services.

**Project progress ledger:** overall 61% (Δ +0 percentage points). The BYOB Firefox 160 browser acceptance above passed as a separately documented M4 integration check, but no existing M4 milestone gate was explicitly completed in the machine-readable ledger. M3 pruning remains deferred.
