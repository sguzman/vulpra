# M3 — Original browser graphical dynamic request edges beyond ordinary ELF loader lists (2026-11-02)

## Scope and independent verification

[**Original graphical conditional-request crosswalk CI 41522017287 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41522017287), [**workflow lint 41522017192 — PASS**](https://github.com/sguzman/vulpra/actions/runs/41522017192). Artifact **13178066912** (`m3-original-21-dynamic-vs-per-elf-loader.json`) was independently downloaded and inspected. The new bounded jq verifier `ci/m3-original-21-dynamic-vs-per-elf-loader.jq` compares three independently passed original-code evidence sources:

| Independent original evidence | GitHub Actions run | What it proves |
| --- | --- | --- |
| Actual private Weston/Wayland glibc dynamic loader request trace | [41149955223](https://github.com/sguzman/vulpra/actions/runs/41149955223) | **21** actual loader-reported dynamic-request edges in one successful original compiled browser graphical workload |
| Exact-original source and packaged XPCOM manifest candidate mapping of those 21 edges | [41269693997](https://github.com/sguzman/vulpra/actions/runs/41269693997) | **14** manifest-preload source candidates and **7** other supported source candidates, without claiming exact native callsites |
| Actual original 28-ELF source ownership and independent Ubuntu/Arch per-ELF provider sets | [41515803526](https://github.com/sguzman/vulpra/actions/runs/41515803526) | Per-original-ELF direct and transitive ordinary glibc `--list` provider basenames in **both** isolated userspace environments |

Each historical run is independently authenticated against its successful conclusion, fixed exact Git commit, workflow path and unexpired named artifact. Each source report must match historical compiled original Vulpra tree `b1482404dfb8b01342990ee99ea3df0f9756b5f7` and full-normal native package SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`. The archive of the new crosswalk carries **21 exact requester/target ELF basename pairs**, the original packaged source-owner manifest for each requester and its previously measured runtime-binding category, with explicit booleans for each platform's ordinary provider coverage.

The new CI rejects an incomplete 20-edge runtime trace, a mutated original 14+7 source classification, and an invented per-ELF Arch provider overlap. It performs no browser build, original or installed browser launch, network access or modification of application source.

## Verified results: three independent levels of dependency

| Evidence category | Verified result | Interpretation |
| --- | ---: | --- |
| Loader-reported dynamic request edges observed in original graphical browser | **21** | Real bounded native runtime requests, not a complete future-feature inventory |
| Requested basenames that are among original packaged 28 ELF members | **18** | Packaged libraries required in this observed workload; do not treat them as absent or removable |
| Requested basenames outside original package | **3** | Actual host-runtime names in this isolated observation: `libavcodec.so.60`, `libgbm.so.1`, `libpulse.so.0` |
| Source-supported original XPCOM manifest bootstrap candidates | **14** | Original packaged `dependentlibs.list` / source manifest loader, all requested by `vulpra` in this trace |
| Additional source-supported original graphical request candidates | **7** | Five loader-reported requests from `libnspr4.so`, two from `libxul.so` |
| Edges already listed within *that requester's own* Ubuntu ordinary glibc provider set | **0/21** | Independent direct + transitive `DT_NEEDED` metadata does **not** enumerate these 21 observed edges |
| Edges already listed within *that requester's own* Arch ordinary glibc provider set | **0/21** | Same bounded distinction in the isolated Arch userspace |

### Actual original graphical loader-reported requests

| Observed requester basename | Requested basename | Original target? | Source-candidate classification |
| --- | --- | --- | --- |
| `libnspr4.so` | `libavcodec.so.60` | No — host runtime | Other original source candidate |
| `libnspr4.so` | `libfreeblpriv3.so` | Yes | Other original source candidate |
| `libnspr4.so` | `libmozavcodec.so` | Yes | Other original source candidate |
| `libnspr4.so` | `libmozavutil.so` | Yes | Other original source candidate |
| `libnspr4.so` | `libsoftokn3.so` | Yes | Other original source candidate |
| `libxul.so` | `libgbm.so.1` | No — host runtime | Other original source candidate |
| `libxul.so` | `libpulse.so.0` | No — host runtime | Other original source candidate |
| `vulpra` | `libgkcodecs.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `liblgpllibs.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libmozgtk.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libmozsandbox.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libmozsqlite3.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libmozwayland.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libnspr4.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libnss3.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libnssutil3.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libplc4.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libplds4.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libsmime3.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libssl3.so` | Yes | Manifest bootstrap candidate |
| `vulpra` | `libxul.so` | Yes | Manifest bootstrap candidate |

The requester labels are **glibc loader-report attribution**, not automatically the source-level C/C++ or Rust function that called `dlopen`. For example, a request attributed to `libnspr4.so` is not a proven callsite in its source code. The source-candidate validation is independent, but its 21/21 original observed request count does **not** supply an uninstrumented complete machine call stack or all possible routes. The original selected `pulse-rust` audio and libudev work is separately documented.

## Engineering conclusion and next unresolved work

This is a **validated gap between two distinct dependency layers**: ordinary static native `DT_NEEDED` and per-root transitive glibc `--list` resolution on both distributions, versus 21 dynamic requests actually made in one original browser graphical workload. The 18 requested packaged binaries are demonstrated to participate in that bounded workload even when absent from their requester's conventional provider list. The three host-library basenames are actual workload observations, **not evidence they are available on or mandatory for every different user host or feature path**.

**Still open**: Full source/build/feature-root reachability, all generated Rust and C/C++ dynamic FFI boundaries, every future `dlopen` route, arbitrary security/device/network workload coverage, optional-versus-required fallback validation, exact user EndeavourOS/Hyprland environment, and safe source deletion. These 21 edges cannot be extrapolated into an exhaustive library dependency graph.

**No source was deleted, no new bytes were saved. M3 gate six remains OPEN (5/6 = 83%); overall Vulpra 61%, session Δ +0 percentage points.**
