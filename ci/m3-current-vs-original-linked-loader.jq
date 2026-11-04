# Bounded original-to-current native loader-callsite evidence crosswalk.
# Both sources are linked unstripped native libxul ELF files as attested by
# separate source-pinned build artifacts. Do not equate finite direct-call
# comparisons with a complete dlsym/dlopen/FFI graph or pruning permission.
def insist($condition; $why): if $condition then true else error($why) end;
def sha40: type == "string" and test("^[a-f0-9]{40}$");
def sha256: type == "string" and test("^[a-f0-9]{64}$");
def loader: . == "dlopen" or . == "dlmopen" or . == "PR_LoadLibrary" or . == "PR_LoadLibraryWithFlags" or . == "PR_LoadLibraryByPathname";
def shape($x; $src; $hash):
  (
    [
      insist($x.schema_version == 1 and $x.binary == "libxul.so" and
        $x.status == "compiled_direct_loader_api_callsite_census"; "Wrong compiled-census schema"),
      insist($x.source_commit == $src and ($src|sha40); "Compiled-census source provenance mismatch"),
      insist($x.unstripped_native_elf_sha256 == $hash and ($hash|sha256); "Linked ELF hash mismatch"),
      insist(($x.unstripped_native_elf_bytes|type) == "number" and
        $x.unstripped_native_elf_bytes > 10000000 and
        $x.unstripped_native_elf_bytes <= 4294967296; "Implausible linked ELF size"),
      insist(($x.native_instruction_lines|type) == "number" and
        $x.native_instruction_lines > 10000 and
        $x.native_instruction_lines <= 35000000; "Implausible instruction count"),
      insist(($x.direct_loader_callsite_records|type) == "array" and
        ($x.direct_loader_callsite_records|length) > 0 and
        ($x.direct_loader_callsite_records|length) <= 5000; "Unbounded or empty caller records"),
      insist(all($x.direct_loader_callsite_records[];
        (.caller_symbol|type == "string" and length > 0 and length <= 512) and
        (.loader_api|loader) and
        (.branch_kind == "call" or .branch_kind == "tail-jump") and
        (.native_branches|type == "number" and . >= 1 and . <= 100000));
        "Invalid caller/native API/branch kind or multiplicity"),
      insist($x.distinct_caller_loader_kind_records == ($x.direct_loader_callsite_records|length) and
        ($x.direct_loader_callsite_records|map([.caller_symbol,.loader_api,.branch_kind])|unique|length) ==
        ($x.direct_loader_callsite_records|length); "Duplicated or inconsistent caller entries"),
      insist($x.direct_loader_branches == ([$x.direct_loader_callsite_records[].native_branches]|add) and
        $x.direct_loader_branches >= 1 and $x.direct_loader_branches <= 100000;
        "Compiled loader branch counts contradict records"),
      insist($x.independently_accepted_ffmpeg_to_nspr_call_count == 1;
        "Expected FFmpeg to NSPR direct loader control missing"),
      insist($x.indirect_loader_calls_enumerated == false and
        $x.every_dynamic_loader_api_enumerated == false and
        $x.actual_dynamic_library_names_verified == false and
        $x.conditional_runtime_routes_exercised == false and
        $x.all_elf_consumers_covered == false and
        $x.arch_workstation_verified == false and
        $x.source_pruning_authorized == false and
        $x.m3_sixth_gate_closed == false; "Census makes unsupported closure claims")
    ] | all
  );
def rowkey: [.caller_symbol,.loader_api,.branch_kind] | @json;
def agg($r):
  [$r[]|{key:rowkey,value:.native_branches}]|from_entries;
def histogram($r):
  [$r|group_by(.loader_api)[]|{api:.[0].loader_api,branches:(map(.native_branches)|add),records:length}] | sort_by(.api);
($original[0]) as $o | ($current[0]) as $c |
shape($o;$original_source;$original_elf_sha256) as $original_ok |
shape($c;$current_source;$current_elf_sha256) as $current_ok |
insist($original_ok and $current_ok and $original_source != $current_source;
       "Source comparison identities invalid") as $valid |
insist($o.direct_loader_branches == 73 and
       $o.distinct_caller_loader_kind_records == 47 and
       $o.independently_accepted_ffmpeg_to_nspr_call_count == 1;
       "Pinned historic compiled-census baseline changed") as $historical_valid |
agg($o.direct_loader_callsite_records) as $left |
agg($c.direct_loader_callsite_records) as $right |
([$left|keys[]] + [$right|keys[]] | unique) as $all_keys |
[$all_keys[]|. as $k|{key:$k, original:($left[$k]//0),current:($right[$k]//0)}|
  select(.original != .current)] as $changed |
{
 schema_version:1,
 status:"bounded_original_to_current_linked_direct_loader_callsite_comparison",
 historical_source:$original_source,
 current_source:$current_source,
 historical_unstripped_elf_sha256:$original_elf_sha256,
 current_unstripped_elf_sha256:$current_elf_sha256,
 exact_both_source_and_elf_identities_checked:($valid and $historical_valid),
 historical_census:{direct_branches:$o.direct_loader_branches,
                    caller_api_kind_records:$o.distinct_caller_loader_kind_records,
                    loader_histogram:histogram($o.direct_loader_callsite_records)},
 current_census:{direct_branches:$c.direct_loader_branches,
                 caller_api_kind_records:$c.distinct_caller_loader_kind_records,
                 loader_histogram:histogram($c.direct_loader_callsite_records)},
 changed_caller_api_kind_multiplicities:$changed,
 changed_records:($changed|length),
 bytewise_symbol_identity_or_ffi_resolution_verified:false,
 all_indirect_loader_calls_or_sonames_enumerated:false,
 protected_feature_fallbacks_verified:false,
 target_endeavouros_hyprland_workstation_verified:false,
 m3_sixth_gate_closed:false,
 source_pruning_authorized:false,
 marginal_native_bytes_saved:null
}
