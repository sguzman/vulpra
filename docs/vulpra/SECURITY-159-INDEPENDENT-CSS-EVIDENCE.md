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
