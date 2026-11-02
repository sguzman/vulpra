# Preserve the exact original source-pinned native glibc --list result's
# per-ELF provider sets from an isolated Arch userspace. Do not infer omitted
# per-ELF paths/edges from the old 90-name global union.
def require($condition; $message): if $condition then true else error($message) end;
def valid_name: type=="string" and length>0 and length<=111 and test("^[A-Za-z0-9._+-]+$");
($sample | if length==1 then .[0] else error("expected one original native Arch metadata report") end) as $s |
($s.per_original_elf|keys) as $names |
([$s.per_original_elf[].loader_listed_provider_basenames[]]|unique|sort) as $providers |
[
  require($s.schema_version==1 and
          $s.status=="source_pinned_original_all_28_elf_loader_list_resolution" and
          $s.original_source_commit==$src and
          $s.original_archive_sha256==$sha and
          $s.original_elf_members_listed==28 and
          $s.declared_direct_needed_edges==268 and
          $s.direct_needed_sonames_present_in_loader_lists==268 and
          $s.no_network_egress==true and
          $s.glibc_linker_list_metadata_only==true and
          $s.application_main_executed==false and
          $s.arch_hyprland_runtime_tested==false and
          $s.raw_loader_paths_or_pids_exported==false and
          $s.complete_lazy_or_future_dlopen_map_proven==false and
          $s.source_pruning_authorized==false and $s.m3_sixth_gate_closed==false;
          "wrong original source or loader metadata evidence"),
  require($image|test("^sha256:[a-f0-9]{64}$") and
          ($glibc|test("^[0-9][0-9A-Za-z.+_:-]*$"));
          "unsafe container image ID or glibc version"),
  require(($names|length)==28 and
          ($s.original_elf_basenames|sort)==$names and
          all($names[]; valid_name) and
          ($names|index("libxul.so"))!=null and
          ($names|index("vulpra-bin"))!=null;
          "mismatched or unsafe original ELF requester identity"),
  require(all($s.per_original_elf[];
          (.declared_direct_needed_count|type)=="number" and
          .declared_direct_needed_count>=0 and
          (.loader_listed_provider_count|type)=="number" and
          .loader_listed_provider_count>=.declared_direct_needed_count and
          (.loader_listed_provider_basenames|type)=="array" and
          (.loader_listed_provider_basenames|length)==.loader_listed_provider_count and
          (.loader_listed_provider_basenames|unique|length)==.loader_listed_provider_count and
          all(.loader_listed_provider_basenames[]; valid_name));
          "per-original-ELF Arch loader records invalid"),
  require(([$s.per_original_elf[].declared_direct_needed_count]|add)==268 and
          ([$s.per_original_elf[].loader_listed_provider_count]|add)==$s.loader_listed_provider_name_occurrences and
          ($s.loader_listed_provider_basenames|sort)==$providers and
          ($providers|length)==$s.distinct_loader_listed_provider_basenames;
          "Arch per-ELF source and global loader counts disagree")
] as $checks |
{
 schema_version:1,
 status:"original_archlinux_userspace_all_28_elf_loader_list_resolved",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 arch_container_image_id:$image,
 arch_userspace_glibc_version:$glibc,
 original_elf_count:28,
 original_direct_needed_edges:268,
 direct_needed_names_listed_in_arch:268,
 arch_loader_provider_name_occurrences:$s.loader_listed_provider_name_occurrences,
 distinct_arch_loader_provider_basenames:($providers|length),
 arch_loader_provider_basenames:$providers,
 original_requester_basenames:$names,
 per_original_elf:$s.per_original_elf,
 per_original_elf_provider_map_preserved_and_count_reconciled:true,
 per_original_elf_provider_map_metadata_only:true,
 arch_userspace_container_only:true,
 runtime_network_disabled:true,
 application_main_executed:false,
 actual_arch_host_or_hyprland_tested:false,
 complete_lazy_transitive_feature_map_proven:false,
 generated_build_feature_ownership_complete:false,
 installed_browser_or_profile_changed:false,
 source_removal_authorized:false,
 m3_sixth_gate_closed:false
}
