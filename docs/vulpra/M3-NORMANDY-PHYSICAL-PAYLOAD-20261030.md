# M3: physical file/embedded resource accounting for the first matched Normandy pair

**2026-10-30 UTC**, checked directly from two independently built native archives
at the **same** source `674db8e385c36aec23e78bbe059b2a1fec194fae`.
Read-only physical payload CI: [40983063003 PASS](https://github.com/sguzman/vulpra/actions/runs/40983063003),
report artifact **12945337486**.

The job checked the original lean/full build run status and exact SHA before
downloading and independently rehashing the full two 87 MB tar.xz artifacts.
It never extracted archive members to disk, executed packaged browser code,
used a user profile, or claimed runtime success from mere file matching.
The original candidate browser runtime was separately accepted by
[40439671494](https://github.com/sguzman/vulpra/actions/runs/40439671494).

| Physically measured property | Full normal | Opt-in Normandy-free |
| --- | ---: | ---: |
| Compressed tar.xz archive | 86,937,548 B | 86,909,928 B |
| Sum of regular tar member logical bytes | 339,564,498 B | 339,454,609 B |
| Tar members including directories | 58 | 58 |
| Archive SHA-256 | `47c8ac5ce90747c051eac8daf24544d88767fdeb989293c0b50c5e8ac9e53c30` | `4888a1955883406f64a48cca6eedd28e359d0583596e68ec23f3d7280c165062` |

**Difference:** 27,620 B compressed outer archive; **109,889 B**
sum-of-regular-member logical bytes. The second and third independently
matched Normandy pairs also reported the same **109,889 B** total
logical-content-size difference, despite their different compressed
archive deltas (**15,752** and **17,352 B**). This is a repeatable
**observed net logical-size difference**, not a demonstration that those
bytes belong exclusively to one recipe-runner file.

## Independent reconciliation across three source revisions

[Three-pair variance CI 40983703521](https://github.com/sguzman/vulpra/actions/runs/40983703521)
**PASSED**, artifact **12945423159**. It downloaded only
the original checksum-bearing machine reports of source-matched comparisons
[40439793884](https://github.com/sguzman/vulpra/actions/runs/40439793884),
[40968688858](https://github.com/sguzman/vulpra/actions/runs/40968688858)
and [40976632873](https://github.com/sguzman/vulpra/actions/runs/40976632873),
not more full browser binaries. The workflow authenticated the
original three native candidates and independent runtime acceptances.
Ten falsification fixtures guard report source identity, SHA-256 fields,
arithmetic, percentages and other invalid claims.

| Source-matched pair | Signed observed compressed B | Signed net regular logical B |
| --- | ---: | ---: |
| `674db8e385c3` | 27,620 | 109,889 |
| `034ddd665a08` | 15,752 | 109,889 |
| `ad0dea4a317c` | 17,352 | 109,889 |

The **regular-file net logical difference is identical in these three
independent source revisions**, but the compressed archive difference
is *not invariant*. Neither this report nor the physical payload audit
isolates all causal recipe-runner bytes or measures future builds.

## SHA-256 physical file census

- **47 regular files or links with matching paths** in both packages:
  **34** content-identical, **13** content-different, **0** added and
  **0** removed at the outer tar-member file level.
- Some changed physical files are native binaries: `libxul.so`,
  `libmozavcodec.so`, `libfreeblpriv3.so`, `libsmime3.so`,
  `libsoftokn3.so`, `crashhelper`, `crashreporter`, `vulpra` and
  `vulpra-bin`; `application.ini`, `platform.ini` and both
  `omni.ja` also differ.
- Inside the two `omni.ja` ZIP packages, **22** file resources were
  removed, **1** was added, **5** existing entries changed, and
  **7,974** resource entries have identical SHA-256 bytes.
- All 22 removed inner resources have the namespace
  `chrome/toolkit/res/normandy/`, including the runner, migration,
  actions, study page, heartbeat resources and vendor files.
- The sole added resource is
  `moz-src/toolkit/components/nimbus/NimbusBootstrap.sys.mjs`.
  `ClientEnvironment.sys.mjs`, `NormandyUtils.sys.mjs` and
  `NormandyApi.sys.mjs` remain in the lean archive.
- The five modified ZIP resources are two manifests,
  `aboutSupport.xhtml`, `buildconfig.html` and
  `AppConstants.sys.mjs`. These may legitimately encode different
  native configuration or manifest registries.

The independent scanner `ci/m3-native-package-payload-diff.py` uses
SHA-256 of every regular tar file and embedded ZIP member, rejects unsafe
tar/ZIP names, never follows symlinks and preserves only a bounded JSON
report. [Its CI workflow](https://github.com/sguzman/vulpra/actions/workflows/m3-native-package-payload-diff.yml)
tests malformed archive fixtures and verifies provenance. A subsequent
tightened workflow also requires exactly this **22/1/5/7974** manifest
difference and refuses any removed resources outside the Normandy path.

**Limits:** Differences in native binaries and manifests prevent treating
27,620 B compressed as an isolated, causal runner saving. Package tar metadata
and compression can differ between builds. This does not prove all source
consumers were removed or that the browser is secure with every Normandy
feature disabled. Full dynamic dependency/ABI/loader, protected New Tab,
FxAccounts/Sync and telemetry privacy behavior remain separately gated.

No default Vulpra build feature was changed, no further source deletion
was authorized, and no M3 whole acceptance gate advanced:
**M3 2/6 (33%), overall 44%.**
