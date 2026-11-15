# Exact versioned ELF import name@version / candidate-class parity across
# Ubuntu22, Ubuntu24 and Arch Linux userspace; no native relocation claim.
def check($condition;$why): if $condition then . else error($why) end;
def symbol_safe($v):
  ($v|type)=="string" and
  ($v|test("^[A-Za-z_$?][A-Za-z0-9_.$?+:~%-]{0,254}$"));
def name_safe($v):
  ($v|type)=="string" and
  ($v|test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,127}$"));
def tuples($r):
  [$r.versioned_import_candidate_details[] |
    [.requester_basename,.declared_provider_basename,
     .undefined_symbol,.required_version_name,
     .undefined_symbol_bind,.candidate_class]] | sort;
def triple($r):
  [$r.requirements[]|[.requester_basename,.provider_basename,.version_name]]|unique|sort;
def valid($r;$g;$os;$version;$label):
  $r.schema_version==1 and
  $r.original_native_source_commit==$source and
  $r.original_archive_sha256==$g.archive_sha256 and
  $r.scanned_userspace_id==$os and
  $r.scanned_userspace_version==$version and
  $r.host==$label and
  $r.target_host_kernel_verified==false and
  $r.original_native_elf_members==28 and
  $r.versioned_undefined_dynamic_symbol_imports==4592 and
  ($r.versioned_import_candidate_details|length)==4592 and
  $r.declared_provider_candidate_export_name_matches==3989 and
  $r.modern_glibc_libc_consolidation_name_candidates==603 and
  $r.provider_candidate_unavailable==0 and
  $r.versioned_symbol_candidate_name_not_found==0 and
  ($r.versioned_undefined_dynamic_symbol_imports==
    ($r.declared_provider_candidate_export_name_matches +
     $r.modern_glibc_libc_consolidation_name_candidates +
     $r.provider_candidate_unavailable +
     $r.versioned_symbol_candidate_name_not_found)) and
  all($r.versioned_import_candidate_details[];
    name_safe(.requester_basename) and
    name_safe(.declared_provider_basename) and
    symbol_safe(.undefined_symbol) and
    name_safe(.required_version_name) and
    (.undefined_symbol_bind=="GLOBAL" or .undefined_symbol_bind=="WEAK") and
    (.candidate_class=="declared_provider_candidate_export_name_match" or
     .candidate_class=="modern_glibc_libc_consolidation_export_name_candidate")) and
  ((tuples($r)|unique|length)==4592) and
  $r.unversioned_imports_examined==false and
  $r.weak_symbol_runtime_binding_guaranteed==false and
  $r.actual_elf_symbol_bindings_resolved==false and
  $r.host_ldconfig_candidate_is_runtime_selected_proven==false and
  $r.glibc_merged_symbol_loader_compatibility_proven==false and
  $r.runtime_dlopen_or_feature_coverage_complete==false and
  $r.target_arch_hyprland_symbol_abi_proven==false and
  $r.browser_or_host_elf_executed==false and
  $r.new_source_removal_authorized==false and
  $r.m3_sixth_gate_closed==false;
check(($graph|length)==1 and ($versions|length)==1 and
      ($ubuntu22|length)==1 and ($ubuntu24|length)==1 and ($arch|length)==1;
  "Missing independent source/version/symbol native input") |
($graph[0]) as $g |
check($g.schema_version==1 and
      $g.firefox160_upstream_release_commit==$source and
      $g.firefox160_candidate_git_tree==$tree and
      $g.firefox160_verified_overlays==28 and
      $g.native_browser_producer_run==43138458940 and
      $g.exact_source_archive_mirror_run==43724886827 and
      ($g.elf_members|length)==28 and
      $g.direct_needed_edges==268 and
      $g.all_native_binary_execution_avoided==true and
      $g.complete_native_ffi_dependency_map_proven==false and
      $g.m3_sixth_gate_closed==false;
  "Unauthenticated Firefox160 28-ELF package source") |
($versions[0]) as $v |
check($v.schema_version==1 and
      $v.source_commit==$source and
      $v.original_archive_sha256==$g.archive_sha256 and
      $v.scanned_userspace_id=="ubuntu" and
      $v.scanned_userspace_version=="22.04" and
      $v.native_elf_declared_version_requirements==521 and
      ($v.requirements|length)==521 and
      $v.candidate_version_name_present_count==521 and
      $v.candidate_version_name_absent_count==0 and
      $v.candidate_version_name_unavailable_count==0 and
      $v.actual_symbol_resolution_proven==false and
      $v.target_host_kernel_verified==false and
      $v.m3_sixth_gate_closed==false;
  "Forged 521-name GNU version-indexed source contract") |
($ubuntu22[0]) as $u22 |
($ubuntu24[0]) as $u24 |
($arch[0]) as $a |
check(
 valid($u22;$g;"ubuntu";"22.04";"Ubuntu 22.04 x86-64 CI userspace metadata candidates") and
 valid($u24;$g;"ubuntu";"24.04";"Ubuntu 24.04 x86-64 CI userspace metadata candidates") and
 valid($a;$g;"arch";null;"Arch Linux x86-64 CI userspace metadata candidates");
 "Forged provider, symbol, source, target or ABI candidate evidence") |
(tuples($u22)) as $s22 |
(tuples($u24)) as $s24 |
(tuples($a)) as $sa |
check($s22==$s24 and $s22==$sa and ($s22|length)==4592;
  "Mismatch in exact Firefox160 symbol@version candidates or classifications") |
(triple($v)) as $allowed |
([$u22.versioned_import_candidate_details[] |
  [.requester_basename,.declared_provider_basename,.required_version_name]] |
  unique | sort) as $used |
check(($allowed|length)==521 and ($used|length)==521 and $used==$allowed;
  "Versioned undefined symbol triples differ from exact independent VERNEED metadata") |
([ $s22[]|.[1] ]|unique|sort) as $provider_names |
([ $s22[]|.[0] ]|unique|sort) as $requesters |
check(($requesters|length)==28 and ($provider_names|length)==17;
  "Expected exact Firefox160 native ELF/requester provider census changed") |
{
 schema_version:1,
 status:"firefox160_three_userland_exact_versioned_undefined_symbol_candidate_parity",
 upstream_release_commit:$source,
 candidate_source_tree:$tree,
 original_native_archive_sha256:$g.archive_sha256,
 source_matched_native_census_run:43730900702,
 original_gnu_verneed_521_run:43733171548,
 original_ubuntu_symbol_candidate_run:43733957707,
 original_arch_symbol_candidate_run:43734169158,
 actual_packaged_native_elf_members:28,
 exact_versioned_undefined_symbol_name_version_imports:4592,
 declared_provider_candidate_exact_name_version_matches:3989,
 glibc_consolidation_candidate_exact_name_version_matches:603,
 no_symbol_name_candidate_found:0,
 exact_requester_provider_symbol_version_classification_parity:true,
 all_undefined_versioned_imports_have_independent_verneed_contract:true,
 distinct_requester_elf_names:($requesters|length),
 distinct_versioned_import_provider_names:($provider_names|length),
 verified_gnu_version_name_requirements:521,
 all_observed_candidate_export_names_matched_in_each_userland:true,
 arch_is_disposable_userspace_on_ubuntu_ci_kernel:true,
 exact_actual_runtime_symbol_relocations_proven:false,
 optional_dlopen_unversioned_ffi_feature_closure_proven:false,
 target_endeavouros_hyprland_kernel_gpu_verified:false,
 source_pruning_or_package_saving_authorized:false,
 security_current:false,
 release_ready:false,
 m3_sixth_gate_closed:false
}
