# Decisions

## 2026-10-24 — snapshot, not a history-bearing GitHub fork

Import a pinned Firefox release as new Vulpra Git history rather than importing all of Mozilla's historic commits. Preserve the release tag, original commit hash, archive checksum and exact original tree.

## 2026-10-24 — distinct baseline and working branch

`upstream-base` is the untouched Mozilla snapshot. `main` carries Vulpra documentation and changes; the original Firefox tree remains available for provenance and diffs.

## 2026-10-24 — Linux-first, functionality before rewrite

Target x86-64 Linux, Wayland, Hyprland. Prove the baseline and isolate its profile before pruning. A full Rust plus web-technology browser remains the long-term architecture.

## 2026-10-24 — evidence before percentages

A source import, verified build, removal, regression test and shipped binary are different milestones. Record each with independent evidence. Treat uncertainties and failed attempts as incomplete.

## 2026-10-25 — resilient full source instead of iterative sparse-build failures

The first native Linux build is blocked on a partial local checkout rather than
a demonstrated compiler failure. Stop requesting individual source directories
as build errors reveal them. Acquire all tracked blobs for the pinned local HEAD
in small, retryable Git fetches, verify local object presence, and only then
disable sparse checkout. Keep successful objects across network disconnections;
do not reclone, discard tracked edits, or reset the working tree.

The downloader is ci/vulpra-fetch-all.sh. Its offline regression suite is
ci/tests/vulpra-fetch-all-test.sh. A complete local source checkout and a
successful native browser build are distinct acceptance gates.

## 2026-10-25 — native build on the Linux workstation

GitHub-hosted full-browser jobs repeatedly ended without a verified packaged
binary. Do not use hosted full-browser builds as the development loop.
The full-build workflow is manual-only to prevent automatic wasted attempts.
Continue the first native build on the target Linux x86-64 environment and
protect the pre-existing Firefox installation and profile. Mock launcher checks
and successful configure do not count as a working Vulpra browser.
