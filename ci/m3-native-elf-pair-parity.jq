# Compare source-pinned bounded metadata for two real Linux browser packages.
# Inputs via --slurpfile historical H.json --slurpfile current C.json,
# with caller-supplied exact source and archive SHA digests.
# This checks direct ELF contracts ONLY: no runtime/FFI/dlopen/ABI parity claim.
def insist($ok; $msg): if $ok then true else error($msg) end;
def hex40: type == "string" and test("^[0-9a-f]{40}$");
def hex64: type == "string" and test("^[0-9a-f]{64}$");
def nameok: type == "string" and test("^\\./vulpra/[a-zA-Z0-9_.+/-]{1,100}$") and (contains("..")|not);
def key($m): {path:$m.path, name:$m.name, soname:$m.soname, needed:$m.needed};
def declared: [.elf_members[] as $m | $m.needed[] | {requester:$m.path, needed:.}] | sort_by(.requester,.needed);
def observed: [.direct_edges[]|{requester,needed}] | sort_by(.requester,.needed);
def packages:
  [.elf_members[]|{path,name,soname,needed}]|sort_by(.path);
def validate($doc; $source; $archive; $is_current):
  ($doc.elf_members | map(.path)) as $names |
  ($doc | declared) as $derived |
  ($doc | observed) as $recorded |
  [
    insist($doc.schema_version == 1; "ELF report schema wrong"),
    insist(($source|hex40) and ($archive|hex64); "Expected source/archive identity not SHA"),
    insist($doc.archive_sha256 == $archive; "Archive identity differs from trusted metadata"),
    insist((if $is_current then $doc.source_commit else $doc.archive_compiled_source_commit end) == $source;
      "Compiled-source identity differs from trusted metadata"),
    insist(($doc.elf_members|length)==28 and ($names|unique|length)==28 and
      ($doc.direct_edges|length)==268; "Native ELF inventory or direct edge count changed"),
    insist($doc.archive_regular_members==47 and $doc.archive_link_members==0;
      "Unexpected package member class or count"),
    insist(all($doc.elf_members[];
      (.path|nameok) and .name == (.path|split("/")[-1]) and
      (.sha256|hex64) and .logical_bytes>0 and
      (.needed|length)==(.needed|unique|length));
      "Invalid ELF path/hash/dependency multiplicity"),
    insist($derived == $recorded; "Direct edge rows inconsistent with source ELF declarations"),
    insist($doc.direct_needed_edges==268 and
      $doc.unique_needed_names == ([$doc.direct_edges[].needed]|unique|length) and
      $doc.unique_needed_names==50;
      "Incorrect native direct edge/name aggregate"),
    insist(($doc.packaged_elf_needed_names|length)==14 and
      ($doc.not_packaged_needed_names|length)==36 and
      ($doc.archive_link_only_needed_names|length)==0 and
      ((($doc.packaged_elf_needed_names+$doc.not_packaged_needed_names)|unique|length)==50);
      "Bad packaged versus external native dependency sets"),
    insist($doc.host_dependency_resolution_verified==false and
      $doc.dlopen_and_indirect_runtime_dependencies_complete==false and
      $doc.current_main_compiled_source_matched==false and
      $doc.source_removal_authorized==false and
      $doc.marginal_compressed_saving_bytes==null;
      "ELF-only artifact overclaims safe closure")
  ] | all;
($historical[0]) as $a |
($current[0]) as $b |
validate($a;$historical_source;$historical_archive;false) as $valid_a |
validate($b;$current_source;$current_archive;true) as $valid_b |
($a|packages) as $left |
($b|packages) as $right |
[
  insist($valid_a and $valid_b; "One package is not authenticated"),
  insist(($left|map({path,name,soname,needed}))==($right|map({path,name,soname,needed}));
    "Native direct dependency/SONAME/owner parity regression"),
  insist($a.packaged_elf_needed_names==$b.packaged_elf_needed_names and
    $a.not_packaged_needed_names==$b.not_packaged_needed_names;
    "Direct dependency packaged/external classification changed")
] | all as $accepted |
($a.elf_members | map({key:.path,value:.}) | from_entries) as $A |
($b.elf_members | map({key:.path,value:.}) | from_entries) as $B |
{
  schema_version:1,
  scope:"native regular ELF owners and static DT_NEEDED metadata across two complete normal Linux packages",
  historical_compiled_source:$historical_source,
  current_compiled_source:$current_source,
  historical_archive_sha256:$historical_archive,
  current_archive_sha256:$current_archive,
  source_pinned_metadata_parity_verified:$accepted,
  exact_native_elf_path_soname_needed_parity:true,
  native_elf_members:($left|length),
  static_direct_needed_edges:($a.direct_edges|length),
  unique_direct_needed_names:$a.unique_needed_names,
  packaged_direct_needed_names:($a.packaged_elf_needed_names|length),
  external_direct_needed_names:($a.not_packaged_needed_names|length),
  native_binary_sha256_changed:[($A|keys[]) as $k | select($A[$k].sha256 != $B[$k].sha256) |
    {path:$k,historical_logical_bytes:$A[$k].logical_bytes,current_logical_bytes:$B[$k].logical_bytes}],
  archive_regular_logical_byte_difference:($b.archive_regular_logical_bytes - $a.archive_regular_logical_bytes),
  archive_compressed_byte_difference:($b.archive_compressed_bytes - $a.archive_compressed_bytes),
  conditional_dlopen_and_ffi_closure_proven:false,
  linker_symbol_or_native_abi_parity_proven:false,
  source_removal_authorized:false,
  marginal_native_size_savings_claimed:null,
  target_endeavouros_hyprland_parity_proven:false
}
