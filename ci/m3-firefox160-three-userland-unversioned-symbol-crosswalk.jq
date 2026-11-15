# Reconcile source-identical bare ELF imports across three independently
# produced userspace candidate reports. Names are not live relocations.
def check($ok; $why): if $ok then . else error($why) end;
def name_safe($v):
  ($v|type)=="string" and
  ($v|test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$"));
def symbol_safe($v):
  ($v|type)=="string" and
  ($v|length)<=8192 and
  ($v|test("^[A-Za-z_$?][A-Za-z0-9_.$?+:~%-]+$"));
def record_ok($d):
  name_safe($d.requester_basename) and
  symbol_safe($d.undefined_symbol) and
  ($d.undefined_symbol_bind=="GLOBAL" or $d.undefined_symbol_bind=="WEAK") and
  ($d.direct_needed_candidate_provider_basenames|type)=="array" and
  all($d.direct_needed_candidate_provider_basenames[]; name_safe(.)) and
  ($d.direct_needed_candidate_provider_basenames ==
    ($d.direct_needed_candidate_provider_basenames|unique|sort)) and
  (
    ($d.candidate_class=="direct_needed_export_name_candidate" and
      ($d.direct_needed_candidate_provider_basenames|length)>0) or
    ($d.candidate_class=="weak_import_without_direct_candidate" and
      $d.undefined_symbol_bind=="WEAK" and
      ($d.direct_needed_candidate_provider_basenames|length)==0) or
    ($d.candidate_class=="strong_import_without_direct_candidate" and
      $d.undefined_symbol_bind=="GLOBAL" and
      ($d.direct_needed_candidate_provider_basenames|length)==0)
  );
def rows($r):
  [$r.unversioned_import_candidate_details[] |
    {key:[.requester_basename,.undefined_symbol,.undefined_symbol_bind],
     candidate_class:.candidate_class,
     providers:.direct_needed_candidate_provider_basenames}] |
  sort_by(.key);
def valid($r;$g;$os;$version;$direct;$weak):
  $r.schema_version==1 and
  $r.original_native_source_commit==$source and
  $r.original_archive_sha256==$g.archive_sha256 and
  $r.scanned_userspace_id==$os and
  $r.scanned_userspace_version==$version and
  $r.target_host_kernel_verified==false and
  $r.original_native_elf_members==28 and
  $r.unversioned_undefined_dynamic_symbol_imports==2154 and
  ($r.unversioned_import_candidate_details|length)==2154 and
  $r.direct_needed_export_name_candidates==$direct and
  $r.weak_imports_without_direct_candidate==$weak and
  $r.strong_imports_without_direct_candidate==0 and
  ($r.direct_needed_export_name_candidates+
   $r.weak_imports_without_direct_candidate+
   $r.strong_imports_without_direct_candidate)==2154 and
  all($r.unversioned_import_candidate_details[]; record_ok(.)) and
  $r.unversioned_imports_examined==true and
  $r.all_unversioned_imports_loader_resolved==false and
  $r.weak_symbol_runtime_binding_guaranteed==false and
  $r.actual_elf_symbol_bindings_resolved==false and
  $r.host_ldconfig_candidate_is_runtime_selected_proven==false and
  $r.transitive_preload_and_dynamic_scope_complete==false and
  $r.runtime_dlopen_or_feature_coverage_complete==false and
  $r.target_arch_hyprland_symbol_abi_proven==false and
  $r.browser_or_host_elf_executed==false and
  $r.new_source_removal_authorized==false and
  $r.m3_sixth_gate_closed==false;
check(($graph|length)==1 and ($ubuntu22|length)==1 and
      ($ubuntu24|length)==1 and ($arch|length)==1;
  "Missing pinned source or userspace bare symbol evidence") |
($graph[0]) as $g |
check($g.schema_version==1 and
      $g.firefox160_upstream_release_commit==$source and
      $g.firefox160_candidate_git_tree==$tree and
      $g.native_browser_producer_run==43138458940 and
      $g.exact_source_archive_mirror_run==43724886827 and
      ($g.elf_members|length)==28 and
      $g.direct_needed_edges==268 and
      $g.all_native_binary_execution_avoided==true and
      $g.complete_native_ffi_dependency_map_proven==false and
      $g.m3_sixth_gate_closed==false;
  "Untrusted exact original package graph") |
($ubuntu22[0]) as $u22 |
($ubuntu24[0]) as $u24 |
($arch[0]) as $a |
check(
  valid($u22;$g;"ubuntu";"22.04";1833;321) and
  valid($u24;$g;"ubuntu";"24.04";1835;319) and
  valid($a;$g;"arch";null;1835;319);
  "Invalid or inconsistent original bare symbol report") |
(rows($u22)) as $r22 |
(rows($u24)) as $r24 |
(rows($a)) as $ra |
check(([$r22[].key]==[$r24[].key]) and
      ([$r22[].key]==[$ra[].key]) and
      ($r22|length)==2154;
  "Actual bare undefined requester/name/bind tuples disagree between userspaces") |
[range(0;2154) as $i |
  select(($r22[$i].candidate_class!=$r24[$i].candidate_class) or
         ($r22[$i].providers!=$r24[$i].providers) or
         ($r22[$i].candidate_class!=$ra[$i].candidate_class) or
         ($r22[$i].providers!=$ra[$i].providers)) |
  {import:$r22[$i].key,
   ubuntu22:{class:$r22[$i].candidate_class,providers:$r22[$i].providers},
   ubuntu24:{class:$r24[$i].candidate_class,providers:$r24[$i].providers},
   arch:{class:$ra[$i].candidate_class,providers:$ra[$i].providers}}] as $differences |
{
  schema_version:1,
  status:"firefox160_three_userland_unversioned_undefined_symbol_name_candidate_reconciliation",
  original_native_source_commit:$source,
  exact_candidate_source_tree:$tree,
  original_archive_sha256:$g.archive_sha256,
  original_native_elf_members:28,
  exact_bare_undefined_import_records:2154,
  exact_requester_name_bind_tuple_parity:true,
  ubuntu22_direct_needed_export_name_candidates:1833,
  ubuntu24_direct_needed_export_name_candidates:1835,
  arch_direct_needed_export_name_candidates:1835,
  ubuntu22_weak_imports_without_direct_candidate:321,
  ubuntu24_weak_imports_without_direct_candidate:319,
  arch_weak_imports_without_direct_candidate:319,
  no_strong_bare_import_without_direct_candidate:true,
  userspace_candidate_differences:$differences,
  userspace_candidate_difference_count:($differences|length),
  run_ubuntu:43740138658,
  run_arch:43740286694,
  original_package_graph_run:43730900702,
  actual_loader_symbol_bindings_proven:false,
  optional_dlopen_and_ffi_closure_complete:false,
  target_endeavouros_hyprland_verified:false,
  security_current:false,
  source_pruning_or_release_authorized:false,
  m3_sixth_gate_closed:false
}
