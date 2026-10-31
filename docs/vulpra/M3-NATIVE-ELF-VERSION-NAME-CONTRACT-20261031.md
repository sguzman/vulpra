# M3 — Native ELF GNU version-name contracts (2026-10-31)

## Original compiled binary provenance

[Successful full source-pinned CI 41157293087](https://github.com/sguzman/vulpra/actions/runs/41157293087), sanitized artifact **13025696998**, authenticated original full-normal/native Firefox 159.0b5-derived Vulpra source `b1482404dfb8b01342990ee99ea3df0f9756b5f7`, package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` (87,154,544-byte tar.xz). It ran a **read-only** `readelf -hW -dW -VW` metadata scan over every **28** ELF package regular members after validating source/run provenance, archive bytes, ELF64 x86-64 headers, archive bounds and dynamic library name identities.

The checked **519** unique `(requester ELF basename, provider SONAME, required GNU version name)` tuples cover **17** provider basenames. These are original compiled `.gnu.version_r` (VERNEED) declarations; providers' `.gnu.version_d` (VERDEF) definitions are inspected either in the very same SHA-verified package or through x86-64 `ldconfig -p` **candidate** shared libraries installed on Ubuntu 24.04 CI. This is not executing Vulpra, `ldd`, or a dynamic loader, and no absolute host library paths, source environment state, addresses or raw binary contents are retained.

| Observed declared candidate version-name scope | Requirement tuples | Candidate version names present | Absent | No candidate |
| --- | ---: | ---: | ---: | ---: |
| Original package's own named ELF definitions | **162** | **162** | 0 | 0 |
| Ubuntu 24.04 host x86-64 ELF `ldconfig` candidates | **357** | **357** | 0 | 0 |
| **Total** | **519** | **519** | **0** | **0** |

The highest **declared GLIBC version name** is `GLIBC_2.18`; this is **not** a minimum OS version determination or a test of other glibc components. The largest per-provider requirement counts are `libc.so.6` (154), `libnss3.so` (94), `libstdc++.so.6` (91), `libpthread.so.0` (43) and `libnssutil3.so` (43). Repeated requests across separate ELF modules count separately.

## Real ELF parser correction and regression protection

The first authentic run rejected genuine GNU `Vernaux` entries duplicated under the same provider/version name in NSS/Gecko libraries: distinct version records can repeat an identical name. That was not a malformed binary. The accepted parser checks the raw `Cnt` **number of version auxiliary entries** in each file-group, but deduplicates version-name contracts before producing the bounded report; five deliberately malformed source/size/name/count fixtures remain negative. The final full real CI passes without changing a browser byte or copying external application files into the source tree.

## Exact limitations and next evidence

A matching library-version **name** is not proof that *an individual imported function or variable* is exported by that candidate with the expected type/binding. Provider selection from `ldconfig` is not the same as the actual loader's search order (RPATH, RUNPATH, loader configurations and namespace can differ). A successfully loaded library also can resolve symbols through interposition/other providers. The scan does not cover dynamic `dlopen`, non-ELF resources, conditional feature paths, non-Linux platforms, source-to-feature causal attribution, live runtime ABI under all paths or the user's Arch/Hyprland configuration.

The original successful [offline-host / online-disconnected-netns loader comparison 41150562882](https://github.com/sguzman/vulpra/actions/runs/41150562882) establishes **equal actually observed** 152 basename / 147 needed-by / 21 dynamic loader relation sets in those two executed startup workloads, not a full ABI closure. The present name-level contract is a distinct static complement, not a replacement for symbol-level binding or real browser acceptance.

**M3 fifth accepted gates remain unchanged: 5/6 (83%); overall product 61%; session Δ0pp. No source removal, new compressed savings or whole-source feature/ABI map gate credit.**
