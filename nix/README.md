# Nix development environment for Vulpra

**Scope:** repeatable Linux x86-64 developer tools and wrappers for the existing Mozilla
`mach` build and isolated Vulpra QA. **Not** a system-wide Nix migration, an
browser installer, system-level Nix migration, or an official Firefox release.

The flake lives in `nix/`, but plain `nix develop ./nix` is implicitly a
`git+file:` reference to the **entire Firefox Git checkout**. Always use the
versioned `./nix/vulpra` launcher, which now passes an explicit
`path:<absolute-checkout>/nix` flake reference and sends **only `nix/`**
to the Nix store. Native compilation still runs in the live checkout on
`main`. No Nix operation deletes or reconfigures the historical
`obj-vulpra-linux/` build directory.

## Current local Vulpra build on main (Firefox 160.0.1)

**Firefox 160.0.1 source is committed in `main` itself.** In particular,
`browser/config/version.txt` is `160.0.1`. The previous Firefox159 root
source has been replaced in Git history by a normal forward commit; no
alternate development branch is required. History remains intact.

The normal build runs `mach configure` and `mach build` **in this
repository's checked-out source**, via the pinned Nix/nom developer shell.
It never downloads or clones another Mozilla source tree and never downloads
a precompiled Vulpra/CI browser artifact.

```fish
./nix/vulpra status
./nix/vulpra build
```

The new compiler output lives in the ignored
`obj-vulpra-main-160/` directory. The historical
`obj-vulpra-linux/` directory is not reused or deleted. A generated
`mozconfig` in `~/.cache/vulpra/main160/mozconfig` carries the known Linux
Vulpra settings, explicit Nix libclang and optional sccache; it does not
rewrite personal mozconfig files or installed Firefox profiles.

Other commands:

```fish
./nix/vulpra configure
./nix/vulpra build --jobs 8
./nix/vulpra run
./nix/vulpra package
```

The first build can still cause **Nix and Mozilla build tools** to obtain
missing toolchain/build dependencies; that is distinct from downloading a
second Firefox source tree. The old
`./nix/vulpra build --fetch-source` command is deliberately rejected as
obsolete. `status` and `run` do not enter Nix.

The Vulpra-specific project directories `ci/`, `nix/`, `scripts/`,
`packaging/`, and `docs/vulpra/` are retained on `main`. Native
compilation on the EndeavourOS/Hyprland workstation **passed on 2026-11-20**,
producing `obj-vulpra-main-160/dist/bin/vulpra`. Packaging and GUI runtime
acceptance remain unverified.

## Enter the toolchain with Nix Output Monitor

Nix/Lix is installed separately on the workstation. Enable `nix-command` and
`flakes` once in `~/.config/nix/nix.conf`; see https://nix.dev/concepts/flakes.

**Preferred route:** run the versioned nom-first Vulpra launcher from a
complete checkout. The launcher uses a `nom` already on PATH or automatically
obtains the pinned `path:<checkout>/nix#nom` via `nix shell` if missing; no user-profile
installation is required. Only the very first `nom` bootstrap necessarily
uses Nix's default output.

To make `nom` available outside Vulpra as well, you **may optionally** install
it once into your user profile with `nix profile install "path:$PWD/nix#nom"` from the repository root.

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

The launcher delegates to `nom develop "path:<checkout>/nix" --command ...`, monitors Nix's
dependency realization, preserves Nix error codes, and forwards native tasks
to the guarded `vulpra-dev` CLI. `nom develop` can evaluate the Nix shell
twice; it does **not** execute the native command twice. It cannot monitor
`mach build`'s C++/Rust compiler steps as Nix derivations: those retain the
ordinary native build log and one-build-per-workspace locking.

**Do not interrupt an active Nix realization or Firefox build just to switch
to the launcher.** The launcher takes effect on the next invocation and does
not change any global shell aliases or overwrite personal Nix configuration.
If bypassing `nom`, use `nix develop "path:$PWD/nix" --command fish`
from the repository root. Using `nix develop ./nix` directly will again
copy the large Git checkout into the store.

`nix run "path:$PWD/nix#vulpra-dev" -- help` works from the repository root,
but mutating
native workflows refuse to execute unless `VULPRA_NIX_DEV=1` was set by the
developer shell. Do not set it manually to bypass the guard.

### Native development commands

| Command | Effect |
| --- | --- |
| `vulpra-dev doctor` | Inventory basic local toolchain and preserve-only local mozconfig status |
| `vulpra-dev source` | Check the historical imported source checkout (not the 160 build) |
| `vulpra-dev check` | Syntax-check existing guarded CI/local shell workflows |
| `vulpra-dev configure` | Configures the committed Firefox 160.0.1 source on `main` in its separate new object directory |
| `vulpra-dev build` | Configure and incrementally compile committed Firefox 160.0.1 source directly on `main` |
| `vulpra-dev package` | Package the same locally compiled Firefox 160.0.1 and smoke-test its private profile |
| `vulpra-dev smoke` | Existing private native headless test |
| `vulpra-dev wayland` | Existing private Weston/Wayland QA |
| `vulpra-dev accept` | Existing private localhost JS and archive acceptance |
| `vulpra-dev webext` | Existing private WebExtension lifecycle |
| `vulpra-dev mach ARGS` | Delegate arbitrary commands to this source checkout's `./mach` |

Commands never install or replace Firefox Developer Edition and do not select
its profile. The environment contains GCC/Clang-related tooling, Rust, the
Gecko Python build prerequisites, JS runtime (not a request to use npm),
assembler, developer instrumentation, graphics headers, Weston and WebDriver.

**Mozconfig separation:** `./nix/vulpra build` creates a local
`~/Code/Builds/vulpra-160.0.1/config/mozconfig` based on the pinned CI
Firefox160 configuration plus Nix-provided shared libclang. It neither
overwrites your historical `~/.mozbuild/vulpra-local.mozconfig` (which
has a workstation WASI override) nor writes to the old Firefox159 object
directory. The historical `./nix/vulpra mach ...` command still uses the
tracked `nix/mozconfig-overlay.sh` shim with your unchanged original
mozconfig. Nix's developer shell supplies the WASI toolchain for both.
An actual on-workstation 160 build remains to be verified.

This shim is needed because Mozilla's
`build/moz.configure/bindgen.configure` doesn't automatically discover
Nix's split shared-libclang output by searching generic `LIBCLANG_PATH`.
The Nix devShell also exports `LIBCLANG_PATH` for Rust binding generators.
`vulpra-dev doctor` now checks that an actual `libclang.so*` is available,
not just the `clang++` executable. A successful configure is still not a
successful browser compilation.

### Native assembler driver selection

Mozilla's `build/moz.configure/toolchain.configure` uses the **C compiler
driver**, not standalone GNU `as`, to compile native assembly in GCC/Clang
builds. The pinned Nix development shell previously inherited
`clang-wrapper/bin/as` as `AS`, but Mozilla's `config/rules.mk` passes
compiler-driver options including `-Wa,--noexecstack`, `-fPIC`, `-include`
and `-gdwarf-4`. A workstation `mach build` therefore failed at
`config/external/nspr/pr/os_Linux_x86_64.o` with
`Fatal error: invalid listing option ','`.

The Vulpra-only Nix devShell now exports `AS` as the **same pinned native
GCC compiler driver** used by `mach configure`. It does not alter a
system-wide environment, the personal mozconfig, the installed browser,
or built outputs; the current `./nix/vulpra build` configures its separate
Firefox 160 object directory with the corrected native assembler. `test-native-assembler.sh` runs a native assembly smoke with
the actual failed flags in CI before another full browser build is attempted.
This is an isolated assembler check, **not full browser-build acceptance**.

### WASM cross-compiler isolation

The workstation's preserved `--with-wasi-sysroot=/usr/share/wasi-sysroot`
is still authoritative. Mozilla selects its WebAssembly C/C++ compilers via
`WASM_CC`/`WASM_CXX`, separately from native `CC`/`CXX`. Nix's ordinary
`clang` is a host cc-wrapper that injects x86-only hardening flags (including
`-fzero-call-used-regs=used-gpr`), which LLVM rejects when targeting
`wasm32-wasi`. A subsequent workstation configure exposed the missing `wasm32-wasi`
`libclang_rt.builtins.a` archive in the **host** unwrapped LLVM resource
directory. The Nix shell now defaults those **WASM-only** variables to
the pinned `pkgsCross.wasi32.stdenv.cc` cross-compiler wrapper, supplying
WASI-targeted compiler-rt while retaining native compilers, the existing
`sccache` configuration, the original workstation WASI sysroot and
explicit user overrides. The `test-wasm-compiler.sh` CI gate now actually
**preprocesses and links** C and C++ programs with `--target=wasm32-wasi`.
This is focused toolchain evidence, not a successful workstation
`mach configure` or entire Firefox build.


## Reproducibility boundary and verification

The versioned `flake.lock` pins nixpkgs for toolchain resolution. It does
not guarantee byte-identical Firefox native artifacts by itself: actual
Gecko builds also depend on source SHA, `MOZCONFIG`, toolchain integration,
WASI sysroot, mach bootstrap, dynamic libraries, host graphics and full native
tests. Do not use a green flake evaluation or a shell test to close a Vulpra
product/security milestone.

CI must check `nix flake check "path:$PWD/nix"`, realize the dev shell and validate
`vulpra-dev doctor` and shell guards. Separate **real native build,
package, WebDriver and target EndeavourOS/Hyprland runtime** gates are tracked
in [issue #10](https://github.com/sguzman/vulpra/issues/10). These cannot be
replaced with synthetic fixtures.

To deliberately update dependencies: review changes to `nix/flake.lock`,
run `nix flake update "path:$PWD/nix"` with the intended maintenance window, then
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

### Native xsum format-security warning integration (2026-11-17)

After NSPR assembly was repaired, the incremental workstation browser build
reached `js/src/xsum/xsum.cpp` and stopped at:
`cc1plus: error: '-Wformat-security' ignored without '-Wformat'
[-Werror=format-security]`. The Nix GCC wrapper enforces this hardening,
but the xsum per-file `moz.build` had explicitly disabled its prerequisite
warning group with `-Wno-format`. The minimal correction removes **only**
that per-file suppression. It does not relax `-Wformat-security`,
`-Werror=format-security`, the native GCC wrapper, or Mozilla hardening.

The sparse Nix CI workflow now compiles the **real vendored xsum.cpp**
with the pinned compiler and the hardened format-warning flags. This is
focused compiler evidence only; the full workstation browser build and
package/runtime tests remain separate acceptance gates.

### Native linker isolation: keep WASI runtime out of x86-64 linker inputs

On 2026-11-17 the workstation's incremental Firefox build failed while
linking `config/external/sqlite/libmozsqlite3.so` with
`ld.bfd: ...compiler-rt-static-wasm32-unknown-wasi.../lib/libgcc.a:
error adding symbols: file format not recognized`. This was a **target
architecture collision**, not a SQLite source error.

The initial WASI support put `pkgs.pkgsCross.wasi32.stdenv.cc` directly in
the native `mkShell.packages`. Its cross-target library search paths could
then be activated for native GCC links. The WASI compiler is now retained
through `WASM_CC` and `WASM_CXX` absolute paths from `shellHook` instead
of including the cross CC in the native shell's package list. Its Nix store
derivation is still realized through those explicit references, but its
cross setup inputs are not applied to the native linker environment.

CI runs *both* `test-wasm-compiler.sh` (real WASI C/C++ links)
and `test-native-linker.sh` (native x86-64 shared link requiring
`libgcc`, plus environment contamination checks). This does not prove the
full Firefox native build: the workstation must re-enter its Nix shell,
reconfigure, and retry the exact SQLite link target, preserving the
existing object directory.

### WASI C++ linker isolation and the first CI regression

The first native/cross isolation change (`1af06795`) deliberately removed
the WASI compiler from native `mkShell.packages` to prevent native
`libgcc.a` linker collisions. Its initial CI run correctly caught a
secondary problem: the standalone WASI `clang++` compiler then could not
find target `-lc++` or `-lc++abi`, even though C linking worked.

The corrected default `WASM_CXX` is a small, dedicated shell-script
wrapper that invokes the same pinned cross `clang++` with a
target-specific `-L` pointing at
`pkgs.pkgsCross.wasi32.llvmPackages.libcxx`. Nixpkgs' own Mozilla build
also supplies the WASI C++ libraries from that target package. The
cross-compiled archive is **never** placed in native `NIX_LDFLAGS`.
The C compiler remains the original cross wrapper. Users' explicit
`WASM_CC` and `WASM_CXX` overrides remain respected.

Both real WASI C/C++ link tests **and** the native x86-64 shared link
regression must pass in CI before the workstation is asked to pull. The
workstation's independent mozconfig, build cache and object directory
remain unchanged.


### Nixpkgs Xorg attribute deprecation cleanup (2026-11-17)

The native browser acceptance log showed the same 12 Nixpkgs `xorg.*`
deprecation warnings twice during flake evaluation. The pinned nixpkgs
release supplies the equivalent root-level attributes (`libx11`,
`libxext`, `libxrender`, `libxcomposite`, `libxdamage`, `libxt`,
`libxi`, `libxrandr`, `libxcursor`, `libxfixes`,
`libxinerama`, `libxcb`). The toolchain shell now uses those
attributes and its CI script contract rejects reintroduction of
`xorg.lib*` names. This changes the Nix declarations only, not
Firefox source, profiles, native object files, or host Xorg/Wayland setup.

Other warnings have different owners: the fontconfig parse errors from
`/etc/fonts/conf.d/` must be diagnosed in the isolated runtime versus
host fontconfig, Remote Settings network startup errors require an online
security-service verification, and the completed build's compiler warnings
require separate source-level triage; do not suppress these globally.


### Fontconfig version-matched configuration on Arch hosts (2026-11-17)

On the EndeavourOS workstation, `fc-match sans-serif` outside Nix
returns `Noto Sans Regular` without any warnings. Inside the pinned
Vulpra Nix shell, the same command returns the same family but produces
dozens of XML parser warnings from host `/etc/fonts/conf.d/48-guessfamily.conf`,
`48-spacing.conf`, and `49-sansserif.conf` (notably `xsi:nil`).

The pinned Nix-linked Fontconfig library may not support the newer Arch
Fontconfig XML grammar. The devShell therefore defaults `FONTCONFIG_FILE`
to `${pkgs.fontconfig}/etc/fonts/fonts.conf`, giving the library its
matching standard configuration rather than the host's newer
`/etc/fonts/fonts.conf`. This uses the package's own font directories
and user config include rules, **without changing /etc/fonts or the host
environment**; callers can override `FONTCONFIG_FILE` explicitly.
Host/GUI font-family parity still needs a workstation check: check
`fc-match sans-serif` and compare to the host's Noto Sans result before
declaring the fix fully accepted.

The sparse CI job checks readable pinned config, sans-serif lookup, and
the absence of XML parse errors, without running a full browser build.

#### Nix multi-output path correction

The initial CI run [44160856394](https://github.com/sguzman/vulpra/actions/runs/44160856394)
correctly rejected a `FONTCONFIG_FILE` that pointed to the
`fontconfig-2.17.1-bin` output (which has no `etc/fonts/fonts.conf`).
Nixpkgs Fontconfig is a multi-output package. The configuration belongs
to `pkgs.fontconfig.out`; the shellHook now points there explicitly.
This was caught before a workstation pull or release. Never downgrade
or edit host Fontconfig to work around the path.


#### Why the first config-path-only fix passed Ubuntu but failed on Arch

Workstation `fc-match` with [`169b0688`](https://github.com/sguzman/vulpra/commit/169b06888b31b3cdcd4ab74afb324aa5b01a7fbd)
still selected Noto Sans **and emitted the same XML warnings**. The exact
reason is in the pinned Nixpkgs 2.17.1 package definition:
`pkgs/development/libraries/fontconfig/default.nix` invokes
`make-fonts-conf.xsl` with `--stringparam includes /etc/fonts/conf.d`.
That explicitly imports Arch's system rule files even from a
`FONTCONFIG_FILE` inside the Nix store. The earlier CI checked only
font resolution and warnings on Ubuntu, where those host rules were
compatible: it didn't check which system rule files were loaded.

Vulpra now builds a tiny version-matched **configuration-only** Nix
derivation. It copies the packaged fonts.conf, substitutes the one
`/etc/fonts/conf.d` import with the pinned Nix Fontconfig rule
directory, and adds `/usr/share/fonts` and `/usr/local/share/fonts`
as **font directories** (not config directories). It keeps XDG user
fonts and explicit `FONTCONFIG_FILE` overrides. No native browser
sources or compiled objects are rebuilt.

The CI test now runs `fc-conflist` and rejects actual loading of
host `/etc/fonts/conf.d` rules, in addition to requiring successful
sans-serif matching without parser warnings. This is the missing
cross-distribution regression check. Local parity is still required to
confirm the EndeavourOS host's Noto Sans match is unchanged.
