# Vulpra: isolated security QA while dogfooding

**Status:** Source-worktree, QA binary-copy, and isolated headless-smoke infrastructure is implemented. Offline synthetic CI validates the separation contract. **This does not mean the Firefox 160.0.1 browser passed actual sandbox/TLS/extension security acceptance.**

## The two environments

| | Daily Vulpra | Security QA |
| --- | --- | --- |
| Source | `~/Code/Apps/vulpra` on bleeding-edge `main` | `~/Code/Apps/vulpra-security-qa` — detached worktree pinned to a specific `main` commit |
| Executable | Existing native `obj-vulpra-main-160/dist/bin/vulpra` | Explicitly copied, checksum-checked snapshot under `vulpra-security-qa/obj-vulpra-security-qa/snapshots/` |
| Profile | `~/.local/share/vulpra/default` (persistent) | New per-run `obj-vulpra-security-qa/runtime/run.*/profile` (disposable test data) |
| HOME and XDG data/config/cache | Ordinary user environment | New isolated per-run paths under the QA worktree |
| Launch | `./nix/vulpra run` | Explicit `security-qa headless`; no GUI window |
| Automatic sync/replacement | **Never** | **Never** |

The QA worktree shares Git **object storage**, not its checked-out files/index, browser profile, build directory or executable snapshot. Its snapshot is a **copy** of the already compiled main browser, not a separate independently compiled build. The copying step is opt-in and may consume significant disk space. Nothing copies or migrates cookies, passwords, history, Vaultwarden data, the Firefox Developer Edition profile, or the day-to-day Vulpra profile.

## Commands (from the regular Vulpra checkout)

All the following bypass Nix, do not download dependencies and do not install/replace browsers:

```bash
./nix/vulpra security-qa status
./nix/vulpra security-qa setup
./nix/vulpra security-qa snapshot
./nix/vulpra security-qa headless
```

- **status** is read-only. It reports whether the detached QA source worktree and selected QA binary snapshot exist.
- **setup** creates the **previously nonexistent** sibling `vulpra-security-qa` directory by `git worktree add --detach` using the current committed `main` HEAD. It does not touch the live checkout or copy a browser binary. It refuses to overwrite an existing destination. Full Firefox source checkout can take substantial disk space.
- **snapshot** explicitly copies the already compiled native Vulpra `dist/bin` payload to a private QA directory with symlinks dereferenced, checks the binary and application identity/checksums, and selects an immutable name based on `main` commit and executable hash. It refuses to overwrite an existing snapshot or combine differing QA and main commits. **This checks copied bytes, not build reproducibility or correspondence of the executable to the Git source commit.**
- **headless** runs only the selected copied QA executable under a new `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `--profile`. It loads only a synthetic local `file://` HTML fixture, requires a PNG screenshot, leaves a local QA-only log, and does not open a graphical window. It does not navigate to any real site, use real credentials or alter the active browser.
- **sync** (later, as new `main` changes accumulate): `./nix/vulpra security-qa sync` advances **only a clean detached QA source worktree** to the current committed `main` commit. It refuses to discard edited or untracked QA source and never replaces an existing binary snapshot or launches a browser.

## Security and scope limits

1. No automatic promotion to daily Vulpra: the active daily executable/profile are never switched by this script. Changes to `main` remain ordinary source commits until the owner explicitly rebuilds their browser.
2. Existing `./nix/vulpra qa` has a *separate profile* but uses the original `main` executable. Use `security-qa` when independent executable bytes matter.
3. This first step is **not an independent QA compilation pipeline**. A separately compiled worktree-native object directory, packaged real-browser WebDriver/security replay, and target Hyprland sandbox tests remain outstanding acceptance work. In particular, do not claim a current-main native binary is accepted from the synthetic CI fixture.
4. Test-only contents in the QA state are under ignored `obj*/` paths. The script refuses existing destinations and symlinked QA state entrypoints; it never cleans the QA worktree or runs `git reset --hard`, `git clean`, or `rm` on the live source/profile. A temporary failed snapshot staging directory can be removed by its own cleanup handler.
5. Keep ordinary dogfooding active. For actual security acceptance, use **source-only GitHub Actions** first, then **isolated binary tests** against this QA snapshot, and schedule opt-in real Wayland/physical GPU latency comparisons only when needed. Physical GUI tests may momentarily take focus and are not invoked by any of the commands above.

## Evidence

- Offline synthetic QA infrastructure fixtures: [GitHub Actions worktree-isolation test](https://github.com/sguzman/vulpra/actions/workflows/security-qa-worktree-fixtures.yml). This checks source separation, no-Nix dispatch, copied test executable, clean source sync, temporary HOME/XDG/profile, and refusal to overwrite existing state. It is not a real Gecko/browser security pass.
- Security gate order and release holds: [Firefox 160.0.1 acceptance roadmap](SECURITY-ACCEPTANCE-ROADMAP-20261120.md).
- Formal progress baseline unchanged: **61% overall, Δ 0 percentage points**; security gates remain open until current real compiled/runtime evidence passes.
