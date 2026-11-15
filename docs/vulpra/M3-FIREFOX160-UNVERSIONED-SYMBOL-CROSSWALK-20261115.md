# Firefox 160: source-authenticated bare ELF dynamic imports across three CI userspaces (2026-11-15)

## Accepted static name-candidate evidence, not actual loader binding

The **unchanged original Firefox 160 Vulpra native package**, SHA-256
`530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`,
was re-examined read-only, without rebuilding or running its ELF executables.
The exact upstream release source commit is
`2887d9de1f69c0e9776413da80e7ba0d1225dd9b`, with candidate source Git
tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`, **28 native ELF members**.
These identities were checked against the previously accepted independent
package graph ([run 43730900702](https://github.com/sguzman/vulpra/actions/runs/43730900702)).

The existing [versioned symbol inspector](../../ci/m3-native-elf-symbol-provider-candidates.py)
now has a separate opt-in `--mode unversioned`. Its original versioned path and
4,592-name@version census remain unchanged. The new mode inventories undefined
GLOBAL/WEAK bare dynamic symbol names, compares them with unversioned and
default-version export names on packaged or `ldconfig`-listed **direct
`DT_NEEDED` metadata candidates**, and preserves missing/optional matches.
It does not follow loader scope, transitive resolution, `LD_PRELOAD`,
`dlopen`/`dlsym`, relocation semantics or runtime weak-symbol handling.
The read-only parser admits bounded long C++ mangled names after a genuine
original-package fixture exposed the old 255-character limit.

### Real authenticated results

- [Ubuntu 22.04 and 24.04 run 43740138658 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43740138658).
- [Disposable Arch Linux userspace run 43740286694 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43740286694). This still uses the GitHub-hosted Ubuntu kernel, not the owner's Arch workstation.
- [Independent crosswalk run 43740754186 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43740754186), using the separate source/ELF package graph and all three userspace artifacts; its three forged source/name, count and false-completion fixtures were rejected. Accepted artifact: `firefox160-three-userland-bare-symbol-crosswalk-not-loader-closure` (ID **14172142916**).

| Actual source-pinned ELF observation | Ubuntu 22.04 | Ubuntu 24.04 | Arch userspace |
|---|---:|---:|---:|
| Bare undefined dynamic imports examined | 2,154 | 2,154 | 2,154 |
| Direct `DT_NEEDED` export-name candidates available | 1,833 | 1,835 | 1,835 |
| Weak imports lacking a direct candidate | 321 | 319 | 319 |
| Strong imports lacking a direct candidate | 0 | 0 | 0 |

The independent comparator matched **all 2,154 exact
(requester ELF basename, undefined symbol name, GLOBAL/WEAK bind) tuples**
across all three reports. It found exactly **two** candidate-record
differences, both in `crashreporter`:

1. Weak import `pidfd_getpid` — no direct export-name candidate in
   Ubuntu 22.04; candidate `libc.so.6` on Ubuntu 24.04 and Arch.
2. Weak import `pidfd_spawnp` — the same provider difference.

These are candidate **name** observations, not a claim that either symbol
was actually bound, exercised, mandatory, absent from every possible
runtime scope, or subject to a successful or failed fallback. The
unmatched weak imports on Ubuntu 22.04 must not be treated as
link-time or runtime failures merely because the candidate table has
no matching name.

### Remaining acceptance boundaries

This closes a bounded **static unversioned import inventory gap**, not
M3's sixth gate. Exact actual loader-selected bindings, startup
relocations, `dlopen`/conditional feature loading, full Rust/C++ FFI
consumer edges, 18-feature fallback coverage, platform-specific
NVIDIA/iGPU Hyprland behavior, source-removal safety and release/security
acceptance remain open. All reports explicitly set these completion
claims to false.

The old failures remain provenance, not acceptance: the initial
Arch workflow's hardcoded original inspector blob SHA rejected the
changed scanner, and the first real bare-symbol Ubuntu scan rejected a
valid long C++ mangled name. The Arch pin and bounded parser were
corrected before the successful source-pinned three-userspace evidence
above. No local desktop, browser profile, Firefox Developer Edition,
production source or `main` was changed. No engine compilation,
unapproved source pruning, merge or release occurred.

**Progress unchanged:** overall **61% (Δ +0 pp)**; M3 **83% (5/6)**.
