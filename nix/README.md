# Nix development environment for Vulpra

**Scope:** repeatable Linux x86-64 developer tools and wrappers for the existing Mozilla
`mach` build and isolated Vulpra QA. **Not** a system-wide Nix migration, an
already-verified native browser build, an installation method, or a Firefox release.

The flake deliberately lives in `nix/` rather than in the Firefox source root.
An ordinary `nix develop ./nix` therefore does **not** copy the enormous
Firefox source tree into the Nix store. No Nix operation here deletes or
reconfigures the existing `obj-vulpra-linux` build directory.

## Enter the toolchain with Nix Output Monitor

Nix/Lix is installed separately on the workstation. Enable `nix-command` and
`flakes` once in `~/.config/nix/nix.conf`; see https://nix.dev/concepts/flakes.

**Preferred route:** run the versioned nom-first Vulpra launcher from a
complete checkout. The launcher uses a `nom` already on PATH or automatically
obtains the pinned `./nix#nom` via `nix shell` if missing; no user-profile
installation is required. Only the very first `nom` bootstrap necessarily
uses Nix's default output.

To make `nom` available outside Vulpra as well, you **may optionally** install
it once into your user profile with `nix profile install ./nix#nom`.

Run:

```fish
./nix/vulpra doctor
./nix/vulpra shell
```

Within the shell, `vulpra-dev doctor`, `vulpra-dev check`, etc. work as before.
To perform a native build directly through the launcher:

```fish
./nix/vulpra source
./nix/vulpra build
```

The launcher delegates to `nom develop ./nix --command ...`, monitors Nix's
dependency realization, preserves Nix error codes, and forwards native tasks
to the guarded `vulpra-dev` CLI. `nom develop` can evaluate the Nix shell
twice; it does **not** execute the native command twice. It cannot monitor
`mach build`'s C++/Rust compiler steps as Nix derivations: those retain the
ordinary native build log and one-build-per-workspace locking.

**Do not interrupt an active Nix realization or Firefox build just to switch
to the launcher.** The launcher takes effect on the next invocation and does
not change any global shell aliases or overwrite personal Nix configuration.
The plain `nix develop ./nix --command fish` route remains available if
you want to bypass `nom` entirely.

`nix run ./nix#vulpra-dev -- help` remains available as well, but mutating
native workflows refuse to execute unless `VULPRA_NIX_DEV=1` was set by the
developer shell. Do not set it manually to bypass the guard.

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

### Archived browser versus Nix-built browser

The archived Firefox 160 package was originally compiled against the hosted
Ubuntu runtime, **not** built by Nix. Testing it from a Nix devShell is an
integration/replay test, not evidence that its ELF dependencies were built
by Nix. GTK can load plugins from `GDK_PIXBUF_MODULE_FILE`; a Nix-supplied
loader cache can be ABI-incompatible with host-built GTK. The separate
artifact-only Wayland replay therefore strips Nix GTK/GdkPixbuf plugin
cache variables **only for that disposable host-built browser test**. This
does not change the global shell, user's GTK configuration, or any profile.
A future truly Nix-built browser requires its own native configure, linker,
package and Wayland acceptance rather than relying on this workaround.
