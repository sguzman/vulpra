# Nix development environment for Vulpra

**Scope:** repeatable Linux x86-64 developer tools and wrappers for the existing Mozilla
`mach` build and isolated Vulpra QA. **Not** a system-wide Nix migration, an
already-verified native browser build, an installation method, or a Firefox release.

The flake deliberately lives in `nix/` rather than in the Firefox source root.
An ordinary `nix develop ./nix` therefore does **not** copy the enormous
Firefox source tree into the Nix store. No Nix operation here deletes or
reconfigures the existing `obj-vulpra-linux` build directory.

## Enter the toolchain

Nix is installed separately on the developer workstation; this repository
does not install Nix, require NixOS, modify system configuration or reboot.

Enable the `nix-command` and `flakes` experimental features for the command
if they are not already configured (see https://nix.dev/concepts/flakes).

From a complete Vulpra checkout, in the user's Fish shell:

```fish
nix --extra-experimental-features 'nix-command flakes' develop ./nix --command fish
vulpra-dev doctor
vulpra-dev check
```

To issue a one-shot read-only check:

```fish
nix --extra-experimental-features 'nix-command flakes' develop ./nix --command vulpra-dev doctor
```

`nix run ./nix#vulpra-dev -- help` is also available, but mutating/native
workflows refuse to execute unless `VULPRA_NIX_DEV=1` has been set by the
Nix devShell. Do not set that variable by hand to bypass the guard.

### Native development commands

| Command | Effect |
| --- | --- |
| `vulpra-dev doctor` | Inventory basic local toolchain and preserve-only local mozconfig status |
| `vulpra-dev source` | Check tracked source completeness and sparse checkout status |
| `vulpra-dev check` | Syntax-check existing guarded CI/local shell workflows |
| `vulpra-dev configure` | Existing `./mach configure`, no source rewriting |
| `vulpra-dev build` | Existing locked `ci/build-local.sh` native build and logging |
| `vulpra-dev package` | Existing isolated package/smoke runner |
| `vulpra-dev smoke` | Existing private native headless test |
| `vulpra-dev wayland` | Existing private Weston/Wayland QA |
| `vulpra-dev accept` | Existing private localhost JS and archive acceptance |
| `vulpra-dev webext` | Existing private WebExtension lifecycle |
| `vulpra-dev mach ARGS` | Delegate arbitrary commands to this source checkout's `./mach` |

Commands never install or replace Firefox Developer Edition and do not select
its profile. The environment contains GCC/Clang-related tooling, Rust, the
Gecko Python build prerequisites, JS runtime (not a request to use npm),
assembler, developer instrumentation, graphics headers, Weston and WebDriver.

**Local mozconfig is intentionally not replaced.** Your existing
`~/.mozbuild/vulpra-local.mozconfig` includes a workstation-specific WASI
sysroot override. `ci/mozconfig-linux` is a different CI configuration, and
the Nix shell will **not** silently substitute it. A failed doctor/console
check is safer than a long broken browser rebuild.

## Reproducibility boundary and verification

The versioned `flake.lock` pins nixpkgs for toolchain resolution. It does
not guarantee byte-identical Firefox native artifacts by itself: actual
Gecko builds also depend on source SHA, `MOZCONFIG`, toolchain integration,
WASI sysroot, mach bootstrap, dynamic libraries, host graphics and full native
tests. Do not use a green flake evaluation or a shell test to close a Vulpra
product/security milestone.

CI must check `nix flake check ./nix`, realize the dev shell and validate
`vulpra-dev doctor` and shell guards. Separate **real native build,
package, WebDriver and target EndeavourOS/Hyprland runtime** gates are tracked
in [issue #10](https://github.com/sguzman/vulpra/issues/10). These cannot be
replaced with synthetic fixtures.

To deliberately update dependencies: review changes to `nix/flake.lock`,
run `nix flake update ./nix` with the intended maintenance window, then
re-run all Nix checks and native acceptance before calling the upgrade safe.

## Why not nix-build the entire Firefox tree immediately?

That would be a materially separate packaging effort and could trigger huge
source-store copies and duplicate old build artifacts. Start by making the
toolchain **declarative, usable and testable**, then implement a bounded,
source-pinned native browser derivation only after the exact compiler/WASI,
offline dependency, sandbox and runtime boundaries are demonstrated.

No `npm`, system FIPS change, Flatpak, new desktop profile or source
pruning is introduced by this tooling. Native work remains serial per
workspace through the existing build wrapper.
