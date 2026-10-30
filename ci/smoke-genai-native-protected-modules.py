#!/usr/bin/env python3
"""Real full-normal Vulpra protected GenAI module import and offline fallback.

This reuses an independently compiled, SHA-256-verified native archive and
disposable geckodriver profile. It does not initialize an AI provider, call a
remote model, enable a browser preference or use a real user's account.
No module removal/saving/full runtime feature coverage is inferred.
"""
from __future__ import annotations
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location(
    "vulpra_genai_webdriver", ROOT/"smoke-webextension-package-local.py")
webdriver=importlib.util.module_from_spec(spec)
spec.loader.exec_module(webdriver)

SCRIPT=r"""
const done=arguments[arguments.length-1];
(async () => {
 const result={status:"loaded",imported:{},
   offline_null_input_response_preserved:false,
   preference_values_unchanged:false,
   ai_provider_or_remote_model_called_by_probe:false};
 const keys=["browser.ml.chat.enabled",
   "browser.ml.linkPreview.enabled","browser.ml.pageAssist.enabled"];
 const snapshot=()=>keys.map(p=>Services.prefs.getBoolPref(p,false));
 const before=snapshot();
 const definitions=[
   ["genai_module","GenAI.sys.mjs","GenAI","object","init"],
   ["link_preview_module","LinkPreview.sys.mjs","LinkPreview","object","init"],
   ["page_assist_module","PageAssist.sys.mjs","PageAssist","object","fetchAiResponse"],
   ["genai_parent","GenAIParent.sys.mjs","GenAIParent","function",null],
   ["genai_child","GenAIChild.sys.mjs","GenAIChild","function",null],
   ["link_preview_parent","LinkPreviewParent.sys.mjs","LinkPreviewParent","function",null],
   ["link_preview_child","LinkPreviewChild.sys.mjs","LinkPreviewChild","function",null],
   ["page_assist_parent","PageAssistParent.sys.mjs","PageAssistParent","function",null],
   ["page_assist_child","PageAssistChild.sys.mjs","PageAssistChild","function",null],
 ];
 try {
   for(const [key,file,symbol,kind,method] of definitions) {
     result.last_module=key;
     const mod=ChromeUtils.importESModule(
       "moz-src:///browser/components/genai/"+file);
     const member=mod[symbol];
     result.imported[key]=typeof member===kind &&
       (!method || typeof member[method]==="function");
     if(key==="page_assist_module") {
       // This existing local code path returns early when pageData is absent.
       // No model, page data or external request is supplied.
       const response=await member.fetchAiResponse("offline-test",null);
       result.offline_null_input_response_preserved=response===null;
     }
   }
   result.preference_values_unchanged=
     JSON.stringify(before)===JSON.stringify(snapshot());
   delete result.last_module;
 } catch(e) {
   result.status="rejected";
   result.error_stage=result.last_module || "unknown";
   result.error_kind=String(e?.name || "UnexpectedImportError").slice(0,48);
   // Never expose exception messages, paths, actor data or profile contents.
 }
 done(result);
})().catch(()=>done({status:"rejected",error_kind:"AsyncError"}));
"""

MODULE_KEYS=(
    "genai_module","link_preview_module","page_assist_module",
    "genai_parent","genai_child","link_preview_parent",
    "link_preview_child","page_assist_parent","page_assist_child",
)

def validate(x):
    if not isinstance(x,dict) or x.get("status")!="loaded":
        stage=x.get("error_stage","unknown") if isinstance(x,dict) else "nonobject"
        kind=x.get("error_kind","unknown") if isinstance(x,dict) else "unknown"
        raise ValueError("GenAI packaged module import failed: "+
                         str(stage)[:32]+" / "+str(kind)[:48])
    if not isinstance(x.get("imported"),dict) or set(x["imported"])!=set(MODULE_KEYS):
        raise ValueError("Missing GenAI module or unexpected actor keys")
    for key in MODULE_KEYS:
        if x["imported"][key] is not True:
            raise ValueError("Missing actual GenAI module/actor: "+key)
    if x.get("offline_null_input_response_preserved") is not True:
        raise ValueError("PageAssist pure offline null-input fallback changed")
    if x.get("preference_values_unchanged") is not True:
        raise ValueError("GenAI import altered chat/preview/assist preferences")
    if x.get("ai_provider_or_remote_model_called_by_probe") is not False:
        raise ValueError("Remote model or AI service invoked by test")
    if "error_kind" in x or "error_stage" in x:
        raise ValueError("Failure metadata in passed GenAI native smoke")
    return {key:True for key in MODULE_KEYS}

def run(repo:Path,driver:str):
    archive=webdriver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-normal-genai-") as tmp:
        root=Path(tmp)
        dest=root/"browser"
        dest.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(dest)],check=True,
                       stdout=subprocess.DEVNULL)
        ini=list(dest.rglob("application.ini"))
        if len(ini)!=1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
            raise ValueError("Not a unique original Vulpra native package")
        native=webdriver.select_binary(ini[0].parent)
        home=root/"isolated-home"
        home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"private-profile-marker-unchanged\n")
        env=os.environ.copy()
        env.update(HOME=str(home), XDG_DATA_HOME=str(home/"xdg"),
            MOZ_HEADLESS="1", MOZ_DISABLE_NONLOCAL_CONNECTIONS="1",
            NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost")
        for k in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):
            env.pop(k,None)
        port=webdriver.find_port()
        proc=None
        session=None
        try:
            with (root/"geckodriver.log").open("wb") as log:
                proc=subprocess.Popen([driver,"--host","127.0.0.1",
                    "--port",str(port),"--allow-system-access"],
                    env=env,stdout=log,stderr=subprocess.STDOUT,
                    start_new_session=True)
                webdriver.wait_ready(port,proc)
                result=webdriver.request(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox",
                        "moz:firefoxOptions":{
                            "binary":str(native),
                            "args":["-headless","-no-remote"],
                            "prefs":{
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                "network.dns.disablePrefetch":True,
                                "browser.shell.checkDefaultBrowser":False,
                                "datareporting.healthreport.uploadEnabled":False,
                                "datareporting.policy.dataSubmissionEnabled":False,
                            }
                        }
                    }}},timeout_seconds=80)
                session=result["sessionId"]
                base="/session/"+session
                webdriver.request(port,"POST",base+"/timeouts",{"script":45000})
                webdriver.request(port,"POST",base+"/moz/context",{"context":"chrome"})
                try:
                    status=webdriver.request(port,"POST",base+"/execute/async",
                        {"script":SCRIPT,"args":[]},timeout_seconds=60)
                finally:
                    webdriver.request(port,"POST",base+"/moz/context",
                        {"context":"content"})
                protected=validate(status)
                if sentinel.read_bytes()!=b"private-profile-marker-unchanged\n":
                    raise ValueError("Native GenAI module probe altered user-profile sentinel")
                return {
                    "schema_version":1,
                    "status":"full_normal_native_protected_genai_modules_loaded",
                    "verified_archive_sha256":True,
                    "private_home_and_profile_verified":True,
                    "gecko_nonlocal_connections_disabled":True,
                    "protected_genai_module_imports":protected,
                    "offline_null_page_data_returns_null":True,
                    "chat_and_preview_preferences_unchanged":True,
                    "ai_provider_or_model_called_by_probe":False,
                    "signed_in_user_state_used":False,
                    "linkpreview_or_genai_initialized_by_probe":False,
                    "actual_chat_provider_or_page_assist_model_request_tested":False,
                    "full_dynamic_genai_dependency_graph_proven":False,
                    "source_removal_authorized":False,
                    "new_whole_m3_gate_passed":False,
                    "limitations":[
                        "Real compiled full-normal native modules imported under isolated chrome WebDriver context.",
                        "LinkPreview/GenAI init methods and actor instances were not exercised by the probe.",
                        "PageAssist null-data fallback only; no AI model inference or network request.",
                        "No source deletion, per-feature compressed saving, runtime actor lifecycle, or dynamic graph closure.",
                    ],
                }
        finally:
            if session:
                try:webdriver.request(port,"DELETE","/session/"+session,timeout_seconds=8)
                except (OSError,RuntimeError):pass
            if proc:
                proc.terminate()
                try:proc.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

def main():
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("repo",type=Path,nargs="?",default=Path.cwd())
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        good={"status":"loaded","imported":{key:True for key in MODULE_KEYS},
              "offline_null_input_response_preserved":True,
              "preference_values_unchanged":True,
              "ai_provider_or_remote_model_called_by_probe":False}
        assert validate(good)==good["imported"]
        for key in MODULE_KEYS:
            bad={**good,"imported":{**good["imported"],key:False}}
            try:validate(bad)
            except ValueError:pass
            else:raise AssertionError("False native GenAI module accepted: "+key)
        for field,value in (
            ("status","rejected"),
            ("offline_null_input_response_preserved",False),
            ("preference_values_unchanged",False),
            ("ai_provider_or_remote_model_called_by_probe",True),
        ):
            bad={**good,field:value}
            try:validate(bad)
            except ValueError:pass
            else:raise AssertionError("False GenAI runtime acceptance: "+field)
        print("PASS:",len(MODULE_KEYS)+4,
              "GenAI fake-import/preference/network rejection fixtures")
        return
    driver=shutil.which("geckodriver")
    if not driver:raise RuntimeError("Need geckodriver for real native browser")
    report=run(a.repo.resolve(),driver)
    output=a.repo/".git/vulpra-native-build/m3-full-normal-genai-modules.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: nine real shipped normal GenAI/actor modules and offline null-data fallback")

if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL packaged GenAI protected native runtime:",e,file=sys.stderr)
        raise SystemExit(1)
