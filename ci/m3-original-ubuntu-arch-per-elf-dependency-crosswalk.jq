# Exact source/ELF identity join: archived Ubuntu per-file sources and loader
# lists vs a second, independently executed original Arch userspace loader run.
# Provider sets are glibc --list metadata, not executed feature paths.
def require($test; $err): if $test then true else error($err) end;
($matrix|if length==1 then .[0] else error("expected one pinned previous 28 ELF matrix") end) as $m |
($arch|if length==1 then .[0] else error("expected one pinned Arch per-ELF report") end) as $a |
($m.rows|map(.elf)) as $names |
($a.per_original_elf|keys) as $arch_names |
[
  require($m.schema_version==1 and
          $m.status=="original_28_elf_source_loader_runtime_binding_matrix_crosschecked" and
          $m.original_source_commit==$src and $m.original_archive_sha256==$sha and
          $m.source_manifest_owners==28 and $m.ubuntu_direct_needed_edges==268 and
          $m.ubuntu_per_elf_loader_provider_occurrences==586 and
          $m.per_elf_arch_provider_mapping_available==false and
          $m.observed_original_runtime_binding_requesters==28 and
          $m.complete_lazy_and_future_dynamic_loading_map_proven==false and
          $m.source_pruning_authorized==false and $m.m3_sixth_gate_closed==false;
          "old original 28 ELF inventory untrusted"),
  require($a.schema_version==1 and
          $a.status=="original_archlinux_userspace_all_28_elf_loader_list_resolved" and
          $a.original_source_commit==$src and $a.original_archive_sha256==$sha and
          $a.original_elf_count==28 and $a.original_direct_needed_edges==268 and
          $a.direct_needed_names_listed_in_arch==268 and
          $a.per_original_elf_provider_map_preserved_and_count_reconciled==true and
          $a.per_original_elf_provider_map_metadata_only==true and
          $a.arch_userspace_container_only==true and
          $a.runtime_network_disabled==true and $a.application_main_executed==false and
          $a.actual_arch_host_or_hyprland_tested==false and
          $a.source_removal_authorized==false and $a.m3_sixth_gate_closed==false;
          "new original 28 ELF Arch report untrusted"),
  require(($names|length)==28 and ($names|unique|length)==28 and
          ($names|sort)==$arch_names and
          ($a.original_requester_basenames|sort)==$arch_names;
          "historical source owners versus Arch ELF basenames mismatch")
] as $cross_checks |
[$m.rows[] | . as $old | $a.per_original_elf[.elf] as $new |
   ($old.ubuntu_loader_provider_basenames|sort|unique) as $ubuntu_names |
   ($new.loader_listed_provider_basenames|sort|unique) as $arch_names |
   {
     elf:$old.elf,
     source_manifest:$old.source_manifest,
     source_manifest_anchor_line:$old.source_manifest_anchor_line,
     source_declaration_class:$old.source_declaration_class,
     source_declaration_guard_present:$old.source_declaration_guard_present,
     original_native_binding_observation:$old.native_binding_observation,
     original_runtime_requester_observed:$old.original_runtime_requester_observed,
     direct_needed_ubuntu:$old.ubuntu_direct_needed_count,
     direct_needed_arch:$new.declared_direct_needed_count,
     ubuntu_loader_provider_basenames:$ubuntu_names,
     arch_loader_provider_basenames:$arch_names,
     ubuntu_loader_provider_count:$old.ubuntu_loader_provider_count,
     arch_loader_provider_count:$new.loader_listed_provider_count,
     common_provider_basenames:($ubuntu_names - ($ubuntu_names - $arch_names)),
     ubuntu_only_provider_basenames:($ubuntu_names - $arch_names),
     arch_only_provider_basenames:($arch_names - $ubuntu_names),
     direct_needed_cross_distro_count_matches:($old.ubuntu_direct_needed_count==$new.declared_direct_needed_count)
   }
] as $rows |
([$rows[].ubuntu_loader_provider_basenames[]]|unique|sort) as $ubuntu_union |
([$rows[].arch_loader_provider_basenames[]]|unique|sort) as $arch_union |
[
  require(all($rows[];
    .direct_needed_cross_distro_count_matches==true and
    .original_runtime_requester_observed==true and
    (.source_manifest|type)=="string" and .source_manifest!="" and
    (.source_manifest_anchor_line|type)=="number" and .source_manifest_anchor_line>0 and
    (.source_declaration_class|type)=="string" and
    (.ubuntu_loader_provider_basenames|length)==.ubuntu_loader_provider_count and
    (.arch_loader_provider_basenames|length)==.arch_loader_provider_count and
    ((.common_provider_basenames|length) + (.ubuntu_only_provider_basenames|length))==.ubuntu_loader_provider_count and
    ((.common_provider_basenames|length) + (.arch_only_provider_basenames|length))==.arch_loader_provider_count);
    "per-ELF original source, direct deps or provider set partition inconsistent"),
  require(([$rows[].direct_needed_ubuntu]|add)==268 and
          ([$rows[].direct_needed_arch]|add)==268 and
          ([$rows[].ubuntu_loader_provider_count]|add)==586 and
          ([$rows[].arch_loader_provider_count]|add)==$a.arch_loader_provider_name_occurrences and
          ($arch_union|length)==$a.distinct_arch_loader_provider_basenames and
          $arch_union==($a.arch_loader_provider_basenames|sort) and
          ($ubuntu_union|length)==91;
          "global and original per-ELF loader counts inconsistent")
] as $row_checks |
{
 schema_version:1,
 status:"original_28_elf_ubuntu_arch_per_elf_loader_and_source_crosswalk_verified",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 historical_matrix_run:41513030899,
 exact_original_arch_per_elf_run:$arch_run,
 arch_container_image_id:$a.arch_container_image_id,
 arch_userspace_glibc_version:$a.arch_userspace_glibc_version,
 source_manifest_owners:28,
 resolved_ubuntu_direct_needed:268,
 resolved_arch_direct_needed:268,
 ubuntu_loader_provider_occurrences:586,
 arch_loader_provider_occurrences:$a.arch_loader_provider_name_occurrences,
 ubuntu_distinct_provider_names:91,
 arch_distinct_provider_names:($arch_union|length),
 common_global_provider_basenames:($ubuntu_union - ($ubuntu_union - $arch_union)),
 ubuntu_only_global_provider_basenames:($ubuntu_union - $arch_union),
 arch_only_global_provider_basenames:($arch_union - $ubuntu_union),
 original_runtime_requester_observed_count:28,
 every_original_elf_has_arch_loader_provider_list:true,
 every_elf_direct_needed_count_matches_across_distros:true,
 per_elf_provider_names_are_metadata_only:true,
 every_original_feature_route_proven:false,
 complete_future_dlopen_closure_proven:false,
 exact_target_endeavouros_hyprland_verified:false,
 source_pruning_authorized:false,
 native_bytes_saved:0,
 m3_sixth_gate_closed:false,
 rows:$rows
}
