# First successful local Vulpra run — EndeavourOS/Hyprland QA, 2026-11-09

## Actual user-run test (not CI or an invented native rebuild)

The owner recovered and synchronized an existing, enormous partial Vulpra checkout at `/home/sguzman/Code/Apps/vulpra` using successful filtered Git fetch and `git merge --ff-only FETCH_HEAD`. The working tree was clean and the original downloaded object store was retained; no destructive reset or reclone occurred. It synchronized through `46b3970224939fbb98abdac742c03d67ea93b758` when checked.

The existing *previously built* `obj-vulpra-linux/dist/vulpra/vulpra` ELF launcher was executed locally under Hyprland/Wayland, with `MOZ_ENABLE_WAYLAND=1` and `GDK_BACKEND=wayland`. No compilation or system install was needed. **The browser opened real websites and displayed Vulpra branding**, including its fox image and renamed settings/troubleshooting interface. The local binary reported **Vulpra 159.0b5, build ID 20261026084702**. The packaged ELF was stripped; `obj-vulpra-linux/dist/bin/vulpra` had debugging symbols with the same ELF Build ID.

A disposable `mktemp` QA profile was first used; then the owner relaunched with a **persistent, isolated Vulpra QA profile** `~/.local/share/vulpra/qa`. `about:support` directly confirmed that exact profile directory and a startup cache written under it. This means settings and bookmarks in the persistent QA profile can survive restarts. The user was advised not to make Vulpra the default browser or import real account credentials in this security-incomplete build.

## Graphics and codec observations: strict limits

- `about:support`: `Window Protocol = wayland`, `Desktop Environment = hyprland`, `Compositing = WebRender`.
- Browser WebGL1/WebGL2 reported **Mesa/radeonsi AMD Ryzen 9 7950X integrated GPU active**, **NVIDIA PCI 0x10de:0x2204 inactive** for this browser's graphics. So don't call Vulpra's browser graphics NVIDIA accelerated.
- `DMABUF_SURFACE_EXPORT` graphics decision reported **blocked by gfxInfo / FEATURE_FAILURE_BROKEN_DRIVER**; `WEBRENDER_COMPOSITOR` reported blocklisted. These are feature decisions, not proof of all DMA-BUF imports or exports failing.
- Separate read-only host checks confirmed NVIDIA GeForce **RTX 3090** with driver **615.78.08**, `/dev/dri/renderD129` NVIDIA vendor, both userspace render nodes accessible, and installed VA-API/GBM/DRM libraries.
- Separate **FFmpeg** tests on the *host*, not in Vulpra: H.264 CUDA output format `cuda`, 5/5 frames; H.264 VA-API output format `vaapi`, 5/5 frames; VP9 Profile 0 VA-API output format `vaapi`, **10/10 frames**. The bridge was explicitly selected by `LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct`. These results support actual host decoding, **not** Vulpra media-process VA-API/DMABuf operation.

No browser GPU device selection, VA-API in Vulpra, hardware DMA-BUF imported frame or complete loader/FFI closure was verified. The earlier native Weston/Pixman CI VP9 tests were separate and cannot be substituted for this hardware test.

## First real website compatibility bug: Google legacy UI

The original local Vulpra User Agent reported:

```text
Mozilla/5.0 (X11; Linux x86_64; rv:159.0) Gecko/20100101 Vulpra/159.0
```

Google Search presented a simplified/legacy layout, while Bing rendered normally. In the isolated QA profile, temporary `general.useragent.override` with a Firefox token restored Google's modern interface. Crucially the owner then removed that override and enabled **the existing** `general.useragent.compatMode.firefox=true`: Google continued to render its modern layout, including dark mode, retaining Vulpra identity. The owner had originally spotted this Boolean preference, so this should be the solution rather than inventing a hardcoded full override.

**Permanent source-only fix:** [`64426cb`](https://github.com/sguzman/vulpra/commit/64426cb2ef9077d6a2a9ab6cd7ab568efdcd705b) enables the built-in Firefox compatibility token in the browser-specific `browser/app/profile/firefox.js`. The existing `nsHttpHandler::BuildUserAgent` appends Firefox compatibility plus Vulpra when the app is non-Firefox. Generic `all.js` and application branding are preserved. [Regression CI **42733163567 PASS**](https://github.com/sguzman/vulpra/actions/runs/42733163567) with 5/5 hostile fixtures rejected; [workflow lint **42733163400 PASS**](https://github.com/sguzman/vulpra/actions/runs/42733163400); [build/recovery guard **42733121502 PASS**](https://github.com/sguzman/vulpra/actions/runs/42733121502). No native rebuild yet; the existing local binary continues to rely on the persisted user preference. [Issue #5](https://github.com/sguzman/vulpra/issues/5) tracks real native acceptance on the next build.

## Next manual QA without disturbing the working setup

Continue ordinary low-risk dogfooding within `~/.local/share/vulpra/qa`, and report real site issues in issue-specific tickets. For **source fix acceptance** only after a future safe native build: use a **fresh disposable profile** with no `general.useragent.override` and no user-created compatibility pref; check default Firefox compatibility is true, Vulpra token remains, Google receives modern search results, and normal branding/profile isolation still works. No need to compile Firefox just to repeat the already accepted source-level test.

**Project checkpoint remains M3 5/6 gates (83%), overall 61%, Δ+0 percentage points.** First local browser launch and Google compatibility workaround are verified, but they do not independently close the entire dependency, security, target GPU/DMA-BUF or release gates.
