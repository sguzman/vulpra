# M3 — Newer full-normal native ELF and localization cross-source reconciliation

**Accepted read-only CI:** [41077981663](https://github.com/sguzman/vulpra/actions/runs/41077981663)
**PASS**, with immutable evidence artifact **12988306891**.
[Workflow lint 41077981730](https://github.com/sguzman/vulpra/actions/runs/41077981730)
**PASS**. The verifier is committed in
[`93f18ad`](https://github.com/sguzman/vulpra/commit/93f18adbf566cff1b04448538b92d9112330e80c).

## Provenance

The two sources were independently compiled and packaged as **normal,
full-Normandy Linux Vulpra**, with no opt-in feature omission in this
comparison.

| Provenance | Prior full-native | Newer full-native |
| --- | --- | --- |
| Compiled source SHA | `cde4d83043f8c476173c8dbc78b66b078c3f6b5b` | `b1482404dfb8b01342990ee99ea3df0f9756b5f7` |
| Original native build run | [40963098075](https://github.com/sguzman/vulpra/actions/runs/40963098075) | [40997075527](https://github.com/sguzman/vulpra/actions/runs/40997075527) |
| Archive SHA-256 | `18798900c5307fd136f7d93db6681741616981b609741a4b2209a1810273eb51` | `7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a` |
| Compressed native archive | 87,154,700 bytes | 87,154,544 bytes |
| Source-pinned runtime evidence | Native link/runtime within 40963098075 | [New Tab native runtime 41004025705](https://github.com/sguzman/vulpra/actions/runs/41004025705) |

The newer
[physical package ELF and locale inventory 41077034156](https://github.com/sguzman/vulpra/actions/runs/41077034156)
**PASSED** (artifact **12987621504**). The reconciliation authenticated
the original build and inventory CI run identities, original compiled
source SHAs, archive digests and link evidence before comparing any data.

## Per-file ELF direct dependency result

| Measured property | Prior full build | Newer full build |
| --- | ---: | ---: |
| ELF member paths | 28 | 28 |
| Direct `DT_NEEDED` edges | 268 | 268 |
| Distinct needed library names | 50 | 50 |
| Added/removed ELF paths | — | **0** |
| Files with changed `DT_NEEDED` or SONAME | — | **0** |
| ELF files with identical SHA-256 | — | **25** |
| ELF files with changed SHA-256 | — | **3** |

The three changed ELF payload hashes are **`./vulpra/libxul.so`**,
**`./vulpra/vulpra`**, and **`./vulpra/vulpra-bin`**.
The native binary is not byte-identical; its direct ELF dependency
declarations remain stable. The **156-byte compressed archive difference**
is observed *across different source revisions* and **must not** be
reported as a causal, isolated, repeatable or additive feature saving.

The historical full source from `1683ca67b69389a879717bcd537772c3b40624b6`
was independently checked in
[localization census 40923776304](https://github.com/sguzman/vulpra/actions/runs/40923776304).
Six protected resource categories from that earlier package were unchanged
in the newly compiled normal package:

| Protected nested resource category | Files | Logical bytes |
| --- | ---: | ---: |
| Browser localization | 137 | 689,418 |
| Toolkit localization | 104 | 312,382 |
| Default locale | 1 | 6 |
| Dictionaries | 2 | 552,470 |
| Hyphenation | 46 | 4,471,692 |
| Legacy chrome localization | 93 | 274,525 |
| **Classified subtotal** | **383** | **6,300,493** |

The newer root `omni.ja` has **2,674 entries**; the newer browser
`omni.ja` has **5,327 entries**. This is a **classification-specific**
preservation check, not proof that all bundled files are unchanged.
Unclassified entries are not included. Logical bytes inside nested ZIP
files do **not** equal recoverable compressed `tar.xz` savings.

## Limits and next boundary

This comparison is static direct ELF metadata plus categorized physical
resource preservation, independently associated with *actual normal
native builds*. It does not resolve symbol versions, ABI compatibility,
host dynamic loader selection, indirect `dlopen`, Rust/C++ ownership of
individual symbols, real remote recommendation fetches, or optional
localization fallbacks. The runtime evidence belongs to the original
native workflows, not the static comparison itself. No source removal or
feature savings are authorized.

**M3 remains 2 of 6 acceptance gates (33%); Vulpra overall 44%;
delta 0 percentage points.**
