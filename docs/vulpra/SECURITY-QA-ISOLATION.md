# Vulpra: isolated security QA while dogfooding

**Status:** Source-worktree, QA binary-copy, independent native QA-build path and isolated headless-smoke infrastructure are implemented. Offline synthetic CI validates the separation contract, including a fake `mach configure/build`. **No actual QA worktree has been created on the user's workstation, no separate Firefox 160.0.1 QA build has run, and no sandbox/TLS/extension security acceptance is claimed.**

## The two environments

| | Daily Vulpra | Security QA |
| --- | --- | --- |
| Source | `~/Code/Apps/vulpra` on bleeding-edge `main` | `~/Code/Apps/vulpra-security-qa` — detached worktree pinned to a specific `main` commit |
| Executable | Existing native `obj-vulpra-main-160/dist/bin/vulpra` | Explicit checksum-checked copy under `vulpra-security-qa/obj-vulpra-security-qa/snapshots/`, **or**, after a separate opt-in build, `vulpra-security-qa/obj-vulpra-security-qa-build/dist/bin/vulpra` |
| Profile | `~/.local/share/vulpra/default` (persistent) | New per-run `obj-vulpra-security-qa/runtime/run.*/profile` (disposable test data) |
| HOME and XDG data/config/cache | Ordinary user environment | New isolated per-run paths under the QA worktree |
| Launch | `./nix/vulpra run` | Explicit `security-qa headless` (snapshot) or `security-qa headless-build` (QA-compiled binary); neither opens a GUI window |
| Automatic sync/replacement | **Never** | **Never** |

The QA worktree shares Git **object storage**, not its checked-out files/index, browser profile, build directory or executable snapshot. Its **snapshot** is a copy of the already compiled main browser; the separate **build** command instead compiles the QA worktree source into its own object directory and requires the pinned Nix environment. The copying step is opt-in and may consume significant disk space. The original snapshot from November 20 remains usable with its two-field legacy manifest; no re-copy is required. Nothing copies or migrates cookies, passwords, history, Vaultwarden data, the Firefox Developer Edition profile, or the day-to-day Vulpra profile.

## Commands (from the regular Vulpra checkout)

All the following operations **except the explicitly named build** bypass Nix and do not download dependencies; none installs or replaces the daily browser:

```bash
./nix/vulpra security-qa status
./nix/vulpra security-qa setup
./nix/vulpra security-qa snapshot
./nix/vulpra security-qa verify
./nix/vulpra security-qa headless
./nix/vulpra security-qa sync
./nix/vulpra security-qa build --jobs 2
./nix/vulpra security-qa headless-build
```

- **status** is read-only. It reports whether the detached QA source worktree and selected QA binary snapshot exist.
- **setup** creates the **previously nonexistent** sibling `vulpra-security-qa` directory by `git worktree add --detach` using the current committed `main` HEAD. It does not touch the live checkout or copy a browser binary. It refuses to overwrite an existing destination. Full Firefox source checkout can take substantial disk space.
- **snapshot** explicitly copies the already compiled native Vulpra `dist/bin` payload to a private QA directory with symlinks dereferenced, checks the binary and application identity/checksums, and selects an immutable name based on `main` commit and executable hash. It refuses to overwrite an existing snapshot or combine differing QA and main commits. **This checks copied bytes, not build reproducibility or correspondence of the executable to the Git source commit.**
- **build** (explicitly opt-in) enters the pinned `path:<QA worktree>/nix` Nix shell with `nom`, derives an isolated mozconfig under `obj-vulpra-security-qa/native.mozconfig`, and runs `mach configure` + `mach build` with outputs under `obj-vulpra-security-qa-build/`. It never changes the live `main` build scripts, their object directory or any browser profile. Default parallelism is **2** to reduce interference during dogfooding. A separate full Firefox build consumes substantial CPU, memory, disk and time; **it has not been executed on the real workstation**.
- **headless-build** runs only the already compiled QA worktree executable in the same private per-run environment used by `headless`, failing closed when the QA binary is absent.
- **verify** is read-only and checks the selected QA snapshot's copied executable SHA-256 against its manifest and source-commit-based snapshot ID; new copies also carry an `application.ini` SHA-256. Older snapshots remain valid after checking ELF hash and application identity/version. The `headless` command calls this check before launching; it refuses altered copies and never touches the original compiled browser or any daily profile.
- **headless** runs only the selected copied QA executable under a new `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `--profile`. It loads only a synthetic local `file://` HTML fixture, requires a PNG screenshot, leaves a local QA-only log, and does not open a graphical window. It does not navigate to any real site, use real credentials or alter the active browser.
- **sync** (later, as new `main` changes accumulate): `./nix/vulpra security-qa sync` advances **only a clean detached QA source worktree** to the current committed `main` commit. It refuses to discard edited or untracked QA source and never replaces an existing binary snapshot or launches a browser.

## Security and scope limits

1. No automatic promotion to daily Vulpra: the active daily executable/profile are never switched by this script. Changes to `main` remain ordinary source commits until the owner explicitly rebuilds their browser.
2. Existing `./nix/vulpra qa` has a *separate profile* but uses the original `main` executable. Use `security-qa` when independent executable bytes matter.
3. A **separate native QA build command exists but has only passed an offline mocked build test**, not real Firefox compilation. Real QA compilation, a separately packaged WebDriver/security replay, and target Hyprland sandbox tests remain outstanding acceptance work. Do not count the synthetic CI fixture as browser-security proof.
4. Test-only contents in the QA state are under ignored `obj*/` paths. The script refuses existing destinations and symlinked QA state entrypoints; it never cleans the QA worktree or runs `git reset --hard`, `git clean`, or `rm` on the live source/profile. A temporary failed snapshot staging directory can be removed by its own cleanup handler.
5. Keep ordinary dogfooding active. For actual security acceptance, use **source-only GitHub Actions** first, then **isolated binary tests** against this QA snapshot, and schedule opt-in real Wayland/physical GPU latency comparisons only when needed. Physical GUI tests may momentarily take focus and are not invoked by any of the commands above.

## Evidence

- Offline synthetic QA infrastructure fixtures: [GitHub Actions worktree-isolation test](https://github.com/sguzman/vulpra/actions/workflows/security-qa-worktree-fixtures.yml). This checks source separation, no-Nix dispatch for non-build actions, copied test executable, clean source sync, **mocked QA-only build output and mozconfig**, temporary HOME/XDG/profile, and refusal to overwrite existing state. It is not a real Gecko/browser security pass.
- Security gate order and release holds: [Firefox 160.0.1 acceptance roadmap](SECURITY-ACCEPTANCE-ROADMAP-20261120.md).
- Formal progress baseline unchanged: **61% overall, Δ 0 percentage points**; security gates remain open until current real compiled/runtime evidence passes.
