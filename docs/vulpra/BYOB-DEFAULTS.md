# Vulpra BYOB identity and password defaults

**Source implementation:** `browser/branding/unofficial/pref/firefox-branding.js` on `main`.  
**Status (2026-11-18): source policy and negative-fixture CI PASS; native packaged runtime acceptance PENDING.**  
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
- This **does not prove effective packaged pref precedence, extension autofill behavior, clean-profile UI, or web compatibility**. For acceptance, use a newly packaged Vulpra binary under an isolated *new* HOME/profile, read effective and default branch values in privileged test code without logging actual saved credentials, verify no user values, confirm no built-in save/autofill UI on an inert localhost form, and verify a Bitwarden-compatible extension can still be installed and operate against a fake/local test endpoint. Never use live personal Vaultwarden credentials for acceptance.
- The Firefox **160 draft branch** has an exact-source, fixed-hash overlay and a preserved already-built native archive. **Do not silently call this new `main` source preference change part of that old archived Firefox 160 binary.** Its independently verified 28-overlay source ledger must be deliberately updated, reviewed, and recompiled/packaged before these settings can be called effective in a Firefox 160 browser.
- This is independent of [Safe Browsing provider authorization](https://github.com/sguzman/vulpra/issues/8), [Firefox 160 security acceptance](https://github.com/sguzman/vulpra/pull/6), and the paused M3 source-pruning gate. None are closed by these defaults.

## Release criteria

Do not label BYOB defaults **runtime accepted** until a built new Vulpra package proves both the default-branch settings and real WebExtension independence, with profile preservation and threat protection unaffected. Consider explicitly documenting other account/sync/telemetry services before any public distribution; **do not** disable security controls merely to eliminate external services.

**Project progress:** overall 61% (Δ +0 percentage points); M3 pruning deferred; no newly accepted runtime gate.
