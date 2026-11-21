#!/usr/bin/env bash
# Static packaging and UI CSS contract; no Firefox build or profile access.
set -Eeuo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
css="$root/browser/themes/shared/tabbrowser/vulpra-compact-tabs.css"
shared="$root/browser/themes/shared/browser-shared.css"
jar="$root/browser/themes/shared/jar.inc.mn"
[[ -s "$css" && -f "$shared" && -f "$jar" ]] ||
  { echo 'FAIL: Vulpra CSS or theme registration absent' >&2; exit 1; }
grep -Fxq '  skin/classic/browser/tabbrowser/vulpra-compact-tabs.css      (../shared/tabbrowser/vulpra-compact-tabs.css)' "$jar"
grep -Fxq '@import url("chrome://browser/skin/tabbrowser/vulpra-compact-tabs.css");' "$shared"
num_imports="$(grep -Fc '@import url("chrome://browser/skin/tabbrowser/vulpra-compact-tabs.css");' "$shared")"
[[ "$num_imports" -eq 1 ]] || { echo 'FAIL: duplicate CSS import' >&2; exit 1; }
stock_line="$(grep -nF 'tabbrowser/tabs.css");' "$shared" | cut -d: -f1)"
vulpra_line="$(grep -nF 'tabbrowser/vulpra-compact-tabs.css");' "$shared" | cut -d: -f1)"
[[ "$vulpra_line" -gt "$stock_line" ]] ||
  { echo 'FAIL: Vulpra CSS must load after upstream tabs.css' >&2; exit 1; }
for fragment in \
  '--tab-min-height: 27px !important;' \
  'padding-inline-start: 7px !important;' \
  'margin-inline: 2px !important;' \
  'border-radius: 5px !important;' \
  'font-family: "Lexica Ultralegible", "Luciole", "Atkinson Hyperlegible", sans-serif !important;' \
  'tab-group > .tab-group-label-container > .tab-group-label-hover-highlight {' \
  'tab-group > .tab-group-overflow-count-container .tab-group-overflow-count {' \
  'margin-inline-end: 0 !important;' \
  'border-radius: 0 !important;'; do
  grep -Fq -- "$fragment" "$css" ||
    { printf 'FAIL: missing expected Vulpra CSS: %s\n' "$fragment" >&2; exit 1; }
done
[[ "$(grep -Fc 'margin-inline-start: 2px !important;' "$css")" -eq 2 ]] ||
  { echo 'FAIL: both collapsed group items need the same 2px inset' >&2; exit 1; }
[[ "$(grep -Fc '#tabbrowser-tabs[orient="vertical"]:not([expanded])' "$css")" -eq 2 ]] ||
  { echo 'FAIL: collapsed group rules must not modify expanded tab groups' >&2; exit 1; }
[[ "$(grep -Fc '#tabbrowser-tabs[orient="vertical"][expanded]' "$css")" -gt 3 ]] ||
  { echo 'FAIL: expanded-only source styling was lost' >&2; exit 1; }
# All tab geometry declarations are scoped; never enforce global/system theme colors.
! grep -Eq -- '(background-color: *#[0-9a-fA-F]{3,8}|color: *#[0-9a-fA-F]{3,8})' "$css" ||
  { echo 'FAIL: hard-coded theme colors added to tab chrome' >&2; exit 1; }
echo 'PASS: Vulpra CSS shipped and loaded after Mozilla tabs.css with original Firefox compact styling'
echo 'PASS: collapsed badges/counters align to 2px tab outlines, no expanded-sidebar override'
echo 'LIMIT: static packaging/selector checks only, actual browser rendering untested'
