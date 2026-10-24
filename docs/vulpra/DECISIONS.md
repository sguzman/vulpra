# Decisions

## 2026-10-24 — snapshot, not a history-bearing GitHub fork

Import a pinned Firefox release as new Vulpra Git history rather than importing all of Mozilla's historic commits. Preserve the release tag, original commit hash, archive checksum and exact original tree.

## 2026-10-24 — distinct baseline and working branch

`upstream-base` is the untouched Mozilla snapshot. `main` carries Vulpra documentation and changes; the original Firefox tree remains available for provenance and diffs.

## 2026-10-24 — Linux-first, functionality before rewrite

Target x86-64 Linux, Wayland, Hyprland. Prove the baseline and isolate its profile before pruning. A full Rust plus web-technology browser remains the long-term architecture.

## 2026-10-24 — evidence before percentages

A source import, verified build, removal, regression test and shipped binary are different milestones. Record each with independent evidence. Treat uncertainties and failed attempts as incomplete.
