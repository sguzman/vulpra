# Vulpra: isolated security QA while dogfooding

**Status:** Source-worktree, QA binary-copy, independent native QA-build path, isolated headless smoke and WebDriver real-browser acceptance entrypoint are implemented. Offline synthetic CI validates the separation contract (including mocked `mach configure/build` and mocked QA `accept` dispatcher), WebDriver certificate parser and local extension fixtures. **The user confirmed the detached QA worktree/snapshot on 2026-11-20 and ran a real snapshot-backed WebDriver acceptance check on 2026-11-21. Its strict shell report passed localhost untrusted-TLS rejection, temporary WebExtension lifecycle and BYOB preference checks, using disposable QA HOME/XDG. No separate QA-native Firefox build, sandbox syscall, trusted-CA positive control, extension restart persistence, or live threat-provider acceptance is claimed.**

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

## QA-owned commands and one-time handoff

The already-created QA checkout has an older copy of the runner. **Once**,
advance its detached source to the current GitHub `main` without updating
or running the daily main checkout, and without altering the copied executable:

```fish
git -C ~/Code/Apps/vulpra-security-qa -c http.version=HTTP/1.1 fetch origin main
git -C ~/Code/Apps/vulpra-security-qa checkout --detach FETCH_HEAD
```

`git checkout --detach` does **not** force or discard local source edits. If
the QA checkout is dirty, stop instead of resetting or cleaning it. Normal
private QA tests are then launched exclusively from the QA source tree:

```fish
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa verify
~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa accept
```

Subsequent source refreshes also happen **inside QA**, with one explicit
`~/Code/Apps/vulpra-security-qa/nix/vulpra security-qa sync` command.
This fetches from origin using HTTP/1.1 into shared Git object storage and
moves only the **clean detached QA checkout**. The daily `main` worktree,
compiled browser, profile, and existing QA snapshot are not changed.
It downloads changed Git data when requested, not a new browser build.
The QA runner loads `ci/smoke-webextension-package-local.py` from the QA
checkout itself. The sibling main checkout is used only as shared Git metadata.

Only `setup` and `snapshot` are one-time/migration operations invoked from
the regular main checkout; they deliberately refuse to run inside QA.

## Commands (from the regular Vulpra checkout)

All the following operations **except the explicitly named build** bypass Nix and do not download dependencies; none installs or replaces the daily browser:

```bash
./nix/vulpra security-qa status
./nix/vulpra security-qa setup
./nix/vulpra security-qa snapshot
./nix/vulpra security-qa verify
./nix/vulpra security-qa headless
./nix/vulpra security-qa accept
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
- **accept** (explicit, real QA run from the QA checkout) verifies the selected snapshot digest, executes the **QA worktree's own checked-out test harness**, requires existing `python3`, `geckodriver`, `openssl`, `jq`, and `timeout`, and reuses `ci/smoke-webextension-package-local.py` **directly against the copied QA ELF**. The command does **not** package, compile, replace, or launch the daily browser. It creates private `obj-vulpra-security-qa/runtime/accept.*` HOME/XDG/log directories, passes no inherited desktop profile variables to the browser, starts only a local WebDriver endpoint and loopback HTTP/HTTPS fixtures, and runs certificate-rejection, extension install/content/background/storage/uninstall, BYOB defaults, and JavaScript/UA checks with a strict JSON pass report. It does not change the workstation trust store or use any live vault/passwords. It can still consume some CPU and disk while running, but never opens a visible window. If geckodriver is not already installed, it **stops without installing anything**. Logs/evidence are saved only in the QA runtime directory. This is not a sandbox-role denial test, provider-backed Safe Browsing readiness check, or proof of zero browser background egress.
- **headless** runs only the selected copied QA executable under a new `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `--profile`. It loads only a synthetic local `file://` HTML fixture, requires a PNG screenshot, leaves a local QA-only log, and does not open a graphical window. It does not navigate to any real site, use real credentials or alter the active browser.
- **sync** (as source changes accumulate): when invoked from **QA**, it explicitly fetches latest `origin/main` and advances **only a clean detached QA source worktree**; when invoked from main, it advances QA to local main HEAD without fetching. It refuses modified or untracked QA source, never replaces existing snapshots, and never launches a browser.

## Browser styling QA, separate from security acceptance

To verify compact vertical tabs in **Vulpra** without rebuilding or restarting
the daily browser, use the detached QA checkout's `security-qa style-preview`
command after `security-qa sync`. It loads the new QA source CSS **only inside
a disposable copied-browser process** and measures native chrome group badge
alignment. A separate `security-qa style` tests whether a later **QA-native
build** actually packages the same styling; that native build is optional,
explicit and expensive. [Detailed steps and evidence limits](VERTICAL-TABS-STYLE-QA.md).

Neither style command reads the daily Firefox/Vulpra profile, and passing
source preview does not mean that the daily Vulpra executable was rebuilt.

## Security and scope limits

1. No automatic promotion to daily Vulpra: the active daily executable/profile are never switched by this script. Changes to `main` remain ordinary source commits until the owner explicitly rebuilds their browser.
2. Existing `./nix/vulpra qa` has a *separate profile* but uses the original `main` executable. Use `security-qa` when independent executable bytes matter.
3. A **separate native QA build command exists but has only passed an offline mocked build test**, not real Firefox compilation. Real QA compilation, a separately packaged WebDriver/security replay, and target Hyprland sandbox tests remain outstanding acceptance work. Do not count the synthetic CI fixture as browser-security proof.
4. Test-only contents in the QA state are under ignored `obj*/` paths. The script refuses existing destinations and symlinked QA state entrypoints; it never cleans the QA worktree or runs `git reset --hard`, `git clean`, or `rm` on the live source/profile. A temporary failed snapshot staging directory can be removed by its own cleanup handler.
5. Keep ordinary dogfooding active. For actual security acceptance, use **source-only GitHub Actions** first, then **isolated binary tests** against this QA snapshot, and schedule opt-in real Wayland/physical GPU latency comparisons only when needed. Physical GUI tests may momentarily take focus and are not invoked by any of the commands above.

## Evidence

- **Real workstation evidence (2026-11-21):** user-provided successful stdout from `security-qa accept` reported copied executable/manifest verification, live localhost TLS rejection, temporary extension lifecycle and BYOB checks. Evidence report is stored locally in the QA runtime folder `obj-vulpra-security-qa/runtime/accept.rfdL0ykH/webextension-smoke-20261121-085209.json` (not uploaded or inspected in full). The shell acceptance parser passed, which is narrower than completing the S3 or security-release gate.
- [QA-native runner and self-fetch synchronization mock CI PASS](https://github.com/sguzman/vulpra/actions/runs/44917174476): verifies QA-only harness execution, no daily main changes, refusal of dirty checkout sync, preservation of snapshot, and no external network in synthetic fixtures.
- [QA WebDriver dispatch and security parser fixtures — CI PASS](https://github.com/sguzman/vulpra/actions/runs/44915322512). Exercises false TLS report rejection, checksum mismatch refusal, no profile override, disposable HOME/XDG, and pre-existing certificate/extension/parser self-tests. **Not a real Gecko acceptance run.**
- Offline synthetic QA infrastructure fixtures: [GitHub Actions worktree-isolation test](https://github.com/sguzman/vulpra/actions/workflows/security-qa-worktree-fixtures.yml). This checks source separation, no-Nix dispatch for non-build actions, copied test executable, clean source sync, **mocked QA-only build output and mozconfig**, temporary HOME/XDG/profile, and refusal to overwrite existing state. It is not a real Gecko/browser security pass.
- Security gate order and release holds: [Firefox 160.0.1 acceptance roadmap](SECURITY-ACCEPTANCE-ROADMAP-20261120.md).
- Formal progress baseline unchanged: **61% overall, Δ 0 percentage points**; security gates remain open until current real compiled/runtime evidence passes.
