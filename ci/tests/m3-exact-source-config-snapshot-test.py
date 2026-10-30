#!/usr/bin/env python3
"""Fail closed on contradictory M3 generated-config and binary provenance claims.

Metadata-only regression: original Actions artifact remains authority, and
source-only checks do not replicate native configure or compile.
"""
from copy import deepcopy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SHA="74e390f8f27ba705fbf26aa4750a21f0929a6ae8"
TRUTHY=("ENABLE_WEBDRIVER","MOZ_CRASHREPORTER","MOZ_HAS_REMOTE",
        "MOZ_NORMANDY","MOZ_SANDBOX","MOZ_SERVICES_HEALTHREPORT",
        "MOZ_SERVICES_SYNC","MOZ_UPDATER","MOZ_WAYLAND","MOZ_X11")
ABSENT=("ENABLE_TESTS","MOZILLA_OFFICIAL","MOZ_APPSERVICES_IN_TREE",
        "MOZ_BROWSER_BRANDING","MOZ_CONFIGURE_TRUSTED_PROXY",
        "MOZ_GECKODRIVER","MOZ_TELEMETRY_REPORTING")
def check(d,progress,roadmap):
    assert d["schema_version"]==1 and d["project"]=="Vulpra"
    assert d["observed_source_commit"]==SHA
    assert d["source_configure_run_id"]==40932179859
    assert d["source_configure_artifact_id"]==12924085624
    flags=d["generated_selected_substs"]
    assert d["flag_count"]==25 and len(flags)==25
    assert flags["MOZ_BUILD_APP"]=={"state":"recorded","value":"browser"}
    assert flags["MOZ_WIDGET_TOOLKIT"]=={"state":"recorded","value":"gtk"}
    assert flags["OS_TARGET"]=={"state":"recorded","value":"Linux"}
    assert flags["MOZ_APP_BASENAME"]=={"state":"recorded","value":"Vulpra"}
    assert flags["MOZ_APP_NAME"]=={"state":"recorded","value":"vulpra"}
    assert flags["MOZ_APP_VERSION"]=={"state":"recorded","value":"159.0"}
    assert flags["MOZ_DEVTOOLS"]=={"state":"recorded","value":"all"}
    assert all(flags[k]=={"state":"recorded","value":"1"} for k in TRUTHY)
    assert all(flags[k]=={"state":"absent","value":None} for k in ABSENT)
    assert flags["VULPRA_NO_ASROUTER_PROMOS"]=={
        "state":"empty_string","value":""}
    assert d["absent_subst_is_not_disabled_feature"] is True
    for key in ("source_binary_compiled","native_package_generated",
                "current_source_runtime_verified","removal_authorized"):
        assert d[key] is False
    assert d["unknown_build_settings_remain"] is True
    assert d["compiled_savings_bytes"] is None
    assert "M3-EXACT-SOURCE-CONFIG-SNAPSHOT.json" in roadmap
    assert "M3-EXACT-SOURCE-CONFIG-SNAPSHOT.md" in roadmap
    m3=next(m for m in progress["milestones"] if m["id"]=="M3")
    assert m3["acceptance_gates"]["passed"]==5
    assert m3["acceptance_gates"]["total"]==6
    assert m3["percent"]==83 and progress["overall"]["percent"]==61
def test_mutants(d,p,r):
    changes=[
      lambda a,b,c:a.update(observed_source_commit="1683ca67b69389a879717bcd537772c3b40624b6"),
      lambda a,b,c:a.update(source_configure_run_id=40567473401),
      lambda a,b,c:a.update(flag_count=24),
      lambda a,b,c:a["generated_selected_substs"]["MOZ_WAYLAND"].update(value=""),
      lambda a,b,c:a["generated_selected_substs"]["MOZ_GECKODRIVER"].update(state="recorded",value=False),
      lambda a,b,c:a["generated_selected_substs"]["MOZ_TELEMETRY_REPORTING"].update(state="recorded",value=False),
      lambda a,b,c:a["generated_selected_substs"]["VULPRA_NO_ASROUTER_PROMOS"].update(state="absent"),
      lambda a,b,c:a.update(source_binary_compiled=True),
      lambda a,b,c:a.update(absent_subst_is_not_disabled_feature=False),
      lambda a,b,c:a.update(compiled_savings_bytes=1577264),
      lambda a,b,c:b["overall"].update(percent=49),
      lambda a,b,c:b["milestones"][2]["acceptance_gates"].update(passed=2),
    ]
    for mutate in changes:
        a,b,c=deepcopy(d),deepcopy(p),r
        mutate(a,b,c)
        try:check(a,b,c)
        except (AssertionError,KeyError,TypeError):
            continue
        raise AssertionError("False compiled/generated-config claim passed")
    return len(changes)
def main():
    base=ROOT/"docs/vulpra"
    d=json.loads((base/"M3-EXACT-SOURCE-CONFIG-SNAPSHOT.json").read_text())
    p=json.loads((base/"PROGRESS.json").read_text())
    road=(base/"ROADMAP.md").read_text()
    check(d,p,road)
    print("PASS: 25 exact source-generated config values and absent-state semantics")
    print("PASS:",test_mutants(d,p,road),"false config/compiled/gate claims rejected")
    print("METADATA: original configure-only CI artifact remains the primary evidence")
if __name__=="__main__":
    main()
