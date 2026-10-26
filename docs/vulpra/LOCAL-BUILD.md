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

## 3. Later acceptance gates

A successful native build alone is not a shipped browser. Remaining gates include `./mach package`, isolated native launch/profile checks, Wayland rendering and navigation, extension/security smoke checks, and measured build/runtime behavior. Each gate requires actual execution evidence before crediting the roadmap.

**Git workflow:** Development is on `main`; the workstation downloader remains pinned to its original local HEAD, and no Git pull is required merely to use the standalone local-build runner. The full hosted-build workflow is manual-only. Do not restart hosted full builds as a substitute for the workstation build.
