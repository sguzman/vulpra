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
    assert pending["state"]=="first_normal_native_build_and_runtime_passed_packager_replay_retry_unaccepted"
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
    assert pending["followup_replay_workflow_completed"] is True
    assert pending["followup_replay_workflow_conclusion"]=="failure"
    assert pending["followup_replay_full_compile_and_package_succeeded"] is True
    assert pending["followup_replay_error_text"]=="Missing or implausibly sized native libxul.so"
    assert pending["followup_replay_failure_exact_missing_or_oversize_unidentified"] is True
    assert pending["followup_replay_raw_libxul_size_known"] is False
    assert pending["followup_replay_oversize_cause_proven"] is False
    assert pending["next_evidence_replay_workflow_run_id"]==40952352531
    assert pending["next_evidence_replay_workflow_result"]=="in_progress_not_accepted_at_last_observation"
    assert pending["next_evidence_replay_checks_input_path_sizes"] is True
    assert pending["next_evidence_replay_verification_accepted"] is False
    assert pending["schema_compatibility_probe_run_id"]==40953419796
    assert pending["schema_compatibility_source_native_run_id"]==40935344279
    assert pending["schema_compatibility_probe_status"]=="passed_test_only_real_evidence_schema_with_unverified_in_memory_packager_record"
    assert pending["schema_compatibility_used_synthetic_transform_only"] is True
    for k in ("schema_compatibility_synthetic_report_persisted",
              "schema_compatibility_proves_real_packager_transform",
              "schema_compatibility_accepted_as_native_runtime_evidence",
              "schema_compatibility_new_gate_credit"):
        assert pending[k] is False,k
    assert "independently_reproduced_exact_source_mozpack_executable_transformation" in pending["requires"]
    assert pending["full_linker_symbol_map_claimed"] is False
    assert pending["compiled_feature_savings_established"] is False
    assert pending["broad_m3_gate_advanced"] is False
    # The first/second/third failed or incomplete native evidence remains
    # historical. Accept only the separately pinned fourth full native run.
    assert pending["historical_scope_only"] is True
    assert pending["superseded_by_accepted_native_run_id"]==40963098075
    accepted=reg["accepted_current_source_native_link_runtime_evidence"]
    assert accepted["source_commit"]=="cde4d83043f8c476173c8dbc78b66b078c3f6b5b"
    assert accepted["original_full_native_run_id"]==40963098075
    assert accepted["source_native_artifact_id"]==12938864326
    assert accepted["separate_reconciliation_run_id"]==40969046569
    assert accepted["reconciliation_artifact_id"]==12939456325
    assert accepted["status"]=="passed_full_native_evidence_reconciliation"
    assert accepted["original_native_run_conclusion"]=="success"
    for flag in ("independent_reconciliation_passed","compiler_and_packaging_succeeded",
                 "matched_reproducible_mozpack_copy",
                 "staged_shipped_and_reproduced_libxul_sha256_identical",
                 "configured_strip_enabled","verified_libmozgtk_precedes_libmozwayland",
                 "private_weston_wayland_js_webextension_profile_nimbus_passed"):
        assert accepted[flag] is True,flag
    for flag in ("compiled_raw_library_equals_staged_library","configured_elfhack_enabled",
                 "complete_resolved_linker_symbol_map","host_transitive_and_dlopen_dependencies_closed",
                 "compiled_per_feature_byte_attribution","current_head_binary_after_future_commits_proven",
                 "full_vs_lean_feature_omission_pair_from_this_run",
                 "additional_source_removal_authorized","whole_m3_gate_advanced"):
        assert accepted[flag] is False,flag
    assert accepted["new_compiled_savings_bytes"] is None
    assert accepted["source_original_libxul_sha256"]=="0ec00c074bd7b846e6b0bd621f43b92f49c3dc4ce9bff8b1c020e6a3d0521eb4"
    assert accepted["packaged_libxul_sha256"]=="a6139ee9ec4d0d8df7bec6b89bab6c41c553703842486ddfe773a1acc50a76c2"
    assert accepted["package_sha256"]=="18798900c5307fd136f7d93db6681741616981b609741a4b2209a1810273eb51"
    assert accepted["linker_response_sha256"]=="3e1926f4674246622013393366071c80ca2b492afc15463e4a92eb17e1746126"
    assert (accepted["package_compressed_bytes"],accepted["packaged_libxul_bytes"],
            accepted["linker_response_object_inputs"])==(87154700,189486696,2435)
    assert (accepted["regular_packaged_elf_members"],accepted["packaged_direct_dt_needed_edges"],
            accepted["external_direct_needs_names"])==(28,268,36)
    assert accepted["packaging_method"]=="mozpack.files.ExecutableFile.copy"

    drift=reg["accepted_current_source_elf_import_stability"]
    assert drift["status"]=="verified_two_sha256_pinned_native_ELF_direct_import_graphs"
    assert drift["run_id"]==40973033976 and drift["evidence_artifact_id"]==12939844976
    assert drift["historical_archive_sha256"]=="e8717fd10a1ffc330ef96f802a4112da335aaf57c6e68d70e639b3e137c9e97f"
    assert drift["current_archive_sha256"]==accepted["package_sha256"]
    assert drift["historical_compiler_commit_declared_in_elf_graph"] is None
    assert drift["current_source_commit"]==accepted["source_commit"]
    assert (drift["historical_archive_compressed_bytes"],drift["current_archive_compressed_bytes"])==(86930792,87154700)
    assert (drift["historical_ELF_member_count"],drift["current_ELF_member_count"])==(28,28)
    assert (drift["historical_direct_needed_edges"],drift["current_direct_needed_edges"])==(268,268)
    assert (drift["missing_or_added_packaged_ELF_member_paths"],
            drift["changed_per_file_sonames_or_dt_needed"])==(0,0)
    assert drift["differing_ELF_payload_sha256_count"]==6
    assert drift["byte_identical_ELF_payload_sha256_count"]==22
    assert len(drift["different_payload_members"])==6
    assert drift["source_checksum_proven_for_both_archives"] is True
    assert drift["original_native_runtime_independently_accepted"] is True
    for flag in ("host_loader_searchpaths_or_symbol_versions_proven",
                 "binary_semantics_equal_proven",
                 "different_source_archive_size_difference_is_feature_savings",
                 "new_source_pruning_authorized","whole_m3_gate_advanced"):
        assert drift[flag] is False,flag

    repeat=reg["accepted_normandy_second_matched_native_recheck"]
    assert repeat["status"]=="same_source_opt_in_normandy_runner_omission_runtime_and_comparison_passed"
    assert repeat["source_commit"]=="034ddd665a080f173ce45094ae3afb8868b45e1a"
    assert (repeat["lean_native_build_run_id"],repeat["separate_runtime_acceptance_run_id"],
            repeat["source_matched_full_compile_and_compare_run_id"],
            repeat["comparison_artifact_id"])==(40954193793,40968542013,40968688858,12941182844)
    for flag in ("variant_runtime_passed","source_and_non_omission_flags_matched",
                 "full_native_build_package_verified","normal_default_browser_unchanged",
                 "shared_nimbus_helpers_preserved","optin_runner_physically_absent"):
        assert repeat[flag] is True,flag
    assert (repeat["new_full_compressed_bytes"],repeat["new_lean_compressed_bytes"],
            repeat["new_signed_delta_bytes"])==(87153852,87138100,15752)
    assert repeat["new_full_compressed_bytes"]-repeat["new_lean_compressed_bytes"]==repeat["new_signed_delta_bytes"]
    assert repeat["new_observed_reduction_percent"]==0.018
    assert repeat["new_full_sha256"]=="4f51ccf82103dd0381702cf925bf0d786a559037f7ecb0633e045e591f9d633e"
    assert repeat["new_lean_sha256"]=="7095a57083a6211177fd182a2c5275d0ef8c8b2398f4eb1b3298ae951861adac"
    assert repeat["earlier_independent_source_matched_run_id"]==40439793884
    assert repeat["earlier_independent_observed_signed_delta_bytes"]==27620
    for flag in ("identical_build_source_across_the_two_experiments",
                 "constant_component_compressed_savings_proven",
                 "can_add_these_two_experiments_savings",
                 "additional_source_deletion_authorized","new_whole_m3_roadmap_gate_passed"):
        assert repeat[flag] is False,flag

    third=reg["accepted_normandy_third_matched_native_recheck"]
    assert third["status"]=="source_matched_third_normandy_optin_native_runtime_and_package_comparison_passed"
    assert third["source_commit"]=="ad0dea4a317cfe5f22213f6dc778366c6dc042d0"
    assert (third["lean_native_run_id"],third["independent_candidate_runtime_run_id"],
            third["matched_full_native_comparison_run_id"],third["evidence_artifact_id"]) == (
                40954395174,40976502356,40976632873,12943929109)
    assert (third["full_compressed_bytes"],third["lean_compressed_bytes"],
            third["signed_observed_compressed_reduction_bytes"]) == (87151648,87134296,17352)
    assert third["full_compressed_bytes"]-third["lean_compressed_bytes"] == third["signed_observed_compressed_reduction_bytes"]
    assert (third["full_regular_logical_bytes"],third["lean_regular_logical_bytes"]) == (339566140,339456251)
    assert third["observed_reduction_percent_rounded"] == 0.02
    assert third["full_archive_sha256"]=="ce033a97e72a673d6f174e82ba93a163ac39b8357428b5261c07da6b76376980"
    assert third["lean_archive_sha256"]=="ca8f3495da6122dec7a7715459534605da7d9270375b3114c4c7bf06cfeff729"
    assert third["earlier_independent_pairs_signed_observed_deltas_bytes"] == [27620,15752]
    for flag in ("source_and_protected_non_omission_flags_matched","native_full_and_lean_builds_passed",
                 "independent_real_browser_runtime_passed","normandy_runner_absent_only_in_lean",
                 "shared_nimbus_helpers_preserved","default_browser_unchanged"):
        assert third[flag] is True,flag
    for flag in ("three_experiments_same_source","constant_or_intrinsic_component_savings_proven",
                 "can_add_independent_trial_savings","general_feature_dependency_coverage_complete",
                 "additional_source_deletion_authorized","new_m3_gate_credit"):
        assert third[flag] is False,flag
    assert third["documentation"]=="docs/vulpra/M3-NORMANDY-NATIVE-RECHECK-20261030.md"

    cross=reg["accepted_m3_protected_source_crosscheck"]
    assert cross["status"]=="passed_source_pinned_four_subsystem_protected_boundary_crosscheck"
    assert cross["run_id"]==40982290720
    assert cross["source_commit"]=="010d4b7e847f3a0cd0bb69d20b17db59108120ae"
    assert cross["evidence_artifact_id"]==12945352163
    assert cross["independent_audit_boundary_counts"]=={
        "pocket":5,"sync":7,"telemetry":6,"deletion":6
    }
    assert cross["protected_source_boundaries_total"]==sum(
        cross["independent_audit_boundary_counts"].values())==24
    assert cross["explicitly_joined_high_impact_risks"]==5
    assert cross["synthetic_false_claim_rejection_cases"]==13
    for flag in ("all_source_audits_same_commit",
                 "script_does_not_execute_browser",
                 "protected_pocket_and_sync_interfaces_preserved",
                 "user_upload_deletion_path_source_anchors_preserved"):
        assert cross[flag] is True,flag
    for flag in ("normal_browser_source_modified",
                 "actual_runtime_callgraph_complete",
                 "actual_network_submission_privacy_proven",
                 "source_deletion_authorized",
                 "new_m3_roadmap_gate_passed"):
        assert cross[flag] is False,flag
    assert cross["new_compiled_savings_bytes"] is None
    assert cross["documentation"]=="docs/vulpra/M3-PROTECTED-SOURCE-CROSSCHECK-20261030.md"

    physical=reg["accepted_normandy_first_pair_physical_payload"]
    assert physical["status"]=="real_two_native_archive_tar_and_omni_payload_sha256_diff_passed"
    assert physical["matching_original_source_commit"]=="674db8e385c36aec23e78bbe059b2a1fec194fae"
    assert (physical["original_full_native_run_id"],physical["original_optin_native_run_id"],
            physical["original_candidate_runtime_run_id"]) == (40431769117,40431768974,40439671494)
    assert (physical["physical_payload_diff_run_id"],physical["stricter_only_normandy_remove_guard_run_id"],
            physical["physical_payload_artifact_id"])==(40983063003,40983193150,12945337486)
    assert physical["full_archive_sha256"]=="47c8ac5ce90747c051eac8daf24544d88767fdeb989293c0b50c5e8ac9e53c30"
    assert physical["lean_archive_sha256"]=="4888a1955883406f64a48cca6eedd28e359d0583596e68ec23f3d7280c165062"
    assert (physical["full_compressed_bytes"],physical["lean_compressed_bytes"],
            physical["signed_observed_compressed_delta_bytes"])==(86937548,86909928,27620)
    assert (physical["full_regular_logical_bytes"],physical["lean_regular_logical_bytes"],
            physical["observed_regular_file_net_logical_delta_bytes"])==(339564498,339454609,109889)
    assert physical["full_regular_logical_bytes"]-physical["lean_regular_logical_bytes"] == physical["observed_regular_file_net_logical_delta_bytes"]
    assert (physical["full_tar_members_including_directories"],physical["lean_tar_members_including_directories"])==(58,58)
    assert (physical["tar_file_paths_added"],physical["tar_file_paths_removed"])==(0,0)
    assert (physical["tar_file_payloads_sha256_changed"],physical["tar_file_payloads_sha256_identical"])==(13,34)
    assert (physical["embedded_omni_resources_removed"],physical["embedded_omni_resources_added"],
            physical["embedded_omni_resources_changed"],
            physical["embedded_omni_resources_sha256_identical"])==(22,1,5,7974)
    assert physical["sole_added_inner_resource"]=="vulpra/omni.ja::moz-src/toolkit/components/nimbus/NimbusBootstrap.sys.mjs"
    for flag in ("all_removed_inner_resources_namespaced_under_normandy",
                 "shared_nimbus_helpers_retained","some_native_elf_payloads_differ"):
        assert physical[flag] is True,flag
    for flag in ("package_payloads_bit_identical","equal_native_runtime_semantics_proven",
                 "causal_archive_bytes_per_feature_proven","source_removal_authorized",
                 "new_m3_roadmap_gate_passed"):
        assert physical[flag] is False,flag
    variance=reg["accepted_normandy_three_pair_variance"]
    assert variance["success_run_id"]==40983703521
    assert variance["strict_schema_followup_run_id"]==40983784911
    assert variance["strict_followup_artifact_id"]==12946415710
    assert variance["status"]=="three_source_distinct_native_pairs_reconciled_under_corrected_non_additive_schema"
    assert variance["artifact_id"]==12945423159
    assert variance["original_pair_comparison_runs"]==[40439793884,40968688858,40976632873]
    assert variance["original_package_candidate_runtime_runs"]==[40439671494,40968542013,40976502356]
    assert variance["source_commits"]==[
        "674db8e385c36aec23e78bbe059b2a1fec194fae",
        "034ddd665a080f173ce45094ae3afb8868b45e1a",
        "ad0dea4a317cfe5f22213f6dc778366c6dc042d0"]
    assert variance["observed_compressed_deltas_bytes"]==[27620,15752,17352]
    assert variance["net_regular_file_logical_deltas_bytes"]==[109889,109889,109889]
    assert variance["test_cases_rejecting_false_source_hash_and_arithmetic"]==10
    assert variance["net_regular_logical_difference_invariant_for_these_three_trials"] is True
    for flag in ("same_source_revision_across_three_trials","compressed_archive_delta_invariant",
                 "native_package_executed_or_recompiled_by_reconciliation",
                 "compressed_omission_savings_additive","causal_component_bytes_proven",
                 "causal_future_size_savings_guaranteed","source_removal_authorized",
                 "new_m3_roadmap_gate_passed"):
        assert variance[flag] is False,flag

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
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(followup_replay_oversize_cause_proven=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(next_evidence_replay_verification_accepted=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(followup_replay_workflow_conclusion="success"),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(schema_compatibility_accepted_as_native_runtime_evidence=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(schema_compatibility_proves_real_packager_transform=True),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(schema_compatibility_new_gate_credit=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(independent_reconciliation_passed=False),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(compiled_raw_library_equals_staged_library=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(whole_m3_gate_advanced=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(complete_resolved_linker_symbol_map=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(host_transitive_and_dlopen_dependencies_closed=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(full_vs_lean_feature_omission_pair_from_this_run=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(additional_source_removal_authorized=True),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(new_compiled_savings_bytes=100),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(package_sha256="f"*64),
        lambda a,b,c:a["accepted_current_source_native_link_runtime_evidence"].update(original_full_native_run_id=40944392090),
        lambda a,b,c:a["pending_current_source_link_input_acceptance"].update(historical_scope_only=False),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(changed_per_file_sonames_or_dt_needed=1),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(missing_or_added_packaged_ELF_member_paths=1),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(binary_semantics_equal_proven=True),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(host_loader_searchpaths_or_symbol_versions_proven=True),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(different_source_archive_size_difference_is_feature_savings=True),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(historical_compiler_commit_declared_in_elf_graph="a"*40),
        lambda a,b,c:a["accepted_current_source_elf_import_stability"].update(differing_ELF_payload_sha256_count=0),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(variant_runtime_passed=False),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(source_and_non_omission_flags_matched=False),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(new_signed_delta_bytes=27620),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(new_whole_m3_roadmap_gate_passed=True),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(constant_component_compressed_savings_proven=True),
        lambda a,b,c:a["accepted_normandy_second_matched_native_recheck"].update(can_add_these_two_experiments_savings=True),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(new_m3_gate_credit=True),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(three_experiments_same_source=True),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(signed_observed_compressed_reduction_bytes=27620),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(full_compressed_bytes=87151647),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(independent_real_browser_runtime_passed=False),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(general_feature_dependency_coverage_complete=True),
        lambda a,b,c:a["accepted_normandy_third_matched_native_recheck"].update(can_add_independent_trial_savings=True),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(new_m3_roadmap_gate_passed=True),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(actual_runtime_callgraph_complete=True),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(actual_network_submission_privacy_proven=True),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(source_deletion_authorized=True),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(protected_source_boundaries_total=23),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(all_source_audits_same_commit=False),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(new_compiled_savings_bytes=1),
        lambda a,b,c:a["accepted_m3_protected_source_crosscheck"].update(source_commit="0"*40),
        lambda a,b,c:a["accepted_normandy_first_pair_physical_payload"].update(embedded_omni_resources_removed=23),
        lambda a,b,c:a["accepted_normandy_first_pair_physical_payload"].update(tar_file_payloads_sha256_changed=0),
        lambda a,b,c:a["accepted_normandy_first_pair_physical_payload"].update(all_removed_inner_resources_namespaced_under_normandy=False),
        lambda a,b,c:a["accepted_normandy_first_pair_physical_payload"].update(causal_archive_bytes_per_feature_proven=True),
        lambda a,b,c:a["accepted_normandy_first_pair_physical_payload"].update(source_removal_authorized=True),
        lambda a,b,c:a["accepted_normandy_three_pair_variance"].update(observed_compressed_deltas_bytes=[27620,27620,27620]),
        lambda a,b,c:a["accepted_normandy_three_pair_variance"].update(net_regular_file_logical_deltas_bytes=[0,0,0]),
        lambda a,b,c:a["accepted_normandy_three_pair_variance"].update(causal_component_bytes_proven=True),
        lambda a,b,c:a["accepted_normandy_three_pair_variance"].update(new_m3_roadmap_gate_passed=True),
        lambda a,b,c:a["accepted_normandy_three_pair_variance"].update(strict_schema_followup_run_id=None),
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
