#!/usr/bin/env bash
# M3 focused telemetry submission / policy / local Glean boundaries. READ ONLY.
# Literal references do not establish dynamic reachability or safe removal.
set -euo pipefail
root="${1:-.}"
output="${2:?usage: m3-telemetry-reference-audit.sh CHECKOUT OUTPUT_DIR}"
cd "$root"
test -f mach
test "$(git rev-parse --is-inside-work-tree)" = true
command -v jq >/dev/null
mkdir -p "$output"
output="$(cd "$output" && pwd)"
matches="$output/references.txt"
records="$output/references.tsv"
report="$output/report.json"
rc=0
git grep -I -n -E \
  -e 'TelemetrySend[.]sys[.]mjs' \
  -e 'TelemetryReportingPolicy[.]sys[.]mjs' \
  -e 'TelemetryControllerParent[.]sys[.]mjs' \
  -e 'MOZ_TELEMETRY_REPORTING' \
  -e 'MOZ_DATA_REPORTING' \
  -e 'toolkit[.]telemetry[.]' \
  -e 'datareporting[.](policy|healthreport)[.]' \
  -e 'GleanPings' \
  -e 'pingsender' \
  -- . > "$matches" || rc=$?
if ((rc>1)); then echo "FAIL: git grep status $rc" >&2; exit "$rc"; fi
awk '
  {
    i=index($0,":")
    if (!i) {print "bad grep path" > "/dev/stderr"; exit 2}
    path=substr($0,1,i-1)
    rest=substr($0,i+1)
    j=index(rest,":")
    if (!j) {print "bad grep location" > "/dev/stderr"; exit 2}
    line=substr(rest,1,j-1)
    if (line !~ /^[0-9]+$/) {print "bad line number" > "/dev/stderr"; exit 2}
    if (path ~ /^testing\// || path ~ /(^|\/)(test|tests)\// ||
        path ~ /(^|\/)test_[^\/]*$/) klass="test-only"
    else if (path ~ /^browser\/locales\// || path ~ /^l10n\// ||
             path ~ /\.(ftl|dtd|properties)$/) klass="localization"
    else if (path ~ /^(docs|ci|\.github)\// || path ~ /(^|\/)docs\// ||
             path ~ /\.(md|rst)$/) klass="docs-tooling"
    else if (path ~ /^toolkit\/components\/telemetry\/app\//) klass="telemetry-policy-and-sender"
    else if (path ~ /^toolkit\/components\/telemetry\//) klass="telemetry-native-and-other"
    else if (path ~ /^toolkit\/components\/glean\//) klass="glean-runtime"
    else if (path ~ /^toolkit\/crashreporter\//) klass="crashreporter"
    else if (path ~ /^browser\//) klass="browser-consumer"
    else if (path ~ /^toolkit\//) klass="toolkit-consumer"
    else klass="other"
    printf "%s\t%s\t%s\n",path,line,klass
  }
' "$matches" > "$records"
commit="$(git rev-parse HEAD)"
jq -Rn --arg commit "$commit" '
  [inputs|select(length>0)|split("\t")|{
      path:.[0],line:(.[1]|tonumber),class:.[2]}] as $lines
  | {
      schema_version:1,phase:"M3",
      candidate:"telemetry_submission_and_policy",
      source_commit:$commit,
      matching_lines:($lines|length),
      counts_by_class:(reduce $lines[] as $m ({}; .[$m.class]=((.[$m.class]//0)+1))),
      outside_consumers:([$lines[]|
        select(.class=="browser-consumer" or .class=="toolkit-consumer" or .class=="other")]
        |group_by(.path)|map({path:.[0].path,lines:length})|sort_by(-.lines,.path)),
      matches:$lines,
      removal_authorized:false,
      decision:"Keep native telemetry/Glean/crashreporter; evaluate reporting/ping transport only after actual configured defaults, upload policy and caller graph are verified",
      limitations:[
        "Source-only literal matching includes comments, prefs, tests and third-party data",
        "Dynamic callers and actual network submission are not established",
        "A telemetry reporting preference is not proof of data leaving the browser",
        "Removing transport code without guarding caller lifecycle can break startup or shutdown",
        "No native build, package-size result or source deletion from this audit"
      ]
    }
' < "$records" > "$report"
jq -e '.matching_lines>0
  and (.counts_by_class["telemetry-policy-and-sender"]//0)>0
  and (.counts_by_class["telemetry-native-and-other"]//0)>0
  and (.counts_by_class["browser-consumer"]//0)>0
  and .removal_authorized==false' "$report" >/dev/null
echo "PASS: pinned-source telemetry policy/transport/Glean dependency inventory at $commit"
jq -r '"Literal matching lines: \(.matching_lines)",
 (.counts_by_class|to_entries[]|"  \(.key): \(.value)"),
 "Top external consumers:",(.outside_consumers[:30][]|"  \(.lines) \(.path)")' "$report"
echo "AUDIT ONLY: no telemetry/Glean/crashreporter deletion or M3 credit"
