# Vulpra security acceptance — Firefox 160.0.1 dogfooding to release
**Started:** 2026-11-20 (America/Mexico_City)
**Verified native-code baseline:** `f8fd382fe95b9afd0a1d19795c91c7ebb39b6df8` on `main` (later documentation-only commits do not change compiled browser code), with Firefox 160.0.1 source and the locally compiled `obj-vulpra-main-160` browser.
**Owner's work order:** security acceptance first; next [typing/rendering lag #7](https://github.com/sguzman/vulpra/issues/7); only after that, local-disk-only Edge-like persistent workspaces (no cloud account/sync).
**Status:** IN PROGRESS, **not accepted for security-current public release**. This is a gate checklist, not a percentage or claim of exploit resistance.

## Scope and operating rules
- Distinguish **experimental personal dogfooding** from **security-approved routine/sensitive use** and **public distribution**. Successful GUI startup, Vaultwarden login, or a passing historical Firefox 160 test is not a substitute for security acceptance of the exact current Firefox **160.0.1** executable.
- Work directly on `main` for ordinary source/testing work. Do not modify `upstream-base`, merge the historical draft Firefox 160 PR #6 as an unrelated step, or switch the working browser to an unverified CI artifact.
- Verify using **disposable profiles**, synthetic localhost data and non-secret, bounded reports. Never read/copy the persistent `~/.local/share/vulpra/default` vault, bookmarks, account cookies or credentials; never touch Firefox Developer Edition's profile.
- Avoid arbitrary source pruning, missing-provider workarounds, disabling Safe Browsing checks, TLS bypasses, relaxed sandbox policies or unreviewed global host changes. No automatic host display/network/driver changes or reboot.
- Prefer reusing existing `ci/security-160-*`, `ci/smoke-webextension-package-local.py`, and `./nix/vulpra` workflows. A **source check**, **mock CI**, **headless browser**, **private-Weston**, **actual Hyprland workstation**, and **signed-in real-world dogfooding** are distinct evidence tiers. Do not silently promote evidence from one to another.

## Ordered acceptance gates

### S0 — Official 160.0.1 source / security-update provenance: PARTIAL
- [x] Check Mozilla's official `FIREFOX_160_0_1_RELEASE` tag resolves to `58fed86b1b6864ad71b83c910a879d6f1a6b678b`; confirmed 2026-11-20 against Mozilla GitHub.
- [x] Independently compare the Git blob identities of `main` and that official tag for:
  - `dom/media/ChannelMediaDecoder.cpp`: **`d688d7ec968395490c84c308eb0ddc241a7ba2ea`** (media security hotfix path);
  - `gfx/gl/GLBlitHelper.cpp`: **`0fb43a1429ef359313ebae7873ac3b2cd20fea64`** (Linux Wayland graphics hotfix path);
  - `browser/config/version.txt`: **`9aab5b81294c1aeb29b4b926c76bb1e52c617cd6`** (`160.0.1`).
- [ ] Reconcile **full** current-`main` Git-tree delta against authenticated Mozilla 160.0.1, including source changes, removals and build wiring, instead of importing the earlier 28-overlay candidate proof as though it describes `main`.
- [ ] Inspect security advisory applicability/patch retention for the exact current build, identify any new Mozilla release before acceptance, and ensure future upstream security refreshes have a repeatable check.
**Evidence limit:** three identical source blobs do not establish full-source equivalence, compiled binary retention or vulnerability mitigation. See [#13](https://github.com/sguzman/vulpra/issues/13) and [Mozilla MFSA 2026-130](https://www.mozilla.org/en-US/security/advisories/mfsa2026-130/).

### S1 — Exact current-`main` binary, build and package provenance: OPEN
- [ ] In a **disposable/test path**, bind the actual `obj-vulpra-main-160/dist/bin/vulpra` ELF, `application.ini` (Name=Vulpra; Version=160.0.1), source Git HEAD, Nix toolchain, and build outputs to a recorded evidence manifest/checksum. Do not claim that application.ini alone proves source identity.
- [ ] `./nix/vulpra package` and its checksum-verified headless smoke **PASS** against this current `main` executable; distinguish any prior Firefox 159 package from the current binary.
- [ ] Re-run relevant private-profile, native Wayland and local JS/navigation checks, with an independent test profile; no user profile input. 
**Acceptance:** a reproducible artifact-to-source chain with a real current native binary and explicit test results, not a source-only or mocked claim.

### S2 — Linux content sandbox / isolation on the target: OPEN
- [ ] Run actual **Firefox 160.0.1 `main`** Gecko-tab worker-role checks: seccomp active, one source-defined denied `prctl` syscall with positive parent control, and separate denied disposable HOME-canary file write. Never overattribute a file denial to seccomp alone.
- [ ] Verify the target **EndeavourOS / Hyprland** kernel and sandbox context, user namespace/chroot/proc restrictions, plus Socket/RDD/Utility role boundaries as appropriate; log *only* bounded non-private evidence.
- [ ] Cross-check against existing older Firefox 160 CI witnesses, including [#9](https://github.com/sguzman/vulpra/issues/9); those genuine historical passes do **not** transfer to 160.0.1 on eosbox.
**Acceptance:** independently attributable real-worker denies and target-host boundaries without disabling security measures.

### S3 — TLS, Safe Browsing flags, extensions and local password workflow: OPEN
- [ ] Real current-`main` WebDriver test of certificate rejection (`acceptInsecureCerts=false`, isolated localhost self-signed certificate, W3C `insecure certificate`), followed separately by an isolated trusted-CA positive control. Never import a test CA into the dogfooding profile.
- [ ] Test extension installation, permissions, content/background messaging, `storage.local`, restart persistence and clean uninstallation using synthetic test add-ons or other disposable fixtures; reproduce with the **new** native binary.
- [ ] Validate the four BYOB **default** preferences (FxAccount/Sync off, built-in password save/autofill/generator off) without locking settings or deleting profile data. Verify phishing/malware/download protection **switches remain enabled**; distinguish switches from actual provider-backed protection.
- [ ] Preserve the user's independently working Vaultwarden/Bitwarden setup; user-observed login and CA trust are functional evidence **only**, not automated end-to-end credential-security evidence.
**Acceptance:** disposable current-binary tests pass, no TLS or extension safety regression, no live user credential in fixtures. See [#12](https://github.com/sguzman/vulpra/issues/12).

### S4 — Network/service behavior and ongoing security updates: OPEN
- [ ] Inspect effective Remote Settings and threat-list freshness/update behavior using actual current-`main` runtime evidence, not only absence of startup errors in a brief offline smoke.
- [ ] Check outbound update/telemetry/Sync/Push behaviors with explicit service-specific assertions, while preserving normal Web Push/notifications; avoid unsound conclusions from short no-route tests.
- [ ] Specify automatic/verified upstream security-rebase cadence, source review, package signing/integrity, update distribution and rollback for public use. Local `git pull && rebuild` is **manual maintenance**, not an automatic security updater.
**Acceptance:** documented, tested operational security policy and real-binary network behavior.

### S5 — Provider-backed malicious-site/download checks and release decision: DEFERRED FOR EXPERIMENTAL DOGFOODING; REQUIRED FOR RELEASE
- [ ] [#8](https://github.com/sguzman/vulpra/issues/8) established that the earlier BYOB candidate's Google Safe Browsing v5 key/endpoints were unavailable. Existing local classifier switches did not prove malicious-URL/download protection.
- [ ] Investigate a legally authorized, no-mandatory-Google-account threat provider/integration or another reviewed protection architecture. Require a **real live provider-backed threat list update and classification test**, along with licensing/redistribution review, before claiming working protection.
- [ ] Only after S0–S5 pass, plus target-platform QA and release/update policy, make a public-release security determination. Until then: experimental, unapproved release.
**Owner decision 2026-11-19:** do not require a Google account, key, subscription or provider integration merely to dogfood. **Do not weaken existing security defaults** to hide this gap.

## Immediate next execution
1. Preserve the verified S0 three-blob source check. Expand to a full `main` vs official Firefox 160.0.1 path-by-path provenance report before considering that gate accepted.
2. Reuse current packaging and disposable WebDriver/security harness to run S1/S2/S3 on the **already compiled** current native binary; do not order a needless full recompile.
3. Record exact executable hash, test command/commit, date, run/platform and bounded pass/fail. Update this checklist on **actual evidence only**, never automatically mark a gate complete for added scaffolding.
4. Return to [#7 typing/frame lag](https://github.com/sguzman/vulpra/issues/7) once the security acceptance workstream is addressed; then work on local-disk-only persistent workspaces. Workspaces must not require Mozilla/Google account sync or a cloud service.

**Progress accounting:** Existing project-wide M1/M2/M3/M4 ledger remains **61% overall, Δ 0 percentage points**. Security gates have no invented independent completion percentage. Old successes are historical witnesses, not accepted passes of this new gate set.
