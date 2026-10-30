#!/usr/bin/env bash
# Conservative baseline protection for Vulpra testing/build/QA source.
# All anchors are actual Git HEAD records, never guesses from filenames.
# Deliberately does NOT authorize removal of peripheral fixtures.
set -euo pipefail
root="${1:-$(git rev-parse --show-toplevel)}"
out="${2:-}"
test -d "$root/.git"
test -f "$root/mach"
command -v jq >/dev/null
cd "$root"
sha="$(git rev-parse HEAD)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/cache"
: > "$tmp/evidence.jsonl"
checked=0
rejected=0
get() {
  local path="$1" file="$tmp/cache/$1"
  if [[ ! -f "$file" ]]; then
    mkdir -p -- "$(dirname "$file")"
    git show "HEAD:$path" > "$file"
  fi
  printf '%s\n' "$file"
}
one() {
  local hits
  hits="$(grep -F -c -- "$2" "$1" || true)"
  [[ "$hits" == 1 ]]
}
check() {
  local name="$1" path="$2" fragment="$3" file line blob
  file="$(get "$path")"
  if ! one "$file" "$fragment"; then
    echo "FAIL: missing/duplicate protected build/QA relationship: $name" >&2
    exit 1
  fi
  line="$(grep -Fn -m1 -- "$fragment" "$file" | cut -d: -f1)"
  blob="$(git rev-parse "HEAD:$path")"
  jq -nc --arg id "$name" --arg path "$path" --arg sha "$blob" \
     --arg anchor "$fragment" --argjson line "$line" \
     '{id:$id,path:$path,git_blob_sha:$sha,line:$line,
       source_anchor:$anchor,proof:"source-presence-only;no-evaluated-generated-build-graph"}' \
     >> "$tmp/evidence.jsonl"
  checked=$((checked+1))
  awk -v marker="$fragment" 'index($0,marker)==0 {print}' "$file" > "$tmp/mutated"
  if one "$tmp/mutated" "$fragment"; then
    echo "FAIL: test missed deliberately removed dependency $name" >&2
    exit 1
  fi
  rejected=$((rejected+1))
}
check 'root_testing' 'moz.build' '"testing",'
check 'root_python_build' 'moz.build' '"python",'
check 'root_thirdparty_python' 'moz.build' '"third_party/python",'
check 'manifest_mozbase_mozharness' 'testing/moz.build' 'DIRS += ["manifest", "mozbase", "mozharness"]'
check 'android_test_manifest_even_linux' 'testing/moz.build' '"android-test/tests/python.toml",'
check 'test_perf_manifest' 'testing/moz.build' '"performance/perftest.toml",'
check 'web_driver_guard' 'toolkit/toolkit.mozbuild' 'if CONFIG["ENABLE_WEBDRIVER"]:'
check 'marionette_runtime' 'toolkit/toolkit.mozbuild' '"/testing/marionette",'
check 'geckodriver_tool' 'toolkit/toolkit.mozbuild' 'DIRS += ["/testing/geckodriver"]'
check 'geckodriver_compile_guard' 'toolkit/toolkit.mozbuild' 'CONFIG["MOZ_GECKODRIVER"]'
check 'headless_qa_browser' 'toolkit/toolkit.mozbuild' '"/testing/firefox-ui",'
check 'test_core_gtest' 'toolkit/toolkit.mozbuild' '"/testing/gtest",'
check 'test_specialpowers' 'toolkit/toolkit.mozbuild' 'DIRS += ["/testing/specialpowers"]'
check 'wpt_standard_tests' 'toolkit/toolkit.mozbuild' '"/testing/web-platform",'
check 'qa_profiles' 'toolkit/toolkit.mozbuild' '"/testing/profiles",'
check 'qa_modules' 'toolkit/toolkit.mozbuild' '"/testing/modules",'
check 'qa_raptor_source' 'toolkit/toolkit.mozbuild' '"/testing/raptor/test/python.toml",'
check 'qa_talos_source' 'toolkit/toolkit.mozbuild' '"/testing/talos/talos/unittests/python.toml",'
check 'qa_mochitest' 'toolkit/toolkit.mozbuild' '"/testing/mochitest",'
check 'qa_xpcshell' 'toolkit/toolkit.mozbuild' '"/testing/xpcshell",'
check 'package_remote_webdriver' 'browser/installer/package-manifest.in' '@RESPATH@/chrome/remote.manifest'
check 'package_webdriver_guard' 'browser/installer/package-manifest.in' '#ifdef ENABLE_WEBDRIVER'
check 'marionette_unit_tests' 'testing/marionette/moz.build' 'MARIONETTE_MANIFESTS += ["harness/marionette_harness/tests/unit/unit-tests.toml"]'
check 'marionette_driver_python' 'testing/marionette/moz.build' 'SPHINX_PYTHON_PACKAGE_DIRS += ["client/marionette_driver"]'
check 'browser_locale_core' 'browser/moz.build' '"locales",'
jq -s --arg sha "$sha" \
  '{schema_version:1,candidate:"source_testing",source_commit:$sha,
    state:"source_pinned_test_and_webdriver_dependencies_preserved",
    relationships:.,verified_source_boundaries:length,
    deliberately_broken_boundaries_rejected:length,
    normal_browser_testing_source_policy:"keep_core_QA_and_build_roots",
    optional_peripheral_test_fixtures_individually_audited:false,
    evaluated_build_dependency_graph_complete:false,
    source_only:true,native_test_executed_by_this_audit:false,
    source_removal_authorized:false,no_compiled_savings_claimed:true,
    compiled_package_savings_bytes:null,whole_m3_gate_advanced:false}' \
  "$tmp/evidence.jsonl" > "$tmp/result.json"
jq -e --arg sha "$sha" \
  '.schema_version==1 and .source_commit==$sha and
   .candidate=="source_testing" and
   .verified_source_boundaries==25 and
   .deliberately_broken_boundaries_rejected==25 and
   (.relationships|map(.id)|unique|length)==25 and
   .source_only==true and .native_test_executed_by_this_audit==false and
   .evaluated_build_dependency_graph_complete==false and
   .optional_peripheral_test_fixtures_individually_audited==false and
   .source_removal_authorized==false and
   .compiled_package_savings_bytes==null and .whole_m3_gate_advanced==false' \
  "$tmp/result.json" >/dev/null
[[ "$checked" -eq 25 && "$rejected" -eq 25 ]]
if [[ -n "$out" ]]; then
  mkdir -p -- "$(dirname "$out")"
  cp -- "$tmp/result.json" "$out"
fi
echo "PASS: $checked exact core testing/build/QA/WebDriver relationships"
echo "PASS: $rejected deliberate missing-relationship mutations rejected"
echo "LIMIT: this keeps shared QA infrastructure; optional peripheral test pruning separately blocked"
