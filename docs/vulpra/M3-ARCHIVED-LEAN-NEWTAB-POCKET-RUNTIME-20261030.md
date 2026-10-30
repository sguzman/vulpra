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
