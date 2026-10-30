# M3: real archived lean-browser New Tab dual-feed runtime boundary

**2026-10-30 UTC:** [GitHub Actions 40985864152](https://github.com/sguzman/vulpra/actions/runs/40985864152)
**PASSED**, artifact **12947495420**.
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

The test toggled
`browser.newtabpage.activity-stream.testing.shouldInitializeFeeds`
**only in a disposable headless session** on freshly constructed
ActivityStream objects. It restores the previous preference after both
branches; it does not call `TopStoriesFeed.lazyLoadTopStories`,
fetch live recommendations, construct remote/sponsored feeds or test
server-side fallback. A source-level audit separately confirms the
legacy Discovery Stream-disabled branch.

**Source continuity:** Six protected Git blobs are byte-identical
between the archive's original source and current main: activity-stream
registration, Discovery Stream feed, TopStories feed, newtab `moz.build`,
newtab `addon-jar.mn`, and sponsored AdBanner component.
The six-source check is not proof the entire current browser source,
build configuration or platform ABI matches the archived package.
The test suite rejected **11** deliberately fabricated registration,
restricted-map and page-document results.

An earlier attempt [40985644967](https://github.com/sguzman/vulpra/actions/runs/40985644967)
failed an overly literal test-harness metadata suffix assertion; a
second attempt [40985695231](https://github.com/sguzman/vulpra/actions/runs/40985695231)
revealed that automation's default `shouldInitializeFeeds=false`
means the normal `ActivityStream.feeds` getter returns only the reduced
Top Sites/prefs map. The final test explicitly and reversibly checks
**both** source-supported map branches. Neither preliminary failure was
accepted as native runtime evidence.

**Limits:** This is proof of retained native packaged module imports
and registration/factory maps in a Normandy-free opt-in build, **not**
a successful signed-in user path, live Pocket recommendation network
load, legacy story-fetch fallback, real ad delivery, complete runtime
dependency map or newly measured feature saving. No source code was
removed. **M3 2/6 (33%), overall 44%.**
