# M3 — Network restriction triggered during graphical CI (2026-10-30)

## Exact protected reproduction

The original source-pinned full-normal native archive from `b1482404dfb8b01342990ee99ea3df0f9756b5f7` (tar.xz SHA-256 `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`) failed the ordinary Ubuntu 24.04 private Weston 10-second graphical acceptance, while the identical archive passed inside a no-egress network namespace. No target Arch/Hyprland failure is established by these tests.

The failing host workflow [41139704250](https://github.com/sguzman/vulpra/actions/runs/41139704250) records **FATAL ERROR: Non-local network connections are disabled** for an attempted connection to `location.services.mozilla.com`; the separate crash-reporter-disabled 10-second probe exited 139. Earlier [41133467657](https://github.com/sguzman/vulpra/actions/runs/41133467657) independently reports the same hostname and fatal guard. No IP addresses, profile contents, or raw crash arguments are needed to diagnose the cause.

The fully compiled, source-pinned comparison [41134661335](https://github.com/sguzman/vulpra/actions/runs/41134661335) **SUCCESS** rebuilt the exact original source on one Ubuntu runner; original and freshly packaged normal binaries **both failed** their ten-second graphical tests with exit 11. The fresh package matched its own linked `libxul.so` `.text` before symbol substitution. GDB confirmed SIGSEGV at null fault address and resolved `MOZ_CrashSequence → MOZ_Crash → mozilla::net::nsHttpChannel::OnStartRequest → nsInputStreamPump::OnStateStart`. This is a function-level stack, not proof of a specific network request's call stack.

## Pinned browser source path

- `netwerk/base/nsSocketTransport2.cpp` (source `b1482404`), `ShouldBlockAddress` and `nsSocketTransport::InitiateSocket` at approximately lines 1266–1392: with `xpc::AreNonLocalConnectionsDisabled()`, disallowed non-local addresses print the fatal error and return `NS_ERROR_NON_LOCAL_CONNECTION_REFUSED`.
- `netwerk/protocol/http/nsHttpChannel.cpp`, `nsHttpChannel::OnStartRequest` at approximately lines 9415–9447: `mStatus == NS_ERROR_NON_LOCAL_CONNECTION_REFUSED` invokes `MOZ_DUMP_PROFILE_OR_CRASH_UNSAFE`. The observed symbolic stack and fatal runtime message are consistent with this *intentional* test restriction, not a random graphics null dereference.
- `toolkit/modules/Region.sys.mjs` at approximately lines 149–180 and 370–392: `RegionDetector.init()` schedules `_fetchRegion()` on an **unset** `browser.search.region` home value; `#getRegion()` fetches the `browser.region.network.url` endpoint. A nonempty region pref suppresses that initial fetch.

These are source/runtime corroborations. We have **not** captured the rejected request's exact GDB frame arguments, and other browser services can also attempt prohibited traffic.

## Isolated smoke-profile correction

`packaging/test-wayland.sh` now writes `user_pref("browser.search.region", "ZZ");` **only** to its already-disposable private profile before starting the browser. `ZZ` is a deterministic unknown-region value for an isolated test, not a country inference, user setting, Firefox source patch, or real-world location choice. The normal `MOZ_DISABLE_NONLOCAL_CONNECTIONS=1` guard remains enabled in the calling CI workflows; the test still requires the original ten-second survival and a same-surface, non-null Wayland buffer attach/commit.

`.github/workflows/test-wayland-harness.yml` checks this file exists with mode 0600 under the private profile (mode 0700) and confirms the real network guard reaches the mock browser. This mock check is *not* native-browser acceptance. Because the harness now seeds the profile directory itself, successful GUI acceptance also requires Firefox to generate a nonempty `compatibility.ini` marker during real profile initialization; the synthetic mock explicitly simulates that file and is never accepted as browser evidence. The ordinary-runner full native graphical workflow must pass on the current harness before the original CI crash can be considered resolved. This targeted CI-only profile fixture does not close the broader feature/build/binary ABI mapping gate.

**Acceptance: pending real uninstrumented Ubuntu-host graphical pass. M3 5/6 (83%), overall 61%, current round +0 percentage points.**
