# M3: real archived lean-browser New Tab dual-feed runtime boundary

**2026-10-30 UTC:** initial [native factory run 40985864152](https://github.com/sguzman/vulpra/actions/runs/40985864152)
**PASSED** its 10 source-registration checks (artifact **12947495420**).
Expanded [real native 14-check run 40986240766](https://github.com/sguzman/vulpra/actions/runs/40986240766)
**PASSED** both factory maps **and actual TopStoriesFeed method-level legacy branches**, artifact **12947750031**.
This executed the actual native Linux Vulpra browser from the independently
successful [Normandy runner-free source-matched build
40954193793](https://github.com/sguzman/vulpra/actions/runs/40954193793),
with source SHA `034ddd665a080f173ce45094ae3afb8868b45e1a`.
The downloaded **87,138,100 B** tar.xz digest
`7095a57083a6211177fd182a2c5275d0ef8c8b2398f4eb1b3298ae951861adac`
matched its original build-generated metadata and SHA sidecar.
Earlier real [native candidate runtime 40968542013](https://github.com/sguzman/vulpra/actions/runs/40968542013)
was independently required to have succeeded.

This package is **NOT** the standard full-Normandy browser. It is an
accepted opt-in variant omitting Normandy's recipe runner and retaining
Nimbus helpers; the built-in New Tab and Pocket source/bundle were
intentionally **not** omitted.

## Actual packaged browser assertions

The CI test launched the native executable using geckodriver with a
new disposable home/profile and Gecko's nonlocal network guard,
navigated to **`about:newtab`** and verified a real HTML document.
In a privileged *test-only* browser context it imported the packaged
`ActivityStream`, `TopStoriesFeed` and `DiscoveryStreamFeed` modules.

| Protected check | Observed |
| --- | --- |
| `feeds.system.topstories` | Registered in complete factory map |
| `feeds.discoverystreamfeed` | Registered in complete factory map |
| `feeds.system.topsites` | Registered |
| `feeds.prefs` | Registered |
| `feeds.adsfeed` | Registered; AdsFeed opt-in omission **disabled** |
| `TopStoriesFeed` class | Imports successfully |
| `DiscoveryStreamFeed` class | Imports successfully |
| New Tab AdsFeed omission guard | Off, protecting normal New Tab inventory |
| Test `shouldInitializeFeeds=false` on fresh *uninitialized* stream | Exactly Top Sites + preferences remain in the restricted map |
| No feed factories explicitly called by probe | Verified test method boundary |
| Malformed Discovery Stream JSON passed to shipped `TopStoriesFeed.lazyLoadTopStories` | Legacy `initializeProperties` and `init` *inert test hooks* each invoked once |
| Explicit `{"enabled":false}` discovery configuration | Same inert legacy initialization path invoked |
| `storiesLoaded=true` | Guard returned without calling either inert hook |
| User Top Stories preference disabled | Guard returned without calling either inert hook |

The test toggled
`browser.newtabpage.activity-stream.testing.shouldInitializeFeeds`
**only in a disposable headless session** on freshly constructed
ActivityStream objects. It restores the previous preference after both
branches. The follow-up then calls the *actual packaged*
`TopStoriesFeed.lazyLoadTopStories` method on controlled inert objects
whose `initializeProperties` and `init` hooks only increment counters.
This checks malformed-JSON, Discovery Stream disabled, stories-already-loaded
and user-opt-out branches without creating a real feed, performing
recommendation requests or proving live fallback delivery.
A source-level audit independently traces the matching method and registration.

**Source continuity:** Six protected Git blobs are byte-identical
between the archive's original source and current main: activity-stream
registration, Discovery Stream feed, TopStories feed, newtab `moz.build`,
newtab `addon-jar.mn`, and sponsored AdBanner component.
The six-source check is not proof the entire current browser source,
build configuration or platform ABI matches the archived package.
The extended test suite rejected **16** deliberately fabricated
registration, legacy-branch, restricted-map and page-document results.

An earlier attempt [40985644967](https://github.com/sguzman/vulpra/actions/runs/40985644967)
failed an overly literal test-harness metadata suffix assertion; a
second attempt [40985695231](https://github.com/sguzman/vulpra/actions/runs/40985695231)
revealed that automation's default `shouldInitializeFeeds=false`
means the normal `ActivityStream.feeds` getter returns only the reduced
Top Sites/prefs map. The final test explicitly and reversibly checks
**both** source-supported map branches. Neither preliminary failure was
accepted as native runtime evidence.

## Modern Discovery Stream fallback and opt-out getter runtime (follow-up)

[Expanded native CI 40989926138](https://github.com/sguzman/vulpra/actions/runs/40989926138)
**PASSED** at test/workflow commit `320abb31a2a044c027ee2e494e21bae424cfa1a5`,
with original **identical** checksum-pinned candidate binary and six protected
New Tab source blobs. Evidence artifact **12948896162**:
`m3-archived-lean-pocket-native-registration-smoke`.
[Workflow lint 40989926148](https://github.com/sguzman/vulpra/actions/runs/40989926148) also passed.
The native positive assertions rose from **14 to 22**; the original 14
legacy/registration checks remain required, and the eight additional checks
invoke **actual packaged `DiscoveryStreamFeed` getter/method code** with
inert constructed objects instead of instantiating a live feed.

- Valid JSON configuration with system-enable preference retains enabled state
  and expected ordinary layout property.
- System-enable preference off disables an otherwise enabled configuration.
- Explicit disabled JSON configuration stays disabled even with system pref on.
- Malformed JSON takes the shipped empty-config error fallback.
- A cached parsed config is reused without re-reading a deliberately throwing
  store, verifying the tested cache fast path.
- `showSponsoredStories` requires both user and system sponsorship preferences;
  either opt-out disables it.
- `showStories` respects system Top Stories disablement in the checked
  user-enabled branch.
- `onPocketExperimentUpdated` ignores load-only experiment/rollout notices,
  but invokes the stub change hook for a subsequent feature update.

This is a **controlled, real-packaged-method** test with a private profile and
no requested content fetch, store dispatch or remote sponsored data. It does
**not** test a live `DiscoveryStreamFeed` instance, all `showStories` override
cases, real recommendation failure recovery, full production-context browser
behavior or current-main compiled source equivalence. No source removal,
package saving, completed broad M3 gate or opt-out privacy guarantee follows.

**Limits:** This is proof of retained native packaged module imports
and registration/factory maps in a Normandy-free opt-in build, **not**
a successful signed-in user path, live Pocket recommendation network
load, *production-context* story-fetch fallback, real ad delivery, complete runtime
dependency map or newly measured feature saving. No source code was
removed. **M3 2/6 (33%), overall 44%.**

## Additional real packaged selection and opt-out checks

[Native browser CI 40993562424](https://github.com/sguzman/vulpra/actions/runs/40993562424)
**PASSED**, artifact **12949863723**, and [workflow lint
40993562212](https://github.com/sguzman/vulpra/actions/runs/40993562212)
**PASSED**. [Test/workflow commit
`cd12bfa`](https://github.com/sguzman/vulpra/commit/cd12bfad77357ecbd63e08cbe2dbdd625e01cfc1)
raised the required actual packaged native assertions from **22 to 26**.
All prior assertions remain required. The four new shipped-method checks
verify:

- Modern Discovery Stream JSON with its system preference enabled
  selects modern mode without initializing legacy Top Stories properties.
- With modern JSON enabled but its system preference disabled, the
  shipped TopStories method selects legacy initialization instead.
- Repeated legacy fallback initializes legacy properties only once,
  with inert initialization hooks called twice.
- The shipped DiscoveryStream `showStories` getter respects the user's
  Top Stories opt-out without an assigned-space override, even when the
  system stories preference remains enabled.

No new browser build was made. The original checksum-verified
Normandy-free archive was reused, the six pinned New Tab source blobs
still match current main, and the real `about:newtab` page was loaded
in an isolated private browser session. All feed-init side effects were
replaced by inert test hooks: no live recommendations or sponsored data
fetches, user login, profile changes or production-context feed setup
were tested. A suitable downloadable full-Normandy normal browser
artifact has not been verified for this specific cross-check.
No source deletion, compressed-size saving, privacy guarantee or broad
M3 gate credit follows. **M3 2/6 (33%), overall 44%, Δ0 pp.**

## Original historical full-versus-lean native comparison (2026-10-30 UTC)

[Paired real browser CI 40996685167](https://github.com/sguzman/vulpra/actions/runs/40996685167)
**PASSED** with artifact **12951213932**,
[regression of the later archived lean browser
40996685005](https://github.com/sguzman/vulpra/actions/runs/40996685005)
**PASSED** (artifact **12951706716**), and
[workflow lint 40996684989](https://github.com/sguzman/vulpra/actions/runs/40996684989)
**PASSED**. Implementation commit
[`9cb22b0`](https://github.com/sguzman/vulpra/commit/9cb22b02f95ff1ff008b3f33f191b6ba9626ec64).

This test reused **two originally independent native Linux builds from the
exact same older source**
`674db8e385c36aec23e78bbe059b2a1fec194fae`:
normal full-Normandy [40431769117](https://github.com/sguzman/vulpra/actions/runs/40431769117)
and opt-in Normandy-free [40431768974](https://github.com/sguzman/vulpra/actions/runs/40431768974).
The already established successful original runtime
[40439671494](https://github.com/sguzman/vulpra/actions/runs/40439671494)
was required. Metadata, source identity, SHA-256 sidecars, tar sizes and
physical `omni.ja` Normandy runner presence/absence were verified before
execution. Full-normal tar.xz **86,937,548 B**, sha256
`47c8ac5ce90747c051eac8daf24544d88767fdeb989293c0b50c5e8ac9e53c30`;
lean tar.xz **86,909,928 B**. The runner exists only in full.

The refactored common read-only test ran on **both actual extracted native
browser executables**, with separate disposable HOME/profile, nonlocal Gecko
connections disabled, `about:newtab` loaded, and full/lean variant
identity preserved separately. **26/26 protected packaged-method/factory
assertions passed for each variant** and their 26 boolean maps were equal.
The live test exercised the real shipped legacy TopStories method and modern
DiscoveryStream getters through *inert preference/store/initialization
hooks* rather than fetching real stories. The previously successful newer
Normandy-free browser continued to pass the same 26 checks.

**Important source boundary:** the two original binaries are
**source-matched to each other**, but **NOT to current main**. Among six
previously audited New Tab source blobs, `TopStoriesFeed.sys.mjs`
and `browser/extensions/newtab/moz.build` were identical to current main;
`ActivityStream.sys.mjs`, `DiscoveryStreamFeed.sys.mjs`,
`addon-jar.mn` and `AdBanner.jsx` differed. This paired test proves
only that the selected behavior passed in the original historical pair,
not that current-main full Normandy or all newer sponsored/UI behavior is
source-equivalent. No network story recovery, actual user accounts,
sign-in, production feed initialization, causal package saving, browser
source deletion or a new full M3 gate is established.

**Progress remains M3 2/6 (33%), overall 44%; Δ0 pp.**

## Newer-source full normal browser verification dependency

[Commit b148240](https://github.com/sguzman/vulpra/commit/b1482404dfb8b01342990ee99ea3df0f9756b5f7)
adds positive New Tab resource checks to the existing
[normal full-Normandy native build workflow](https://github.com/sguzman/vulpra/actions/workflows/build-m3-normandy-matched-baseline.yml)
and a new automatic
[post-build actual browser test](https://github.com/sguzman/vulpra/blob/main/.github/workflows/m3-newtab-full-normal-after-build.yml)
that pins the original build's commit, rehashes its archived native package,
checks its physical full-Normandy and New Tab modules, then executes the
same 26 shipped-method and registration checks on a disposable real Vulpra
browser profile. The first compile run is
[40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527);
workflow lint [40997075529](https://github.com/sguzman/vulpra/actions/runs/40997075529)
**PASSED**.

**Acceptance not yet earned:** Native compilation/package result and the
automatic post-build New Tab test must both finish successfully before
the result may be credited. This is not an opt-in feature removal,
causal size measurement, network recommendation fallback proof or entire
M3 milestone gate. No user workstation/source browser modification.
