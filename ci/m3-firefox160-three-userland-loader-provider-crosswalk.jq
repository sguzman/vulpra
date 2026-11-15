# Reconcile three independently source-pinned Firefox 160 native ELF glibc
# --list artifacts. No binary runtime, source pruning or target OS acceptance.
def check($ok;$why): if $ok then . else error($why) end;
def safe($xs):
  ($xs|type)=="array" and
  ($xs|length)==($xs|unique|length) and
  all($xs[];type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
def shared($x;$y): [$x[]|select(. as $v | ($y|index($v))!=null)]|unique|sort;
def valid($r;$expected;$g):
  $r.schema_version==1 and
  $r.status=="source_pinned_firefox160_all_28_elf_loader_list_resolution" and
  $r.firefox160_source_commit==$src and
  $r.firefox160_archive_sha256==$g.archive_sha256 and
  $r.firefox160_elf_members_listed==28 and
  $r.declared_direct_needed_edges==268 and
  $r.direct_needed_sonames_present_in_loader_lists==268 and
  $r.loader_listed_provider_name_occurrences>=268 and
  $r.distinct_loader_listed_provider_basenames==$expected and
  safe($r.firefox160_elf_basenames) and
  safe($r.loader_listed_provider_basenames) and
  ($r.loader_listed_provider_basenames|length)==$expected and
  ($r.firefox160_elf_basenames|sort)==($g.elf_members|map(.name)|sort) and
  ($r.per_firefox160_elf|keys)==($g.elf_members|map(.name)|sort) and
  all($g.elf_members[];
    . as $m |
    ($r.per_firefox160_elf[$m.name].declared_direct_needed_names|sort)==($m.needed|sort) and
    $r.per_firefox160_elf[$m.name].declared_direct_needed_count==($m.needed|length)
  ) and
  ([$r.per_firefox160_elf[]|.loader_listed_provider_basenames[]]|unique|sort)==
    ($r.loader_listed_provider_basenames|sort) and
  $r.glibc_linker_list_metadata_only==true and
  $r.application_main_executed==false and
  $r.no_network_egress==true and
  $r.actual_genuine_feature_workflows_proven==false and
  $r.complete_lazy_or_future_dlopen_map_proven==false and
  $r.arch_hyprland_runtime_tested==false and
  $r.raw_loader_paths_or_pids_exported==false and
  $r.source_pruning_authorized==false and
  $r.security_current==false and $r.release_ready==false and
  $r.m3_sixth_gate_closed==false;
check(($graph|length)==1 and ($ubuntu22|length)==1 and
      ($ubuntu24|length)==1 and ($arch|length)==1;
      "Missing or ambiguous pinned source or loader report") |
($graph[0]) as $g |
check($g.schema_version==1 and
      $g.firefox160_upstream_release_commit==$src and
      $g.firefox160_candidate_git_tree==$tree and
      $g.firefox160_verified_overlays==28 and
      $g.native_browser_producer_run==43138458940 and
      $g.exact_source_archive_mirror_run==43724886827 and
      ($g.elf_members|length)==28 and
      $g.direct_needed_edges==268 and
      $g.unique_needed_names==50 and
      ($g.packaged_elf_needed_names|length)==14 and
      ($g.not_packaged_needed_names|length)==36 and
      $g.host_dependency_resolution_verified==false and
      $g.complete_native_ffi_dependency_map_proven==false and
      $g.m3_sixth_gate_closed==false;
      "Wrong source-authenticated direct-ELF census") |
($ubuntu22[0]) as $u22 |
($ubuntu24[0]) as $u24 |
($arch[0]) as $a |
check(valid($u22;92;$g) and valid($u24;91;$g) and valid($a;90;$g);
      "Wrong or forged direct ELF loader provider evidence") |
($u22.loader_listed_provider_basenames|sort) as $p22 |
($u24.loader_listed_provider_basenames|sort) as $p24 |
($a.loader_listed_provider_basenames|sort) as $pa |
(shared($p22;$p24)) as $shared_ubuntu |
(shared($shared_ubuntu;$pa)) as $shared_three |
($p22+$p24+$pa|unique|sort) as $union |
($p22-$p24|sort) as $only22v24 |
($p24-$p22|sort) as $only24v22 |
($p22-$pa|sort) as $only22va |
($pa-$p22|sort) as $onlyav22 |
($p24-$pa|sort) as $only24va |
($pa-$p24|sort) as $onlyav24 |
check(($shared_three|length)>60 and ($union|length)>=92 and
      ($union|length)<=160 and
      (($p22+$p24+$pa|unique|length)==($union|length)) and
      (($p22|length)==($shared_ubuntu|length)+($only22v24|length)) and
      (($p24|length)==($shared_ubuntu|length)+($only24v22|length));
      "Provider set reconciliation failed") |
{
 schema_version:1,
 status:"firefox160_three_ci_userland_glibc_direct_loader_provider_crosswalk",
 source_release_commit:$src,
 candidate_complete_git_tree:$tree,
 native_archive_sha256:$g.archive_sha256,
 independently_verified_source_graph_run:43730900702,
 independently_verified_ubuntu_loader_run:43731304463,
 independently_verified_arch_loader_run:43731540340,
 verified_native_elf_members:28,
 verified_direct_needed_edges:268,
 direct_sonames_found_per_elf_on_each_userspace:268,
 ubuntu22_provider_basename_count:($p22|length),
 ubuntu24_provider_basename_count:($p24|length),
 arch_userspace_provider_basename_count:($pa|length),
 shared_all_three_count:($shared_three|length),
 unique_three_userland_provider_count:($union|length),
 shared_all_three_basenames:$shared_three,
 ubuntu22_only_vs_ubuntu24_basenames:$only22v24,
 ubuntu24_only_vs_ubuntu22_basenames:$only24v22,
 ubuntu22_only_vs_arch_basenames:$only22va,
 arch_only_vs_ubuntu22_basenames:$onlyav22,
 ubuntu24_only_vs_arch_basenames:$only24va,
 arch_only_vs_ubuntu24_basenames:$onlyav24,
 all_member_direct_dependency_names_cross_checked:true,
 provider_basename_differences_are_not_dependency_failures:true,
 loader_special_names_not_counted_as_bundled_libraries:true,
 arch_linux_userspace_uses_ubuntu_host_kernel:true,
 native_application_entrypoints_executed:false,
 complete_optional_dlopen_or_rust_cpp_ffi_map_proven:false,
 actual_endeavouros_hyprland_hardware_verified:false,
 raw_paths_pids_or_user_data_exported:false,
 safe_source_pruning_or_measured_package_savings_authorized:false,
 security_current:false,
 release_ready:false,
 m3_sixth_gate_closed:false
}
