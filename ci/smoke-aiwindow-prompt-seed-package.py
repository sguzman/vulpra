#!/usr/bin/env python3
"""Real archived Vulpra AI Window prompt-loader boundary probe.

Runs Firefox only in a private disposable HOME and blocks nonlocal connections.
Exercises fake Remote Settings clients to observe missing-manifest and required
module safety, then inspects seeded collection count without retaining content.
No model or external API is called; no prompt records or user profile are read.
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
import time

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location(
    "vulpra_existing_webdriver",ROOT/"smoke-webextension-package-local.py")
driver=importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)

SCRIPT=r"""
const done=arguments[arguments.length-1];
(async () => {
  const Utils=ChromeUtils.importESModule(
    "moz-src:///browser/components/aiwindow/models/Utils.sys.mjs");
  const Loader=ChromeUtils.importESModule(
    "moz-src:///browser/components/aiwindow/models/PromptLoader.sys.mjs");
  const Services=globalThis.Services ||
    ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs").Services;
  const original=Services.prefs.prefHasUserValue("browser.smartwindow.mistralRelease")
    ? Services.prefs.getBoolPref("browser.smartwindow.mistralRelease") : null;
  const literal="Vulpra synthetic offline fixture";
  const fake=items=>({
    get:async()=>items,on:()=>{},off:()=>{}});
  let data={status:"observed",fake_client_used:true,
            required_modules:["identity","response-rules"],
            real_seed_content_not_collected:true,
            model_engine_started:false};
  async function shouldFail(records) {
    Utils._setRemoteClientForTesting(fake(records));
    try {
      await Loader.buildChatSystemPrompt("generic");
      return {rejected:false,client_reason:null};
    } catch(e) {
      return {rejected:true,client_reason:e?.clientReason || null};
    }
  }
  const params={kind:"params",feature:"chat",model:"generic",
                version:"10.0",is_default:true,
                modules:[{name:"identity",version:"10.0"},
                         {name:"response-rules",version:"10.0"}]};
  const identity={kind:"module",feature:"chat",model:"generic",
                  version:"10.0",module:"identity",
                  prompts:literal+" identity"};
  const rules={kind:"module",feature:"chat",model:"generic",
               version:"10.0",module:"response-rules",
               prompts:literal+" response-rules"};
  try {
    Services.prefs.setBoolPref("browser.smartwindow.mistralRelease",false);
    data.empty_collection=await shouldFail([]);
    data.missing_required_module=await shouldFail([params,rules]);
    data.missing_params=await shouldFail([identity,rules]);
    Utils._setRemoteClientForTesting(fake([params,identity,rules]));
    try {
      const observed=await Loader.buildChatSystemPrompt("generic");
      data.complete_fixture={
        assembled:typeof observed.prompt==="string" &&
                  observed.prompt.includes(literal+" identity") &&
                  observed.prompt.includes(literal+" response-rules"),
        version:observed.version,
        prompt_length:observed.prompt?.length || 0
      };
    } catch(e) {
      data.complete_fixture={assembled:false,error:String(e),
                             reason:e?.clientReason || null};
    }
    // No remote nonlocal connection is permitted. This is a bounded diagnostic,
    // not a guarantee the seeded collection is immediately loaded on first run.
    Utils._clearRemoteClientForTesting();
    try {
      const records=await Promise.race([
        Utils.getRemoteRecords(),
        new Promise((_,reject)=>setTimeout(()=>reject(Error("seed_timeout")),12000))
      ]);
      data.seeded_collection={
        status:"readable",count:records.length,
        chat_params_count:records.filter(r=>r.kind==="params" &&
          r.feature==="chat").length,
        identity_count:records.filter(r=>r.kind==="module" &&
          r.feature==="chat" && r.module==="identity").length,
        response_rules_count:records.filter(r=>r.kind==="module" &&
          r.feature==="chat" && r.module==="response-rules").length
      };
    } catch(error) {
      data.seeded_collection={status:"not_readable",
        error_category:String(error).includes("seed_timeout")?
          "timeout":"unavailable"};
    }
  } finally {
    Utils._clearRemoteClientForTesting();
    if (original===null)
      Services.prefs.clearUserPref("browser.smartwindow.mistralRelease");
    else
      Services.prefs.setBoolPref("browser.smartwindow.mistralRelease",original);
  }
  done(data);
})().catch(error=>done({status:"error",failure:String(error)}));
"""

def validate(r):
    if not isinstance(r,dict) or r.get("status")!="observed":
        raise RuntimeError("AIWindow privileged browser script did not complete: "+repr(r))
    if r.get("fake_client_used") is not True:
        raise RuntimeError("No isolated Remote Settings fake used")
    if r.get("real_seed_content_not_collected") is not True:
        raise RuntimeError("Actual prompt data would escape to the report")
    if r.get("model_engine_started") is not False:
        raise RuntimeError("Unexpected model execution")
    for phase in ("empty_collection","missing_required_module","missing_params"):
        x=r.get(phase)
        if not isinstance(x,dict) or x.get("rejected") is not True or x.get("client_reason")!="promptLoadFailure":
            raise RuntimeError("Missing safety fail-closed behavior in "+phase+": "+repr(x))
    valid=r.get("complete_fixture")
    if (not isinstance(valid,dict) or valid.get("assembled") is not True or
        valid.get("version")!="10.0" or
        type(valid.get("prompt_length")) is not int or valid["prompt_length"]<40):
        raise RuntimeError("Expected complete synthetic prompt assembly, observed "+repr(valid))
    seeded=r.get("seeded_collection")
    if not isinstance(seeded,dict) or seeded.get("status") not in ("readable","not_readable"):
        raise RuntimeError("Missing real-seed diagnostic state")
    if seeded["status"]=="readable":
        for key in ("count","chat_params_count","identity_count","response_rules_count"):
            if type(seeded.get(key)) is not int or seeded[key]<0:
                raise RuntimeError("Invalid seed count "+key)
    else:
        if seeded.get("error_category") not in ("timeout","unavailable"):
            raise RuntimeError("Invalid seed diagnostic limitation")

def selftest():
    r={
      "status":"observed","fake_client_used":True,
      "real_seed_content_not_collected":True,"model_engine_started":False,
      "empty_collection":{"rejected":True,"client_reason":"promptLoadFailure"},
      "missing_required_module":{"rejected":True,"client_reason":"promptLoadFailure"},
      "missing_params":{"rejected":True,"client_reason":"promptLoadFailure"},
      "complete_fixture":{"assembled":True,"version":"10.0","prompt_length":98},
      "seeded_collection":{"status":"not_readable","error_category":"unavailable"}
    }
    validate(r)
    broken=[
      ("empty_collection",{"rejected":False,"client_reason":None}),
      ("missing_required_module",{"rejected":True,"client_reason":"other"}),
      ("missing_params",{}),
      ("complete_fixture",{"assembled":False,"version":"10.0","prompt_length":98}),
      ("complete_fixture",{"assembled":True,"version":"9.0","prompt_length":98}),
      ("seeded_collection",{"status":"readable","count":-1}),
      ("seeded_collection",{"status":"not_readable","error_category":"network_payload"}),
      ("real_seed_content_not_collected",False),
    ]
    for key,value in broken:
        changed=dict(r);changed[key]=value
        try:validate(changed)
        except RuntimeError:continue
        raise AssertionError("Unsupported AI prompt loader evidence accepted: "+key)
    return len(broken)

def run(repo,gecko):
    archive=driver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-aiwindow-offline-") as tmp:
        base=Path(tmp)
        app=base/"app";app.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(app)],check=True)
        inis=list(app.rglob("application.ini"))
        if len(inis)!=1 or "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Not a uniquely identified packaged Vulpra")
        binary=driver.select_binary(inis[0].parent)
        home=base/"home";home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"existing Firefox profile sentinel, must remain unchanged\n")
        env=os.environ.copy()
        env.update(HOME=str(home),XDG_DATA_HOME=str(home/"xdg"),
                   MOZ_HEADLESS="1",MOZ_DISABLE_NONLOCAL_CONNECTIONS="1",
                   NO_PROXY="127.0.0.1,localhost",no_proxy="127.0.0.1,localhost")
        for key in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):env.pop(key,None)
        port=driver.find_port()
        proc=None;session=None
        try:
            with (base/"geckodriver.log").open("wb") as out:
                proc=subprocess.Popen([gecko,"--host","127.0.0.1","--port",
                    str(port),"--allow-system-access"],
                    env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
                driver.wait_ready(port,proc,seconds=45)
                session_data=driver.request(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{"browserName":"firefox",
                        "moz:firefoxOptions":{"binary":str(binary),
                            "args":["-headless","-no-remote"],
                            "prefs":{
                                "browser.shell.checkDefaultBrowser":False,
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                "network.dns.disablePrefetch":True,
                                "browser.smartwindow.mistralRelease":False
                        }}}}},timeout_seconds=60)
                session=session_data["sessionId"]
                route="/session/"+session
                driver.request(port,"POST",route+"/timeouts",{"script":40000})
                driver.request(port,"POST",route+"/moz/context",{"context":"chrome"})
                response=driver.request(port,"POST",route+"/execute/async",
                    {"script":SCRIPT,"args":[]},timeout_seconds=65)
                driver.request(port,"POST",route+"/moz/context",{"context":"content"})
                validate(response)
                if sentinel.read_bytes()!=b"existing Firefox profile sentinel, must remain unchanged\n":
                    raise RuntimeError("Altered non-Vulpra Firefox profile sentinel")
                return {"schema_version":1,
                        "status":"packaged_aiwindow_fake_records_and_offline_seed_diagnostic_passed",
                        "historical_archive_name":archive.name,
                        "synthetic_client_result":response,
                        "browser_profile_isolated":True,
                        "nonlocal_connections_blocked":True,
                        "real_model_engine_started":False,
                        "no_remote_prompt_payload_stored":True,
                        "source_removal_authorized":False,
                        "offline_first_run_without_seed_verified":False,
                        "packaged_seed_removal_tested":False,
                        "marginal_tar_xz_savings_measured":None,
                        "limitations":[
                          "Source-matched critical PromptLoader and Utils blobs, but not whole browser source.",
                          "Injected synthetic client validates loader logic, not normal Remote Settings cache.",
                          "Real seed counts are bounded diagnostic only, not proof all first-run profiles synchronize.",
                          "No AI model or external API called, no actual prompts retained.",
                          "No test of removal/replacement of the packaged source seed."]}
        finally:
            if session:
                try:driver.request(port,"DELETE","/session/"+session,timeout_seconds=7)
                except (RuntimeError,OSError):pass
            if proc:
                proc.terminate()
                try:proc.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    proc.kill();proc.wait(timeout=5)

def main():
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("repo",nargs="?",type=Path)
    p.add_argument("--self-test",action="store_true")
    args=p.parse_args()
    if args.self_test:
        print("PASS:",selftest(),"AI Window failure/success evidence mutants rejected")
    if args.repo is None:
        if not args.self_test:p.error("repository required")
        return
    gecko=shutil.which("geckodriver")
    if not gecko:raise RuntimeError("Missing stock geckodriver")
    repo=args.repo.resolve()
    result=run(repo,gecko)
    dest=repo/".git/vulpra-native-build/m3-aiwindow-offline-prompt-runtime.json"
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: real Vulpra isolated AIWindow fake-client manifest acceptance; real seed counts only")
    print("SEED DIAGNOSTIC:",json.dumps(result["synthetic_client_result"]["seeded_collection"]))
    print("No real model/API, source omission, first-run fallback or compressed bytes claimed")
if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL M3 AIWindow offline prompt runtime:",e,file=sys.stderr);raise SystemExit(1)
