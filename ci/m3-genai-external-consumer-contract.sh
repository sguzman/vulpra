#!/usr/bin/env bash
# Source-pinned, exact external-GenAI registration and consumer contract.
# Never deletes files, changes prefs or claims tested runtime/complete closure.
set -euo pipefail
root="${1:-$(git rev-parse --show-toplevel)}"
output="${2:-}"
test -d "$root/.git"
test -f "$root/mach"
command -v jq >/dev/null
cd "$root"
source_sha="$(git rev-parse HEAD)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/cache"
: > "$tmp/verified.jsonl"
verified=0
negative=0
load() {
  local path="$1" dest="$tmp/cache/$1"
  if [[ ! -f "$dest" ]]; then
    mkdir -p -- "$(dirname "$dest")"
    git show "HEAD:$path" > "$dest"
  fi
  printf '%s\n' "$dest"
}
require_one() {
  local file="$1" needle="$2" occurrences
  occurrences="$(grep -F -c -- "$needle" "$file" || true)"
  [[ "$occurrences" == 1 ]]
}
check() {
  local id="$1" path="$2" anchor="$3" file line blob
  file="$(load "$path")"
  if ! require_one "$file" "$anchor"; then
    echo "FAIL: missing/duplicate GenAI external dependency: $id at $path" >&2
    exit 1
  fi
  line="$(grep -Fn -m1 -- "$anchor" "$file" | cut -d: -f1)"
  blob="$(git rev-parse "HEAD:$path")"
  jq -nc --arg id "$id" --arg path "$path" --arg sha "$blob" \
     --arg anchor "$anchor" --argjson line "$line" \
     '{id:$id,path:$path,git_blob_sha:$sha,line:$line,source_anchor:$anchor,
       scoped_proof:"literal_source_anchor_present_once;not_runtime_dependency_closure"}' \
    >> "$tmp/verified.jsonl"
  verified=$((verified+1))
  # Every actual accepted anchor has its own precisely corrupted fixture.
  # Verify that removing the anchor line causes the same assertion to fail.
  awk -v needle="$anchor" 'index($0,needle)==0 {print}' "$file" > "$tmp/without-anchor"
  if require_one "$tmp/without-anchor" "$anchor"; then
    echo "FAIL: deletion mutation accepted for $id" >&2
    exit 1
  fi
  negative=$((negative+1))
}
check 'component-root' 'browser/components/moz.build' '"genai",'
check 'primary-module' 'browser/components/genai/moz.build' '"GenAI.sys.mjs",'
check 'link-preview-module' 'browser/components/genai/moz.build' '"LinkPreview.sys.mjs",'
check 'link-preview-model' 'browser/components/genai/moz.build' '"LinkPreviewModel.sys.mjs",'
check 'page-assist-module' 'browser/components/genai/moz.build' '"PageAssist.sys.mjs",'
check 'genai-parent-module' 'browser/components/genai/moz.build' '"GenAIParent.sys.mjs",'
check 'genai-child-module' 'browser/components/genai/moz.build' '"GenAIChild.sys.mjs",'
check 'link-preview-parent-module' 'browser/components/genai/moz.build' '"LinkPreviewParent.sys.mjs",'
check 'link-preview-child-module' 'browser/components/genai/moz.build' '"LinkPreviewChild.sys.mjs",'
check 'page-assist-parent-module' 'browser/components/genai/moz.build' '"PageAssistParent.sys.mjs",'
check 'page-assist-child-module' 'browser/components/genai/moz.build' '"PageAssistChild.sys.mjs",'
check 'delayed-startup-link-preview' 'browser/components/BrowserComponents.manifest' 'category browser-window-delayed-startup moz-src:///browser/components/genai/LinkPreview.sys.mjs LinkPreview.init'
check 'idle-startup-genai' 'browser/components/BrowserComponents.manifest' 'category browser-idle-startup moz-src:///browser/components/genai/GenAI.sys.mjs GenAI.init'
check 'genai-parent-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/GenAIParent.sys.mjs"'
check 'genai-child-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/GenAIChild.sys.mjs"'
check 'genai-actor-provider-pref' 'browser/components/DesktopActorRegistry.sys.mjs' 'Services.prefs.getCharPref("browser.ml.chat.provider", "") ||'
check 'genai-actor-provider-observer' 'browser/components/DesktopActorRegistry.sys.mjs' 'Services.prefs.addObserver("browser.ml.chat.provider", maybeRegister);'
check 'link-preview-parent-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/LinkPreviewParent.sys.mjs"'
check 'link-preview-child-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/LinkPreviewChild.sys.mjs"'
check 'link-preview-enabled-pref' 'browser/components/DesktopActorRegistry.sys.mjs' 'enablePreference: "browser.ml.linkPreview.enabled"'
check 'page-assist-parent-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/PageAssistParent.sys.mjs"'
check 'page-assist-child-actor' 'browser/components/DesktopActorRegistry.sys.mjs' '"moz-src:///browser/components/genai/PageAssistChild.sys.mjs"'
check 'page-assist-enabled-pref' 'browser/components/DesktopActorRegistry.sys.mjs' 'enablePreference: "browser.ml.pageAssist.enabled"'
check 'preferences-genai-import' 'browser/components/preferences/config/tabs-browsing.mjs' 'GenAI: "moz-src:///browser/components/genai/GenAI.sys.mjs"'
check 'preferences-linkpreview-import' 'browser/components/preferences/config/tabs-browsing.mjs' 'LinkPreview: "moz-src:///browser/components/genai/LinkPreview.sys.mjs"'
check 'preferences-keypoints' 'browser/components/preferences/config/tabs-browsing.mjs' 'pref: "browser.ml.linkPreview.optin"'
check 'sidebar-chat-gate' 'browser/components/sidebar/browser-sidebar.js' '"browser.ml.chat.enabled",'
check 'sidebar-chat-page' 'browser/components/sidebar/browser-sidebar.js' 'url: "chrome://browser/content/genai/chat.html"'
check 'sidebar-page-assist-gate' 'browser/components/sidebar/browser-sidebar.js' '"browser.ml.pageAssist.enabled",'
check 'sidebar-page-assist-page' 'browser/components/sidebar/browser-sidebar.js' 'url: "chrome://browser/content/genai/pageAssist.html"'
check 'enterprise-linkpreview-policy' 'browser/components/enterprisepolicies/Policies.sys.mjs' '"LinkPreviews",'
check 'nimbus-link-preview-pref' 'toolkit/components/nimbus/FeatureManifest.yaml' 'pref: browser.ml.linkPreview.enabled'
check 'genai-to-ai-window' 'browser/components/genai/GenAI.sys.mjs' '"moz-src:///browser/components/aiwindow/ui/modules/AIWindow.sys.mjs"'
# Keep checkout provenance attached to per-file anchors and protect reclassification.
jq -s --arg source "$source_sha" \
  '{schema_version:1,source_commit:$source,candidate:"browser_genai",
    status:"exact_source_high_impact_genai_consumer_boundary_verified",
    protected_source_relationships:.,verified_relationship_count:length,
    deliberately_removed_anchor_mutations_rejected:length,
    dependency_decision:"review_and_retain_genai_root",
    external_startup_and_actor_callers_remain:true,
    browser_source_or_package_mutation:false,
    source_removal_authorized:false,
    normal_browser_feature_changed:false,
    native_runtime_verified_by_this_test:false,
    complete_dynamic_import_or_caller_graph_proven:false,
    new_compiled_savings_bytes:null,
    full_m3_gate_passed:false}' "$tmp/verified.jsonl" > "$tmp/report.json"
jq -e --arg sha "$source_sha" \
  '.schema_version==1 and .source_commit==$sha and
   .candidate=="browser_genai" and
   .status=="exact_source_high_impact_genai_consumer_boundary_verified" and
   .verified_relationship_count==33 and
   .deliberately_removed_anchor_mutations_rejected==33 and
   (.protected_source_relationships|map(.id)|unique|length)==33 and
   .external_startup_and_actor_callers_remain==true and
   .source_removal_authorized==false and
   .normal_browser_feature_changed==false and
   .native_runtime_verified_by_this_test==false and
   .complete_dynamic_import_or_caller_graph_proven==false and
   .new_compiled_savings_bytes==null and
   .full_m3_gate_passed==false' "$tmp/report.json" >/dev/null
if [[ "$verified" -ne 33 || "$negative" -ne 33 ]]; then
  echo "FAIL: anchor count / fixture integrity mismatch" >&2
  exit 1
fi
if [[ -n "$output" ]]; then
  mkdir -p -- "$(dirname "$output")"
  cp -- "$tmp/report.json" "$output"
fi
echo "PASS: $verified source-pinned GenAI / startup / actor / preference / sidebar / policy / Nimbus relationships"
echo "PASS: $negative missing-anchor mutations correctly rejected"
echo "LIMIT: no removal, native compile, live actor runtime, complete dynamic graph, or saving"
