#!/usr/bin/env bash
# Exact Git-source, fail-closed New Tab / ASRouter / messaging crosswalk.
# This protects known source anchors; it does not prove dynamic reachability.
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
: > "$tmp/rows.jsonl"
accepted=0
rejected=0
load() {
  local path="$1" file="$tmp/cache/$1"
  if [[ ! -f "$file" ]]; then
    mkdir -p -- "$(dirname "$file")"
    git show "HEAD:$path" > "$file"
  fi
  printf '%s\n' "$file"
}
unique_anchor() {
  local matches
  matches="$(grep -F -c -- "$2" "$1" || true)"
  [[ "$matches" == 1 ]]
}
check() {
  local id="$1" path="$2" anchor="$3" file line blob
  file="$(load "$path")"
  if ! unique_anchor "$file" "$anchor"; then
    echo "FAIL missing or duplicate protected New Tab/ASRouter source anchor: $id ($path)" >&2
    exit 1
  fi
  line="$(grep -Fn -m1 -- "$anchor" "$file" | cut -d: -f1)"
  blob="$(git rev-parse "HEAD:$path")"
  jq -nc --arg id "$id" --arg path "$path" --arg sha "$blob" \
    --arg anchor "$anchor" --argjson line "$line" \
    '{id:$id,path:$path,git_blob_sha:$sha,line:$line,source_anchor:$anchor,
      evidence_kind:"source-literal-only;no-dynamic-call-graph"}' >> "$tmp/rows.jsonl"
  accepted=$((accepted+1))
  awk -v key="$anchor" 'index($0,key)==0 {print}' "$file" > "$tmp/mutated"
  if unique_anchor "$tmp/mutated" "$anchor"; then
    echo "FAIL missing-anchor mutation unexpectedly passed: $id" >&2
    exit 1
  fi
  rejected=$((rejected+1))
}
check 'root_asrouter' 'browser/components/moz.build' '"asrouter",'
check 'root_newtab' 'browser/components/moz.build' '"newtab",'
check 'startup_aboutnewtab' 'browser/components/BrowserComponents.manifest' 'category browser-first-window-ready resource:///modules/AboutNewTab.sys.mjs AboutNewTab.init'
check 'startup_newtabutils' 'browser/components/BrowserComponents.manifest' 'category browser-first-window-ready resource://gre/modules/NewTabUtils.sys.mjs NewTabUtils.init'
check 'shutdown_asrouter_hook' 'browser/components/BrowserComponents.manifest' 'category browser-quit-application-granted resource:///modules/asrouter/ASRouterNewTabHook.sys.mjs ASRouterNewTabHook.destroy'
check 'browserglue_router_import' 'browser/components/BrowserGlue.sys.mjs' 'ASRouter: "resource:///modules/asrouter/ASRouter.sys.mjs",'
check 'browserglue_hook_import' 'browser/components/BrowserGlue.sys.mjs' 'ASRouterNewTabHook: "resource:///modules/asrouter/ASRouterNewTabHook.sys.mjs",'
check 'browserglue_hook_task' 'browser/components/BrowserGlue.sys.mjs' 'lazy.ASRouterNewTabHook.createInstance(lazy.ASRouterDefaultConfig());'
check 'asrouter_main_package' 'browser/components/asrouter/moz.build' '"modules/ASRouter.sys.mjs",'
check 'asrouter_hook_package' 'browser/components/asrouter/moz.build' '"modules/ASRouterNewTabHook.sys.mjs",'
check 'asrouter_parent_handler_package' 'browser/components/asrouter/moz.build' '"modules/ASRouterParentProcessMessageHandler.sys.mjs",'
check 'asrouter_telemetry_package' 'browser/components/asrouter/moz.build' '"modules/ASRouterTelemetry.sys.mjs",'
check 'asrouter_preferences_package' 'browser/components/asrouter/moz.build' '"modules/ASRouterPreferences.sys.mjs",'
check 'asrouter_promos_optin_guard' 'browser/components/asrouter/moz.build' 'if not CONFIG["VULPRA_NO_ASROUTER_PROMOS"]:'
check 'asrouter_main_class' 'browser/components/asrouter/modules/ASRouter.sys.mjs' 'export class _ASRouter {'
check 'asrouter_hook_singleton' 'browser/components/asrouter/modules/ASRouterNewTabHook.sys.mjs' 'export const ASRouterNewTabHook = (() => {'
check 'asrouter_hook_initialize' 'browser/components/asrouter/modules/ASRouterNewTabHook.sys.mjs' '  async initialize({ messageHandler, router, createStorage }) {'
check 'asrouter_hook_shutdown' 'browser/components/asrouter/modules/ASRouterNewTabHook.sys.mjs' '    destroy: () => {'
check 'asrouter_default_config' 'browser/components/asrouter/modules/ASRouterDefaultConfig.sys.mjs' 'export const ASRouterDefaultConfig = () => {'
check 'asrouter_parent_handler_export' 'browser/components/asrouter/modules/ASRouterParentProcessMessageHandler.sys.mjs' 'export class ASRouterParentProcessMessageHandler {'
check 'newtab_native_redirect' 'browser/components/newtab/moz.build' '"AboutNewTabRedirector.sys.mjs",'
check 'newtab_native_mapping' 'browser/components/newtab/moz.build' '"AboutNewTabResourceMapping.sys.mjs",'
check 'newtab_native_library' 'browser/components/newtab/moz.build' 'FINAL_LIBRARY = "browsercomps"'
check 'newtab_activitystream_bundle' 'browser/extensions/newtab/addon-jar.mn' 'builtin-addons/newtab/lib/ActivityStream.sys.mjs (./lib/ActivityStream.sys.mjs)'
check 'newtab_messaging_bundle' 'browser/extensions/newtab/addon-jar.mn' 'builtin-addons/newtab/lib/NewTabMessaging.sys.mjs (./lib/NewTabMessaging.sys.mjs)'
check 'newtab_modern_feed' 'browser/extensions/newtab/addon-jar.mn' 'builtin-addons/newtab/lib/DiscoveryStreamFeed.sys.mjs (./lib/DiscoveryStreamFeed.sys.mjs)'
check 'newtab_legacy_feed' 'browser/extensions/newtab/addon-jar.mn' 'builtin-addons/newtab/lib/TopStoriesFeed.sys.mjs (./lib/TopStoriesFeed.sys.mjs)'
check 'newtab_store' 'browser/extensions/newtab/addon-jar.mn' 'builtin-addons/newtab/lib/Store.sys.mjs (./lib/Store.sys.mjs)'
check 'newtab_activitystream_import_modern' 'browser/extensions/newtab/lib/ActivityStream.sys.mjs' '"resource://newtab/lib/DiscoveryStreamFeed.sys.mjs",'
check 'newtab_activitystream_import_legacy' 'browser/extensions/newtab/lib/ActivityStream.sys.mjs' '"resource://newtab/lib/TopStoriesFeed.sys.mjs",'
check 'newtab_activitystream_messaging' 'browser/extensions/newtab/lib/ActivityStream.sys.mjs' '"resource://newtab/lib/NewTabMessaging.sys.mjs",'
check 'newtab_messaging_export' 'browser/extensions/newtab/lib/NewTabMessaging.sys.mjs' 'export class NewTabMessaging {'
check 'newtab_messaging_observer' 'browser/extensions/newtab/lib/NewTabMessaging.sys.mjs' 'Services.obs.addObserver(this, "newtab-message");'
check 'newtab_message_parent_actor' 'browser/extensions/newtab/lib/NewTabMessaging.sys.mjs' '"AboutNewTab"'
jq -s --arg sha "$source_sha" \
  '{schema_version:1,candidate:"newtab_and_messaging",source_commit:$sha,
    status:"source_pinned_newtab_asrouter_message_bridge_preserved",
    relationships:.,protected_source_relationship_count:length,
    deliberately_missing_anchor_mutations_rejected:length,
    asrouter_newtab_bridge_preserved_by_source:true,
    default_newtab_and_messaging_decision:"retain_shared_root_pending_other_fallbacks",
    asrouter_telemetry_deletion_policy_independently_required:true,
    tested_native_binary_here:false,complete_dynamic_dependency_map:false,
    no_source_or_binary_modified:true,source_removal_authorized:false,
    whole_m3_gate_advanced:false,new_binary_savings_bytes:null}' \
  "$tmp/rows.jsonl" > "$tmp/report.json"
jq -e --arg sha "$source_sha" \
  '.schema_version==1 and .source_commit==$sha and
   .candidate=="newtab_and_messaging" and
   .protected_source_relationship_count==34 and
   .deliberately_missing_anchor_mutations_rejected==34 and
   (.relationships|map(.id)|unique|length)==34 and
   .asrouter_newtab_bridge_preserved_by_source==true and
   .source_removal_authorized==false and .whole_m3_gate_advanced==false and
   .tested_native_binary_here==false and
   .complete_dynamic_dependency_map==false and
   .no_source_or_binary_modified==true and .new_binary_savings_bytes==null' \
  "$tmp/report.json" >/dev/null
[[ "$accepted" -eq 34 && "$rejected" -eq 34 ]]
if [[ -n "$output" ]]; then
  mkdir -p -- "$(dirname "$output")"
  cp -- "$tmp/report.json" "$output"
fi
echo "PASS: $accepted exact source New Tab/ASRouter/messaging links"
echo "PASS: $rejected deliberately removed anchors rejected"
echo "LIMIT: no full dependency closure, live ASRouter routing or source removal"
