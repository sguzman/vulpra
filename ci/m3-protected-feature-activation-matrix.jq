# Fail closed on false positive or cross-source feature acceptance claims.
# The evidence runs below are a versioned allowlist from prior source-pinned
# reports; this is a finite acceptance WORKLIST, not an independent GitHub API
# authenticity check or an all-feature runtime test.
def insist($ok;$why): if $ok then true else error($why) end;
def wanted: [
 "wayland_graphics","javascript_navigation","webextensions","nimbus",
 "normandy_policy","newtab_promo_guards","sandbox","certificate_safebrowsing",
 "sync_fxaccounts","devtools","crash_reporting","updater",
 "telemetry_glean","ffmpeg_media","drm_clearkey","webaudio_pulse",
 "webauthn_usb","inference_onnx"
] | sort;
def configmap: {
 wayland_graphics:["MOZ_WAYLAND","1"],
 normandy_policy:["MOZ_NORMANDY","1"],
 sandbox:["MOZ_SANDBOX","1"],
 sync_fxaccounts:["MOZ_SERVICES_SYNC","1"],
 devtools:["MOZ_DEVTOOLS","all"],
 crash_reporting:["MOZ_CRASHREPORTER","1"],
 updater:["MOZ_UPDATER","1"]
};
def current_ids: ["wayland_graphics","javascript_navigation","webextensions","nimbus"];
def historical: {
 newtab_promo_guards:[41233793696,"original_browser_optin"],
 crash_reporting:[41724548163,"original_browser_workload"],
 updater:[41161508642,"original_helper_diagnostic"],
 telemetry_glean:[41741770814,"original_browser_instrumented"],
 ffmpeg_media:[41266875131,"original_host_abi_diagnostic"],
 drm_clearkey:[41161025114,"original_module_diagnostic"],
 webaudio_pulse:[41714793962,"original_browser_workload"],
 webauthn_usb:[41674689904,"original_browser_workload"],
 inference_onnx:[41567402153,"original_module_diagnostic"]
};
def fallbacks: {
 webextensions:[41762298450,"current"],
 newtab_promo_guards:[41233793696,"historical"],
 webauthn_usb:[41674689904,"historical"]
};
def check_config($x):
 (configmap[$x.id]) as $expected |
 if $expected == null then
   $x.configuration == {status:"not_directly_observed",flag:null,value:null,run:null}
 else
   $x.configuration == {status:"observed_current",
                         flag:$expected[0],value:$expected[1],run:41762298450}
 end;
def check_current($x;$src):
 if (current_ids|index($x.id)) != null then
  $x.current_behavior == {status:"bounded_pass",run:41762298450,source_commit:$src}
 else
  $x.current_behavior == {status:"unverified",run:null,source_commit:null}
 end;
def check_historical($x):
 (historical[$x.id]) as $witness |
 if $witness == null then
  $x.historical_behavior == {status:"unverified",run:null,kind:null}
 else
  $x.historical_behavior == {status:"bounded_pass",run:$witness[0],kind:$witness[1]}
 end;
def check_fallback($x):
 (fallbacks[$x.id]) as $witness |
 if $witness == null then
  $x.negative_fallback == {status:"unverified",run:null,source:null}
 else
  $x.negative_fallback == {status:"bounded_pass",run:$witness[0],source:$witness[1]}
 end;
. as $m |
[
 insist($m.schema_version == 1 and
   $m.kind == "m3_protected_feature_activation_acceptance_matrix" and
   $m.status == "partial_verified_coverage_with_explicit_unverified_paths" and
   $m.as_of == "2026-11-04";"Unexpected matrix schema/status/date"),
 insist($m.current_native_workflow_run == 41762298450 and
   $m.current_source_commit == "96454f7a1fbe6b505af440c6c2c5fc91e798756d" and
   $m.original_source_commit == "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
   "Current/original source or workflow identity mismatch"),
 insist(($m.features|type) == "array" and
   ($m.features|length) == 18 and
   ([$m.features[].id]|sort) == wanted;
   "Required protected feature set incomplete, missing or duplicated"),
 insist(all($m.features[];
   (.protected_retain == true) and
   (.id|type == "string" and test("^[a-z][a-z_]{2,39}$")) and
   (.area|type == "string" and length > 2 and length <= 40) and
   (.next_check|type == "string" and length >= 30 and length <= 250) and
   .target_current_workstation_verified == false and
   .complete_feature_dependency_closure == false and
   .source_removal_authorized == false);
   "Protected feature wrongly pruned, overstated or lacks actionable fallback check"),
 insist(all($m.features[];check_config(.));"Current configure flag provenance overclaimed"),
 insist(all($m.features[];check_current(.;$m.current_source_commit));
   "Current runtime gate missing or falsely attributed to current source"),
 insist(all($m.features[];check_historical(.));
   "Historical work claimed as current or wrong historical workload ID/type"),
 insist(all($m.features[];check_fallback(.));
   "Unproven or misattributed negative/fallback behavior"),
 insist($m.source_removal_authorized == false and
   $m.all_protected_features_current_runtime_complete == false and
   $m.all_negative_fallbacks_complete == false and
   $m.conditional_native_ffi_dlopen_closure_proven == false and
   $m.actual_current_workstation_parity_proven == false and
   $m.m3_sixth_gate_closed == false;
   "Unsupported final gate, security, source pruning or workstation success")
] | all as $valid |
{
 schema_version:1,
 status:"bounded_protected_feature_matrix_consistent",
 current_source_commit:$m.current_source_commit,
 accepted_current_native_workflow_run:$m.current_native_workflow_run,
 all_required_protected_features_present:$valid,
 protected_feature_count:($m.features|length),
 current_bounded_runtime_witnesses:[$m.features[]|select(.current_behavior.status=="bounded_pass")|.id]|sort,
 historical_bounded_witnesses:[$m.features[]|select(.historical_behavior.status=="bounded_pass")|.id]|sort,
 negative_fallback_witnesses:[$m.features[]|select(.negative_fallback.status=="bounded_pass")|.id]|sort,
 current_runtime_unverified:[$m.features[]|select(.current_behavior.status=="unverified")|.id]|sort,
 negative_fallback_unverified:[$m.features[]|select(.negative_fallback.status=="unverified")|.id]|sort,
 actual_workstation_accepted:false,
 complete_dynamic_or_ffi_graph:false,
 current_feature_error_fallback_matrix_complete:false,
 source_removal_authorized:false,
 m3_sixth_gate_closed:false
}
