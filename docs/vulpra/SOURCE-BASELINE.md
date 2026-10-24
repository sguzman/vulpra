# Verified Firefox 159.0b5 source baseline

[GitHub Actions source-inventory run 40125494649](https://github.com/sguzman/vulpra/actions/runs/40125494649) measured the **pristine** `upstream-base` checkout, not the modified Vulpra tree or an installed binary. A full report is available as the `vulpra-1590b5-upstream-source-metrics` workflow artifact; its SHA-256 is `f027ff50a4601be0a1f99160a8e7d4bf98c1ede38a7ecbe4fd7958000c78e85e`. The checked-in machine-readable summary is [source-baseline-summary.json](source-baseline-summary.json).

- **483,770 regular files**.
- **3,633,991,406 file-content bytes**, or approximately **3.63 GB** decimal (3.38 GiB).
- Sizes exclude Git objects, directory allocation, symlink target bytes and any compiled application output. This differs from the earlier `du` result for extracted source (approximately 4.9 GB), which includes filesystem allocation.
- The full workflow report includes every first-level directory and file extension; this summary preserves the largest verified values without misrepresenting the rest.

## Largest upstream directories (file-content bytes)

| Directory | Files | Bytes |
| --- | ---: | ---: |
| `third_party` | 54,647 | 942,679,171 |
| `testing` | 201,089 | 776,796,490 |
| `dom` | 32,406 | 271,653,539 |
| `security` | 7,357 | 234,319,326 |
| `js` | 72,934 | 220,218,929 |
| `toolkit` | 11,541 | 173,502,732 |
| `intl` | 8,172 | 172,053,735 |
| `mobile` | 15,570 | 133,583,277 |
| `browser` | 11,649 | 119,068,827 |
| `devtools` | 9,725 | 95,216,242 |
| `layout` | 24,349 | 71,610,307 |
| `gfx` | 6,829 | 70,432,581 |
| `media` | 3,517 | 66,212,230 |
| `taskcluster` | 1,267 | 65,479,425 |
| `netwerk` | 2,521 | 22,586,145 |

## What this tells us for pruning

`testing/` includes a large amount of test material and is **not synonymous with runtime bloat**. `third_party/` includes potentially critical dependencies and requires dependency mapping before deletion. `mobile/` and `taskcluster/` warrant separate Linux-desktop build-dependency audits before pruning. We must separately measure packaged bytes, build duration, RAM and startup behavior before claiming a browser-performance win.

**No source deletion is approved or credited by this inventory alone.** After a passing full native build, compare each accepted removal against this source snapshot and compiled/package baselines.
