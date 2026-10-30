# M3 third same-source Normandy opt-out native package comparison

**2026-10-30 UTC.** Third source-matched Normandy omission experiment from
`ad0dea4a317cfe5f22213f6dc778366c6dc042d0`; the normal/default
browser source remains unchanged by this opt-in experiment.

- [Opt-in Normandy-free native build 40954395174](https://github.com/sguzman/vulpra/actions/runs/40954395174)
  **PASSED** compiler, package, checksum, isolated localhost/Wayland smoke.
- [Separate real packaged candidate runtime 40976502356](https://github.com/sguzman/vulpra/actions/runs/40976502356)
  **PASSED**.
- [Independently compiled source-matched full-Normandy baseline and size
  comparison 40976632873](https://github.com/sguzman/vulpra/actions/runs/40976632873)
  **PASSED**. Artifact **12943929109**.

| Metric | Full normal | Opt-in no Normandy runner |
| --- | ---: | ---: |
| Compressed package bytes | 87,151,648 | 87,134,296 |
| Sum of regular file logical bytes | 339,566,140 | 339,456,251 |
| Package SHA-256 | `ce033a97e72a673d6f174e82ba93a163ac39b8357428b5261c07da6b76376980` | `ca8f3495da6122dec7a7715459534605da7d9270375b3114c4c7bf06cfeff729` |

The signed observed compressed difference is **+17,352 B saved** for
the source-matched opt-in omission (**0.020%** as rounded in CI). Normandy's
recipe runner is absent from the lean browser, while the shared Nimbus
helpers remain. This measured CI archive-size difference is not per-feature
linked bytes or a guaranteed savings forecast for a new build.

## Multiple independent Normandy trials

| Source-pinned experiment | Full compressed B | Opt-in compressed B | Observed reduction B |
| --- | ---: | ---: | ---: |
| [First 40439793884](https://github.com/sguzman/vulpra/actions/runs/40439793884) | 86,937,548 | 86,909,928 | 27,620 |
| [Second 40968688858](https://github.com/sguzman/vulpra/actions/runs/40968688858) | 87,153,852 | 87,138,100 | 15,752 |
| [Third 40976632873](https://github.com/sguzman/vulpra/actions/runs/40976632873) | 87,151,648 | 87,134,296 | 17,352 |

These comparisons use **different source revisions** and must
**not** be added together, averaged as a causal component size, or
claimed as a stable per-feature size. They each establish a positive
bounded archive delta and relevant native/runtime fallback for
their particular source-matched opt-in pair.

This strengthens the already accepted isolated-removal subtask.
It does not prove complete candidate classification, dynamic
`dlopen` dependency closure, feature-wide fallback, security or privacy
audit, or Arch workstation compatibility. No further source deletion is
authorized by these comparisons. **M3: 2/6 (33%). Overall: 44%.**
