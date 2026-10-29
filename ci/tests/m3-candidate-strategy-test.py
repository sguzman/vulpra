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
 "aiwindow_prompt_seed":"review"
}

def validate(reg,paired,progress):
    names=[c["id"] for c in reg["candidates"]]
    assert len(names)==19 and len(set(names))==19
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
    assert control["total_candidates"]==19
    assert counts==control["categories"]
    assert counts=={"keep":8,"remove_source":4,"review":4,"conditional_compile":3}
    assert control["complete_feature_dependency_inventory"] is False
    assert control["complete_candidate_fallback_validation"] is False
    assert control["whole_m3_gate_passed"] is False
    assert control["no_new_source_deletion"] is True
    assert control["no_normal_browser_feature_changed"] is True
    assert control["new_compiled_savings_bytes"] is None

    ai,=(x for x in reg["candidates"] if x["id"]=="aiwindow_prompt_seed")
    assert ai["source_files"]==1 and ai["source_bytes"]==1577264
    assert ai["package_logical_bytes"]==1577264
    assert ai["source_files_removed"]==0
    assert ai["normal_browser_changed"] is False
    assert ai["removal_authorized"] is False
    assert ai["decision"]=="review_missing_offline_bootstrap_fallback"

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
        lambda a,b,c:a["m3_decision_classification"]["categories"].update(keep=9),
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
    ]
    for mutate in mutations:
        a,b,c=deepcopy(reg),deepcopy(paired),deepcopy(progress)
        mutate(a,b,c)
        try:validate(a,b,c)
        except (AssertionError,ValueError,KeyError,TypeError):
            continue
        raise AssertionError("Contradictory M3 strategy accepted")
    return len(mutations)

def main():
    docs=ROOT/"docs/vulpra"
    reg=json.loads((docs/"DEBLOAT-CANDIDATES.json").read_text())
    paired=json.loads((docs/"M3-PROMOCARD-NATIVE-PAIR.json").read_text())
    prog=json.loads((docs/"PROGRESS.json").read_text())
    counts=validate(reg,paired,prog)
    negative=negative_fixtures(reg,paired,prog)
    print("PASS: 19 bounded M3 strategies reconciled:",counts)
    print(f"PASS: {negative} contradictory classifications/evidence mutants rejected")
    print("READ-ONLY LEDGER: no new source removal, runtime, linker or size claim")

if __name__=="__main__":
    main()
