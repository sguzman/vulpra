# Original packaged libonnxruntime and CI plugin: readelf DT_NEEDED vs real
# dl_iterate_phdr basename snapshots, sampled only in one no-egress workload.
# No paths, symbols, raw process traces, or claims of whole-browser closure.
def safe: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9_.+-]{0,110}$");
def needed($raw):
  ($raw | split("\n") | map(select(length > 0))) as $names
  | if (($names | length) >= 1 and ($names | length) <= 64 and
        ($names | unique | length) == ($names | length) and
        all($names[]; safe))
    then $names else error("invalid or empty static DT_NEEDED names") end;
def mapped($records; $stage; $kind):
  [$records[] | select(.stage == $stage and .kind == $kind) | .name] | unique;
def edges($names; $requester; $stage; $records):
  [$names[] as $need |
    [$records[] | select(.stage == $stage and .name == $need)] as $matches |
    if ($matches | length) != 1 then
      error("static DT_NEEDED basename not uniquely mapped at expected stage")
    else
      {requester:$requester, needed:$need, observed_stage:$stage,
       mapped_kind:$matches[0].kind, matched_by_basename_only:true}
    end];
($map_records | length) as $map_files |
(if $map_files != 1 or ($map_records[0] | type) != "array" then
  error("expected exactly one runtime mapping report")
else $map_records[0] end) as $records |
(if (($records | length) < 16 or ($records | length) > 2048 or
    any($records[]; (.stage | type) != "string" or
                    (.stage | IN("before_dlopen", "after_dlopen", "registered", "session_created", "after_run", "session_released", "unregistered", "after_dlclose") | not) or
                    (.kind | IN("package", "plugin", "host") | not) or
                    (.name | safe | not)) or
    ($records | unique | length) != ($records | length)) then
  error("untrusted, duplicate or incomplete runtime loader map")
else $records end) as $validated |
needed($original_needed) as $onnx_needed |
needed($plugin_needed) as $ep_needed |
(if (["before_dlopen", "after_dlopen", "registered", "session_created", "after_run", "session_released", "unregistered", "after_dlclose"] | all(.[]; . as $stage | any($validated[]; .stage == $stage))) | not then
  error("missing expected lifecycle snapshot")
else $validated end) as $live |
if ((mapped($live; "after_dlopen"; "package") | index("libonnxruntime.so")) == null or
    (mapped($live; "registered"; "plugin") | index("libvulpra-onnx-ci-ep.so")) == null or
    (mapped($live; "unregistered"; "plugin") | length) != 0 or
    (mapped($live; "after_dlclose"; "package") | length) != 0) then
  error("original ONNX or plugin lifecycle mismatch")
else . end |
(edges($onnx_needed; "libonnxruntime.so"; "after_dlopen"; $live) +
 edges($ep_needed; "libvulpra-onnx-ci-ep.so"; "registered"; $live)) as $direct |
(mapped($live; "before_dlopen"; "host")) as $baseline_host |
(mapped($live; "after_dlopen"; "host")) as $loaded_host |
(mapped($live; "after_dlclose"; "host")) as $remaining_host |
{
  schema_version:1,
  status:"original_onnx_ep_live_mapping_direct_needed_basename_crosswalk_pass",
  original_source_commit:$src,
  original_archive_sha256:$archive,
  compared_native_objects:["libonnxruntime.so", "libvulpra-onnx-ci-ep.so"],
  original_direct_needed_count:($onnx_needed|length),
  plugin_direct_needed_count:($ep_needed|length),
  direct_needed_entries:$direct,
  pre_dlopen_host_names:$baseline_host,
  mapped_host_after_dlopen:$loaded_host,
  newly_mapped_host_after_dlopen:($loaded_host - $baseline_host),
  host_resident_after_final_dlclose:$remaining_host,
  host_still_resident_after_final_dlclose_not_in_baseline:($remaining_host - $baseline_host),
  sampled_stage_count:8,
  static_direct_needed_names_matched_at_snapshot_by_basename:true,
  dlopen_transitive_and_lazy_graph_complete:false,
  runtime_dlsym_and_symbol_binding_proven:false,
  all_28_browser_elf_mapping_or_ffi_proven:false,
  platform_arch_wayland_coverage_proven:false,
  further_source_removal_authorized:false,
  native_bytes_saved:0,
  m3_sixth_gate_closed:false
}