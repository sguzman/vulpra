# Original-source FFmpeg runtime linker candidate and failure-state execution — 2026-11-09 UTC

**Accepted independent source-function CI:** [M3 Current FFmpeg Native Source Candidate Fixtures #42554770227 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42554770227), [actual archived JSON artifact 13646812639](https://github.com/sguzman/vulpra/actions/runs/42554770227/artifacts/13646812639) independently downloaded and parsed, and [workflow lint #42554770251 SUCCESS](https://github.com/sguzman/vulpra/actions/runs/42554770251). Five distinct runtime cases passed using the original C++ `FFmpegRuntimeLinker::Init()` and source `sLibs[]` Linux candidate array, with fake NSPR library loads and fake `FFmpegLibWrapper::Link()` responses.

## Authentication and actual test boundary

The source-owner C++ file `dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp` is still the exact immutable Git blob `c854f34aa71f6fd4146e04ab332d3e0f8a60fb11` from the already successful [full normal native Vulpra build #42546880350](https://github.com/sguzman/vulpra/actions/runs/42546880350), source `d7bf1cb73b384df047871d6b8c608312eb6cb5b4`. The [source-extraction runner](../../ci/tests/m3-current-ffmpeg-linker-fixtures.sh) authenticated that successful GitHub Actions run, the original GitHub file object, the current checkout's Git object, and the exact working source bytes, then extracted the actual `static const char* sLibs[]` array and full `bool FFmpegRuntimeLinker::Init()` method unchanged.

The [minimal C++ ABI-shaped fixture](../../ci/tests/m3-real-ffmpeg-linker-candidates-fixture.cpp) includes both extracted original source fragments. Only the external NSPR library load, FFmpeg wrapper ABI link callback, logging, mutex and decoder/encoder initialization hooks are mocks. Each scenario runs as a separate process, keeping cached global initialization from contaminating another case. The Linux candidate array has **14 names** including a **build-config-dependent first candidate**; the fixture uses a **mock compile-time version 63** and does **not** claim that the currently compiled browser has the exact same first candidate name. Its 14 source candidates and the earlier **14 observed browser denied FFmpeg calls** are consistent but **not independent proof of one-to-one runtime symbol/candidate identity**.

| Original source method scenario | Expected/observed native `PR_LoadLibraryWithFlags` calls | Original behavior verified |
| --- | ---: | --- |
| All provider candidates missing | 14 | `Init()` false; `LinkStatus_NOT_FOUND` retained |
| First candidate usable | 1 | `Init()` true; decoder/encoder initialization and successful name recorded |
| Last candidate usable | 14 | Source iterated and tried every candidate, then succeeded |
| First candidate invalid, second candidate usable | 2 | Rejected first candidate without aborting the entire candidate search |
| Two available but invalid candidates; remaining missing | 14 | Correctly retained `LinkStatus_INVALID_FFMPEG_CANDIDATE` and the preferred candidate name |

All scenarios also called `Init()` a second time and verified that it returned the cached outcome without additional loader calls. The fixture checked actual source method return value, candidate load counts, `sLibAV.Link()` call counts, selected status, callback registrations, and decoder/encoder initialization counts. Unsupported fixture modes are rejected.

## What has and has not been proved

**Proved:** original source-level Linux FFmpeg provider iteration, failure exhaustiveness, priority/error-state, selection and initialization caching under deterministic *mocked* NSPR and FFmpeg ABIs. The exact source Git blob was already compiled in the earlier successful real native browser, but these particular five test processes execute a standalone C++ fixture, **not the packaged browser**.

**Not proved:** exact runtime `libavcodec` name arguments from actual machine code; real FFmpeg shared library loading or ABI compatibility; codec availability and actual H.264/AAC playback; software decoder fallback; complete direct/indirect dynamic loader graph; target EndeavourOS/Hyprland behavior; safe source removal; security hotfix readiness or release approval.

Separate new [source-pinned full native build #42553489035](https://github.com/sguzman/vulpra/actions/runs/42553489035) is **still compiling at this checkpoint**. It will test a real generated H.264/AVC video in actual packaged Vulpra using WebDriver, both normally and with FFmpeg denied. Its decoded-video evidence must be examined separately; no media playback outcome is established by these five mock cases.

**Overall 61% (Δ+0 pp). M3 5/6 gates (83%), gate six open. No duplicate Firefox build, source pruning, host library modification, security hotfix merge or release.**
