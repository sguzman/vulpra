#!/usr/bin/env python3
"""Read-only pinned Linux native Gecko/Rust/feature build boundary audit."""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FILES={
 "app":"browser/app.mozbuild",
 "configure":"browser/moz.configure",
 "graph":"toolkit/toolkit.mozbuild",
 "widget":"widget/moz.build",
 "xul":"toolkit/library/moz.build",
 "rust":"toolkit/library/rust/moz.build",
 "rust_features":"toolkit/library/rust/gkrust-features.mozbuild",
 "components":"toolkit/components/moz.build",
 "telemetry":"toolkit/components/telemetry/moz.build",
 "services":"services/moz.build",
 "devtools":"devtools/moz.build",
 "browser_components":"browser/components/moz.build",
 "newtab":"browser/components/newtab/moz.build",
 "newtab_js":"browser/extensions/newtab/moz.build",
 "genai":"browser/components/genai/moz.build",
}
def text_at_head():
    return {k:subprocess.check_output(["git","-C",str(ROOT),"show","HEAD:"+path],
            text=True,stderr=subprocess.PIPE) for k,path in FILES.items()}
def verify(t,k,value):
    raw=t[k]
    if raw.count(value)!=1:
        raise ValueError(f"Expected unique anchor {k}: {value!r}, seen {raw.count(value)}")
    return {"path":FILES[k],"line":raw.count("\n",0,raw.index(value))+1,
            "literal":value}
def guard(t,k,start,end,*required):
    raw=t[k]
    if raw.count(start)!=1: raise ValueError("Invalid guard "+k+": "+start)
    pos=raw.index(start)
    stop=raw.find(end,pos+len(start))
    if stop<0: raise ValueError("Lost guard end "+k+": "+end)
    body=raw[pos:stop]
    for required_text in required:
        if required_text not in body:
            raise ValueError("Escaped guard "+k+": "+required_text)
    return verify(t,k,start)
def analyze(t):
    entries=[]
    def add(name,decision,why,*items):
        if decision not in ("retain","conditional") or not items:
            raise ValueError("Unclassified "+name)
        entries.append({"id":name,"decision":decision,"basis":why,"anchors":list(items)})
    add("browser_depends_on_gecko","retain",
        "Browser application includes shared toolkit, not a self-contained Rust app.",
        verify(t,"app",'include("/toolkit/toolkit.mozbuild")'),
        verify(t,"app",'DIRS += ["/browser"]'))
    add("gtk_wayland_native_widget","retain",
        "Selected widget toolkit is GTK on accepted Linux build; Wayland and X11 support "
        "have own compile/dir paths joined into xul.",
        verify(t,"widget",'toolkit = CONFIG["MOZ_WIDGET_TOOLKIT"]'),
        guard(t,"widget",
              'if toolkit in ("android", "cocoa", "gtk", "uikit", "windows"):',
              'if toolkit == "cocoa":','DIRS += [toolkit]'),
        verify(t,"widget",'if CONFIG["MOZ_X11"] or CONFIG["MOZ_WAYLAND"]:'),
        verify(t,"widget",'FINAL_LIBRARY = "xul"'),
        verify(t,"widget",'    CXXFLAGS += CONFIG["MOZ_WAYLAND_CFLAGS"]'))
    add("xul_native_link_dependencies","retain",
        "libxul C/C++ native link brings in JS, NSPR/NSS, SQLite and other libraries.",
        verify(t,"xul",'Library("xul")'),
        verify(t,"xul",'FINAL_LIBRARY = "xul-real"'),
        verify(t,"xul",'    "nss",'),
        verify(t,"xul",'    "nspr",'),
        verify(t,"xul",'    "sqlite",'))
    add("rust_gkrust_ffi_into_xul","retain",
        "Shared toolkit includes Rust gkrust unless replaced; it uses for_xul FFI features.",
        guard(t,"graph",'if not CONFIG["MOZ_OVERRIDE_GKRUST"]:',
              'if CONFIG["MOZ_SANDBOX"]:','"/toolkit/library/rust"'),
        verify(t,"rust",'RustLibrary("gkrust", gkrust_features, is_gkrust=True)'),
        verify(t,"rust_features",'    "for_xul",'))
    add("glean_official_build_difference","conditional",
        "All gkrust enables Glean-for-Gecko, while non-official builds conditionally "
        "enable Glean upload disabling. This is source config, not network proof.",
        verify(t,"rust_features",'gkrust_features += ["glean_with_gecko"]'),
        guard(t,"rust_features",'if not CONFIG["MOZILLA_OFFICIAL"]:',
              'if CONFIG["MOZ_ENABLE_DBUS"]:',
              'gkrust_features += ["glean_disable_upload"]'))
    add("crashreporter_rust_link","conditional",
        "Native Rust crash reporter support is separately configured; protect safety paths.",
        guard(t,"rust_features",'if CONFIG["MOZ_CRASHREPORTER"]:',
              'if CONFIG["MOZ_WEBMIDI_MIDIR_IMPL"]:',
              'gkrust_features += ["crashreporter"]'))
    add("telemetry_cxx_xul_and_pingsender","retain",
        "Native Telemetry C++ and pingsender remain linked; desktop IPC differs from "
        "mobile stub branches even if ordinary ping transport is toggled.",
        verify(t,"components",'    "telemetry",'),
        verify(t,"telemetry",'FINAL_LIBRARY = "xul"'),
        verify(t,"telemetry",'    "pingsender",'),
        guard(t,"telemetry",
              'if CONFIG["MOZ_WIDGET_TOOLKIT"] not in ("android", "uikit"):',
              'else:','"core/ipc/TelemetryIPC.cpp"'))
    add("glean_and_core_security_native","retain",
        "Glean, browser extensions and crashes are separate toolkit owners; security "
        "libraries and sandbox branches are not discretionary UI.",
        verify(t,"components",'    "glean",'),
        verify(t,"components",'    "extensions",'),
        guard(t,"graph",'if CONFIG["COMPILE_ENVIRONMENT"]:\n    DIRS += [\n        "/config/external",',
              'if not CONFIG["MOZ_OVERRIDE_GKRUST"]:','"/security"'),
        guard(t,"graph",'if CONFIG["MOZ_SANDBOX"]:',
              'if CONFIG["MOZ_USING_WASM_SANDBOXING"]',
              '"/security/sandbox"'),
        verify(t,"graph",'    "/security/manager",'))
    add("fxaccounts_independent_of_sync","conditional",
        "Desktop FxAccounts and Sync have separate build guards and UI consumers.",
        verify(t,"configure",'imply_option("MOZ_SERVICES_SYNC", True)'),
        guard(t,"services",'if CONFIG["MOZ_WIDGET_TOOLKIT"] != "android":',
              'if CONFIG["MOZ_WIDGET_TOOLKIT"] == "android" or CONFIG["MOZ_APPSERVICES_IN_TREE"]:',
              '"fxaccounts"'),
        guard(t,"services",'if CONFIG["MOZ_SERVICES_SYNC"]:',
              'SPHINX_TREES["/services"]','DIRS += ["sync"]'))
    add("devtools_client_separate_from_server","conditional",
        "Browser requests full DevTools client but server, startup/shared are separately wired.",
        verify(t,"configure",'imply_option("MOZ_DEVTOOLS", "all")'),
        guard(t,"devtools",'if CONFIG["MOZ_DEVTOOLS"] == "all":',
              'DIRS += [\n    "platform",','"client"'),
        verify(t,"devtools",'    "server",'),
        verify(t,"devtools",'    "startup",'))
    add("newtab_and_genai_native_registration","retain",
        "Browser components register New Tab, GenAI and AIWindow; New Tab includes "
        "browsercomps/native component and GenAI has separately packaged modules.",
        verify(t,"browser_components",'    "newtab",'),
        verify(t,"browser_components",'    "genai",'),
        verify(t,"browser_components",'    "aiwindow",'),
        verify(t,"newtab",'FINAL_LIBRARY = "browsercomps"'),
        verify(t,"genai",'    "GenAI.sys.mjs",'))
    add("newtab_generated_javascript_and_jar","conditional",
        "Compiled New Tab resources are generated via Node and are packaged alongside "
        "a webextension glue directory; a preference does not remove bundled JS.",
        verify(t,"newtab_js",'JAR_MANIFESTS += ["addon-jar.mn"]'),
        guard(t,"newtab_js",'if CONFIG["NODEJS"]:',
              'DIRS += ["webext-glue"]',
              'entry_point="generate_js"','entry_point="generate_css"'),
        verify(t,"newtab_js",'DIRS += ["webext-glue"]'))
    add("nimbus_normandy_helper_distinction","conditional",
        "Browser's opt-in runner omission still retains shared Normandy helper for Nimbus.",
        verify(t,"configure",'imply_option("MOZ_NORMANDY", True, when=vulpra_include_normandy)'),
        guard(t,"components",'if CONFIG["MOZ_BUILD_APP"] == "browser":',
              'if CONFIG["MOZ_BUILD_APP"] != "comm/mail":',
              'DIRS += ["normandy"]'),
        verify(t,"components",'DIRS += ["nimbus"]'))
    add("updater_native_signing_lib","conditional",
        "Native libmar is gated by MOZ_UPDATER and must retain required NSS/signing.",
        guard(t,"graph",'if CONFIG["MOZ_UPDATER"]:',
              'DIRS += [\n    "/config/external/abseil-cpp",',
              'DIRS += ["/modules/libmar"]'))
    return {"schema_version":1,"project":"Vulpra",
            "scope":"bounded Linux Gecko native/Rust/feature build configuration",
            "source_only":True,"config_guard_values_not_evaluated":True,
            "removal_authorized":False,"package_bytes_saved":None,
            "boundaries":entries,
            "limitations":[
                "Source manifest anchors are not complete generated build/linker graph.",
                "Exact configured values and package object files require separate evidence.",
                "Native, Rust FFI, security and JavaScript reachability remains incomplete.",
                "No native rebuild, performance gain, binary saving or removal."]}
def negative_fixtures(t):
    cases=[
      ("app",'include("/toolkit/toolkit.mozbuild")'),
      ("widget",'toolkit = CONFIG["MOZ_WIDGET_TOOLKIT"]'),
      ("widget",'    CXXFLAGS += CONFIG["MOZ_WAYLAND_CFLAGS"]'),
      ("xul",'Library("xul")'),
      ("xul",'    "nss",'),
      ("rust",'RustLibrary("gkrust", gkrust_features, is_gkrust=True)'),
      ("rust_features",'gkrust_features += ["glean_disable_upload"]'),
      ("rust_features",'gkrust_features += ["crashreporter"]'),
      ("telemetry",'"core/ipc/TelemetryIPC.cpp"'),
      ("components",'    "telemetry",'),
      ("graph",'    "/security/manager",'),
      ("services",'DIRS += ["sync"]'),
      ("devtools",'    "server",'),
      ("newtab",'FINAL_LIBRARY = "browsercomps"'),
      ("genai",'    "GenAI.sys.mjs",'),
      ("newtab_js",'entry_point="generate_js"'),
      ("components",'DIRS += ["nimbus"]'),
      ("graph",'DIRS += ["/modules/libmar"]'),
    ]
    for key,phrase in cases:
        if t[key].count(phrase)!=1:
            raise AssertionError("Invalid fixture "+key+": "+phrase)
        damaged=dict(t);damaged[key]=damaged[key].replace(phrase,"__BROKEN__",1)
        try: analyze(damaged)
        except ValueError: continue
        raise AssertionError("Failed to detect broken "+key+": "+phrase)
    return len(cases)
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--self-test",action="store_true")
    p.add_argument("--output")
    args=p.parse_args()
    rev=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    t=text_at_head()
    report=analyze(t);report["source_commit"]=rev
    if args.self_test: report["invalid_mutations_rejected"]=negative_fixtures(t)
    if args.output:
        out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True)
        out.write_text(json.dumps(report,indent=2)+"\n")
    print(f"PASS: {len(report['boundaries'])} native/feature source boundaries at {rev}")
    if args.self_test: print(f"PASS: {report['invalid_mutations_rejected']} negative mutations rejected")
    print("Source only; not a compiled, tested, removable or sized browser feature map.")
if __name__=="__main__":
    try: main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL: Linux native feature dependency map:",e,file=sys.stderr)
        raise SystemExit(1)
