# Wayland graphical startup acceptance

Vulpra is Linux x86-64 / Wayland / Hyprland-first. Ordinary `MOZ_HEADLESS=1` screenshot testing does **not** verify the graphical Wayland stack.

`packaging/test-wayland.sh` launches a private Weston headless compositor using the CPU Pixman renderer, verifies the Wayland protocol registry with `wayland-info`, and then starts the staged Vulpra browser with `GDK_BACKEND=wayland`, `MOZ_ENABLE_WAYLAND=1`, no X11 `DISPLAY` and **without** `MOZ_HEADLESS`. The test requires the launched process to remain alive for a bounded interval and to create only its private Vulpra profile. Weston is a Wayland compatibility proxy; it is **not** a Hyprland integration test.

The standalone harness CI initially uses a mock executable for startup/early-exit assertions. This proves the harness works, **not that real Vulpra works under Wayland**. Once a native package exists, integrate this as a separate real-browser CI step and record its result in the M2 progress ledger. Only an actual browser passing the test may satisfy the initial Wayland startup acceptance evidence. Full Hyprland and graphics/extension compatibility remain distinct tests.

Weston reference: https://wayland.pages.freedesktop.org/weston/toc/running-weston.html
