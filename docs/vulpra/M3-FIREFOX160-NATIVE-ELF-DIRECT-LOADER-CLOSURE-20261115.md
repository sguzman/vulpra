# M3 Firefox 160: source-bound complete packaged ELF DT_NEEDED census and direct glibc loader resolution (2026-11-15)

## Verified, no native Firefox rebuild

**Three independent read-only native metadata workflows passed against the exact same original compiled Firefox 160 Vulpra candidate:**

| Boundary | Actual accepted CI | Result | Distinct loader provider basenames |
| --- | --- | --- | ---: |
| Original authenticated native package ELF metadata | [43730900702 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43730900702) | **28/28** packaged native ELF files; **268** direct `DT_NEEDED` declarations; **50** distinct required dependency names | Not a host loader test |
| Ubuntu 22.04 glibc, real `--list` metadata on every ELF | [43731304463 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43731304463) | **268/268** direct dependency names present in per-ELF glibc loader maps | **92** |
| Ubuntu 24.04 glibc, real `--list` metadata on every ELF | [43731304463 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43731304463) | **268/268** direct dependency names present in per-ELF glibc loader maps | **91** |
| Disposable Arch Linux userspace under Ubuntu-hosted Docker | [43731540340 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43731540340) | **268/268** direct dependency names present in per-ELF glibc loader maps | **90** |

The counts above reflect genuine ELF metadata and native *dynamic linker resolution metadata*, not a graph inferred from source manifests alone. They remain **limited to direct `DT_NEEDED` and glibc `--list`**, which do not execute Firefox application mains or all optional features.

### Exact source/binary provenance

- Original native browser producer: [Firefox 160 exact-source build and runtime candidate, run **43138458940**](https://github.com/sguzman/vulpra/actions/runs/43138458940), pinned producer branch commit `0624235fdc956ab18af3c3f310b3588ca72fff61`. The identical compiled browser package plus SHA-256 sidecar was byte-preserved by [run **43724886827**](https://github.com/sguzman/vulpra/actions/runs/43724886827), whose authenticated head is `54728803f058c3edf54d2e8d3f6e0a7d2af0aec6`.
- Official Mozilla Firefox 160 release source commit: `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`. Complete 28-overlay Vulpra candidate Git tree: `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`, independently checked by `materialized-candidate.json` in the preserved source archive. The original archive's existing `sha256sum` sidecar was rechecked before every extraction/scan.
- The [read-only existing package metadata collector](../../ci/m3-native-elf-package-graph.py) was pinned to its exact Git blob `2953ff3a1dff6512e5c69c6b0dded193e8f87945`, and rejected **eight** fabricated/corrupt fixture scenarios before scanning. It returned **28** actual ELF files with **268** direct edges. Among **50** unique required names, **14** names are supplied by packaged ELF members, **36** are not contained in the package and therefore must be supplied at runtime, and **zero** were only archive symlink placeholders. An absent-from-package library is **not** a missing host dependency.
- The separate [std-only Rust per-ELF observer](../../ci/security-160-native-elf-loader-list.rs) uses bounded `readelf -Wd` and direct glibc interpreter `--list` (never `ldd` on application code, `dlopen` or `vulpra-bin` as a normal application entrypoint). Its native metadata evidence is joined to the independently archived `43730900702` per-ELF inventory. Each of the **28 exact requester basenames** must match; **every member's complete direct `DT_NEEDED` name list and count** must match; each individual loader map must contain **every declared direct SONAME**. The verifier rejects missing rows or any mismatched declaration, even if the aggregate 268 total happens to be unchanged.
- Ubuntu 22.04/24.04 jobs invoke the loader via their system `/lib64/ld-linux-x86-64.so.2 --list` in disposable **no-egress network namespaces** and isolated HOME. The Arch job runs the same precompiled small Rust metadata observer in a **read-only, no-network Docker Arch Linux userland**, using only mounted source-authenticated archive contents, a separately archived base-image digest, and no host privilege or user-device change. The exact original binary is unmodified. The Arch run uses **Ubuntu 24.04 host kernel**, not the target EndeavourOS kernel.

The loader provider-basename counts **92, 91 and 90** are environment-specific, include linker special entries such as the interpreter/vDSO, and do **not** mean 92/91/90 distinct packaged libraries. They should not be used as a measured package-size difference or as proof of ABI-version/symbol relocation closure.

### Connection to the older Firefox 159-era dependency map

The source-pinned Firefox 160 package has the **same aggregate 28 regular native ELF requesters, 268 direct `DT_NEEDED` edges, 50 distinct names, 14 bundled direct dependency names, and 36 absent-from-archive names** as the separately compiled historical source-pinned Firefox 159-era package. [Historical M3 native ELF package graph](M3-NATIVE-DEPENDENCY-CLOSURE-BLOCKERS-20261104.md) and [original read-only loader-list acceptance](M3-ORIGINAL-NATIVE-ALL-28-LOADER-LIST-CLOSURE-20261031.md) record that older baseline. **Aggregate parity is not a per-byte, per-ELF, source-owner, or per-feature parity assertion between the two different builds.** The per-ELF crosscheck performed here is *within the same Firefox 160 package*.

### Still open; no gate inflation

The following are **not** proven by any of these successful checks:

- No complete resolution of optional/indirect `dlopen` and `dlsym`, Rust/C++/generated FFI callsites, all linker archive members, runtime plugin/library fallback branches or conditional feature activation.
- No proof of successful dynamic relocation or all function-level symbol bindings, no execution of native feature code, and no completeness of future or transient dynamic loads.
- No actual target **EndeavourOS/Hyprland** kernel, mixed NVIDIA/iGPU, graphics/Wayland integration, audio/USB environment or its native ABI versions tested by these GitHub userspaces. Arch container evidence is **not** equivalent to a real Arch host.
- No new safe source-pruning approval, no measured marginal compiled-size savings, no Firefox security-current/MFSA/CVE acceptance, no Safe Browsing provider readiness [#8](https://github.com/sguzman/vulpra/issues/8), no closure of role-specific sandbox acceptance [#9](https://github.com/sguzman/vulpra/issues/9), and no merge or release.

**Next dependency-map work:** connect the exact direct-loader maps here with the *current and Firefox160 compiled* source/build owner, Cargo/static archive member and feature activation records; then test specific remaining conditional native provider branches with bounded negative/fallback runtime evidence. This is a narrower evidence advance for the **open M3 sixth gate**, not its completion. **Vulpra overall 61% (previous 61%; Δ +0 pp); M3 83% (5/6)**. [Draft PR #6](https://github.com/sguzman/vulpra/pull/6) remains unmerged. No real workstation/browser-profile change or new Firefox compilation.


## Independent three-userspace provider-set reconciliation (2026-11-15, added after the three native checks)

[**Three-userspace provider crosswalk CI 43732118146 — SUCCESS**](https://github.com/sguzman/vulpra/actions/runs/43732118146) authenticated the exact successful source-matched 28-ELF census from `43730900702`, both Ubuntu 22.04/24.04 glibc reports from `43731304463` and the Arch userspace glibc report from `43731540340`. The [strict jq crosswalk](../../ci/m3-firefox160-three-userland-loader-provider-crosswalk.jq) refused any inconsistent original archive SHA, Mozilla source commit, candidate 28-overlay tree, missing/extra ELF member, altered **per-ELF exact DT_NEEDED name list**, changed source/release or no-network claims, or malformed provider basename. **Ten deliberately forged evidence cases were rejected** in the actual run. All accepted data are sanitized basename sets, not raw absolute paths, process IDs, device information or user data.

| Direct-loader provider set | Observed count |
| --- | ---: |
| Ubuntu 22.04 distinct provider basenames | **92** |
| Ubuntu 24.04 distinct provider basenames | **91** |
| Disposable Arch Linux userland distinct provider basenames | **90** |
| Names present in **all three** provider sets | **80** |
| Distinct names across the full three-userland union | **102** |

**Exact Ubuntu 22.04 vs Ubuntu 24.04 difference:** Ubuntu 22.04's provider list additionally contains `libpcre.so.3` and `libuuid.so.1`; Ubuntu 24.04's list additionally contains `libbz2.so.1.0`.

**Exact Ubuntu 24.04 vs Arch userspace difference:** The ten Ubuntu-24-only provider names are `libbsd.so.0`, `libcap.so.2`, `libgcrypt.so.20`, `libgpg-error.so.0`, `libjpeg.so.8`, `liblz4.so.1`, `liblzma.so.5`, `libmd.so.0`, `libselinux.so.1` and `libzstd.so.1`. The nine Arch-only names are `libcloudproviders.so.0`, `libglycin-2.so.0`, `libicudata.so.78`, `libicuuc.so.78`, `libjson-glib-1.0.so.0`, `libseccomp.so.2`, `libsqlite3.so.0`, `libtinysparql-3.0.so.0` and `libxml2.so.16`.

**Interpretation limit:** These are *loader-listed direct-plus-transitive provider basenames for all 28 ELF requesters*, not differences in the 268 required `DT_NEEDED` edges, direct Firefox capabilities, or browser runtime behavior. A library name appearing only on Arch does **not** establish that Firefox needs that library on Ubuntu, nor does Arch's `libseccomp.so.2` entry imply absent sandbox enforcement on Ubuntu. The Arch result remains a container **userland on an Ubuntu host kernel**, not native target EndeavourOS/Hyprland, so it cannot establish target host ABI/version compatibility or GPU integration. This narrower cross-platform platform-map evidence does not authorize pruning or close M3's last gate. **Overall 61% (Δ +0 pp); M3 83% (5/6).**
