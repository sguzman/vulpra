# M3 — Pocket, account/Sync, promotional UI, and telemetry privacy audit

**Accepted bounded audit on 2026-10-30 UTC.**
[Independent preservation CI 41113199778](https://github.com/sguzman/vulpra/actions/runs/41113199778)
**PASS**, artifact **13004751589**. [Workflow lint
41113199721](https://github.com/sguzman/vulpra/actions/runs/41113199721)
**PASS**. No personal Firefox account, production telemetry endpoint or
remote recommendations were involved.

## Source and shipped-package identity

The [source-pinned four-way risk crosscheck
40982290720](https://github.com/sguzman/vulpra/actions/runs/40982290720)
**PASS**, artifact **12945352163**, classified **24** protected
source boundaries: five Pocket/recommendation, seven Sync/FxAccounts,
six telemetry, and six data-deletion paths. This older source audit is
from `010d4b7e847f3a0cd0bb69d20b17db59108120ae`, **not** the
later compiled browser source.

The real normal full-Normandy Vulpra package was compiled in
[native build 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527)
from exact source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`;
the baseline archive SHA-256 is
`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`.
Independent source-matched runtime tests used isolated Vulpra
profiles and blocked nonlocal Gecko connections.

## Pocket and protected New Tab recommendation feed paths

[Normal New Tab native runtime 41004025705](https://github.com/sguzman/vulpra/actions/runs/41004025705)
**PASS**, artifact **12954189626**: all **26 of 26**
shipped New Tab factory/preference/legacy and modern feed assertions
passed. The normal package retained both TopStoriesFeed and
DiscoveryStreamFeed, their registration, and AdsFeed with the omission
**disabled** by default; `about:newtab` loaded successfully.

This isolated test intentionally did **not** fetch actual Pocket
recommendations, run production story-provider initialization,
authenticate a user, or establish remote sponsored story rendering.
The ASRouter shared message infrastructure was independently protected
by [34 source links 41105957207](https://github.com/sguzman/vulpra/actions/runs/41105957207)
and [10 native imports/5 bridge checks
41106584931](https://github.com/sguzman/vulpra/actions/runs/41106584931).
Consequently **keep the shared New Tab/ASRouter/Pocket root**.

## Sync, FxAccounts and WebExtension storage

[Normal full-browser Sync/FxAccounts native QA 41078779642](https://github.com/sguzman/vulpra/actions/runs/41078779642)
**PASS**, artifact **12987978329**. It verified **eight
protected module and default-account-state assertions** covering the
Sync UI, Weave, FxAccounts, accounts glue, Firefox View and
WebExtension storage.sync in a disposable profile. The normal browser
was physically source- and checksum-bound to the compiled archive.

It did **not** log in to Firefox Accounts or prove live Sync upload,
remote token renewal or cross-device account behavior. Sync and
FxAccounts are distinct systems with separate account, browser UI,
WebExtension and AI Window consumers. **Keep both** until a separate,
fully specified opt-in alternative has independent QA.

## Telemetry lifecycle, policy opt-out and deletion request

[Normal full-browser privacy runtime 41078909794](https://github.com/sguzman/vulpra/actions/runs/41078909794)
**PASS**, artifact **12988478342**:

| Actual test behavior | Observation |
| --- | --- |
| Native sender initial startup, no test initializer | 0 s not ready; 30 s not ready; 75 s ready |
| Local synthetic ordinary upload before/after explicit opt-out | **1 → 1** (no new ordinary ping) |
| Local deletion-request before/after explicit opt-out | **0 → 1** (deletion exception preserved) |
| Independent master data-reporting policy | Upload disabled |
| Local receiver framing errors | **0** |

The natural startup and opt-out test-mode sessions were **separate**.
The receiver bound only to `127.0.0.1` and saved no production ping
bodies or identifiers. The deletion exception preserves an important
privacy lifecycle obligation. This proves **packaged-browser local
test-mode behavior**, not normal production upload or a successful
remote Mozilla data-erasure transaction. Telemetry, Glean, native
bindings, policy controls, crash handling, ClientID rotation and
deletion requests remain protected; replacing/removing the whole
stack is not approved.

## Promotional omissions remain independent and opt-in only

Source and native evidence separately accepted opt-in trials for
[ASRouter promotional resources 40547968387](https://github.com/sguzman/vulpra/actions/runs/40547968387),
[AdsFeed 40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714)
and [PromoCard 40787698972](https://github.com/sguzman/vulpra/actions/runs/40787698972).
Normandy's recipe-runner opt-in also has earlier independent native
acceptance. The standard browser is unchanged: no generic removal of
Nimbus/Normandy, New Tab, Pocket, Sync, telemetry or shared messaging
has been authorized. Source-matched archive-size differences belong
to **separate experiments at different revisions**; they cannot be
combined or attributed causally to individual deleted resources.

## Acceptance / limits

The audit requirement is to **understand and classify** the promotional,
Pocket, account/Sync and telemetry paths against the retained normal
Linux browser and privacy obligations. This audit is accepted through
**conservative keep decisions**, with separately guarded optional
promotion experiments; there is **no production-network claim and no
new code/feature omission**.

The independent complete feature/build/ELF/dynamic dependency graph
remains an unfinished, distinct M3 gate. This audit does not prove
complete caller/loader closure, future-source behavior, all default
sponsored UI appearances or new savings.

**M3 after accepting this audit: 5/6 (83%); overall Vulpra 61%,
+17 M3 points and +6 overall points from the 4/6 checkpoint.**
