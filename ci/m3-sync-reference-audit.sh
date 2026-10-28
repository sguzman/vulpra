#!/usr/bin/env bash
# M3 focused desktop Sync / Firefox Accounts dependency audit. READ ONLY.
# Literal matches and path classes are not dynamic reachability evidence.
set -euo pipefail
root="${1:-.}"
out="${2:?usage: m3-sync-reference-audit.sh CHECKOUT OUTPUT_DIR}"
cd "$root"
test -f mach
test "$(git rev-parse --is-inside-work-tree)" = true
command -v jq >/dev/null
mkdir -p "$out"
out="$(cd "$out" && pwd)"
matches="$out/references.txt"
records="$out/references.tsv"
report="$out/report.json"
rc=0
git grep -I -n -E \
    -e 'resource://services-sync/' \
    -e 'resource://gre/modules/FxAccounts' \
    -e 'MOZ_SERVICES_SYNC' \
    -e 'services[.]sync[.]' \
    -e 'FxAccounts' \
    -e 'fxAccounts' \
    -e 'SyncedTabs' \
    -e 'SyncDisconnect' \
    -- . > "$matches" || rc=$?
if (( rc > 1 )); then
    echo "FAIL: git grep exited $rc" >&2
    exit "$rc"
fi
awk '
  {
    a=index($0, ":")
    if (!a) { print "Invalid grep result: " $0 > "/dev/stderr"; exit 2 }
    path=substr($0,1,a-1)
    rest=substr($0,a+1)
    b=index(rest,":")
    if (!b) { print "Missing line number: " $0 > "/dev/stderr"; exit 2 }
    line=substr(rest,1,b-1)
    if (line !~ /^[0-9]+$/) {print "Bad line number" > "/dev/stderr";exit 2}
    if (path ~ /^testing\// || path ~ /(^|\/)(test|tests)\// ||
        path ~ /(^|\/)test_[^\/]*$/ ||
        path ~ /^browser\/extensions\/newtab\/test\//) klass="test-only"
    else if (path ~ /^browser\/locales\// || path ~ /^l10n\// ||
             path ~ /\.(ftl|dtd|properties)$/) klass="localization"
    else if (path ~ /^(docs|ci|\.github)\// || path ~ /(^|\/)docs\// ||
             path ~ /\.(md|rst)$/) klass="docs-tooling"
    else if (path ~ /^services\/sync\//) klass="sync-owned"
    else if (path ~ /^services\/fxaccounts\//) klass="accounts-owned"
    else if (path ~ /^(toolkit|browser)\/components\/extensions\//) klass="webextension-integrations"
    else if (path ~ /^browser\//) klass="browser-integration"
    else klass="other-integrations"
    printf "%s\t%s\t%s\n", path, line, klass
  }
' "$matches" > "$records"
commit="$(git rev-parse HEAD)"
jq -Rn --arg commit "$commit" '
  [inputs | select(length > 0) | split("\t") |
    {path:.[0], line:(.[1]|tonumber), class:.[2]}] as $rows
  | {
      schema_version:1,
      phase:"M3",
      candidate:"sync_services_and_firefox_accounts",
      source_commit:$commit,
      matching_lines:($rows|length),
      counts_by_class:(reduce $rows[] as $r ({}; .[$r.class] = ((.[$r.class] // 0) + 1))),
      consumers:([$rows[] |
          select(.class == "browser-integration" or .class == "webextension-integrations" or .class == "other-integrations")
        ] | group_by(.path) | map({path:.[0].path, lines:length}) | sort_by(-.lines,.path)),
      matches:$rows,
      removal_authorized:false,
      decision:"Retain Sync and FxAccounts pending explicit caller/fallback mapping and protected native candidate",
      limitations:[
        "Literal grep may match comments and miss computed or indirect module imports",
        "Classifications reflect file ownership, not proof of live runtime reachability",
        "Sync browser UI, FxAccounts, WebExtension identity and startup glue require independent evaluation",
        "This job neither compiles, disables nor measures browser services"
      ]
    }
' < "$records" > "$report"
jq -e '
    .matching_lines > 0
    and (.counts_by_class["sync-owned"] // 0) > 0
    and (.counts_by_class["accounts-owned"] // 0) > 0
    and (.counts_by_class["browser-integration"] // 0) > 0
    and .removal_authorized == false
' "$report" >/dev/null
echo "PASS: Sync/FxAccounts pinned-source reference inventory at $commit"
jq -r '"Literal matching lines: \(.matching_lines)",
    (.counts_by_class | to_entries[] | "  \(.key): \(.value)"),
    "Top outside callers:",
    (.consumers[:30][] | "  \(.lines) \(.path)")' "$report"
echo "AUDIT ONLY: no deletion, byte or milestone credit authorized"
