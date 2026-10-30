# M3 real packaged Sync/FxAccounts module and empty-profile runtime evidence

**2026-10-30 UTC:** [GitHub Actions 40984957431](https://github.com/sguzman/vulpra/actions/runs/40984957431)
**PASSED**. Machine evidence artifact **12946740842**,
`m3-archived-normal-sync-fxa-native-runtime`. This runs a *real normal
browser*, using an **already compiled historical browser** rather than
rebuilding Firefox or changing the user's environment.

The archived source/normal build is
`674db8e385c36aec23e78bbe059b2a1fec194fae`, original successful
[full native run 40431769117](https://github.com/sguzman/vulpra/actions/runs/40431769117)
and SHA-256 `47c8ac5ce90747c051eac8daf24544d88767fdeb989293c0b50c5e8ac9e53c30`,
**86,937,548 B**. The archive, metadata and sidecar were all
verified before a private headless Vulpra session launched through the
real native executable and geckodriver. The original candidate runtime
suite [40439671494](https://github.com/sguzman/vulpra/actions/runs/40439671494)
was also required to have concluded success.

## Eight runtime-boundary assertions actually exercised

| Protected normal-browser API | Runtime observation |
| --- | --- |
| `UIState.sys.mjs` | module imports and exposes Sync UI state API |
| Fresh profile `UIState.get()` | `not_configured` |
| `services-sync/main.sys.mjs` | lazy `Weave` module imports and preference getter is readable |
| `FxAccounts.sys.mjs` | singleton and static `canConnectAccount` API exist |
| Fresh profile `getSignedInUser()` | returns `null`, without credentials |
| `ExtensionStorageSyncKinto.sys.mjs` | class and packaged `extensionStorageSyncKinto` instance import |
| `AccountsGlue.sys.mjs` | browser startup glue module imports via the actual `moz-src` registry and exposes `init`/`observe` |
| `SyncedTabsController.sys.mjs` | Firefox View controller class imports |

The CI script [`ci/smoke-sync-fxa-archive-runtime.py`](../../ci/smoke-sync-fxa-archive-runtime.py)
uses a disposable `HOME` and profile, writes a sentinel to an
unrelated disposable `profiles.ini` and confirms it remains unmodified.
The browser's nonlocal-connection guard was set;
no login, device synchronization, network request or account mutation is
requested by the probe. Only boolean module results are written to the
artifact; **no email, token, user identifier, profile files, URLs,
exception stack or private browser state is saved**.

At the report's run, the **seven named critical source blobs** for
`UIState`, Sync main, FxAccounts, WebExtension storage.sync,
AccountsGlue, Firefox View controller and `services/moz.build` were
confirmed **byte-identical Git blobs** between the old native source
and then-current `main`. The small source-only suite additionally
rejects ten fabricated/incorrect result fixtures.

**Important limits:** The old native package's
`browser/moz.configure` source differs from present HEAD. Thus this
is **NOT** a current exact whole-browser compiled-source acceptance,
and reusing seven identical module blobs does not change that.
Importing `ExtensionStorageSyncKinto` does **not** prove successfully
writing data with `storage.sync`, authenticating FxAccounts, remote
tab synchronization, conflict resolution, or cloud upload.
The module tests do not exercise the entire downstream native Rust,
security or provider network dependency graph. The absence of
credentials is not a test of behavior *while signed in*.
This is not approval to drop Sync/FxAccounts or ship a lean build.

The initial two trials [40984761275](https://github.com/sguzman/vulpra/actions/runs/40984761275)
and [40984871838](https://github.com/sguzman/vulpra/actions/runs/40984871838)
failed on a mistaken test-harness `AccountsGlue` import URL; the
actual registration is under `moz-src:///browser/components/`.
The static-vs-instance FxAccounts API check was corrected before the
first workflow was launched. Neither failure proved a browser regression.
The final passing runtime uses the corrected actual source module
registration.

**Progress:** Useful new runtime acceptance for the already
protected retained modules; **M3 remains 2/6 (33%), overall 44%**.
No source removal or new package savings.

## Newer-source full-normal browser: eight protected account/Sync API checks

[Newer full-normal actual browser CI 41078779642](https://github.com/sguzman/vulpra/actions/runs/41078779642)
**PASSED**, bounded redacted evidence artifact **12987978329**,
and [workflow lint 41078779645](https://github.com/sguzman/vulpra/actions/runs/41078779645)
**PASSED**. The original compiled normal browser was produced at exact
source `b1482404dfb8b01342990ee99ea3df0f9756b5f7` by [native build
40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527).
This actual full-Normandy package has SHA-256
`7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a`,
**87,154,544 compressed bytes**. Its checksum, metadata, seven protected
source-module/build Git blobs and prior full-normal headless New Tab test
were authenticated before the separate Sync/FxAccounts native runtime.

An independently started headless Vulpra in a disposable profile passed
**8/8 actual shipped module/API observations**:
`sync_ui_module`, `sync_ui_default_not_configured`,
`weave_lazy_module`, `fxa_singleton`,
`fxa_no_signed_in_account`, `extension_storage_sync_loaded`,
`accounts_glue_module`, `firefox_view_controller`. No account token,
real user profile, login, remote Sync or nonlocal Gecko connection was
provided by the test.

The evidence JSON inherits an older harness status name
`historical_normal_native_sync_fxa_module_smoke_passed`, but its new
explicit provenance fields authenticate the **newer exact compiled source**,
original build run and full-normal archive digest. This is **not the
post-test documentation HEAD** and does not prove signed-in Sync, remote
cloud synchronization, WebExtension `storage.sync` transaction behavior,
account authentication, or safety after source removal. Keep the protected
Sync/FxAccounts clients and their fallback obligations.

**M3 2/6 (33%), overall 44%, Δ0 pp; no new broad gate.**
