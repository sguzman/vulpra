# M3 fail-closed scoped removal-classification policy.
# Execute: jq -e -f ci/m3-candidate-decision-contract.jq docs/vulpra/DEBLOAT-CANDIDATES.json
#
# Exactly 20 historically scoped candidates are a baseline, NOT a complete
# dependency closure. Reject unsafe reclassification, fake broad authorization
# and inflated permanent-source-removal totals.
def require($condition; $reason):
  if $condition then . else error("M3 candidate policy: " + $reason) end;
def nonempty:
  type=="string" and length>0;
def expected:
  {
    "keep": [
      "gtk_and_webextensions",
      "sync_services",
      "firefox_accounts",
      "telemetry_internals",
      "devtools_client",
      "pocket_integration",
      "browser_genai",
      "core_web_security",
      "localization_default_and_repack",
      "aiwindow_prompt_seed",
      "hungarian_hyphenation_patterns"
    ],
    "remove_source": [
      "windows_widget_installer",
      "macos_cocoa_widget",
      "android_mobile",
      "remaining_mobile_platform_leaves"
    ],
    "review": ["source_testing","newtab_and_messaging"],
    "conditional_compile": [
      "normandy_and_healthreport",
      "newtab_adsfeed_optout",
      "newtab_promocard_optout"
    ]
  };
def valid_candidate:
  . as $c
  | require(($c.id|nonempty); "missing candidate ID")
  | require(($c.m3_strategy|type)=="object"; "missing strategy for " + $c.id)
  | require(($c.m3_strategy.strategy|nonempty); "missing class for " + $c.id)
  | require(($c.m3_strategy.scope|nonempty); "missing scope for " + $c.id)
  | require(($c.m3_strategy.safety_and_fallback|nonempty); "missing fallback for " + $c.id)
  | require(($c.m3_strategy.provenance|nonempty); "missing provenance for " + $c.id)
  | require(($c.evidence|type)=="array" and ($c.evidence|length)>0;
    "missing source/runtime evidence for " + $c.id)
  | require(($c.evidence|all(nonempty)); "blank evidence for " + $c.id)
  | require(($c.m3_strategy.broad_feature_removal_authorized|type)=="boolean"
    and $c.m3_strategy.broad_feature_removal_authorized==false;
    "unsafe broad feature deletion for " + $c.id)
  | require(($c.m3_strategy.permanent_removal_accepted|type)=="boolean";
    "missing permanent-source-removal flag for " + $c.id)
  | require(($c.m3_strategy.guarded_opt_in_omission_accepted|type)=="boolean";
    "missing opt-in omission flag for " + $c.id)
  | require(($c.m3_strategy.requires_further_source_or_runtime_verification|type)=="boolean";
    "missing verification requirement for " + $c.id)
  | (expected as $e
     | require(($c.m3_strategy.strategy|IN("keep","remove_source","review","conditional_compile"));
       "unknown class for " + $c.id)
     | require(($e[$c.m3_strategy.strategy]|index($c.id))!=null;
       "unapproved reclassification for " + $c.id))
  | if $c.m3_strategy.strategy=="keep" then
      require($c.m3_strategy.permanent_removal_accepted==false and
              $c.m3_strategy.guarded_opt_in_omission_accepted==false;
        "protected keep scope marked removable: " + $c.id)
    elif $c.m3_strategy.strategy=="review" then
      require($c.m3_strategy.permanent_removal_accepted==false and
              $c.m3_strategy.guarded_opt_in_omission_accepted==false and
              $c.m3_strategy.requires_further_source_or_runtime_verification==true;
        "unreviewed scope marked as accepted: " + $c.id)
    elif $c.m3_strategy.strategy=="conditional_compile" then
      require($c.m3_strategy.permanent_removal_accepted==false and
              $c.m3_strategy.guarded_opt_in_omission_accepted==true and
              $c.m3_strategy.requires_further_source_or_runtime_verification==true;
        "conditional omit reclassified as permanent: " + $c.id)
    else
      require($c.m3_strategy.permanent_removal_accepted==true and
              $c.m3_strategy.guarded_opt_in_omission_accepted==false and
              $c.m3_strategy.requires_further_source_or_runtime_verification==false;
        "historical accepted prune not correctly bounded: " + $c.id)
    end;
. as $ledger
| require($ledger.schema_version==1 and $ledger.project=="Vulpra" and $ledger.phase=="M3";
  "wrong project/phase/schema")
| require(($ledger.candidates|type)=="array" and ($ledger.candidates|length)==20;
  "candidate baseline is missing or expanded without review")
| require(($ledger.candidates|map(.id)|unique|length)==20;
  "duplicate candidate identifier")
| ($ledger.candidates|map(valid_candidate)) as $c
| (expected as $e
   | reduce (["keep","remove_source","review","conditional_compile"][]) as $kind
       (.;
        require(($c|map(select(.m3_strategy.strategy==$kind))|map(.id)|sort)
          ==($e[$kind]|sort); "candidate scope coverage differs: " + $kind)))
| ($ledger.m3_decision_classification) as $summary
| require($summary.total_candidates==20 and $summary.whole_m3_gate_passed==false
    and $summary.complete_feature_dependency_inventory==false
    and $summary.complete_candidate_fallback_validation==false;
    "false broad M3 classification gate")
| require($summary.categories=={
    "keep":11,"remove_source":4,"review":2,"conditional_compile":3
  }; "classification summary contradicts scoped inventory")
| require($summary.no_new_source_deletion==true and
    $summary.no_normal_browser_feature_changed==true and
    $summary.new_compiled_savings_bytes==null;
    "invented new source/normal-feature removal or saving")
| ($ledger.accepted_source_pruning_cohort_totals) as $prune
| require(($prune.cohorts|type)=="array" and ($prune.cohorts|length)==3;
    "missing distinct source-prune cohorts")
| require(($prune.cohorts|map(.id))==[
    "windows_and_cocoa_widget_installer_combined",
    "android_application_roots",
    "extra_android_ios_uikit_leaves"
  ]; "unexpected source-prune cohort identities")
| require(($prune.cohorts|map(.removed_git_paths))==[453,14134,280] and
    ($prune.cohorts|map(.original_git_blob_bytes))==[6266676,115996869,7704040];
    "verified historical source-prune cohort counts changed")
| require($prune.aggregate_removed_git_paths==14867 and
    $prune.aggregate_original_git_blob_bytes==129967585 and
    $prune.aggregate_removed_git_paths==($prune.cohorts|map(.removed_git_paths)|add) and
    $prune.aggregate_original_git_blob_bytes==($prune.cohorts|map(.original_git_blob_bytes)|add);
    "source-only pruning totals exaggerated")
| require($prune.candidate_fields_source_files_not_additive_as_pruned_totals==true and
    $prune.compiled_package_bytes_saved==null and
    $prune.native_library_removed==false and
    $prune.new_pruning_authorized==false and
    $prune.broader_m3_gate_advanced_by_this_accounting==false;
    "source-only metrics falsely treated as binary saving or new M3 gate")
| {
    schema_version:1,
    status:"scoped_candidate_policy_guard_passed",
    candidates_checked:($c|length),
    classes:$summary.categories,
    verified_distinct_pruned_source_paths:$prune.aggregate_removed_git_paths,
    verified_distinct_pruned_git_blob_bytes:$prune.aggregate_original_git_blob_bytes,
    incomplete_dependencies_preserved:true,
    default_browser_changed:false,
    new_source_deletion_authorized:false,
    new_compiled_savings_claimed:false,
    new_whole_M3_gate_passed:false,
    exact_source_or_binary_runtime_proven_by_this_check:false,
    scope:"source-guardrail for already classified candidate ledger, not independent native build or full caller graph"
  }
