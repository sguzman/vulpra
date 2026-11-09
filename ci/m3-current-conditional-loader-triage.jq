# Fail-closed, exact-source analysis of a *bounded direct loader-callsite*
# census from one real normal Vulpra libxul. Caller-symbol evidence only:
# the library argument, indirect calls, runtime activation and fallbacks are
# NOT established. The authentic native run/artifact origin is independently
# checked by the caller workflow before this filter executes.
def insist($ok;$reason): if $ok then true else error($reason) end;
def hex64: type=="string" and test("^[0-9a-f]{64}$");

insist(($link|length)==1 and ($loader|length)==1 and ($package|length)==1;
       "Exactly one native link, real compiled loader and package report required") |
$link[0] as $l | $loader[0] as $c | $package[0] as $p |
[
  {id:"ffmpeg_runtime_init", clue:"FFmpegRuntimeLinker4InitEv",api:"PR_LoadLibraryWithFlags",kind:"call",expected:1,
   gap:"Conditional FFmpeg codec selection, library failures and media fallback"},
  {id:"onnx_api",clue:"GetOrtAPIEv",api:"PR_LoadLibraryWithFlags",kind:"call",expected:1,
   gap:"ONNX runtime activation and absent-provider fallback"},
  {id:"llama_runtime",clue:"LlamaRuntimeLinker4InitEv",api:"PR_LoadLibraryWithFlags",kind:"call",expected:1,
   gap:"Llama runtime activation and unavailable-model/backend fallback"},
  {id:"drm_library",clue:"LoadDRMLibraryv",api:"PR_LoadLibrary",kind:"call",expected:1,
   gap:"Conditional DRM/graphics library availability and safe fallback"},
  {id:"gmp_child_preload",clue:"GMPChild15RecvPreloadLibs",api:"dlopen",kind:"call",expected:1,
   gap:"GMP child preload library allowlist and failure behavior"},
  {id:"gmp_loader",clue:"GMPLoader4Load",api:"PR_LoadLibraryWithFlags",kind:"call",expected:1,
   gap:"GMP plugin loading and unavailable/unsigned plugin behavior"},
  {id:"vaapi_loader",clue:"VALibWrapper13LinkVAAPILibs",api:"PR_LoadLibraryWithFlags",kind:"call",expected:2,
   gap:"VA-API discovery, GPU backend/driver alternatives and video fallback"},
  {id:"gbm_widget",clue:"GbmLib4Load",api:"dlopen",kind:"call",expected:2,
   gap:"GBM/Wayland device and loader fallback for missing libraries"},
  {id:"pulse_cubeb",clue:"cubeb_pulse7backend7context",api:"dlopen",kind:"call",expected:1,
   gap:"PulseAudio/PipeWire host-library availability and audio fallback"},
  {id:"gssapi_auth",clue:"nsAuthGSSAPIC1E5pType",api:"PR_LoadLibrary",kind:"call",expected:6,
   gap:"GSSAPI/Kerberos provider variants, nondefault auth paths and failure behavior"},
  {id:"gssapi_auth_flags",clue:"nsAuthGSSAPIC1E5pType",api:"PR_LoadLibraryWithFlags",kind:"call",expected:1,
   gap:"GSSAPI alternate loader flag/provider behavior"},
  {id:"libsecret_credentials",clue:"MaybeLoadLibSecretv",api:"PR_LoadLibrary",kind:"call",expected:1,
   gap:"Host credential-store presence, permissions and fallback"}
] as $specs |
[
  insist($l.schema_version==1 and $l.source_commit==$source and
      $l.workflow_run_id==$run and $l.native_build_required==true and
      $l.runtime_passed_after_link_audit==true and
      $l.linker_full_map_recorded==false and
      $l.source_removal_authorized==false and
      $l.packaging_transform_replay.deterministic_reproduction_verified==true and
      ($l.built_libxul_sha256|hex64) and
      ($l.package.package_sha256|hex64);
      "Source-pinned authentic full native build/runtime and package link input required"),
  insist($p.schema_version==1 and $p.source_commit==$source and
      $p.archive_sha256==$l.package.package_sha256 and
      ($p.elf_members|type)=="array" and ($p.elf_members|length)==28 and
      $p.direct_needed_edges==268 and $p.source_removal_authorized==false and
      $p.dlopen_and_indirect_runtime_dependencies_complete==false;
      "Source-pinned packaged 28-ELF dependency inventory mismatch"),
  insist($c.schema_version==1 and
      $c.status=="compiled_direct_loader_api_callsite_census" and
      $c.source_commit==$source and $c.binary=="libxul.so" and
      $c.unstripped_native_elf_sha256==$l.built_libxul_sha256 and
      ($c.unstripped_native_elf_sha256|hex64) and
      $c.unstripped_native_elf_bytes>10000000 and
      $c.native_instruction_lines>1000 and
      $c.direct_loader_branches==73 and
      $c.distinct_caller_loader_kind_records==47 and
      $c.independently_accepted_ffmpeg_to_nspr_call_count==1 and
      ($c.direct_loader_callsite_records|type)=="array" and
      ($c.direct_loader_callsite_records|length)==47 and
      ([ $c.direct_loader_callsite_records[].native_branches ]|add)==73 and
      ([ $c.direct_loader_callsite_records[] |
         [.caller_symbol,.loader_api,.branch_kind] | @json ]|unique|length)==47 and
      all($c.direct_loader_callsite_records[];
        (.caller_symbol|type)=="string" and (.caller_symbol|length)>0 and
        (.loader_api|IN("dlopen","dlmopen","PR_LoadLibrary","PR_LoadLibraryWithFlags","PR_LoadLibraryByPathname")) and
        (.branch_kind|IN("call","tail-jump")) and
        (.native_branches|type)=="number" and .native_branches>0) and
      $c.indirect_loader_calls_enumerated==false and
      $c.every_dynamic_loader_api_enumerated==false and
      $c.actual_dynamic_library_names_verified==false and
      $c.conditional_runtime_routes_exercised==false and
      $c.all_elf_consumers_covered==false and
      $c.arch_workstation_verified==false and
      $c.source_pruning_authorized==false and $c.m3_sixth_gate_closed==false;
      "Expected exact compiled 73/47 bounded loader census and conservative scope")
] | all as $baseline_ok |
(
  $specs | map(. as $spec |
    [ $c.direct_loader_callsite_records[] |
      select((.caller_symbol|contains($spec.clue)) and
             .loader_api==$spec.api and .branch_kind==$spec.kind)
    ] as $matches |
    insist(($matches|length)==1 and $matches[0].native_branches==$spec.expected;
           "Current native conditional loader witness missing or ambiguous: " + $spec.id) |
    {id:$spec.id,
     observed_compiled_caller:$matches[0].caller_symbol,
     loader_api:$spec.api,
     branch_kind:$spec.kind,
     observed_direct_branches:$spec.expected,
     next_protected_runtime_or_source_gap:$spec.gap,
     actual_requested_library_arg_verified:false,
     conditional_fallback_exercised:false,
     feature_safe_to_remove:false}
  )
) as $witnesses |
{
  schema_version:1,
  status:"source_linked_current_compiled_conditional_loader_callsite_gap_triage",
  native_source_commit:$source,
  native_run_id:$run,
  current_unstripped_libxul_sha256:$c.unstripped_native_elf_sha256,
  normal_package_sha256:$p.archive_sha256,
  authenticated_compiled_source_package_runtime_and_direct_loader_report_joined:$baseline_ok,
  scoped_compiled_direct_loader_branches:$c.direct_loader_branches,
  scoped_distinct_caller_api_kind_records:$c.distinct_caller_loader_kind_records,
  scoped_targeted_risk_witnesses:($witnesses|length),
  scoped_targeted_direct_branches:([$witnesses[].observed_direct_branches]|add),
  scoped_witnesses:$witnesses,
  indirect_loader_calls_enumerated:false,
  library_name_arguments_and_dlsym_targets_proven:false,
  all_caller_symbols_in_other_packaged_elfs_enumerated:false,
  alternative_runtime_feature_paths_exercised:false,
  platform_endeavouros_hyprland_parity_proven:false,
  full_dependency_ffi_and_feature_closure_proven:false,
  additional_source_pruning_authorized:false,
  m3_sixth_gate_closed:false,
  release_ready:false
}
