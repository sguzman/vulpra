#!/usr/bin/env bash
# Read-only, literal-reference census for the next M3 debloat candidates.
# It does not establish link-time reachability or authorize code removal.
set -euo pipefail

repo="${1:?usage: audit.sh <git-source-root> <output-dir>}"
outdir="${2:?usage: audit.sh <git-source-root> <output-dir>}"
cd "$repo"
test -f mach || { echo 'FAIL: missing source-root mach' >&2; exit 2; }
git rev-parse --verify HEAD >/dev/null
mkdir -p -- "$outdir"
outdir="$(cd "$outdir" && pwd)"
git rev-parse HEAD > "$outdir/source-commit.txt"

scan() {
  local id="$1" regex="$2" rc=0
  git grep --full-name -n -I -E -e "$regex" -- . > "$outdir/$id.matches.txt" || rc=$?
  ((rc <= 1)) || { echo "FAIL: git grep error for $id (exit $rc)" >&2; exit "$rc"; }
  # Keep source paths and full grep line evidence. Ignore test/doc matches
  # only when ranking review candidates; never discard them from the report.
  cut -d: -f1 "$outdir/$id.matches.txt" |
    awk '!/(^|\/)(tests?|testing|fixtures|docs|ci|\.github)(\/|$)/ && !/\.(md|rst|ftl|dtd)$/' |
    LC_ALL=C sort | uniq -c | sort -k1,1nr -k2,2 > "$outdir/$id.source-paths.txt"
  printf '%-13s %7d matching lines; %5d source files\n' \
    "$id" "$(wc -l < "$outdir/$id.matches.txt")" \
    "$(wc -l < "$outdir/$id.source-paths.txt")"
  echo "Most referenced non-test files for $id:"
  awk 'NR <= 20 {print}' "$outdir/$id.source-paths.txt"
}

# Distinct sets avoid treating Glean's in-browser infrastructure as
# evidence that legacy telemetry uploads are required (or vice versa).
scan pocket '(Pocket|pocket|saveToPocket)'
scan promotion '(SidebarChatBotPromo|SmartWindowNewTabPromo|NewtabPromoMessage|PinnableSitesProvider|OnboardingMessageProvider|ASRouterTelemetry|SponsoredTopSites|sponsoredTopSites)'
scan sync '(MOZ_SERVICES_SYNC|AccountsGlue|FxAccounts|services-sync/|SyncUIState|gSync\.init)'
scan reporting '(MOZ_TELEMETRY_REPORTING|MOZ_SERVICES_HEALTHREPORT|TelemetrySend|TelemetryController|TelemetryReportingPolicy|TelemetryScheduler|UsageReporting|GleanPings)'
cat > "$outdir/README.txt" <<'NOTE'
M3 read-only literal reference audit. *.matches.txt has complete matching source
lines; *.source-paths.txt ranks non-test non-doc matches by file. The
source-commit.txt file records the exact scanned Git HEAD. This does not
resolve dynamic imports, build-graph reachability, runtime behavior or sizes.
No removal is approved by this report.
NOTE
echo 'PASS: four candidate groups scanned; no source changed or deletion approved.'
