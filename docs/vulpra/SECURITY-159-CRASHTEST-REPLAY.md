# Original upstream CSS crashtest replay

The maintenance branch carries Mozilla Bug 2079035 / CVE-2026-120572's unchanged upstream HTML fixture.
The isolated packaged-browser replay in `ci/security-159-crashtest-smoke.py` navigates to that exact fixture
three times through stock geckodriver, verifies the three-column fragmentation trigger's
layout/width/text mutations and subsequent live DOM, preserves a private profile sentinel,
and writes `security-159-css-crashtest-replay.json` under `.git/vulpra-native-build`.

Use `python3 ci/security-159-crashtest-smoke.py --self-test` to check source integrity
and negative DOM-predicate fixtures without building a browser. The default invocation
requires a checksum-verified native Vulpra package and geckodriver on PATH.

The original fixture is pinned to Git blob SHA-1 `31a14963b356d869475bac62ca44991d9275a285`.
The source fixture CI is not a runtime/browser result. A successful replay is not
a complete WPT crashtest harness, ASAN proof, proof of all security fixes,
or release readiness. The runtime check is staged for later wiring into
the full native security workflow; it does not alter the frozen M3 comparison.

No progress credit: overall 61%, M3 5/6 gates (83%).

## Full-native workflow integration

The security-branch normal native build now invokes the original upstream
crashtest replay **after** genuine packaged Wayland/JS/WebExtension/Nimbus
acceptance. It requires all three real DOM/forced-layout iterations, exact
fixture Git blob, same full source SHA, a private profile, and explicit
limitations. The bounded replay record is included in the same native evidence
artifact that the independently triggered security reconciler downloads.
The script's source-only negative fixtures also run before the expensive build.

This change triggers a new security native build; earlier builds cannot be
credited with a replay that they did not execute. No source pruning, broad
vulnerability remediation, target-workstation parity, or M3 sixth gate is
inferred from a passing bounded crashtest.
