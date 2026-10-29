# M3: second source-matched opt-in Normandy runner omission

**2026-10-29:** [lean native build 40954193793](https://github.com/sguzman/vulpra/actions/runs/40954193793)
PASSED. Its isolated packaged browser passed private Weston Wayland and
localhost tests. [Independent candidate runtime run 40968542013](https://github.com/sguzman/vulpra/actions/runs/40968542013)
also **PASSED** the real packaged browser checks before the paired package
comparison was allowed to proceed.

[Matched same-source full versus lean comparison 40968688858](https://github.com/sguzman/vulpra/actions/runs/40968688858)
**PASSED**, preserving bounded comparison JSON in artifact **12941182844**.
Both compiled variants use exact source
`034ddd665a080f173ce45094ae3afb8868b45e1a` and matched non-omission
build settings. The full-Normandy independent native baseline compiled,
staged its archive, and passed checksum/feature boundary validation.

| Native archive metric | Full Normandy | Opt-in Normandy-free |
| --- | ---: | ---: |
| Compressed package bytes | 87,153,852 | 87,138,100 |
| Sum of regular-file logical bytes | 339,566,140 | 339,456,251 |
| Package SHA-256 | `4f51ccf82103dd0381702cf925bf0d786a559037f7ecb0633e045e591f9d633e` | `7095a57083a6211177fd182a2c5275d0ef8c8b2398f4eb1b3298ae951861adac` |

The **observed signed compressed archive delta is +15,752 B saved by the
opt-in omission (0.018%)** within this source-matched pair. Normandy's
recipe runner is absent in the lean package, but **shared Nimbus helpers
remain**. Normal/default Vulpra retains the original Normandy components.

The earlier **independent** [Normandy native matched pair 40439793884](https://github.com/sguzman/vulpra/actions/runs/40439793884)
observed **27,620 B (0.032%)** at a *different source commit*.
The 11,868 B difference between those two experiments means neither
result is a proven invariant, causal feature size or forecast for all
future builds. These savings are **not additive**, should not be
subtracted from the current main normal package, and do not prove that
other omissions are safe. Neither report is a target Arch workstation
measurement.

This recheck strengthens the previously accepted **per-removal native
evidence** gate, not another full M3 roadmap gate. M3 still requires
the broader feature dependency map, complete candidate classifications,
promotional/Sync/telemetry audits and mobile/testing/localization audits.
**M3 2/6 (33%); overall 44%; Δ 0 percentage points.**
