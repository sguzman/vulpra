#!/usr/bin/env python3
"""Read only generated configure substs for this exact-source no-compile run.

The output is an allowlisted, bounded JSON snapshot. Missing, null, false and
empty-string substitutions are all distinct; never infer a feature omission.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
KEYS=(
 "MOZ_BUILD_APP","MOZ_WIDGET_TOOLKIT","OS_TARGET",
 "MOZ_APP_BASENAME","MOZ_APP_NAME","MOZ_APP_VERSION",
 "MOZ_SERVICES_SYNC","MOZ_SERVICES_HEALTHREPORT",
 "MOZ_NORMANDY","MOZ_DEVTOOLS","MOZ_TELEMETRY_REPORTING",
 "MOZ_CRASHREPORTER","MOZ_HAS_REMOTE","ENABLE_WEBDRIVER",
 "MOZ_GECKODRIVER","ENABLE_TESTS","MOZ_UPDATER",
 "MOZ_SANDBOX","MOZ_WAYLAND","MOZ_X11","MOZILLA_OFFICIAL",
 "MOZ_APPSERVICES_IN_TREE","VULPRA_NO_ASROUTER_PROMOS",
 "MOZ_BROWSER_BRANDING","MOZ_CONFIGURE_TRUSTED_PROXY",
)
MAX_VALUE=256
def values(sub):
    if not sub.is_dir():raise ValueError("Missing generated config.statusd/substs")
    found={}
    for key in KEYS:
        file=sub/key
        if not file.is_file():
            found[key]={"state":"absent","value":None};continue
        raw=file.read_bytes()
        if len(raw)>MAX_VALUE:raise ValueError("Unbounded generated flag "+key)
        try:value=json.loads(raw)
        except (UnicodeError,json.JSONDecodeError) as e:
            raise ValueError("Non-JSON configured value "+key) from e
        if isinstance(value,(dict,list)):
            raise ValueError("Complex unexpected configuration value "+key)
        if isinstance(value,str) and ("\n" in value or "\t" in value):
            raise ValueError("Multiline configured flag "+key)
        state=("null" if value is None else
               "empty_string" if value=="" and isinstance(value,str) else
               "recorded")
        found[key]={"state":state,"value":value}
    if found["MOZ_BUILD_APP"]["value"]!="browser":
        raise ValueError("Not a browser configuration")
    if found["MOZ_WIDGET_TOOLKIT"]["value"]!="gtk":
        raise ValueError("Not a GTK Linux configuration")
    if found["MOZ_APP_BASENAME"]["value"]!="Vulpra":
        raise ValueError("Not a Vulpra application configuration")
    if found["MOZ_DEVTOOLS"]["value"]!="all":
        raise ValueError("Full DevTools baseline not configured")
    for key in ("MOZ_WAYLAND","MOZ_SANDBOX","MOZ_SERVICES_SYNC","MOZ_NORMANDY"):
        if str(found[key]["value"]) not in ("True","1"):
            raise ValueError("Protected setting no longer active "+key)
    promo=found["VULPRA_NO_ASROUTER_PROMOS"]["value"]
    if promo not in (None,False,0,""):
        raise ValueError("Default baseline unexpectedly omitted promotion modules")
    return found

def selftest():
    with tempfile.TemporaryDirectory(prefix="vulpra-config-") as d:
        root=Path(d)
        def write(k,v):
            (root/k).write_text(json.dumps(v)+"\n")
        write("MOZ_BUILD_APP","browser")
        write("MOZ_WIDGET_TOOLKIT","gtk")
        write("MOZ_APP_BASENAME","Vulpra")
        write("MOZ_DEVTOOLS","all")
        for k in ("MOZ_WAYLAND","MOZ_SANDBOX","MOZ_SERVICES_SYNC","MOZ_NORMANDY"):
            write(k,"1")
        write("VULPRA_NO_ASROUTER_PROMOS","")
        x=values(root)
        assert x["ENABLE_TESTS"]["state"]=="absent"
        assert x["VULPRA_NO_ASROUTER_PROMOS"]["state"]=="empty_string"
        write("ENABLE_TESTS",False)
        assert values(root)["ENABLE_TESTS"]["value"] is False
        write("ENABLE_TESTS",None)
        assert values(root)["ENABLE_TESTS"]["state"]=="null"
        (root/"ENABLE_TESTS").unlink()
        write("MOZ_DEVTOOLS","server")
        try:values(root)
        except ValueError as e:assert "DevTools" in str(e)
        else:raise AssertionError("Invalid DevTools accepted")
        write("MOZ_DEVTOOLS","all")
        write("MOZ_SANDBOX","")
        try:values(root)
        except ValueError as e:assert "Protected" in str(e)
        else:raise AssertionError("Missing sandbox accepted")
        write("MOZ_SANDBOX","1")
        (root/"MOZ_SERVICES_SYNC").write_text("{invalid}\n")
        try:values(root)
        except ValueError as e:assert "Non-JSON" in str(e)
        else:raise AssertionError("Malformed JSON accepted")
        write("MOZ_SERVICES_SYNC","1")
        write("ENABLE_TESTS","a"*300)
        try:values(root)
        except ValueError as e:assert "Unbounded" in str(e)
        else:raise AssertionError("Unbounded substitution accepted")
    return 9

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--objdir",type=Path)
    parser.add_argument("--output",type=Path)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    if args.self_test:print("PASS:",selftest(),"config parsing and rejection checks")
    if not args.objdir:
        if not args.self_test:parser.error("--objdir required")
        return
    repo=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    m=ROOT/"ci/mozconfig-linux-m3-baseline"
    if not m.is_file():raise ValueError("Missing source pinned Vulpra baseline mozconfig")
    digest=subprocess.check_output(["git","-C",str(ROOT),"hash-object",str(m)],text=True).strip()
    observed=values(args.objdir.resolve()/"config.statusd/substs")
    report={
      "schema_version":1,
      "type":"exact_source_configure_only_generated_substitution_snapshot",
      "source_commit":repo,
      "mozconfig_blob_sha":digest,
      "source_mozconfig":"ci/mozconfig-linux-m3-baseline",
      "configured_object_directory":args.objdir.name,
      "configured_flag_count":len(observed),
      "observed_generated_substs":observed,
      "configure_executed_in_this_run":True,
      "native_browser_compiled":False,
      "native_package_generated":False,
      "runtime_browser_tested":False,
      "current_main_compiled_binary_proven":False,
      "feature_removal_authorized":False,
      "compiled_package_delta_bytes":None,
      "limitations":[
        "Only allowlisted generated substitution keys, not full config.statusd.",
        "Native configure only; cannot prove files actually compiled or linked.",
        "Unobserved flag keys are explicitly absent, not assumed false.",
        "Empty-string value is distinguished from missing/null/false.",
        "No binary output or source-matched comparison exists for this configured source."
      ]}
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: exact-source generated GTK/Vulpra config snapshot, no compiler build")
    print("SOURCE SHA:",repo)
    print("SELECTED SUBSTS:",json.dumps(observed,sort_keys=True))
    print("No native binary, code removal, runtime, package-size savings claimed")

if __name__=="__main__":
    try:main()
    except (OSError,AssertionError,ValueError,subprocess.CalledProcessError) as e:
        print("FAIL Vulpra configure-only evidence:",e,file=sys.stderr)
        raise SystemExit(1)
