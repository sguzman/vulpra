# Firefox 160: exact native ELF GNU version-name candidate compatibility crosswalk (2026-11-15)

## Accepted observations, not a full dynamic ABI/security gate

**Original source-and-SHA-256-authenticated native Firefox 160 Vulpra package:**
- Source of browser: official Firefox 160 release commit `2887d9de1f69c0e9776413da80e7ba0d1225dd9b`, complete Vulpra assembled 28-overlay tree `42dd7439a27dde92f89ac5eed13f88117a4d7ab5`.
- Compiled native producer [43138458940](https://github.com/sguzman/vulpra/actions/runs/43138458940), preserved byte-identically by [43724886827](https://github.com/sguzman/vulpra/actions/runs/43724886827). Original Firefox160 package SHA-256 **`530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb`**. All jobs verified the archived checksum sidecar and source-identity proof before the scan.
- Separately verified [28/28 native ELF, 268 direct DT_NEEDED source/byte census 43730900702 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43730900702). [Ubuntu22/Ubuntu24 direct ELF provider maps 43731304463 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43731304463) and [Arch userland map 43731540340 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43731540340) are **distinct evidence** and do not by themselves prove GNU version-name availability.

### Verified GNU version-name contract

| Authenticated native witness | Source-verified result |
| --- | --- |
| [Ubuntu 22.04 and 24.04 43733171548 — BOTH SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43733171548) | **521/521** named GNU `.gnu.version_r` requirements found in packaged or x86-64 host `ldconfig` provider candidates, 0 absent, 0 unavailable in each |
| [Disposable Arch Linux userspace 43733061688 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43733061688) | **521/521** of the same native package's named GNU requirements present in Arch userspace packaged/host candidate libraries; 0 absent, 0 unavailable |
| [Independent exact-tuple reconciliation 43733451276 — SUCCESS](https://github.com/sguzman/vulpra/actions/runs/43733451276) | **521 identical distinct (requester ELF basename, required provider SONAME, GNU version name) tuples** across all three verified reports; 12 independent forged source/package/ABI/name/role/safety fixtures rejected |

The final authenticated [reconciliation artifact](https://github.com/sguzman/vulpra/actions/runs/43733451276) contains the bounded result:

| Actual cross-environment version-contract classification | Requirement tuples |
| --- | ---: |
| Packaged ELF candidate `VERDEF` version names present | **164** |
| Host `ldconfig` metadata candidate `VERDEF` names present | **357** |
| **Total distinct requested triples** | **521** |
| Version-name candidates absent or unavailable in all three userspaces | **0** |
| Distinct required provider SONAME basenames | **17** |

The 17 SONAMEs reported as requiring GNU version names are `ld-linux-x86-64.so.2`, `libasound.so.2`, `libc.so.6`, `libdl.so.2`, `libgcc_s.so.1`, `libgkcodecs.so`, `libm.so.6`, `libmozavutil.so`, `libmozsqlite3.so`, `libnss3.so`, `libnssutil3.so`, `libpthread.so.0`, `libresolv.so.2`, `librt.so.1`, `libsmime3.so`, `libssl3.so` and `libstdc++.so.6`.

**Historical comparison:** The earlier Firefox159-era source-bound package had **519** unique version-name requirement triples, including **162 packaged** and **357 host candidate** version-name contracts ([historical audit](M3-NATIVE-ELF-VERSION-NAME-CONTRACT-20261031.md)). Firefox160 here has **521** total, **164 packaged**, **357 host**. This is **an aggregate difference of +2**, not a proof of precisely which source symbols changed, or any feature, performance or package-size regression. These are distinct compiled package revisions and host-candidate snapshots; they must not be treated as byte/ABI equality.

### Tests, provenance correction, and guardrails

The extended [existing bounded metadata-only VERNEED inspector](../../ci/m3-native-elf-version-contract.py) still supports its historical pinned original (no override), and requires a **paired, explicitly allowlisted Firefox160 source commit plus exact 64-character native archive SHA-256** for this new opt-in scan. Its existing 5 malformed `readelf` version-metadata fixtures and new invalid/unpaired SHA arguments fail; the original archive SHA comes from independent package preservation, not invented by the inspector. Scanning uses `readelf -hW/-dW/-VW` over all 28 bounded archived ELF members, plus `readelf -VW` over packaged and `ldconfig`-listed host library **candidates**, with no browser run, `ldd`, ELF loader execution, file-system source pruning or release operation.

The inspector originally included a fixed Ubuntu 24.04 report label. That inaccurate label was detected during cross-platform testing and **replaced with strict real `/etc/os-release` reporting** for Ubuntu 22.04/24.04 and Arch Linux userspaces. The re-run acceptance workflow now requires its reported OS/version to match the actual runner, and the independent crosswalk requires exact correct labels for all three. One intermediate Ubuntu rerun [43733089116](https://github.com/sguzman/vulpra/actions/runs/43733089116) failed **after the native version scan itself passed 521/521** because the newly added `jq` OS expression did not receive the `--arg os` binding in that step. That workflow argument was repaired without changing browser bytes or disabling the protection; **final accepted Ubuntu 43733171548 SUCCESS** supersedes it. The source scanner's original historical SHA restrictions remain in place.

The [strict independent `jq` crosswalk](../../ci/m3-firefox160-three-userland-verneed-crosswalk.jq) authenticates all three completed producer runs, exact-source 28-ELF census, exact 521 per-ELF/provider/version triples, and conservative false security/target/release claims. It intentionally rejects 12 forged source SHA, archive identity, per-ELF names, duplicate version tuples, host userspace identity, target-host, unavailable version, and M3-completion cases. Source-identical version-name tuples require **identical `VERNEED` metadata**, but not identical resolved host providers.

### Critical interpretation and remaining M3 work

**A GNU ELF version-name match is NOT individual symbol or relocation proof.** The inspector obtains host providers from `ldconfig` candidate basenames, not from full observed runtime loader binding/search order. It does not establish that every requested *function* or *data symbol* is present, matching its ABI/type, selected by the loader, or successfully relocated during startup/feature invocation. No lazy/optional `dlopen`, `dlsym`, plugins, conditional Rust/C++ FFI/Cargo archive members, source ownership or alternative feature fallbacks were enumerated by these checks. The source/ELF tests neither execute the browser nor establish a minimum supported distro/libc version.

**Arch result is Arch Linux userspace inside GitHub-hosted Ubuntu Docker**, not a real target EndeavourOS/Hyprland host kernel, Nvidia/iGPU workstation, GPU/Wayland/audio runtime, USB or security configuration. These checks cannot establish target ABI parity, full Firefox160 CVE/MFSA security currency or usable Safe Browsing provider credentials ([issue #8](https://github.com/sguzman/vulpra/issues/8)); [security issue #9](https://github.com/sguzman/vulpra/issues/9) is separately open.

These are precise **new direct-native ABI candidate/version-name evidence**, not the complete M3 feature/build/FFI/dynamic dependency and platform map. **M3 final sixth gate remains open (83%, 5/6); Vulpra overall 61%, session Δ +0 pp**. [PR #6](https://github.com/sguzman/vulpra/pull/6) stays **draft and unmerged**, no native Firefox rebuild, browser/profile or workstation modification, source deletion, credential generation, security override or release.
