# Independently reconcile all 521 source-pinned Firefox160 VERNEED tuples
# across Ubuntu 22.04, Ubuntu 24.04 and disposable Arch userspace.
# This proves only ELF GNU version-NAME candidate coverage.
def check($condition;$message): if $condition then . else error($message) end;
def names_safe($xs):
  ($xs|type)=="array" and
  all($xs[];type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$"));
def keyset($r):
  [$r.requirements[] |
    [.requester_basename,.provider_basename,.version_name]] | sort;
def valid($r;$g;$os;$version;$label):
  $r.schema_version==1 and
  $r.source_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  $r.original_archive_sha256==$g.archive_sha256 and
  $r.scanned_native_elf_files==28 and
  $r.native_elf_declared_version_requirements==521 and
  ($r.requirements|length)==521 and
  $r.candidate_version_name_present_count==521 and
  $r.candidate_version_name_absent_count==0 and
  $r.candidate_version_name_unavailable_count==0 and
  $r.scanned_userspace_id==$os and
  $r.scanned_userspace_version==$version and
  $r.host==$label and
  $r.target_host_kernel_verified==false and
  ($r.requirements|all(.[];
     .candidate_scope=="packaged_declared_version_names" or
     .candidate_scope=="host_ldconfig_candidate_version_names")) and
  all($r.requirements[];
    .version_name_present_in_candidate==true and
    names_safe([.requester_basename,.provider_basename,.version_name]) and
    (.provider_basename|index("/"))==null
  ) and
  ($r.native_elf_declared_version_requirements ==
    ((keyset($r))|unique|length)) and
  $r.native_binaries_executed==false and
  $r.ldd_or_dynamic_loader_executed==false and
  $r.actual_symbol_resolution_proven==false and
  $r.loader_search_path_proven==false and
  $r.host_provider_is_runtime_selected_proven==false and
  $r.dlopen_graph_complete==false and
  $r.source_feature_attribution_proven==false and
  $r.target_arch_hyprland_abi_proven==false and
  $r.safe_source_removal_authorized==false and
  $r.m3_sixth_gate_closed==false;
check(($graph|length)==1 and ($ubuntu22|length)==1 and
      ($ubuntu24|length)==1 and ($arch|length)==1;
  "Incomplete or ambiguous source-backed Firefox160 version inputs") |
($graph[0]) as $g |
check($g.schema_version==1 and
  $g.firefox160_upstream_release_commit==$src and
  $g.firefox160_candidate_git_tree==$tree and
  $g.firefox160_verified_overlays==28 and
  $g.native_browser_producer_run==43138458940 and
  $g.exact_source_archive_mirror_run==43724886827 and
  ($g.elf_members|length)==28 and
  $g.direct_needed_edges==268 and
  $g.all_native_binary_execution_avoided==true and
  $g.complete_native_ffi_dependency_map_proven==false and
  $g.m3_sixth_gate_closed==false;
  "Wrong exact-source Firefox160 package direct ELF census") |
($ubuntu22[0]) as $u22 |
($ubuntu24[0]) as $u24 |
($arch[0]) as $a |
check(valid($u22;$g;"ubuntu";"22.04";"Ubuntu 22.04 x86-64 CI userspace metadata candidates") and
  valid($u24;$g;"ubuntu";"24.04";"Ubuntu 24.04 x86-64 CI userspace metadata candidates") and
  valid($a;$g;"arch";null;"Arch Linux x86-64 CI userspace metadata candidates");
  "One Firefox160 ABI version-name report is forged or inconsistent") |
(keyset($u22)) as $s22 |
(keyset($u24)) as $s24 |
(keyset($a)) as $sa |
check($s22==$s24 and $s22==$sa and
      ($s22|length)==521 and
      (($s22|unique|length)==521);
  "Same archive produced mismatching per-ELF GNU VERNEED tuples") |
([$s22[]|.[1]]|unique|sort) as $providers |
([$u22.requirements[]|select(.candidate_scope=="packaged_declared_version_names")]|length) as $packaged |
([$u22.requirements[]|select(.candidate_scope=="host_ldconfig_candidate_version_names")]|length) as $host |
check($packaged>0 and $host>0 and $packaged+$host==521 and
      ([$u24.requirements[]|select(.candidate_scope=="packaged_declared_version_names")]|length)==$packaged and
      ([$a.requirements[]|select(.candidate_scope=="packaged_declared_version_names")]|length)==$packaged;
  "Source-identical packaged versus host-version class counts differ") |
{
 schema_version:1,
 status:"firefox160_three_userspace_exact_gnu_verneed_tuple_parity",
 moz_firefox160_release_source_commit:$src,
 vulpra_candidate_git_tree:$tree,
 verified_overlays:28,
 native_archive_sha256:$g.archive_sha256,
 original_browser_producer_run:43138458940,
 source_package_archive_mirror_run:43724886827,
 independently_verified_elf_census_run:43730900702,
 independently_verified_ubuntu_version_run:43733171548,
 independently_verified_arch_version_run:43733061688,
 packaged_native_elf_files:28,
 all_direct_needed_elf_edges:268,
 exact_unique_elf_provider_version_tuples_common_to_three:521,
 packaged_elf_candidate_version_names_present:$packaged,
 host_ldconfig_candidate_version_names_present:$host,
 all_three_requirements_present_in_candidates:true,
 version_requirement_provider_basenames:$providers,
 distinct_required_version_provider_basenames:($providers|length),
 exact_tuple_parity_across_three_userspaces:true,
 arched_userspace_not_target_kernel:true,
 actual_dynamic_provider_selection_proven:false,
 actual_symbol_bindings_or_relocations_proven:false,
 conditional_dlopen_ffi_feature_graph_complete:false,
 target_endeavouros_hyprland_hardware_verified:false,
 raw_paths_pids_or_user_data_exported:false,
 source_pruning_authorized:false,
 security_current:false,
 release_ready:false,
 m3_sixth_gate_closed:false
}
