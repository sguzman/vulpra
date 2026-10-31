# Independent sanitized cross-workload reconciliation. Each signed source-run
# provenance is authenticated by the workflow before invoking this jq program.
# No symbols, PIDs, filesystem paths or raw loader traces are available.
def valid_names($x):
  ($x.observed_provider_basenames|type=="array") and
  ($x.observed_provider_basename_count==($x.observed_provider_basenames|length)) and
  (($x.observed_provider_basenames|unique|length)==($x.observed_provider_basenames|length)) and
  all($x.observed_provider_basenames[]; test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def check($ok; $message): if $ok then . else error($message) end;
($lib[0]) as $l |
($aux[0]) as $a |
($moz[0]) as $m |
($cdm[0]) as $c |
($onnx[0]) as $o |
($ping[0]) as $p |
($gfx[0]) as $g |
($alt[0]) as $v |
[$l,$a,$m,$c,$o,$p,$g,$v] as $all |
check(all($all[]; .schema_version==1 and .original_archive_sha256==$sha and
  .original_source_commit==$src and valid_names(.));"source identity/schema or unsafe provider basename") |
check($l.status=="observed_original_native_libxul_glibc_symbol_bindings" and
  $l.actual_runtime_binding_proven_for_this_workload==true and
  $l.raw_loader_logs_exported==false and $l.symbol_names_exported==false and
  $l.complete_relocation_coverage_proven==false and
  $l.new_source_pruning_authorized==false and
  $l.browser_pid_traces_with_libxul_bindings>=1 and
  $l.libxul_normal_symbol_binding_events>0 and
  $l.distinct_symbol_provider_pairs_observed>0;"libxul native runtime evidence invalid") |
check($a.status=="original_protected_auxiliary_normal_symbol_bindings" and
  ($a.per_member|keys)==["crashhelper","crashreporter","updater"] and
  $a.original_auxiliary_elf_member_count==3 and
  $a.actual_runtime_bindings_witnessed==true and
  $a.no_network_egress==true and $a.raw_loader_logs_exported==false and
  $a.symbol_names_exported==false and
  $a.new_source_pruning_authorized==false and
  all($a.per_member[]; .pid_traces_with_bindings>=1 and
      .normal_symbol_binding_events>0 and .distinct_symbol_provider_pairs>0) and
  $a.normal_symbol_binding_events==([$a.per_member[].normal_symbol_binding_events]|add) and
  $a.sum_per_member_distinct_symbol_provider_pairs==([$a.per_member[].distinct_symbol_provider_pairs]|add);
  "protected original auxiliary runtime evidence invalid") |
check(($m.original_requester_basename=="libmozinference.so" and
   $c.original_requester_basename=="libclearkey.so" and
   $o.original_requester_basename=="libonnxruntime.so") and
   all([$m,$c,$o][]; .status=="original_native_feature_module_actual_symbol_bindings" and
       .normal_symbol_binding_events>0 and .distinct_symbol_provider_pairs>0 and
       .pid_traces_with_original_requester_bindings>=1 and
       .actual_normal_symbol_bindings_observed==true and
       .original_c_api_diagnostic_only==true and .no_network_egress==true and
       .raw_loader_logs_exported==false and .symbol_names_exported==false and
       .model_inference_or_drm_decryption_proven==false and
       .all_lazy_or_transitive_bindings_proven==false and
       .new_source_pruning_authorized==false);
       "original ONNX, llama or ClearKey C API runtime evidence invalid") |
check($p.status=="original_native_feature_module_actual_symbol_bindings" and
  $p.original_requester_basename=="pingsender" and
  $p.synthetic_loopback_telemetry_only==true and
  $p.original_c_api_diagnostic_only==false and
  $p.no_network_egress==true and
  $p.actual_normal_symbol_bindings_observed==true and
  $p.raw_loader_logs_exported==false and
  $p.symbol_names_exported==false and
  $p.new_source_pruning_authorized==false and
  $p.normal_symbol_binding_events>0 and
  $p.distinct_symbol_provider_pairs>0 and
  $p.pid_traces_with_original_requester_bindings>=1;
  "original pingsender synthetic-only binding evidence invalid") |
check($g.status=="original_native_feature_module_actual_symbol_bindings" and
  $g.original_requester_basename=="gfxtest" and
  $g.private_weston_wayland_gfx_probe_only==true and
  $g.original_c_api_diagnostic_only==false and
  $g.synthetic_loopback_telemetry_only==false and
  $g.no_network_egress==false and
  $g.actual_normal_symbol_bindings_observed==true and
  $g.raw_loader_logs_exported==false and
  $g.symbol_names_exported==false and
  $g.new_source_pruning_authorized==false and
  $g.normal_symbol_binding_events>0 and $g.distinct_symbol_provider_pairs>0 and
  $g.pid_traces_with_original_requester_bindings>=1;
  "original private Weston gfxtest binding evidence invalid") |
check($v.status=="original_native_feature_module_actual_symbol_bindings" and
  $v.original_requester_basename=="vulpra-bin" and
  $v.alternate_browser_wayland_frame_only==true and
  $v.private_weston_wayland_gfx_probe_only==false and
  $v.original_c_api_diagnostic_only==false and
  $v.synthetic_loopback_telemetry_only==false and
  $v.no_network_egress==false and
  $v.actual_normal_symbol_bindings_observed==true and
  $v.raw_loader_logs_exported==false and
  $v.symbol_names_exported==false and
  $v.all_lazy_or_transitive_bindings_proven==false and
  $v.new_source_pruning_authorized==false and
  $v.normal_symbol_binding_events>0 and $v.distinct_symbol_provider_pairs>0 and
  $v.pid_traces_with_original_requester_bindings>=1;
  "original alternate graphical browser runtime binding evidence invalid") |
([$l.observed_provider_basenames,$a.observed_provider_basenames,
  $m.observed_provider_basenames,$c.observed_provider_basenames,
  $o.observed_provider_basenames,$p.observed_provider_basenames,
  $g.observed_provider_basenames,$v.observed_provider_basenames]|add|unique) as $providers |
($l.libxul_normal_symbol_binding_events + $a.normal_symbol_binding_events +
 $m.normal_symbol_binding_events + $c.normal_symbol_binding_events +
 $o.normal_symbol_binding_events + $p.normal_symbol_binding_events + $g.normal_symbol_binding_events + $v.normal_symbol_binding_events) as $events |
($l.distinct_symbol_provider_pairs_observed +
 $a.sum_per_member_distinct_symbol_provider_pairs +
 $m.distinct_symbol_provider_pairs + $c.distinct_symbol_provider_pairs +
 $o.distinct_symbol_provider_pairs + $p.distinct_symbol_provider_pairs + $g.distinct_symbol_provider_pairs + $v.distinct_symbol_provider_pairs) as $unique |
check($events==8394 and $unique==4520 and ($providers|length)==51;
  "independent pinned source-run evidence totals drifted") |
{
  schema_version:1,
  status:"original_native_ten_requester_real_binding_observation_reconciled",
  original_source_commit:$src,
  original_archive_sha256:$sha,
  original_elf_requester_basenames:["libxul.so","crashhelper","crashreporter","updater","libmozinference.so","libclearkey.so","libonnxruntime.so","pingsender","gfxtest","vulpra-bin"]|sort,
  original_elf_requester_count:10,
  per_workload_normal_binding_events:{
    libxul:$l.libxul_normal_symbol_binding_events,
    auxiliary:$a.normal_symbol_binding_events,
    inference:$m.normal_symbol_binding_events,
    clearkey:$c.normal_symbol_binding_events,
    onnx:$o.normal_symbol_binding_events,
    pingsender:$p.normal_symbol_binding_events,
    gfxtest:$g.normal_symbol_binding_events,
    alternate_vulpra_bin:$v.normal_symbol_binding_events
  },
  sum_normal_symbol_binding_events:$events,
  sum_per_requester_distinct_symbol_provider_pairs:$unique,
  observed_provider_basename_count:($providers|length),
  observed_provider_basenames:$providers,
  separate_native_workloads_reconciled:7,
  raw_traces_or_symbol_names_exported:false,
  complete_dependency_or_lazy_binding_map_proven:false,
  production_browser_rebuilt:false,
  new_source_removals_authorized:false,
  new_package_savings_bytes:null,
  m3_final_dependency_gate_closed:false
}
