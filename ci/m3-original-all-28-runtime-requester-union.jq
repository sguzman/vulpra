# Cross-check two independent source/run-authenticated sanitized observations:
# 21 original ELF requesters in one real original browser startup, and ten
# feature-specific requester observations. No symbol names or raw logs exist.
def check($ok; $why): if $ok then . else error($why) end;
def safe($list):
 ($list|type=="array") and
 (($list|unique|length)==($list|length)) and
 all($list[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($native[0]) as $p |
($ten[0]) as $t |
check($p.schema_version==1 and $t.schema_version==1 and
 $p.original_source_commit==$src and $t.original_source_commit==$src and
 $p.original_archive_sha256==$sha and $t.original_archive_sha256==$sha;
 "original runtime source/archive fingerprint mismatch") |
check($p.status=="original_package_elf_requester_live_binding_inventory" and
 $p.original_package_elf_count==28 and
 $p.original_requester_basenames_observed==21 and
 $p.pid_traces_with_package_requester_bindings>0 and
 $p.normal_symbol_binding_events==13501 and
 $p.sum_distinct_requester_symbol_provider_combinations==6463 and
 $p.observed_provider_basename_count==51 and
 $p.raw_loader_logs_exported==false and
 $p.symbol_names_exported==false and
 $p.private_browser_profile_only==true and
 $p.complete_lazy_transitive_or_feature_coverage_proven==false and
 $p.safety_of_source_removal_proven==false and
 $p.m3_sixth_gate_closed==false;
 "incomplete original compiled package-wide runtime observation") |
check($t.status=="original_native_ten_requester_real_binding_observation_reconciled" and
 $t.original_elf_requester_count==10 and
 $t.sum_normal_symbol_binding_events==8394 and
 $t.sum_per_requester_distinct_symbol_provider_pairs==4520 and
 $t.observed_provider_basename_count==51 and
 $t.separate_native_workloads_reconciled==7 and
 $t.raw_traces_or_symbol_names_exported==false and
 $t.complete_dependency_or_lazy_binding_map_proven==false and
 $t.new_source_removals_authorized==false and
 $t.m3_final_dependency_gate_closed==false;
 "untrusted or incomplete previous ten-requester cross-workload union") |
check(safe($p.observed_requester_basenames) and
 safe($p.unobserved_requester_basenames_on_this_workload) and
 safe($p.observed_provider_basenames) and
 safe($t.original_elf_requester_basenames) and
 safe($t.observed_provider_basenames);
 "unsafe or duplicated original native basename") |
check(($p.observed_requester_basenames|length)==21 and
 ($p.unobserved_requester_basenames_on_this_workload|length)==7 and
 ($t.original_elf_requester_basenames|length)==10 and
 (($p.per_original_requester|keys)==$p.observed_requester_basenames) and
 (($p.per_original_requester|to_entries|map(.value.normal_symbol_binding_events)|add)==13501) and
 (($p.per_original_requester|to_entries|map(.value.distinct_symbol_provider_pairs)|add)==6463) and
 (($p.observed_provider_basenames|length)==51) and
 (($t.observed_provider_basenames|length)==51);
 "original per-requester arithmetic or count mismatch") |
($p.observed_requester_basenames + $p.unobserved_requester_basenames_on_this_workload|unique) as $inventory |
($p.observed_requester_basenames + $t.original_elf_requester_basenames|unique) as $coverage |
([$p.observed_provider_basenames[],$t.observed_provider_basenames[]]|unique) as $providers |
check(($inventory|length)==28 and
 ($coverage|length)==28 and
 ($inventory==$coverage) and
 (($p.unobserved_requester_basenames_on_this_workload - $t.original_elf_requester_basenames)|length)==0 and
 ($providers|length)==56;
 "an original ELF requester is not witnessed or a provider union drifted") |
{
 schema_version:1,
 status:"all_original_28_elf_requesters_have_bounded_runtime_binding_evidence",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 original_elf_requester_count:28,
 original_elf_requester_basenames:$coverage,
 original_requesters_seen_during_headless_startup:21,
 original_requesters_seen_in_selected_feature_workloads:10,
 overlapping_requester_count:3,
 startup_unobserved_requesters_exercised_in_other_workloads:$p.unobserved_requester_basenames_on_this_workload,
 package_wide_startup_binding_events:$p.normal_symbol_binding_events,
 package_wide_startup_distinct_requester_symbol_provider_pairs:$p.sum_distinct_requester_symbol_provider_combinations,
 separate_feature_binding_events:$t.sum_normal_symbol_binding_events,
 separate_feature_distinct_requester_symbol_provider_pairs:$t.sum_per_requester_distinct_symbol_provider_pairs,
 total_observed_provider_basename_union_count:($providers|length),
 observed_provider_basenames:$providers,
 every_original_elf_requester_witnessed_in_at_least_one_bounded_workload:true,
 events_across_overlapping_workloads_not_summed:true,
 all_elf_relocations_or_features_proven:false,
 complete_lazy_transitive_dependencies_proven:false,
 source_build_ownership_gate_closed:false,
 installed_browser_or_profiles_modified:false,
 source_removal_authorized:false,
 package_savings_bytes:null,
 m3_sixth_gate_closed:false
}
