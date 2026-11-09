# Target EndeavourOS/Hyprland GPU acceptance preflight — 2026-11-09 UTC

## Reason for this separate target check

Real native archived Vulpra package [42665579538](https://github.com/sguzman/vulpra/actions/runs/42665579538) demonstrably decoded VP9 frames, read the video into a 2D canvas, and created a WebGL2 context inside an isolated **non-headless Wayland browser** while one GBM/DRM provider request was denied before media-page navigation. The real source/package/harness-bound independent reconciliation [42678531306 PASS](https://github.com/sguzman/vulpra/actions/runs/42678531306) downloaded and audited the original evidence, preserving **GBM 1; VA-API 0**, with a separate classified artifact **13700428921**. That report was downloaded and independently inspected; it marks hardware GPU/VA-API/DMA-BUF fallback, final M3 gate and release **false**. [Workflow lint 42678531247 PASS](https://github.com/sguzman/vulpra/actions/runs/42678531247).

The test compositor was Weston **Pixman software rendering** on an Ubuntu-24.04 CI machine. A successful WebGL2 context and decoded VP9 frame there do not prove that the real target EndeavourOS/Hyprland hardware driver, DMA-BUF buffer path, VA-API backend, NVDEC/NVIDIA decoder, or accelerated compositing is functional. Another identical software runner cannot fill that gap.

## Read-only, opt-in target prerequisite inventory

The [small Bash program](../../ci/m3-arch-wayland-gpu-readiness.sh) was added as a strictly **passive** prerequisite inventory. It uses **no privilege elevation, no doas, no sudo, no package installation/update, no network calls, no browser process launch, no GPU API initialization, and no opening of render nodes**. It only checks:
- OS is Linux x86-64 and `XDG_SESSION_TYPE` classification (no session IDs or private paths are printed)
- whether Wayland and Hyprland session variables are present (their values are **not** emitted)
- how many `/dev/dri/renderD*` character devices exist and their apparent current-user read/write permissions
- whether each existing render node's public `/sys/class/drm/renderD*/device/vendor` PCI vendor ID is NVIDIA (0x10de), otherwise other/unknown; the vendor ID and device path are not published
- whether basic diagnostic commands `nvidia-smi`, `vainfo`, `vulkaninfo`, `ffmpeg`, `wayland-info` exist, and whether the pacman package database includes `nvidia-utils`, `libva-nvidia-driver`, `libva`, `libdrm` and `egl-wayland`

Presence/permission checks are **not** proof of working drivers or library ABI compatibility, and package absence does not imply a runtime is unavailable through alternate provisioning. The program does not inspect GPU serials, UUIDs, credentials, network or arbitrary environment variables.

**When the owner explicitly chooses to run target QA**, from a current Vulpra checkout on the EndeavourOS/Hyprland desktop:

```bash
bash ci/m3-arch-wayland-gpu-readiness.sh --inspect
```

It emits one bounded JSON object to the terminal. Do not silently run this on the owner's workstation or install dependencies; if `jq` is absent, the script fails with a clear message. After seeing that report, select the next small, opt-in functional GPU/VA-API test (if supported by the installed driver stack) and require real library requests/decoder outcome instead of declaring VA-API fallback based on video playback alone.

**Verified cheap contract CI:** [42679150145 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42679150145), including Bash syntax, self-test of the report schema and fail-closed hardware/release assertions, default refusal of unexpected active modes, and a no-side-effect inventory on the **Ubuntu runner only**. [Actionlint 42679150192 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42679150192). These CI runs did **not** inspect or validate the user's NVIDIA GPU.

## Remaining gates

Accept nothing as actual owner-machine GPU/VA-API/DMA-BUF operation until the owner runs an explicitly approved real target workload and the report includes actual device/driver/feature evidence. The global M3 sixth gate also requires complete native indirect/FFI/conditional dependency closure and updated security integration. No source pruning, packaged byte savings, release approval, or workstation changes are implied.

**M3 5/6=83%, overall Vulpra 61%, Δ+0 percentage points.**
