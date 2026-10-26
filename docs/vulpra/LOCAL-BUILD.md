# Vulpra native Linux build

**Status:** The first native Vulpra browser has not been built or launched successfully. Mocked packaging and configuration checks are not proof of a functioning browser.

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

Build logs are stored in `.git/vulpra-native-build/`. The runner records the actual mach exit status and verifies that `obj-vulpra-linux/dist/bin/firefox` is executable and that `application.ini` reports `Name=Vulpra`.

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

## 5. Later acceptance gates

A successful native build alone is not a shipped browser. Remaining gates include `./mach package`, isolated native launch/profile checks, Wayland rendering and navigation, extension/security smoke checks, and measured build/runtime behavior. Each gate requires actual execution evidence before crediting the roadmap.

**Git workflow:** Development is on `main`; the workstation downloader remains pinned to its original local HEAD, and no Git pull is required merely to use the standalone local-build runner. The full hosted-build workflow is manual-only. Do not restart hosted full builds as a substitute for the workstation build.
