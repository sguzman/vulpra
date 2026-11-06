# Security 159 CSS crashtest independent evidence controls

This source/package reconciliation uses `ci/security-159-css-evidence.jq`
and `ci/tests/security-159-css-evidence-tests.sh`. The validator requires
three ordered original upstream Mozilla Bug 2079035 crashtest replay
iterations in a real packaged browser and links the bounded replay
to a successful exact-source native browser run and package checksum.

The test rejects twenty deliberately forged CSS evidence or native source,
run, package, TLS-policy and scope flags. This does not replace actual
full-native security branch build and WebDriver replay.

Only the earlier known pre-replay commit `6e38e787...` is exempted from
retroactive CSS credit. It is **not** considered to have passed this check.
All later successful security-source builds must supply the genuine CSS
replay report, and successful source/CI metadata checks do not establish
security-current browser readiness, sanitizer safety, complete upstream
advisory coverage, workstation parity or M3 final dependency closure.

## Verified 2026-11-06 — separate patched native browser

A complete normal packaged Vulpra was built on the isolated
`security/firefox-159-postbeta-hotfixes` branch at exact source SHA
`8bfc833c47226533a55047c5575b2a6f382249f2`.
[Original native workflow 42224511431](https://github.com/sguzman/vulpra/actions/runs/42224511431)
completed successfully, including private Wayland, JavaScript navigation,
temporary WebExtension, Nimbus, and normal certificate-rejection checks.
The real packaged browser then executed the original Mozilla CSS Bug 2079035
crashtest three times, plus original SVG Bug 2079252, table Bug 2079036,
and multicolumn Bug 2079255 crash fixtures twice each.

[Independent reconciliation 42231630654](https://github.com/sguzman/vulpra/actions/runs/42231630654)
passed on `main`, separately authenticating the upstream patched source blobs,
the selected native source commit, package checksum and runtime evidence,
the exact Git objects for all three added original fixtures and their
browser-test driver, and all nine reported original fixture replays.
[Bounded reconciled artifact 13510340553](https://github.com/sguzman/vulpra/actions/runs/42231630654/artifacts/13510340553)
is retained with the CI run, subject to its expiry.

This closes the **specific pending native replay and independent evidence
reconciliation** task. It is not proof of ASAN/UBSAN memory safety, exploit
resistance, entire Firefox 159 advisory coverage, real target
EndeavourOS/Hyprland workstation parity, the M3 sixth dependency-closure
gate, or public-release readiness. No security-branch merge or source pruning
is authorized by these bounded tests.
