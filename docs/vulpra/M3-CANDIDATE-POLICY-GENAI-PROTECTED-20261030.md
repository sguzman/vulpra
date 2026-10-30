# M3 — Candidate decision safety contract and verified GenAI external consumers

**Accepted 2026-10-30 UTC.** The milestones are unchanged: **M3 2/6
(33%), Vulpra 44%, round delta 0 percentage points**. The underlying
normal browser, Sync/FxAccounts, telemetry and user profile were not
modified.

## 1. Fail-closed candidate decision policy

[Policy CI 41080217282](https://github.com/sguzman/vulpra/actions/runs/41080217282)
**PASSED** (artifact **12989500427**);
[actionlint 41080217307](https://github.com/sguzman/vulpra/actions/runs/41080217307)
**PASSED**. The policy is
[`ci/m3-candidate-decision-contract.jq`](../../ci/m3-candidate-decision-contract.jq),
with [32 negative mutation fixtures](../../ci/tests/m3-candidate-decision-contract-test.sh).

It inspects the actual `docs/vulpra/DEBLOAT-CANDIDATES.json` source
ledger and independently guards **all 20 scoped classifications**:

| Historical scope class | Number | Semantics |
| --- | ---: | --- |
| Keep protected | **11** | Core GTK/Wayland/WebExtensions/security, Sync, FxAccounts, telemetry/data-deletion safety, DevTools, Pocket feeds, default localization, AI Window offline seed, Hungarian hyphenation and the shared GenAI root |
| Previously accepted bounded source prune | **4** | Windows/Cocoa, Android apps and independently verified Android/iOS/UIKit leaves; not a general platform removal permit |
| Requires source/runtime review | **2** | `source_testing`, `newtab_and_messaging` |
| Guarded opt-in conditional omission | **3** | Normandy recipe runner, New Tab AdsFeed, New Tab PromoCard; default browser unchanged |

The test deliberately corrupts existing candidate IDs, moves protected
code into an unauthorized removal category, approves unresolved review
scopes, removes safety/fallback/evidence fields, treats guarded opt-ins
as permanent deletion, fabricates whole-M3 completion, and inflates
source savings. **32/32 unsafe mutations were rejected**. The accepted
source-only cohorts remain **14,867 distinct files** and **129,967,585
original Git blob bytes**; their overlapping per-candidate inventory
numbers must not be summed. No compiled-byte saving is attributed to
those source removals.

**Limit:** this is a fail-closed rule for the **already scoped** 20
candidates, not a full binary dependency map or proof that the list
exhausts all future Firefox features. Any new candidate or changed
classification requires an explicit, reviewed contract update. The
two review scopes remain open. GenAI's shared root is now conservatively classified **keep** after verified source and native module behavior; narrow optional assets still need independent acceptance.

## 2. Source-pinned GenAI external consumer safety map

[Source CI 41080608153](https://github.com/sguzman/vulpra/actions/runs/41080608153)
**PASSED** (artifact **12989152509**);
[actionlint 41080608182](https://github.com/sguzman/vulpra/actions/runs/41080608182)
**PASSED**. The
[`ci/m3-genai-external-consumer-contract.sh`](../../ci/m3-genai-external-consumer-contract.sh)
checks **33 distinct source anchors** at the actual Git SHA and rejects
**33 synthetic missing-anchor mutations**.

The current protected caller/registration relationships include:
- `browser/components/moz.build` → GenAI root and its nine packaged
  main/actor modules, including Page Assist and Link Preview.
- `BrowserComponents.manifest` → delayed `LinkPreview.init` and idle
  `GenAI.init`, with no generic build-option omission proven.
- `DesktopActorRegistry.sys.mjs` → six parent/child actor declarations;
  GenAI preference observers and Link Preview/Page Assist actor gating.
- Browser settings, sidebar, enterprise policies and Nimbus
  `linkPreviews` configuration still refer to those resources.
- `GenAI.sys.mjs` itself references AI Window's module.

The script records exact repository commit, Git blob SHA, path and line
for each anchor, not source content or user data. This is stronger than
an unpinned list of strings, but these are still **literal source
relationships**. They do not prove all dynamic imports or which runtime
actors activate for every preference combination. The correct current
GenAI decision is **review and retain the shared root**.

## 3. Real newer full-normal native GenAI module import

[Native CI 41081060039](https://github.com/sguzman/vulpra/actions/runs/41081060039)
**PASSED**, evidence artifact **12988693736**;
[actionlint 41081060200](https://github.com/sguzman/vulpra/actions/runs/41081060200)
**PASSED**. The independently compiled Linux browser is the original
**full-Normandy normal package** from
[build 40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527):
compiled source **`b1482404dfb8b01342990ee99ea3df0f9756b5f7`**,
archive SHA-256
**`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`**,
compressed **87,154,544 B**.

The native replay checked the original compiled source/build identity,
SHA-256 sidecar, preserved full-Normandy manifest and **nine matching
module Git blob hashes**. Using a fresh headless Vulpra process with
disposable HOME/profile, geckodriver and blocked nonlocal Gecko
connections, it imported from the **actually shipped** browser:

| Real privileged module | Result |
| --- | --- |
| GenAI controller | **PASS** |
| Link Preview controller | **PASS** |
| Page Assist controller | **PASS** |
| GenAI Parent and Child actors | **PASS / PASS** |
| Link Preview Parent and Child actors | **PASS / PASS** |
| Page Assist Parent and Child actors | **PASS / PASS** |

All **9/9 native module checks passed**. The test also invoked the
already implemented Page Assist `fetchAiResponse` **with null page
data** and observed the expected `null` early return: no real page
content or model inference was supplied. The three relevant chat/preview/
assist preference values were unchanged by the test.
There were **13 deliberate report-acceptance negative fixtures**
(9 missing modules plus four safety/error states).

**Non-claims:** the probe deliberately did **not** call `GenAI.init`
or `LinkPreview.init`, instantiate actors, load model inference,
contact AI providers, test network login, or prove complete actor
lifecycle/routing. Nonlocal connections were disabled and no credentials
or user profile were used. This cannot authorize stripping shared
GenAI modules or claim binary savings. It is real packaged-module
and offline-early-return compatibility evidence only.

## Next engineering boundary

Complete actual runtime actor registration and preference fallback
testing before narrowing any GenAI source omission. Keep source and
privacy/export contracts fail-closed; consider narrowly isolated
promotional files before broad GenAI or message-router changes.
For testing and localization, preserve Gecko's unconditional build
support and standard-compliance QA until separately source-matched,
packaged and functionally verified.

**No new whole M3 gate and no user workstation action required.**

## Verified GenAI whole-root classification change

[Updated candidate policy 41082489259](https://github.com/sguzman/vulpra/actions/runs/41082489259)
**PASSED**, artifact **12990406989**. The existing
[local source/build safety suite 41082489351](https://github.com/sguzman/vulpra/actions/runs/41082489351)
**PASSED** too. The first policy run 41080217282 checked the historical
**10 keep / 3 review** snapshot; this newer successful run checked the
revised **11 keep / 2 review** snapshot. All **32 intentionally unsafe
classification and pruning-report mutations** remain rejected, and the
older candidate-strategy/accepted-evidence suite passes.

The shared `browser_genai` root now has strategy **keep**, based on
**33 existing source callers/registrations** and **nine successful real
compiled native module imports**, while optional GenAI subfeature
removal remains conditional on a *different, narrower and separately
accepted* candidate. The two remaining coarse review scopes are
`source_testing` and `newtab_and_messaging`. This classification
change neither removes a feature nor closes the full M3 classification
gate; complete dynamic callers and independent optional-feature
fallbacks are not established. **M3 2/6, overall 44%, Δ0 pp.**
