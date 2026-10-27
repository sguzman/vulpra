#!/usr/bin/env bash
set -euo pipefail
script="${1:?expected path to M3 optional-boundary scanner}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/browser/components/asrouter" "$tmp/browser/components/tests" \
  "$tmp/services/fxaccounts" "$tmp/toolkit/components/telemetry"
printf '#!/bin/sh\n' > "$tmp/mach"
printf '// SidebarChatBotPromo and Pocket\n' > "$tmp/browser/components/asrouter/promo.js"
printf '// SponsoredTopSites\n' > "$tmp/browser/components/tests/test.js"
printf '// AccountsGlue imports FxAccounts\n' > "$tmp/services/fxaccounts/accounts.js"
printf '// TelemetrySend is distinct from Glean\n' > "$tmp/toolkit/components/telemetry/report.js"
git -C "$tmp" init -q
git -C "$tmp" add .
git -C "$tmp" -c user.email=qa@vulpra.invalid -c user.name=QA commit -qm fixture
bash "$script" "$tmp" "$tmp/report"
test "$(wc -l < "$tmp/report/pocket.matches.txt")" -eq 1
test "$(wc -l < "$tmp/report/promotion.matches.txt")" -eq 2
test "$(wc -l < "$tmp/report/promotion.source-paths.txt")" -eq 1
test "$(wc -l < "$tmp/report/sync.matches.txt")" -eq 1
test "$(wc -l < "$tmp/report/reporting.matches.txt")" -eq 1
cmp -s "$tmp/report/source-commit.txt" <(git -C "$tmp" rev-parse HEAD)
test -f "$tmp/report/README.txt"
echo 'PASS: optional-boundary scanner fixture, grouping, test exclusion and SHA.'
