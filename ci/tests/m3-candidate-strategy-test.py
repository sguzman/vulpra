#!/usr/bin/env python3
"""Fail closed on contradictory bounded M3 candidate strategy decisions.

Reads already-pinned source and native evidence ledgers. A passing result
does not prove runtime reachability or safe source deletion.
"""
from __future__ import annotations
from copy import deepcopy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
EXPECTED={
 "gtk_and_webextensions":"keep",
 "windows_widget_installer":"remove_source",
 "macos_cocoa_widget":"remove_source",
 "android_mobile":"remove_source",
 "source_testing":"review",
 "sync_services":"keep",
 "firefox_accounts":"keep",
 "telemetry_internals":"keep",
 "normandy_and_healthreport":"conditional_compile",
 "devtools_client":"keep",
 "browser_genai":"review",
 "pocket_integration":"keep",
 "newtab_and_messaging":"review",
 "core_web_security":"keep",
 "remaining_mobile_platform_leaves":"remove_source",
 "newtab_adsfeed_optout":"conditional_compile",
 "newtab_promocard_optout":"conditional_compile",
 "localization_default_and_repack":"keep",
 "aiwindow_prompt_seed":"keep",
 "hungarian_hyphenation_patterns":"keep"
}

def validate(reg,paired,progress):
    names=[c["id"] for c in reg["candidates"]]
    assert len(names)==20 and len(set(names))==20
    assert set(names)==set(EXPECTED)
    counts={}
    for c in reg["candidates"]:
        s=c["m3_strategy"]
        strategy=s["strategy"]
        assert strategy==EXPECTED[c["id"]],c["id"]
        counts[strategy]=counts.get(strategy,0)+1
        assert isinstance(s["scope"],str) and len(s["scope"])>25
        assert isinstance(s["safety_and_fallback"],str) and len(s["safety_and_fallback"])>25
        assert s["broad_feature_removal_authorized"] is False
        assert s["guarded_opt_in_omission_accepted"] is (strategy=="conditional_compile")
        assert s["permanent_removal_accepted"] is (strategy=="remove_source")
        assert s["requires_further_source_or_runtime_verification"] is (
            strategy in ("conditional_compile","review"))
        assert c["evidence"] and c["paths"] and c["next"]
        if strategy=="remove_source":
            assert c["decision"].startswith("accepted_")
            assert c["source_files"]>0 and c["source_bytes"]>0
        if strategy=="conditional_compile":
            assert c["decision"].startswith("accepted_")
            assert strategy!="remove_source"
    control=reg["m3_decision_classification"]
    assert control["total_candidates"]==20
    assert counts==control["categories"]
    assert counts=={"keep":10,"remove_source":4,"review":3,"conditional_compile":3}
    assert control["complete_feature_dependency_inventory"] is False
    assert control["complete_candidate_fallback_validation"] is False
    assert control["whole_m3_gate_passed"] is False
    assert control["no_new_source_deletion"] is True
    assert control["no_normal_browser_feature_changed"] is True
    assert control["new_compiled_savings_bytes"] is None
    loader=reg["historical_native_loader_order_preflight"]
    assert loader["status"]=="verified_historical_physical_normal_package_order"
    assert loader["run_id"]==40936431756
    assert loader["dependentlibs_name_count"]==14
    assert loader["libmozgtk_before_libmozwayland"] is True
    assert loader["libxul_loaded_after_both"] is True
    assert loader["current_source_matched_native_loader_order_verified"] is False
    assert loader["source_deletion_authorized"] is False
    assert loader["compressed_feature_saving_bytes"] is None
    cache=reg["historical_native_host_cache_preflight"]
    assert cache["status"]=="accepted_bounded_ubuntu_host_elf_cache_presence_audit"
    assert cache["success_run_id"]==40947019427
    assert cache["evidence_artifact_id"]==12928349526
    assert cache["underlying_archive_original_native_run_id"]==40567473401
    assert cache["underlying_archive_compiled_source_commit"]=="1683ca67b69389a879717bcd537772c3b40624b6"
    assert (cache["original_archived_elf_members"],cache["original_archived_direct_needed_edges"])==(28,268)
    assert cache["unique_direct_needed_names"]==50
    assert cache["package_regular_library_name_matches"]==14
    assert cache["external_names_checked"]==36
    assert cache["ubuntu_24_04_x86_64_host_elf_cache_matches"]==36
    assert cache["no_host_cache_match_names"]==0
    assert cache["native_package_elf_executed"] is False
    assert cache["host_runtime_loader_searchpath_or_abi_resolution_proven"] is False
    assert cache["target_arch_linux_workstation_resolution_proven"] is False
    assert cache["transitive_and_dlopen_dependencies_closed"] is False
    assert cache["source_matched_to_current_main"] is False
    assert cache["compiled_feature_savings_bytes"] is None
    assert cache["source_deletion_authorized"] is False
    trans=reg["historical_native_host_transitive_map"]
    assert trans["status"]=="accepted_bounded_ubuntu_host_transitive_declared_ELF_file_presence"
    assert trans["success_run_id"]==40947712769
    assert trans["artifact_id"]==12930680277
    assert trans["source_package_compiled_commit"]=="1683ca67b69389a879717bcd537772c3b40624b6"
    assert trans["underlying_earlier_direct_host_preflight_run_id"]==40947019427
    assert (trans["external_root_names"],trans["host_unique_direct_and_transitive_names"],
            trans["host_to_host_direct_DT_NEEDED_edges"])==(36,76,246)
    assert trans["host_ELF_file_candidates"]==76
    assert trans["host_names_without_ldconfig_candidates"]==0
    assert (trans["host_cache_safety_fixtures"],trans["transitive_map_safety_fixtures"])==(11,6)
    for flag in ("package_ELF_executed","host_ELF_executed","ldd_dlopen_invoked",
                 "symbol_versions_or_actual_loader_resolution_verified",
                 "target_user_Arch_system_verified","source_deletion_authorized",
                 "whole_M3_gate_passed"):
        assert trans[flag] is False,flag
    assert trans["new_compiled_savings_bytes"] is None
    pending=reg["pending_current_source_link_input_acceptance"]
    assert pending["workflow_run_id"]==40935344279
    assert pending["source_commit"]=="3f9945cbdb4f6ea1bd75c3cf5127e58d72a9762f"
    assert pending["state"]=="normal_full_native_build_and_runtime_passed_but_independent_package_transform_reconciliation_unaccepted"
    assert pending["native_full_workflow_success"] is True
    assert pending["configure_and_compile_succeeded"] is True
    assert pending["package_and_loader_order_succeeded"] is True
    assert pending["Wayland_js_webextension_profile_nimbus_passed"] is True
    assert pending["native_evidence_artifact_id"]==12927213408
    assert pending["generated_link_input_objects"]==2435
    assert pending["archive_compressed_bytes"]==87147080
    assert pending["packaged_libxul_bytes"]==189486696
    assert pending["packaged_ELF_count"]==28 and pending["direct_DT_NEEDED_edges"]==268
    assert pending["raw_dist_libxul_hash_matches_packaged_libxul"] is False
    assert pending["reason_for_hash_difference_proven"] is False
    assert pending["reproduction_proof_present_in_original_artifact"] is False
    assert pending["independent_reconciliation_original_run_passed"] is False
    assert pending["followup_replay_workflow_accepted"] is False
    assert pending["followup_replay_workflow_run_id"]==40944392090
    assert "independently_reproduced_exact_source_mozpack_executable_transformation" in pending["requires"]
    assert pending["full_linker_symbol_map_claimed"] is False
    assert pending["compiled_feature_savings_established"] is False
    assert pending["broad_m3_gate_advanced"] is False
    source=reg["accepted_source_pruning_cohort_totals"]
    cohorts=source["cohorts"]
    assert len(cohorts)==3
    assert [x["removed_git_paths"] for x in cohorts]==[453,14134,280]
    assert [x["original_git_blob_bytes"] for x in cohorts]==[6266676,115996869,7704040]
    assert sum(x["removed_git_paths"] for x in cohorts)==source["aggregate_removed_git_paths"]==14867
    assert sum(x["original_git_blob_bytes"] for x in cohorts)==source["aggregate_original_git_blob_bytes"]==129967585
    assert source["candidate_fields_source_files_not_additive_as_pruned_totals"] is True
    assert source["compiled_package_bytes_saved"] is None
    assert source["new_pruning_authorized"] is False
    assert source["broader_m3_gate_advanced_by_this_accounting"] is False
    assert cohorts[0]["individually_allocatable_to_candidate_ids"] is False
    accepted={x["id"]:x for x in progress["milestones"][2]["verified_removals"]}
    assert accepted["linux-excluded-widget-installer-source"]["removed_paths"]==cohorts[0]["removed_git_paths"]
    assert accepted["linux-excluded-widget-installer-source"]["removed_git_blob_bytes"]==cohorts[0]["original_git_blob_bytes"]
    assert accepted["android-app-source-tree"]["removed_paths"]==cohorts[1]["removed_git_paths"]
    assert accepted["android-app-source-tree"]["removed_git_blob_bytes"]==cohorts[1]["original_git_blob_bytes"]

    ai,=(x for x in reg["candidates"] if x["id"]=="aiwindow_prompt_seed")
    assert ai["source_files"]==1 and ai["source_bytes"]==1577264
    assert ai["package_logical_bytes"]==1577264
    assert ai["source_files_removed"]==0
    assert ai["normal_browser_changed"] is False
    assert ai["removal_authorized"] is False
    assert ai["decision"]=="keep_default_offline_prompt_seed_verified_native_runtime"
    native_ai=ai["native_offline_prompt_runtime"]
    assert native_ai["status"]=="accepted_real_archived_native_browser_protected_default_seed"
    assert native_ai["success_run_id"]==40937489359
    assert native_ai["artifact_id"]==12925766713
    assert native_ai["critical_module_git_blobs_matched_current"] is True
    assert native_ai["all_browser_source_matched_to_current"] is False
    assert native_ai["nonlocal_connections_blocked"] is True
    assert native_ai["temporary_private_profile"] is True
    assert [native_ai[k] for k in ("seed_record_count","chat_params_record_count",
                                  "identity_record_count","response_rules_record_count")] == [214,21,1,5]
    assert all(native_ai[k] is True for k in (
        "synthetic_empty_records_rejected_promptLoadFailure",
        "synthetic_missing_identity_rejected_promptLoadFailure",
        "synthetic_missing_params_rejected_promptLoadFailure",
        "synthetic_complete_manifest_succeeded"))
    assert native_ai["real_ai_model_executed"] is False
    assert native_ai["remote_api_called"] is False
    assert native_ai["seed_omission_native_compiled_or_tested"] is False
    assert native_ai["replacement_offline_bootstrap_proven"] is False
    assert native_ai["normal_browser_changed"] is False
    assert native_ai["source_removal_authorized"] is False
    assert native_ai["compressed_savings_bytes"] is None
    assert reg["aiwindow_offline_seed_runtime"] == native_ai

    hu,=(x for x in reg["candidates"] if x["id"]=="hungarian_hyphenation_patterns")
    assert hu["package_logical_bytes"]==1048764
    assert hu["source_files_removed"]==0
    assert hu["normal_browser_changed"] is False
    assert hu["removal_authorized"] is False
    assert hu["decision"]=="keep_default_hungarian_hyphenation_verified_native_css"
    rendered=hu["native_css_evidence"]
    assert rendered["status"]=="accepted_hungarian_rendering_observed_full_normal_package"
    assert rendered["run_id"]==40938478049
    assert rendered["evidence_artifact_id"]==12925058497
    assert rendered["critical_hyphen_source_blobs_equal_current"] is True
    assert rendered["whole_browser_source_equal_current"] is False
    assert rendered["package_hu_pattern_present"] is True
    assert all(rendered[k] is True for k in (
        "hu_auto_wraps_more_than_none",
        "hu_auto_wraps_more_than_unknown_locale",
        "hu_HU_auto_wraps_more_than_none",
        "en_US_auto_wraps_more_than_none"))
    assert rendered["hu_pattern_omission_runtime_verified"] is False
    assert rendered["normal_browser_changed"] is False
    assert rendered["source_removal_authorized"] is False
    assert rendered["compressed_package_savings"] is None
    assert reg["hungarian_hyphenation_native_css"] == rendered
    hyph=reg["hungarian_hyphenation_boundary_audit"]
    assert hyph["source_only_passed"] is True and hyph["source_boundaries"]==6
    assert hyph["source_mutation_negatives"]==12
    assert hyph["hu_pattern_historical_logical_zip_bytes"]==1048764
    assert hyph["locale_layout_omission_runtime_checked"] is False
    assert hyph["compressed_savings_bytes"] is None
    assert hyph["normal_source_changed"] is False
    hu_native=hyph["historical_normal_native_css_runtime"]
    assert hu_native==hu["historical_normal_css_runtime"]
    assert hu_native["status"]=="passed_real_unmodified_historical_native_hu_huHU_enUS_css_layout"
    assert hu_native["run_id"]==40937941448
    assert hu_native["evidence_artifact_id"]==12924908962
    assert hu_native["archive_compiled_source_commit"]=="1683ca67b69389a879717bcd537772c3b40624b6"
    assert [hu_native[k] for k in ("hungarian_auto_lines","hungarian_huHU_auto_lines",
                                  "hungarian_none_lines","english_auto_lines",
                                  "english_none_lines")]==[6,6,1,3,1]
    assert hu_native["hungarian_none_overflow_px"]==524
    assert hu_native["hungarian_auto_scroll_width_px"]==112
    assert hu_native["original_package_unchanged"] is True
    assert hu_native["missing_hungarian_pattern_css_fallback_verified"] is False
    assert hu_native["optin_hungarian_pattern_omission_built"] is False
    assert hu_native["compressed_savings_bytes"] is None

    promo,=(x for x in reg["candidates"] if x["id"]=="newtab_promocard_optout")
    trial=promo["native_trial"]
    assert trial["source_commit"]==paired["source_commit"]
    assert trial["normal_run"]==paired["normal"]["workflow_run"]
    assert trial["lean_run"]==paired["optin"]["workflow_run"]
    assert trial["comparison_run"]==paired["comparison"]["replay_workflow_run"]
    assert trial["signed_full_minus_optin_archive_bytes"]==(
        paired["measurements"]["signed_full_minus_optin_compressed_archive_bytes"])
    assert trial["original_promocard_absent_in_optin"] is True
    assert trial["default_browser_changed"] is False
    assert trial["source_files_deleted"]==0
    assert trial["repeatability_established"] is False
    assert trial["component_specific_compressed_saving_established"] is False
    assert promo["normal_browser_changed"] is False
    assert promo["removal_authorized"] is False

    m3,=(m for m in progress["milestones"] if m["id"]=="M3")
    assert m3["acceptance_gates"]["passed"]==2
    assert m3["acceptance_gates"]["total"]==6
    assert m3["percent"]==33
    assert progress["overall"]["percent"]==44
    return counts

def negative_fixtures(reg,paired,progress):
    def change_strategy(reg,val):
        next(x for x in reg["candidates"] if x["id"]=="core_web_security")["m3_strategy"]["strategy"]=val
    def change_promo(reg,key,value):
        next(x for x in reg["candidates"] if x["id"]=="newtab_promocard_optout")["native_trial"][key]=value
    def change_remove(reg):
        next(x for x in reg["candidates"] if x["id"]=="android_mobile")["m3_strategy"]["permanent_removal_accepted"]=False
    mutations=[
        lambda a,b,c:change_strategy(a,"remove_source"),
        lambda a,b,c:change_strategy(a,"unknown"),
        lambda a,b,c:a["m3_decision_classification"]["categories"].update(keep=8),
        lambda a,b,c:a["m3_decision_classification"].update(whole_m3_gate_passed=True),
        lambda a,b,c:a["m3_decision_classification"].update(new_compiled_savings_bytes=6000000),
        lambda a,b,c:change_remove(a),
        lambda a,b,c:change_promo(a,"normal_run",1),
        lambda a,b,c:change_promo(a,"signed_full_minus_optin_archive_bytes",99999),
        lambda a,b,c:change_promo(a,"default_browser_changed",True),
        lambda a,b,c:change_promo(a,"repeatability_established",True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="localization_default_and_repack")["m3_strategy"].update(guarded_opt_in_omission_accepted=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="source_testing")["m3_strategy"].update(safety_and_fallback=""),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="newtab_adsfeed_optout")["m3_strategy"].update(permanent_removal_accepted=True),
        lambda a,b,c:c["milestones"][2]["acceptance_gates"].update(passed=3),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="aiwindow_prompt_seed").update(removal_authorized=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="aiwindow_prompt_seed").update(package_logical_bytes=0),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="aiwindow_prompt_seed")["native_offline_prompt_runtime"].update(seed_record_count=0),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="aiwindow_prompt_seed")["native_offline_prompt_runtime"].update(seed_omission_native_compiled_or_tested=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="aiwindow_prompt_seed")["native_offline_prompt_runtime"].update(remote_api_called=True),
        lambda a,b,c:a["accepted_source_pruning_cohort_totals"].update(aggregate_removed_git_paths=16182),
        lambda a,b,c:a["accepted_source_pruning_cohort_totals"]["cohorts"][1].update(removed_git_paths=15441),
        lambda a,b,c:a["accepted_source_pruning_cohort_totals"].update(candidate_fields_source_files_not_additive_as_pruned_totals=False),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns").update(removal_authorized=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns").update(package_logical_bytes=0),
        lambda a,b,c:a["hungarian_hyphenation_boundary_audit"].update(locale_layout_omission_runtime_checked=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns")["native_css_evidence"].update(hu_auto_wraps_more_than_unknown_locale=False),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns")["native_css_evidence"].update(hu_pattern_omission_runtime_verified=True),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns")["native_css_evidence"].update(compressed_package_savings=1048764),
        lambda a,b,c:next(x for x in a["candidates"] if x["id"]=="hungarian_hyphenation_patterns")["historical_normal_css_runtime"].update(missing_hungarian_pattern_css_fallback_verified=True),
        lambda a,b,c:a["hungarian_hyphenation_boundary_audit"]["historical_normal_native_css_runtime"].update(hu_missing_dictionary_native_variant=True),

        lambda a,b,c:a["historical_native_loader_order_preflight"].update(libmozgtk_before_libmozwayland=False),
        lambda a,b,c:a["historical_native_host_cache_preflight"].update(host_runtime_loader_searchpath_or_abi_resolution_proven=True),
        lambda a,b,c:a["historical_native_host_cache_preflight"].update(target_arch_linux_workstation_resolution_proven=True),
        lambda a,b,c:a["historical_native_host_cache_preflight"].update(transitive_and_dlopen_dependencies_closed=True),
        lambda a,b,c:a["historical_native_host_cache_preflight"].update(external_names_checked=35),
        lambda a,b,c:a["historical_native_host_cache_preflight"].update(source_deletion_authorized=True),
        lambda a,b,c:a["historical_native_host_transitive_map"].update(host_ELF_file_candidates=75),
        lambda a,b,c:a["historical_native_host_transitive_map"].update(symbol_versions_or_actual_loader_resolution_verified=True),
        lambda a,b,c:a["historical_native_host_transitive_map"].update(target_user_Arch_system_verified=True),
        lambda a,b,c:a["historical_native_host_transitive_map"].update(ldd_dlopen_invoked=True),
        lambda a,b,c:a["historical_native_host_transitive_map"].update(whole_M3_gate_passed=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(broad_m3_gate_advanced=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(full_linker_symbol_map_claimed=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(independent_reconciliation_original_run_passed=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(reproduction_proof_present_in_original_artifact=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(reason_for_hash_difference_proven=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(generated_link_input_objects=0),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(followup_replay_workflow_accepted=True),
    ]
    for index,mutate in enumerate(mutations,1):
        a,b,c=deepcopy(reg),deepcopy(paired),deepcopy(progress)
        mutate(a,b,c)
        try:validate(a,b,c)
        except (AssertionError,ValueError,KeyError,TypeError):
            continue
        raise AssertionError(f"Contradictory M3 strategy accepted: mutation case {index}")
    return len(mutations)

def main():
    docs=ROOT/"docs/vulpra"
    reg=json.loads((docs/"DEBLOAT-CANDIDATES.json").read_text())
    paired=json.loads((docs/"M3-PROMOCARD-NATIVE-PAIR.json").read_text())
    prog=json.loads((docs/"PROGRESS.json").read_text())
    counts=validate(reg,paired,prog)
    negative=negative_fixtures(reg,paired,prog)
    print("PASS: 20 bounded M3 strategies reconciled:",counts)
    print(f"PASS: {negative} contradictory classifications/evidence mutants rejected")
    print("READ-ONLY LEDGER: no new source removal, runtime, linker or size claim")

if __name__=="__main__":
    main()
