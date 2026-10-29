#!/usr/bin/env python3
"""Read-only attestation of original native configure/build/package CI.

Selected generated config assertions were executed; the entire config.statusd
directory is NOT saved, and the workflow run SHA is NOT the compiled source SHA.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import json
from pathlib import Path
import re
import sys

RUN=40567473401
JOB=122412477192
WORKFLOW_SHA="341128fd6f640738ea2fbb0f674eb6319b249235"
BUILT_SHA="1683ca67b69389a879717bcd537772c3b40624b6"
ARCHIVE_ID=12767756929
EXACT_ASSERTS={
    "MOZ_APP_BASENAME":'assert get("MOZ_APP_BASENAME")=="Vulpra"',
    "MOZ_WIDGET_TOOLKIT":'assert get("MOZ_WIDGET_TOOLKIT")=="gtk"',
    "MOZ_DEVTOOLS":'assert get("MOZ_DEVTOOLS")=="all"',
    "VULPRA_NO_ASROUTER_PROMOS":'assert no_promo in (False, None, 0, "")',
}
TRUTHY_GUARD='for k in ("MOZ_SANDBOX","MOZ_WAYLAND","MOZ_SERVICES_SYNC","MOZ_NORMANDY"):'
ANSI=re.compile(r"\x1b\[[0-9;]*m")
STAMP=re.compile(r"^\d{4}-\d{2}-\d{2}T[\d:.]+Z\s*")

def lines(s):
    return [STAMP.sub("",ANSI.sub("",x)).strip() for x in s.splitlines()]

def check(run,job,workflow,mozconfig,log):
    if run.get("id")!=RUN or run.get("head_sha")!=WORKFLOW_SHA:
        raise ValueError("Wrong archived workflow run SHA or ID")
    if run.get("conclusion")!="success" or run.get("event")!="push":
        raise ValueError("Historical workflow did not pass as recorded")
    if not str(run.get("path","")).endswith("m3-asrouter-promo-matched-baseline.yml"):
        raise ValueError("Wrong archived workflow file")
    if job.get("id")!=JOB or job.get("conclusion")!="success":
        raise ValueError("Historical native job did not pass")
    ok={z["name"]:z.get("conclusion") for z in job.get("steps",[])}
    expected=[
        "Checkout exact successful candidate source, not latest main",
        "Require source match and identical non-promo compiler options",
        "Verify full-promo baseline configure and protected feature set",
        "Compile native source-matched full-promo browser",
        "Package the full baseline and compare actual tarball bytes",
        "Preserve baseline archive and strict paired-size evidence",
    ]
    if any(ok.get(name)!="success" for name in expected):
        raise ValueError("A native configure, build or packaging gate did not pass")
    if workflow.count(BUILT_SHA)<2 or BUILT_SHA==WORKFLOW_SHA:
        raise ValueError("Pinned compiled source SHA not in historical workflow")
    for required in (
        "CANDIDATE_SHA:",'"$CANDIDATE_SHA"',
        "ref: ${{ github.event_name",
        "./mach configure","./mach build","./mach package",
        TRUTHY_GUARD,'assert str(get(k)) in ("1","True")',
        *EXACT_ASSERTS.values()):
        if required not in workflow:
            raise ValueError("Missing original executable workflow assertion: "+required)
    options=(
        "mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux-m3-baseline",
        "ac_add_options --with-branding=browser/branding/unofficial",
        "ac_add_options --with-app-basename=Vulpra",
        "ac_add_options --disable-tests",
        "ac_add_options --with-ccache=sccache",
    )
    for option in options:
        if option not in mozconfig:
            raise ValueError("Missing original requested source mozconfig: "+option)
    logged=lines(log)
    for assertion in (*EXACT_ASSERTS.values(),TRUTHY_GUARD,
                      'assert str(get(k)) in ("1","True")',"Creating config.status"):
        if not any(assertion in line for line in logged):
            raise ValueError("Configure log missing executed assertion: "+assertion)
    if not any(x.endswith(f"CANDIDATE_SHA: {BUILT_SHA}") for x in logged):
        raise ValueError("Original log does not identify built source commit")
    for marker in (
        "PASS: exact accepted candidate commit, original promo modules enabled for baseline",
        "PASS: same protected browser; only promotion omission differs",
        "PASS: strict positive source-matched Linux native package reduction",
    ):
        if not any(x.endswith(marker) for x in logged):
            raise ValueError("Missing actual success log (not script echo): "+marker)
    return {
        "schema_version":1,
        "scope":"historical pinned source and selected generated configure assertions",
        "original_actions_run_id":RUN,
        "original_actions_workflow_head_sha":WORKFLOW_SHA,
        "actual_compiled_browser_source_sha":BUILT_SHA,
        "original_actions_job_id":JOB,
        "original_archived_package_artifact_id":ARCHIVE_ID,
        "native_configure_build_and_package_all_passed":True,
        "passed_selected_generated_subst_assertions":{
            "MOZ_APP_BASENAME":"Vulpra",
            "MOZ_WIDGET_TOOLKIT":"gtk",
            "MOZ_DEVTOOLS":"all",
            "VULPRA_NO_ASROUTER_PROMOS":"disabled_or_unset",
            "MOZ_SANDBOX":"truthy",
            "MOZ_WAYLAND":"truthy",
            "MOZ_SERVICES_SYNC":"truthy",
            "MOZ_NORMANDY":"truthy"
        },
        "compiled_source_mozconfig_requested":{
            "disable_tests":True,"unofficial_branding":True,"sccache":True,
            "object_dir":"obj-vulpra-linux-m3-baseline"},
        "requested_mozconfig_all_values_verified_in_generated_substs":False,
        "complete_generated_config_statusd_available":False,
        "current_main_whole_source_matched":False,
        "new_removal_authorized":False,
        "compressed_feature_savings_measured":None,
        "limitations":[
            "Workflow GitHub Actions head SHA and actual checked out compiled SHA differ.",
            "Only explicit configure assertions proved; complete config.statusd not archived.",
            "Mozconfig source options requested, not all independently measured in generated values.",
            "Historical full browser, not current-source-matched native build.",
            "No new native runtime acceptance or dependency omission."
        ],
    }

def negative_tests(run,job,workflow,mozconfig,log):
    broken=[
        lambda a,b,c,d,e:a.update(head_sha=BUILT_SHA),
        lambda a,b,c,d,e:a.update(conclusion="failure"),
        lambda a,b,c,d,e:b.update(conclusion="failure"),
        lambda a,b,c,d,e:next(x for x in b["steps"] if x["name"]=="Verify full-promo baseline configure and protected feature set").update(conclusion="failure"),
        lambda a,b,c,d,e:c.remove(EXACT_ASSERTS["MOZ_DEVTOOLS"]),
        lambda a,b,c,d,e:c.remove(TRUTHY_GUARD),
        lambda a,b,c,d,e:c.remove(BUILT_SHA),
        lambda a,b,c,d,e:d.remove("ac_add_options --disable-tests"),
        lambda a,b,c,d,e:e.remove("PASS: same protected browser; only promotion omission differs"),
        lambda a,b,c,d,e:e.remove(f"CANDIDATE_SHA: {BUILT_SHA}"),
    ]
    for mutation in broken:
        a,b=deepcopy(run),deepcopy(job)
        c,d,e=[Mutable(x) for x in (workflow,mozconfig,log)]
        mutation(a,b,c,d,e)
        try:check(a,b,c.value,d.value,e.value)
        except ValueError:continue
        raise AssertionError("Untrustworthy archived provenance accepted")
    return len(broken)

class Mutable:
    def __init__(self,value):self.value=value
    def remove(self,part):
        if part not in self.value:raise AssertionError("Bad negative fixture "+part)
        self.value=self.value.replace(part,"__MUTATED__",self.value.count(part))

def main():
    parser=argparse.ArgumentParser()
    for flag in ("run","job","workflow","mozconfig","log"):
        parser.add_argument("--"+flag,type=Path,required=True)
    parser.add_argument("--self-test",action="store_true")
    parser.add_argument("--output",type=Path)
    a=parser.parse_args()
    run=json.loads(a.run.read_text())
    job=json.loads(a.job.read_text())
    wf=a.workflow.read_text();mz=a.mozconfig.read_text()
    log=a.log.read_text(errors="replace")
    result=check(run,job,wf,mz,log)
    if a.self_test:result["invalid_provenance_mutations_rejected"]=negative_tests(run,job,wf,mz,log)
    if a.output:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: historical exact compiled-source checkout, selected configure, build and package gates")
    if a.self_test:print("PASS:",result["invalid_provenance_mutations_rejected"],"tampered provenance fixtures rejected")
    print("HISTORICAL: not full config.statusd or current compiled source, no source pruning")

if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,json.JSONDecodeError) as e:
        print("FAIL M3 historical configure evidence:",e,file=sys.stderr)
        raise SystemExit(1)
