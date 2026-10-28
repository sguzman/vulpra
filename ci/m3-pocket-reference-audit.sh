#!/usr/bin/env bash
# M3 source-only Pocket/DiscoveryStream consumer audit.
# The output is evidence for classification, never permission to delete.
set -euo pipefail

root="${1:-.}"
output="${2:?usage: m3-pocket-reference-audit.sh CHECKOUT OUTPUT_DIR}"
cd "$root"
test -f mach
test "$(git rev-parse --is-inside-work-tree)" = true
command -v jq >/dev/null
mkdir -p "$output"
output="$(cd "$output" && pwd)"
references="$output/references.txt"
records="$output/references.tsv"
result="$output/report.json"

rc=0
git grep -I -n -i -E \
  -e 'pocket' \
  -e 'DiscoveryStreamFeed' \
  -e 'TopStoriesFeed' \
  -e 'discoverystream[.]' \
  -e 'feeds[.]section[.]topstories' \
  -e 'AdsClient[.]sys[.]mjs' \
  -e 'unifiedAds[.]' \
  -- . > "$references" || rc=$?
if (( rc > 1 )); then
  echo "FAIL: git grep failed with status $rc" >&2
  exit "$rc"
fi

# One TSV record per matching source line; retain original text separately.
# Record class is based on the referring file, not on a semantic conclusion.
awk '
  {
    colon = index($0, ":")
    if (!colon) { print "Invalid git grep line: " $0 > "/dev/stderr"; exit 2 }
    path = substr($0, 1, colon - 1)
    rest = substr($0, colon + 1)
    colon = index(rest, ":")
    if (!colon) { print "Invalid line number in: " $0 > "/dev/stderr"; exit 2 }
    line = substr(rest, 1, colon - 1)
    if (line !~ /^[0-9]+$/) { print "Bad line: " $0 > "/dev/stderr"; exit 2 }
    if (path ~ /^testing\// || path ~ /(^|\/)(test|tests)\// ||
        path ~ /(^|\/)test_[^\/]*$/) klass = "test-only"
    else if (path ~ /^browser\/locales\// || path ~ /^l10n\// ||
             path ~ /\.(ftl|dtd|properties)$/) klass = "localization"
    else if (path ~ /^(docs|ci|\.github)\// || path ~ /(^|\/)docs\// ||
             path ~ /\.(md|rst)$/) klass = "docs-tooling"
    else if (path ~ /^browser\/extensions\/newtab\//) klass = "newtab-owned"
    else if (path ~ /^browser\/components\/newtab\//) klass = "newtab-component"
    else if (path ~ /^browser\//) klass = "browser-external"
    else klass = "other-external"
    printf "%s\t%s\t%s\n", path, line, klass
  }
' "$references" > "$records"

commit="$(git rev-parse HEAD)"
jq -Rn --arg commit "$commit" '
  [inputs | select(length > 0) | split("\t") |
    {path: .[0], line: (.[1] | tonumber), class: .[2]}] as $matches
  | {
      schema_version: 1,
      phase: "M3",
      candidate: "pocket_integration",
      source_commit: $commit,
      matching_lines: ($matches | length),
      counts_by_class: (reduce $matches[] as $m ({}; .[$m.class] = ((.[$m.class] // 0) + 1))),
      external_source_paths: (
        [$matches[] | select(.class == "browser-external" or .class == "other-external")]
        | group_by(.path) | map({path: .[0].path, lines: length})
        | sort_by(-.lines, .path)
      ),
      matches: $matches,
      removal_authorized: false,
      next_gate: "Review live callers, New Tab fallback, Nimbus and packaged registrations before any guarded opt-out",
      limitations: [
        "Literal pattern matching may miss computed references or include comments",
        "New Tab feeds and Pocket labels overlap; no whole-tree removal is supported",
        "Does not build, change, or measure the native browser"
      ]
    }
' < "$records" > "$result"

jq -e '.matching_lines > 0
  and (.counts_by_class["newtab-owned"] // 0) > 0
  and .removal_authorized == false' "$result" >/dev/null

echo "PASS: Pocket/DiscoveryStream full-source reference inventory at $commit"
jq -r '"Matching lines: \(.matching_lines)", (.counts_by_class | to_entries[] | "  \(.key): \(.value)"), "External consumer paths:", (.external_source_paths[:35][] | "  \(.lines) \(.path)")' "$result"
echo "Outputs: $result / $references"
echo "AUDIT ONLY: no deletion authorized"
