# Vulpra native Linux build

**Status (2026-10-26):** Native Vulpra was compiled and packaged successfully on the target Linux workstation, launched headlessly from its independent tar.xz with checksum/profile checks, and passed a real graphical startup test against isolated Weston (Wayland buffer attachments and commits). Actual automated navigation/JavaScript, extension/security smoke and real baseline measurement gates remain open.

## 1. Finish the full-source checkout

The current local download runs the resumable source tool against the pinned Vulpra source checkout. It can be restarted safely after connection failures:

`env VULPRA_BATCH_SIZE=32 bash ~/vulpra-fetch-all.sh`

Wait for the downloader's **SUCCESS: Complete tracked HEAD source checkout** message. This is a source-completion gate, not a browser build result. Do not disable sparse checkout independently, reset tracked files, delete Git objects, or reclone while recovery is underway.

The downloader stores its transcript at `.git/vulpra-complete-source/download.log`.

## 2. Run the local native build

The supported local toolchain configuration is `~/.mozbuild/vulpra-local.mozconfig`, which retains the Vulpra application basename and supplies `--with-wasi-sysroot=/usr/share/wasi-sysroot` on EndeavourOS. Do not silently replace this local override with the Ubuntu-targeted CI mozconfig.

For Fish, retrieve the small runner from this repository, then invoke it:

`curl -fL --retry 20 --retry-all-errors -o ~/vulpra-build-local.sh https://raw.githubusercontent.com/sguzman/vulpra/main/ci/build-local.sh`
`and bash ~/vulpra-build-local.sh`

The runner checks that sparse checkout is off and that no tracked working-tree files are missing, then invokes the existing `./mach build`. It does not reinstall Firefox, touch the Firefox Developer Edition profile, delete the object directory, or start a second Git source download.

Build logs are stored in `.git/vulpra-native-build/`. The runner records the actual `mach` exit status and credits native compiler success without assuming the executable must be named `firefox`. Native application identity and startup are verified separately by the no-rebuild startup probe.

## 3. Check native startup without recompilation

When `./mach build` reports **Your build was successful** and exits with zero,
do not rerun compilation just because the prior Vulpra wrapper could not find
its hardcoded `dist/bin/firefox` path. Mozilla's executable name can differ
from the application/display name. Source/build success is independent of the
package and runtime smoke-test gates.

Use the standalone probe to inspect `obj-vulpra-linux/mozinfo.json`, choose
the actual built browser executable, and perform an isolated local headless
startup without running `./mach build` or `./mach package`:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-smoke-native.sh https://raw.githubusercontent.com/sguzman/vulpra/main/ci/smoke-native-local.sh
and bash ~/vulpra-smoke-native.sh
```

The probe creates a temporary HOME/profile and local HTML test page. It
saves a PNG and diagnostics inside `.git/vulpra-native-build/`. It does not
touch the user's installed Firefox Developer Edition profile. It reports
exactly which prerequisite failed if no executable or application.ini is
present. A passing native headless smoke test does not certify packaged startup,
real Wayland UI behavior, extensions or security.

## 4. Package and smoke-test the compiled browser

Only after the native headless startup probe passes, retrieve the standalone
packaging runner. It uses the **existing native binary** and the pinned
workstation source without requiring a Git pull or copying any newer files
into that checkout:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-package-smoke-local.sh https://raw.githubusercontent.com/sguzman/vulpra/main/ci/package-smoke-local.sh
and bash ~/vulpra-package-smoke-local.sh
```

The runner invokes incremental `./mach package`, selects a valid Vulpra
archive, adds a **vulpra-launch** private-profile wrapper without overwriting
a native executable named `vulpra`, creates an independent tar.xz archive,
verifies SHA-256, and smoke-tests the packaged executable using a temporary
HOME. The native executable might be named `firefox` or `vulpra`; the
application.ini display identity must be `Vulpra`.

The output archive, checksum, screenshot and log persist under
`.git/vulpra-native-build/`. Compilation artifacts and the system Firefox
installation/profile remain untouched. Completed incremental packaging work
can be reused if interrupted; an incomplete compression/archive job may need
to repeat its unfinished work.

**Limit:** This package runner does not verify graphical Wayland startup,
extensions, navigation, security, or real runtime performance. Those remain
separate gates. Its CI mocks are not a substitute for the real package run.

## 5. Test packaged graphical Wayland without rebuilding

The existing package can be tested in an isolated Weston compositor without
installing the browser or disturbing the desktop Firefox profile:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-smoke-wayland-package.sh https://raw.githubusercontent.com/sguzman/vulpra/main/ci/smoke-wayland-package-local.sh
and bash ~/vulpra-smoke-wayland-package.sh
```

Requires `weston` and `wayland-info`. If either is unavailable the probe
explicitly reports NOT VERIFIED before touching the archive. It chooses the
latest verified `vulpra-local-*.tar.xz` package and its SHA-256 sidecar,
extracts privately, runs Weston with a private Wayland socket, starts
`vulpra-launch` with private HOME, checks for actual Wayland buffer attachment and frame commit in the client
protocol log (`wl_surface#13` on modern libwayland, as well as `@` object-ID
formatting), and checks the browser remains alive. Mere process uptime is not
accepted as a graphical test. Logs live under
`.git/vulpra-native-build/`. `Ctrl+C` cleans up child processes and the
temporary extracted archive. This still does not prove navigation,
extensions, security or visual accuracy.

## 6. Test packaged navigation, JavaScript, profile isolation and baseline

Retrieve the one-shot offline/localhost-only acceptance probe. It reuses the
existing staged package and requires no rebuild, Git pull, new dependencies,
browser installation or manual QA:

```fish
curl -fL --retry 20 --retry-all-errors -o ~/vulpra-accept-native.py https://raw.githubusercontent.com/sguzman/vulpra/main/ci/accept-native-package-local.py
and python ~/vulpra-accept-native.py
```

The probe verifies the tarball SHA-256, extracts to a temporary directory,
asserts that the private `vulpra-launch` wrapper refuses an external profile
override, and starts a loopback-only HTTP server on `127.0.0.1`. The real
browser must execute JavaScript on the initial page to navigate to
`/js-run`, follow an HTTP 302 redirect to `/page`, produce a PNG screenshot,
and preserve a preexisting fake Firefox profile untouched. All three HTTP
requests must appear in that order. A separate fetch/XMLHttpRequest API test
is not claimed: the previous synchronous XHR probe could finish too late for
the short-lived screenshot process and falsely reject genuine navigation. The real installed
Firefox and its profile are not used.

A successful run writes `acceptance-<date>.json`, browser startup logs and a
PNG under `.git/vulpra-native-build/`. Baseline fields include the archive
hash/bytes, executable size, optional libxul size, successfully completed
incremental `mach build` duration from the existing logs, measured
startup/navigation/screenshot wall time and sampled parent-process RSS.
Do not mistake parent RSS for total multiprocess Firefox memory. An
unsuccessful local run is not a product gate; only actual workstation PASS
counts. Synthetic negative-case regression tests pass in
https://github.com/sguzman/vulpra/actions/runs/40355994838.

## 7. Remaining acceptance gates

After actual navigation and baseline data, WebExtension loading/compatibility
and the remaining security checks still need independent observable evidence.
Passing the full gated suite is not a comprehensive browser security audit.
Only observed native results count as product progress.

**Git workflow:** Development is on `main`. The workstation checkout remains
pinned to its existing HEAD and can retain uncommitted local build patches.
Standalone runners are downloaded into the user's home directory; running
them never requires a source reset, full rebuild or Git pull. The hosted full
browser build remains manual-only.
