# M3 Hungarian hyphenation resource risk and dependency crosswalk

**Accepted read-only source audit:** [CI 40935728156](https://github.com/sguzman/vulpra/actions/runs/40935728156) **PASSED** with **six source boundaries and twelve deliberate source mutations rejected**. Native package observations come from the older checksum-verified normal Linux archive [40926977310](https://github.com/sguzman/vulpra/actions/runs/40926977310), source commit `1683ca67b69389a879717bcd537772c3b40624b6`. The actual root `omni.ja` contains `hyphenation/hyph_hu.hyf` at **1,048,764 uncompressed ZIP-entry bytes**.

## Verified build and runtime source relationships

| Boundary | Observed source fact | Safety implication |
| --- | --- | --- |
| Native layout integration | `intl/moz.build` always traverses `hyphenation/glue`; the C++ manager/hyphenator compile into `xul`, with Rust `mapped_hyph` bindings. | Cannot delete the hyphenation engine or Rust integration merely because one language is optional |
| Platform-specific format | `intl/locales/moz.build` selects `.hyf` for desktop and `.dic` for Android. | Browser ships a precompiled resource that avoids first-use pattern compilation |
| Default language inclusion | The same locale manifest includes `"hu"`, creates the Hungarian `hyph_hu.hyf` final target and packages `@RESPATH@/hyphenation/*`. | There is no existing per-Hungarian build flag in this verified source scope |
| Runtime pattern discovery | `nsHyphenationManager` enumerates GRE and APP `omni.ja` entries `hyphenation/hyph_*.*`, then compatible directories and profile overrides. | A missing archive entry can change language-specific behavior or use externally installed patterns |
| Locale fallback | `GetHyphenator` checks cached patterns and aliases, progressively tries language-subtag fallbacks and returns `nullptr` if none can be found. | No-pattern return prevents treating omission as a guaranteed crash, but **not** proof that Hungarian rendering is acceptable |
| Invalid pattern detection | Loader asserts on invalid dictionary content; manager removes a failing pattern URI. | Need verify both present and missing-resource branches; malformed resources must not be silently trusted |

The important distinction is between a *missing* language pattern and *safe typography*. A page containing `lang="hu"` and `hyphens:auto` may wrap differently if Hungarian patterns are unavailable. This can affect reading, layout, narrow columns and site-specific behavior even though Gecko's manager returns null instead of throwing.

## Next legitimate trial

Keep `hyph_hu.hyf` in normal Vulpra. To justify an **opt-in** omission, first create a targeted native visual/layout regression for Hungarian and `hu-HU`, compare explicit `hyphens:none` and `hyphens:auto`, include an English control, test profile-supplied pattern precedence, and inspect local alias fallback. Then create a reversible *isolated* build guard, retain the full default version, and compile a source-matched lean/full pair with Wayland/JS/WebExtensions/privacy acceptance. Attribute real compressed bytes only from independently hashed paired packages; **1,048,764 logical ZIP-entry bytes is not a claim of tar.xz savings**.

**Status:** a new review-only subcandidate, not an accepted source prune or conditional compilation. The general default localization and hyphenation engine remain protected. Full M3 map and candidate fallback gates stay open: **M3 2/6 (33%), overall 44%, Δ 0 pp.**
