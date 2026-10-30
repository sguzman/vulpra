# M3 — New Tab and ASRouter shared messaging boundary: native protection

**Accepted bounded check, 2026-10-30 UTC.** No browser source or
feature was removed. The exact shared New Tab/ASRouter messaging root is
**KEEP** on normal Vulpra; narrower promotional resources retain their
own separately guarded optional variants. The overall M3 dependency,
promotion/telemetry and testing/localization gates remain open.

## Source / startup registration

[Source-pinned bridge contract CI 41105957207](https://github.com/sguzman/vulpra/actions/runs/41105957207)
**PASSED**, artifact **13000952309**;
[actionlint 41105956863](https://github.com/sguzman/vulpra/actions/runs/41105956863)
**PASSED**. The checker,
[`ci/m3-newtab-messaging-bridge-contract.sh`](../../ci/m3-newtab-messaging-bridge-contract.sh),
looked up **34 exact anchors** by Git blob at real `HEAD` and rejected
**34 deliberately removed-anchor mutants**. It protects:

- `browser/components/moz.build` includes both `newtab` and `asrouter`.
- `BrowserComponents.manifest` registers `AboutNewTab.init`,
  `NewTabUtils.init` and `ASRouterNewTabHook.destroy`.
- `BrowserGlue.sys.mjs` imports the router/hook and schedules
  `ASRouterNewTabHook.createInstance(ASRouterDefaultConfig())`.
- `browser/components/asrouter/moz.build` packages router, hook,
  parent handler, telemetry and preferences, while the **two separately
  optional promo modules** remain under `VULPRA_NO_ASROUTER_PROMOS`.
- `browser/components/newtab/moz.build` packages redirect/mapping
  resources into `browsercomps`.
- The built-in New Tab addon jar packages `ActivityStream`,
  `NewTabMessaging`, legacy `TopStoriesFeed`, modern
  `DiscoveryStreamFeed`, `Store`, and its shared messaging code.
- The shipped ActivityStream imports both Pocket recommendation feed
  implementations and `NewTabMessaging`; the latter retains its
  `newtab-message` observer and `AboutNewTab` actor route.

Every reported anchor has source line and Git blob SHA. This is
**source-presence and registration evidence**, not a proof of the full
dynamic graph, remotely delivered messages, account login or live
promotional messaging.

## Actually compiled and packaged full-normal browser

[Native source-pinned runtime CI 41106584931](https://github.com/sguzman/vulpra/actions/runs/41106584931)
**PASSED**, artifact **13000664107**. It reused the original
[full-Normandy native Linux Vulpra build 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527):

| Provenance | Verified value |
| --- | --- |
| Compiled browser source | `b1482404dfb8b01342990ee99ea3df0f9756b5f7` |
| Native normal archive SHA-256 | `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` |
| Full-normal compressed archive | **87,154,544 bytes** |
| Source blob identities | **10/10** identical to actual compiled source |
| Real privileged module imports | **10/10** pass |
| Inert default-hook/message bridge assertions | **5/5** pass |
| Packaged `about:newtab` navigation | **PASS** |
| Native report negative fixtures | **18** false-module/bridge/safety reports rejected |

The browser was launched under disposable `HOME`, a separate
GeckoDriver profile, disabled nonlocal Gecko connections, original
`application.ini` Vulpra identity, and SHA-256-verified archive.
No personal profiles, credentials or remote recommendation contents
were read. The test exercised these physical compiled modules:

| ASRouter/New Tab protected modules | Result |
| --- | --- |
| ASRouter singleton | PASS |
| ASRouter default config factory | PASS |
| ASRouterNewTabHook | PASS |
| Parent-process message handler | PASS |
| ASRouterTelemetry | PASS |
| NewTabMessaging | PASS |
| NewTabActorRegistry | PASS |
| ActivityStream | PASS |
| TopStoriesFeed (legacy) | PASS |
| DiscoveryStreamFeed (modern) | PASS |

The real code paths construct **ASRouterDefaultConfig()** without
initializing router storage, preserving its original router identity,
CFR action handler and telemetry dispatch method. `NewTabMessaging`
starts with a safely uninitialized store and retains its observer/init
interfaces. The hook retains its singleton/create/destroy methods.
`new ActivityStream().feeds.keys()` behaves as expected in a real
privileged Gecko realm. `about:newtab` opened successfully. No
remote messages were requested or actor instances deliberately started
by the probe.

The first preliminary
[run 41106436098](https://github.com/sguzman/vulpra/actions/runs/41106436098)
failed on a test-only `instanceof Map` assertion across Gecko JS
compartments, although physical module imports succeeded. We corrected
that check to use the public `.keys()` interface already exercised by
the earlier native 26/26 New Tab tests, and
**41106584931 then passed**. This was a harness assertion mismatch,
not evidence of a broken browser module.

For independently compiled New Tab feed method/factory protections,
see [source-pinned native runtime 41004025705](https://github.com/sguzman/vulpra/actions/runs/41004025705),
**26/26 protected assertions PASS**.

## Conservative classification and limits

The New Tab/ASRouter shared root was moved from **review** to **keep**
after both the source and native evidence succeeded. This is an
explicit safety constraint, **not** a claim that every promotional
message/asset must stay: existing guarded `ASRouter` promos, AdsFeed,
PromoCard and Normandy opt-ins remain independent conditional
candidates with their own acceptance evidence.

[Revised 20-candidate safety policy CI 41107072921](https://github.com/sguzman/vulpra/actions/runs/41107072921)
**PASSED** (artifact **13000104962**), rejecting **33 corrupted
classification/byte/accounting mutants**. The verified classification
now contains **12 keep, 4 previously source-pruned, 1 review,
3 conditional** decisions. **`source_testing`** remains the only
unresolved broad candidate.

No live ASRouter message delivery, actual storage transaction,
remote Pocket fetch, full actor lifecycle, complete dependency
closure, or isolated additional compiled-package savings was
demonstrated. A source-matched native package rebuild and additional
fallback/real-world runtime tests are still required before
removing any *new* module.

**M3 2/6 (33%), overall Vulpra 44%, round Δ0 percentage points.**
