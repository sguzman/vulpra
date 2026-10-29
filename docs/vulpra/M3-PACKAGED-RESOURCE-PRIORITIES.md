# M3 packaged resource hotspots and guarded omission priorities

**Measured, not inferred:** [historical normal Vulpra archive scan 40926977310](https://github.com/sguzman/vulpra/actions/runs/40926977310) **PASSED**, including 11 archive categorization/anti-tamper fixtures. It checked the same previously verified **86,930,792-byte** Linux `tar.xz` (compiled at source `1683ca67b69389a879717bcd537772c3b40624b6`) and enumerated ZIP-entry sizes from the **root and browser `omni.ja`** separately. No source was removed or recompiled.

## Largest selected bundled resources

| ZIP entry (abbreviated) | Uncompressed logical bytes | M3 assessment |
| --- | ---: | --- |
| Root PDF.js `pdf.worker.mjs` | **2,235,560** | **Keep** — built-in PDF capability; no replacement/consent |
| Browser DevTools `css-properties.json` | **1,702,863** | **Keep** — debugging/compatibility data |
| Browser `defaults/settings/main/ai-window-prompts.json` | **1,577,264** | **Review** — large, browser-specific AI Window seed; offline fallback unverified |
| Browser DevTools `parser-worker.js` | **1,531,151** | **Keep** — debugging and JS tooling |
| Browser `security-state/intermediates.json` | **1,467,806** | **Protect** — certificate/security state |
| Browser New Tab `activity-stream.bundle.js` | **1,335,252** | Narrow guarded JS substitutions already tried, core feed kept |
| Root `translations/cld-worker.js.mem` | **1,097,263** | **Keep pending translation fallback** |
| Browser `security-state/onecrl.json` | **1,055,340** | **Protect** — certificate revocation |
| Root `hyphenation/hyph_hu.hyf` | **1,048,764** | **Review** — localized language resource, not proven disposable |
| Root certificate viewer `pkijs.js` | **954,849** | **Protect** — certificate viewer/crypto UI |
| Browser add-on `addons-mlbf.bin` | **938,855** | **Protect** — extension blocklist |
| Root PDF.js `pdf.mjs` | **827,480** | **Keep** — PDF viewer |
| Browser New Tab `activity-stream.css` | **693,203** | Narrow presentation experiments only |
| Root PDF.js `viewer.mjs` | **619,028** | **Keep** — PDF viewer |

**These are nested ZIP-entry payload lengths**. A large entry does not imply an equivalent compressed `tar.xz` saving; nor does an omitted resource guarantee a functional browser. The package scanner ranks these by both logical and inner-ZIP bytes, never adds the entry sizes to the already counted `omni.ja` outer file lengths, and does not inspect runtime consumers.

## AI Window prompt-seed dependency closure

[Source-pinned CI 40927627334](https://github.com/sguzman/vulpra/actions/runs/40927627334) **PASSED** six explicit source relationships and rejected twelve deliberate source changes. Its manifest check measured the same `services/settings/dumps/main/ai-window-prompts.json` source blob at **1,577,264 bytes** *without reading or including the prompt content in the report*.

The exact build and consumer path is:

`browser/components/moz.build` → `aiwindow/` → `models/PromptLoader.sys.mjs`; separately `services/settings/dumps/main/moz.build` packages the named `ai-window-prompts.json` Remote Settings seed for browser applications. `Utils.sys.mjs` obtains `RemoteSettings("ai-window-prompts", { bucketName: "main" })`; `PromptLoader.sys.mjs` requires a published chat module manifest and explicitly throws `promptLoadFailure` when it is missing.

**Safety finding:** deleting the seed without proving an alternate local first-run source and core manifest fallback may break AI Window in a fresh, offline or failed-Remote-Settings state. Remote synchronization and optional custom-prompt preferences do not establish reliable fallback. This is a **new review-only candidate**, `aiwindow_prompt_seed`, separate from GenAI engine/UI removal, **not** an approved default-variant change.

The next safe step is source-matched, opt-in fallback implementation with explicit online/offline initialization cases, native browser/WebExtension/Wayland/profile tests, and *paired* physical package comparisons. Until those pass, retain this seed. Do not prune certificate/revocation/blocklist resources for small gains.

## Classification / acceptance

The candidate register now has **19 bounded scopes**: **8 keep, 4 already accepted source-only prunes, 3 opt-in conditional compilation/bundle omissions, 4 requiring more review**. Source-only prunes are historical accepted work, not new deletions in this round. An opt-in variant does not alter normal Vulpra. This inventory does not complete the entire dynamic dependency graph, all fallbacks, or an additional M3 acceptance gate.

**M3 remains 2/6 (33%), overall product 44%, Δ 0 pp.**
