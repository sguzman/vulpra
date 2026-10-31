# Independent archived artifacts only: original SHA/source-pinned Ubuntu glibc
# and official Arch Linux userspace loader --list results. This is not a live
# Firefox/Hyprland test and no provider-basename difference implies pruning.
def check($ok;$why): if $ok then . else error($why) end;
def safe($xs):
  ($xs|type)=="array" and
  ($xs|length)==($xs|unique|length) and
  all($xs[]; type=="string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($ubuntu[0]) as $u |
($arch[0]) as $a |
check($u.schema_version==1 and
  $u.status=="source_pinned_original_all_28_elf_loader_list_resolution" and
  $u.original_source_commit==$src and $u.original_archive_sha256==$sha and
  $u.original_elf_members_listed==28 and
  $u.declared_direct_needed_edges==268 and
  $u.direct_needed_sonames_present_in_loader_lists==268 and
  $u.distinct_loader_listed_provider_basenames==91 and
  $u.application_main_executed==false and
  $u.complete_lazy_or_future_dlopen_map_proven==false and
  $u.source_pruning_authorized==false and
  $u.m3_sixth_gate_closed==false;
  "incompatible original Ubuntu loader witness") |
check($a.schema_version==1 and
  $a.status=="original_archlinux_userspace_all_28_elf_loader_list_resolved" and
  $a.original_source_commit==$src and $a.original_archive_sha256==$sha and
  $a.original_elf_count==28 and
  $a.original_direct_needed_edges==268 and
  $a.direct_needed_names_listed_in_arch==268 and
  $a.distinct_arch_loader_provider_basenames==90 and
  $a.arch_userspace_container_only==true and
  $a.runtime_network_disabled==true and
  $a.application_main_executed==false and
  $a.actual_arch_host_or_hyprland_tested==false and
  $a.source_removal_authorized==false and
  $a.m3_sixth_gate_closed==false and
  ($a.arch_container_image_id|test("^sha256:[a-f0-9]{64}$")) and
  ($a.arch_userspace_glibc_version|test("^[0-9][0-9A-Za-z.+_:-]*$"));
  "incompatible original Arch container loader witness") |
check(safe($u.original_elf_basenames) and
  safe($a.original_requester_basenames) and
  ($u.original_elf_basenames==$a.original_requester_basenames) and
  safe($u.loader_listed_provider_basenames) and
  safe($a.arch_loader_provider_basenames);
  "malformed or inconsistent original ELF and provider basenames") |
($u.loader_listed_provider_basenames) as $up |
($a.arch_loader_provider_basenames) as $ap |
($up-$ap|sort) as $only_u |
($ap-$up|sort) as $only_a |
($up+$ap|unique) as $all |
($up|map(select(. as $v | $ap|index($v)!=null))|sort) as $shared |
check(($only_u|length)==10 and ($only_a|length)==9 and
  ($shared|length)==81 and ($all|length)==100;
  "original platform provider basename union count drift") |
{
 schema_version:1,
 status:"original_28_elf_ubuntu_arch_container_loader_platform_crosswalk",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 original_elf_member_count:28,
 original_direct_needed_edges:268,
 ubuntu_direct_needed_names_resolved:268,
 arch_userspace_direct_needed_names_resolved:268,
 ubuntu_loader_provider_name_count:($up|length),
 arch_loader_provider_name_count:($ap|length),
 shared_provider_basename_count:($shared|length),
 ubuntu_only_provider_basename_count:($only_u|length),
 arch_only_provider_basename_count:($only_a|length),
 distinct_provider_basename_union_count:($all|length),
 ubuntu_only_provider_basenames:$only_u,
 arch_only_provider_basenames:$only_a,
 shared_provider_basenames:$shared,
 arch_userspace_glibc_version:$a.arch_userspace_glibc_version,
 arch_container_image_id:$a.arch_container_image_id,
 ubuntu_ci_host_environment:"ubuntu-24.04-x86_64",
 arch_ci_environment:"offline_archlinux_base_userspace_container_on_ubuntu_ci",
 arch_hyprland_host_or_real_browser_tested:false,
 shared_library_name_difference_does_not_indicate_missing_dependency:true,
 no_native_application_entrypoints_executed:true,
 full_future_dlopen_or_feature_coverage_proven:false,
 complete_source_build_ownership_proven:false,
 user_browser_or_profiles_modified:false,
 pruning_or_package_savings_authorized:false,
 m3_sixth_gate_closed:false
}
