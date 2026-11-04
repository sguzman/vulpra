# Vulpra M3: fail-closed, per-ELF complete-evidence-gap register.
# JOINS source/archive-authenticated historical artifacts + current scoped
# candidate decisions. It is a closure BLOCKER inventory, NOT a proof that
# the dynamic/FFI graph is complete or that any source may be removed.
#
# Inputs injected by --slurpfile:
#  $platform: verified 28 packaged original ELF source/Ubuntu/Arch matrix
#  $feature: exact seven selected-feature-only ELF loader branch census
#  $dynamic: exactly 21 actual bounded graphical dynamic request edges
#  $drift: 27 original build manifests + 14 current feature source byte checks
#  $pingsender: browser-owned real pingsender -> actual libcurl perform result
#  $candidates: current 20 scoped decisions and safety fallback policy
#  $progress: current milestone evidence and acceptance state.
def insist($ok;$why): if $ok then true else error($why) end;
def validname: type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,100}$");
($platform[0]) as $p |
($feature[0]) as $f |
($dynamic[0]) as $d |
($drift[0]) as $dr |
($pingsender[0]) as $ps |
($candidates[0]) as $c |
($progress[0]) as $g |
($g.milestones|map(select(.id=="M3"))|.[0]) as $m |
($p.rows | map({key:.elf,value:.}) | from_entries) as $E |
($f.rows | map({key:.elf,value:.}) | from_entries) as $F |
(["crashreporter","libclearkey.so","libmozinference.so",
  "libonnxruntime.so","pingsender","updater","vulpra-bin"]) as $feature_names |
([
  insist($p.schema_version==1 and
    $p.status=="original_28_elf_ubuntu_arch_per_elf_loader_and_source_crosswalk_verified" and
    $p.original_source_commit==$source and $p.original_archive_sha256==$archive and
    $p.source_manifest_owners==28 and $p.original_runtime_requester_observed_count==28 and
    $p.resolved_ubuntu_direct_needed==268 and $p.resolved_arch_direct_needed==268 and
    $p.every_elf_direct_needed_count_matches_across_distros==true and
    $p.every_original_elf_has_arch_loader_provider_list==true and
    $p.complete_future_dlopen_closure_proven==false and
    $p.m3_sixth_gate_closed==false and $p.source_pruning_authorized==false and
    ($p.rows|length)==28 and ($E|length)==28;
    "original 28-ELF native package/source/platform artifact mismatch"),
  insist(all($p.rows[];
    (.elf|validname) and .source_manifest_anchor_line>0 and
    (.source_manifest|type)=="string" and
    .original_runtime_requester_observed==true and
    .direct_needed_ubuntu==.direct_needed_arch and .direct_needed_arch>=1 and
    .ubuntu_loader_provider_count==(.ubuntu_loader_provider_basenames|length) and
    .arch_loader_provider_count==(.arch_loader_provider_basenames|length) and
    .direct_needed_cross_distro_count_matches==true) and
    ([$p.rows[].direct_needed_ubuntu]|add)==268 and
    ([$p.rows[].direct_needed_arch]|add)==268;
    "per-original-ELF build ownership, direct ELF declarations or native loader drift"),
  insist($f.schema_version==1 and
    $f.status=="original_feature_only_seven_elf_compiled_loader_candidate_boundaries" and
    $f.original_source_commit==$source and $f.original_archive_sha256==$archive and
    $f.original_feature_only_elf_count==7 and ($f.rows|length)==7 and
    ($F|keys|sort)==$feature_names and
    $f.feature_only_named_direct_loader_branches==8 and
    $f.feature_only_compiled_loader_importer_count==4 and
    $f.all_future_optional_or_required_loader_routes_proven==false and
    $f.m3_sixth_gate_closed==false and $f.source_pruning_authorized==false;
    "selected feature-only compiled branch set/provenance drift"),
  insist(all($f.rows[]; . as $e |
    $E[$e.elf]!=null and
    $E[$e.elf].source_manifest==$e.original_source_manifest and
    $E[$e.elf].direct_needed_ubuntu==$e.ubuntu_direct_needed_count and
    $E[$e.elf].direct_needed_arch==$e.arch_direct_needed_count and
    $E[$e.elf].original_native_binding_observation=="selected_feature_workloads_only" and
    $e.selected_feature_workload_native_binding_observed==true and
    $e.not_seen_in_graphical_trace_does_not_authorize_pruning==true);
    "feature-only source ownership, real native observation or needed counts diverge"),
  insist($d.schema_version==1 and
    $d.status=="original_graphical_21_dynamic_requests_outside_both_per_elf_loader_lists" and
    $d.original_source_commit==$source and $d.original_archive_sha256==$archive and
    $d.observed_graphical_loader_dynamic_request_edges==21 and
    ($d.rows|length)==21 and
    ([$d.rows[].requester]|unique|sort)==["libnspr4.so","libxul.so","vulpra"] and
    ($d.rows|map([.requester,.requested_library]|join(":"))|unique|length)==21 and
    $d.original_trace_is_one_bounded_graphical_workload==true and
    $d.complete_future_dlopen_ffi_or_feature_graph_proven==false and
    $d.m3_sixth_gate_closed==false and $d.source_pruning_authorized==false;
    "bounded original dynamic loader trace drift"),
  insist(all($d.rows[]; (.requester|validname) and
    (.requested_library|validname) and $E[.requester]!=null and
    .requested_library_in_requester_ubuntu_glibc_list==false and
    .requested_library_in_requester_arch_glibc_list==false);
    "unbounded or not-independent original dynamic loader relationship"),
  insist($dr.schema_version==1 and
    $dr.status=="source_pinned_original_to_current_native_feature_manifest_drift" and
    $dr.original_compiled_source_commit==$source and
    $dr.original_compiled_archive_sha256==$archive and
    $dr.checked_original_elf_ownership_manifest_paths==27 and
    $dr.checked_protected_feature_boundary_paths==14 and
    $dr.modified_original_elf_ownership_manifests==0 and
    $dr.modified_feature_boundary_files==0 and
    $dr.missing_current_source_paths==0 and
    $dr.current_config_status_or_feature_runtimes_not_proven==true and
    $dr.original_binary_not_rebuilt_from_current_source==true and
    $dr.m3_sixth_gate_closed==false;
    "current-vs-original native source drift evidence not exact"),
  insist($ps.schema_version==1 and
    $ps.status=="original_browser_owned_actual_pingsender_real_curl_easy_perform_failed_localhost" and
    $ps.source_commit==$source and $ps.archive_sha256==$archive and
    $ps.original_browser_owned_actual_pingsender_elf==true and
    $ps.genuine_source_defined_libcurl_dlopen_and_14_dlsym==true and
    $ps.actual_original_pingsender_executed_real_libcurl_easy_perform==true and
    $ps.actual_real_libcurl_perform_return_code==7 and
    $ps.real_upload_permission_disabled==true and
    $ps.no_network_egress_or_real_user_telemetry==true and
    $ps.all_possible_conditional_ffi_dependency_paths_closed==false and
    $ps.source_pruning_authorized==false and $ps.m3_sixth_gate_closed==false;
    "genuine original browser-owned pingsender real libcurl evidence not accepted"),
  insist(($c.candidates|length)==20 and
    ([$c.candidates[].id]|unique|length)==20 and
    $c.m3_decision_classification.categories=={
      "keep":13,"remove_source":4,"review":0,"conditional_compile":3
    } and
    $c.m3_decision_classification.complete_feature_dependency_inventory==false and
    $c.m3_decision_classification.no_new_source_deletion==true and
    $c.accepted_source_pruning_cohort_totals.aggregate_removed_git_paths==14867 and
    $c.accepted_source_pruning_cohort_totals.aggregate_original_git_blob_bytes==129967585 and
    $c.accepted_source_pruning_cohort_totals.compiled_package_bytes_saved==null and
    all($c.candidates[];
      .m3_strategy.broad_feature_removal_authorized==false and
      (.m3_strategy.strategy=="keep" or
       .m3_strategy.strategy=="remove_source" or
       .m3_strategy.strategy=="conditional_compile"));
    "scoped 20 candidate/prune safety classifications changed"),
  insist($g.overall.percent==61 and $m.percent==83 and
    $m.acceptance_gates.passed==5 and $m.acceptance_gates.total==6 and
    ($m.acceptance_gates.remaining|length)==1 and
    $m.acceptance_gates.remaining[0]=="Complete feature bundle, binary/build dependency and platform map";
    "M3 ledger changed without independent acceptance evidence")
]) as $auth |
[
  $p.rows[] as $e |
  ($F[$e.elf] // null) as $feature |
  ([$d.rows[]|select(.requester==$e.elf)]) as $dynamic_request |
  {
    elf:$e.elf,
    original_source_manifest:$e.source_manifest,
    original_source_declaration_class:$e.source_declaration_class,
    source_manifest_unchanged_in_checked_27_manifest_set:true,
    original_package_runtime_requester_observed_in_bounded_workloads:true,
    source_to_compiled_original_binary_owner_mapped:true,
    ubuntu_direct_needed_count:$e.direct_needed_ubuntu,
    arch_direct_needed_count:$e.direct_needed_arch,
    all_direct_needed_resolved_in_both_bounded_userspaces:true,
    ubuntu_loader_listed_provider_count:$e.ubuntu_loader_provider_count,
    arch_loader_listed_provider_count:$e.arch_loader_provider_count,
    selected_feature_only_binary:($feature!=null),
    original_feature_only_named_direct_loader_branches:(
      if $feature!=null then $feature.compiled_named_direct_loader_api_branch_count else null end
    ),
    original_feature_only_loader_import_names:(
      if $feature!=null then $feature.compiled_dynamic_loader_api_import_names else [] end
    ),
    bounded_graphical_dynamic_request_edges:($dynamic_request|length),
    selected_graphical_dynamic_request_targets:[$dynamic_request[].requested_library],
    true_browser_owned_pingsender_libcurl_perform_witness_in_joined_inputs:($e.elf=="pingsender"),
    all_possible_future_feature_and_ffi_dependencies_enumerated:false,
    safely_prunable_based_on_this_register:false,
    absent_from_one_workload_does_not_prove_unused:true
  }
] as $rows |
{
  schema_version:1,
  status:"source_pinned_m3_original_28_elf_current_source_and_dependency_closure_gap_register",
  original_source_commit:$source,
  original_archive_sha256:$archive,
  current_commit:$current,
  verified_original_elf_inventory:($rows|length),
  original_elf_source_manifests_identical_to_current:27,
  original_elf_source_manifest_count_with_unique_owners:27,
  original_protected_boundary_files_identical_to_current:14,
  original_elf_direct_dependencies_resolved_in_ubuntu_and_arch:268,
  unique_original_runtime_binding_requesters_in_bounded_workloads:28,
  original_graphical_conditional_request_edges_outside_loader_lists:21,
  selected_feature_only_elf_count:7,
  selected_feature_only_named_loader_branches:8,
  genuine_original_browser_owned_pingsender_real_libcurl_perform_observed:true,
  complete_current_source_evaluated_build_graph_proven:false,
  complete_future_optional_dlopen_or_ffi_graph_proven:false,
  production_endeavouros_hyprland_native_abi_parity_proven:false,
  successful_end_to_end_feature_runtime_coverage_for_every_elf_proven:false,
  original_full_compiled_archive_not_a_rebuild_of_current_main:true,
  selected_candidate_decision_counts:$c.m3_decision_classification.categories,
  previously_accepted_non_linux_source_removed_files:14867,
  previously_accepted_non_linux_source_removed_git_blob_bytes:129967585,
  new_source_removal_during_this_audit:false,
  new_compiled_browser_package_bytes_saved:null,
  m3_fifth_of_six_gates_passed:true,
  m3_sixth_gate_closed:false,
  permission_to_prune_any_new_binary_or_source:false,
  remaining_acceptance_blockers:[
    {id:"current_evaluated_build_graph",
     requirement:"Authenticate a current-main evaluated config.status, generated Ninja/Cargo/link feature inputs and every packaged output; 41 unchanged source files alone do not prove this"},
    {id:"conditional_native_loader_and_ffi_closure",
     requirement:"Reconcile all source-declared and compiled direct/indirect dlopen/dlsym/FFI edges, conditional branches and safe fallbacks; 21 graphical edges and 14 pingsender symbols are bounded observations"},
    {id:"feature_activation_and_safety",
     requirement:"Exercise preserved feature, privacy, DRM, crash, updater, security, media, ML and alternate process paths sufficiently before opting out; startup and selected tests are not exhaustive"},
    {id:"target_runtime_and_platform",
     requirement:"Verify current build and ABI/dependency contracts on the target EndeavourOS/Hyprland environment with isolated profiles; Arch container metadata alone is not target parity"}
  ],
  per_original_elf:$rows,
  source_pruning_authorized:false,
  native_bytes_saved:0,
  audit_is_read_only:true,
  no_original_binaries_or_user_profiles_accessed:true
}
