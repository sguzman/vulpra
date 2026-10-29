# M3 actual native Hungarian hyphenation layout

**Accepted real-browser diagnostic:** [GitHub Actions 40938478049](https://github.com/sguzman/vulpra/actions/runs/40938478049) **PASSED**, preserving the bounded JSON artifact `m3-hungarian-archived-css-runtime` (ID **12925058497**). The test used the existing SHA-256-verified full normal Vulpra Linux archive built from source `1683ca67b69389a879717bcd537772c3b40624b6`; it did not recompile, modify or remove language patterns.

Three relevant sources, `nsHyphenationManager.cpp`, `nsHyphenator.cpp`, and `intl/locales/moz.build`, had **identical Git blobs** between this older compiled package source and the current repository. Other whole-browser files and configuration are **not** claimed source-matched.

The workflow launched the real native Vulpra browser under stock geckodriver in a disposable HOME/profile, blocked nonlocal connections, preserved an unrelated Firefox profile sentinel, and used a fixed synthetic Hungarian word in `lang=hu` / `lang=hu-HU` test elements with fixed CSS dimensions. It compared `hyphens:auto` versus explicit `hyphens:none`, and tested a deliberately unsupported `zz-ZZ` locale and an English control. Six negative geometry-evidence fixtures were rejected.

## Observed browser geometry

| Test comparison | Result |
| --- | --- |
| Hungarian `hu`, `hyphens:auto` versus `hyphens:none` | **Additional line wrapping observed** |
| Hungarian `hu`, `hyphens:auto` versus unknown `zz-ZZ` `hyphens:auto` | **Additional Hungarian wrapping observed** |
| Hungarian `hu-HU`, `hyphens:auto` versus Hungarian `hyphens:none` | **Additional line wrapping observed** |
| English `en-US`, `hyphens:auto` versus `hyphens:none` | **Additional line wrapping observed** |

These are actual DOM range/element geometry measurements, not screenshots or subjective appearance. They prove the shipped browser can render automatically hyphenated Hungarian text under the tested font, word and viewport; **they do not test a browser with `hyph_hu.hyf` removed**. Font differences, language aliases, CSS settings and page layout can affect exact outcomes. Unknown-language fallback is a negative control, **not identical to a deliberately omitted Hungarian pattern**.

## Debloating decision

The historical normal package's `omni.ja` carries **1,048,764 uncompressed ZIP-entry bytes** for `hyphenation/hyph_hu.hyf`. The observed Hungarian-specific line breaking is a real capability, so **keep the default Hungarian pattern**. Its omission is not a harmless language-agnostic size optimization.

A future smaller optional language bundle would need an explicit user-visible or installation fallback and tests that preserve correct `hu` and `hu-HU` page behavior, source-matched native/Wayland/WebExtension/profile acceptance and real paired compressed package measurements. There is **no validated removable compressed byte count** and no accepted source omission.

This upgrades a localized-resource subcase from source-only investigation to **real native behavior protection**, not a passed whole M3 gate. **M3 2/6 (33%), overall Vulpra 44%, Δ0 pp.**
