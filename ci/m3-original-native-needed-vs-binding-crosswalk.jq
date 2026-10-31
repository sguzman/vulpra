# Original compiled package exact-source static DT_NEEDED vs *sampled* glibc
# normal-symbol provider-basename observations. Never claim absence=unused.
def check($ok;$why): if $ok then . else error($why) end;
def safe($s): ($s|type=="string") and ($s|test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$"));
($native[0]) as $r |
($direct[0]) as $d |
check($r.schema_version==1 and $r.original_source_commit==$src and
 $r.original_archive_sha256==$sha and
 $r.status=="original_package_elf_requester_live_binding_inventory" and
 $r.original_package_elf_count==28 and
 $r.original_requester_basenames_observed==21 and
 $r.raw_loader_logs_exported==false and
 $r.symbol_names_exported==false and
 $r.complete_lazy_transitive_or_feature_coverage_proven==false;
 "unexpected original compiled runtime evidence") |
check($d.schema_version==1 and $d.original_source_commit==$src and
 $d.original_archive_sha256==$sha and
 $d.original_elf_count==28 and
 ($d.edges|type)=="array" and ($d.edges|length)>100;
 "missing original compiled static DT_NEEDED graph") |
check(all($d.edges[]; . as $e |
 safe($e.requester_basename) and safe($e.needed_basename) and
 (($r.observed_requester_basenames+$r.unobserved_requester_basenames_on_this_workload)|index($e.requester_basename)!=null)) and
 (($d.edges|map([.requester_basename,.needed_basename]|join(":"))|unique|length)==($d.edges|length));
 "invalid, duplicated or non-original static direct ELF dependency") |
check(all($r.per_original_requester[]; .provider_basename_count==(.observed_provider_basenames|length) and
 all(.observed_provider_basenames[]; safe(.)));
 "untrusted or duplicated per-requester real provider report") |
[$d.edges[] |
 . as $edge |
 ($r.per_original_requester[$edge.requester_basename] // null) as $live |
 {
  requester_basename:$edge.requester_basename,
  declared_dt_needed_basename:$edge.needed_basename,
  requester_had_normal_binding_in_this_workload:($live!=null),
  same_provider_basename_normal_binding_observed:(
    $live!=null and (($live.observed_provider_basenames|index($edge.needed_basename))!=null))
 }
] as $rows |
{
 schema_version:1,
 status:"original_elf_direct_needed_vs_sampled_normal_binding_provider_crosswalk",
 original_source_commit:$src,
 original_archive_sha256:$sha,
 original_package_elf_count:28,
 original_elf_requesters_with_sampled_bindings:$r.original_requester_basenames_observed,
 declared_dt_needed_edges:($rows|length),
 edges_with_requester_observed_in_workload:([$rows[]|select(.requester_had_normal_binding_in_this_workload)]|length),
 edges_with_same_provider_normal_binding_witnessed:([$rows[]|select(.same_provider_basename_normal_binding_observed)]|length),
 edges_for_unobserved_requesters_in_this_workload:([$rows[]|select(.requester_had_normal_binding_in_this_workload|not)]|length),
 direct_needed_edges:$rows,
 no_raw_symbols_pids_or_paths_exported:true,
 does_not_claim_each_needed_library_resolved:true,
 no_binding_does_not_imply_unneeded:true,
 complete_lazy_or_transitive_coverage_proven:false,
 removal_authorized:false,
 m3_sixth_gate_closed:false
}
