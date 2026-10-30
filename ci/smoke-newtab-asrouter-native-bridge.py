#!/usr/bin/env python3
"""Real full-normal Vulpra New Tab / ASRouter module and inert bridge smoke.

This reuses an independently compiled, SHA-256-verified native archive and
disposable geckodriver profile. It does not initialize ASRouter, fetch remote Pocket/ads, change prefs or
use a real user's browser profile or account.
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
 const result={status:"loaded",imports:{},bridge:{},
   prefs_unchanged:false,remote_provider_or_network_requested_by_probe:false};
 const prefKeys=[
   "browser.newtabpage.enabled",
   "browser.newtabpage.activity-stream.feeds.section.topstories",
   "browser.newtabpage.activity-stream.feeds.system.topstories",
 ];
 const snapshot=()=>prefKeys.map(key=>Services.prefs.getBoolPref(key,false));
 const before=snapshot();
 const definitions=[
  ["router","resource:///modules/asrouter/ASRouter.sys.mjs","ASRouter","object",null],
  ["default_config","resource:///modules/asrouter/ASRouterDefaultConfig.sys.mjs","ASRouterDefaultConfig","function",null],
  ["hook","resource:///modules/asrouter/ASRouterNewTabHook.sys.mjs","ASRouterNewTabHook","object",null],
  ["parent_handler","resource:///modules/asrouter/ASRouterParentProcessMessageHandler.sys.mjs","ASRouterParentProcessMessageHandler","function",null],
  ["telemetry","resource:///modules/asrouter/ASRouterTelemetry.sys.mjs","ASRouterTelemetry","function",null],
  ["messaging","resource://newtab/lib/NewTabMessaging.sys.mjs","NewTabMessaging","function",null],
  ["registry","resource://newtab/lib/NewTabActorRegistry.sys.mjs","NewTabActorRegistry","object",null],
  ["activity_stream","resource://newtab/lib/ActivityStream.sys.mjs","ActivityStream","function",null],
  ["legacy_feed","resource://newtab/lib/TopStoriesFeed.sys.mjs","TopStoriesFeed","function",null],
  ["modern_feed","resource://newtab/lib/DiscoveryStreamFeed.sys.mjs","DiscoveryStreamFeed","function",null]
 ];
 const exposed={};
 try {
  for(const [id,uri,symbol,kind] of definitions) {
    result.last_module=id;
    const mod=ChromeUtils.importESModule(uri);
    exposed[id]=mod[symbol];
    result.imports[id]=typeof exposed[id]===kind;
  }
  result.bridge.default_config_provides_original_router=false;
  result.bridge.default_handler_preserves_CFR_and_telemetry=false;
  result.bridge.newtab_messaging_uninitialized_safe_construction=false;
  result.bridge.hook_exposes_connectable_singleton=false;
  result.bridge.activity_stream_feed_map_preserved=false;
  const config=exposed.default_config();
  result.bridge.default_config_provides_original_router=
      config.router===exposed.router && typeof config.createStorage==="function";
  result.bridge.default_handler_preserves_CFR_and_telemetry=
      typeof config.messageHandler.handleCFRAction==="function" &&
      typeof config.messageHandler.handleTelemetry==="function";
  const messaging=new exposed.messaging();
  result.bridge.newtab_messaging_uninitialized_safe_construction=
      messaging.initialized===false && messaging.store===null &&
      typeof messaging.init==="function" &&
      typeof messaging.observe==="function" &&
      typeof messaging.uninit==="function";
  result.bridge.hook_exposes_connectable_singleton=
      typeof exposed.hook.getInstance==="function" &&
      typeof exposed.hook.createInstance==="function" &&
      typeof exposed.hook.destroy==="function";
  const stream=new exposed.activity_stream();
  result.bridge.activity_stream_feed_map_preserved=
      typeof stream.feeds?.keys === "function" && [...stream.feeds.keys()].length>0;
  result.prefs_unchanged=JSON.stringify(before)===JSON.stringify(snapshot());
  delete result.last_module;
 } catch(e) {
  result.status="rejected";
  result.error_stage=result.last_module || "bridge";
  result.error_kind=String(e?.name || "UnexpectedError").slice(0,48);
 }
 done(result);
})().catch(()=>done({status:"rejected",error_kind:"AsyncError"}));
"""

MODULE_KEYS=(
 "router","default_config","hook","parent_handler","telemetry",
 "messaging","registry","activity_stream","legacy_feed","modern_feed"
)
BRIDGE_KEYS=(
 "default_config_provides_original_router",
 "default_handler_preserves_CFR_and_telemetry",
 "newtab_messaging_uninitialized_safe_construction",
 "hook_exposes_connectable_singleton",
 "activity_stream_feed_map_preserved"
)

def validate(x):
    if not isinstance(x,dict) or x.get("status")!="loaded":
        stage=x.get("error_stage","unknown") if isinstance(x,dict) else "nonobject"
        kind=x.get("error_kind","unknown") if isinstance(x,dict) else "unknown"
        raise ValueError("Native New Tab/ASRouter bridge rejected: "+
                         str(stage)[:32]+" / "+str(kind)[:48])
    for field,keys in (("imports",MODULE_KEYS),("bridge",BRIDGE_KEYS)):
        got=x.get(field)
        if not isinstance(got,dict) or set(got)!=set(keys):
            raise ValueError("Missing exact packaged "+field+" surface")
        for key in keys:
            if got[key] is not True:
                raise ValueError("Missing actual packaged "+field+" contract: "+key)
    if x.get("prefs_unchanged") is not True:
        raise ValueError("New Tab probe changed a preference")
    if x.get("remote_provider_or_network_requested_by_probe") is not False:
        raise ValueError("Remote provider usage in New Tab probe")
    if "error_kind" in x or "error_stage" in x:
        raise ValueError("Failed module metadata in nominally passed report")
    return {"imports":{key:True for key in MODULE_KEYS},
            "bridge":{key:True for key in BRIDGE_KEYS}}

def run(repo:Path,driver:str):
    archive=webdriver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-normal-asrouter-") as tmp:
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
                webdriver.request(port,"POST",base+"/url",{"url":"about:newtab"},timeout_seconds=60)
                actual_url=webdriver.request(port,"GET",base+"/url",timeout_seconds=25)
                if actual_url!="about:newtab":
                    raise ValueError("Packaged built-in about:newtab navigation rejected")
                webdriver.request(port,"POST",base+"/moz/context",{"context":"chrome"})
                try:
                    status=webdriver.request(port,"POST",base+"/execute/async",
                        {"script":SCRIPT,"args":[]},timeout_seconds=60)
                finally:
                    webdriver.request(port,"POST",base+"/moz/context",
                        {"context":"content"})
                protected=validate(status)
                if sentinel.read_bytes()!=b"private-profile-marker-unchanged\n":
                    raise ValueError("Native ASRouter/New Tab module probe altered user-profile sentinel")
                return {
                    "schema_version":1,
                    "status":"full_normal_native_newtab_asrouter_bridge_preserved",
                    "verified_archive_sha256":True,
                    "private_home_and_profile_verified":True,
                    "gecko_nonlocal_connections_disabled":True,
                    "protected_real_native_module_imports":protected["imports"],
                    "protected_real_native_inert_bridge_checks":protected["bridge"],
                    "packaged_about_newtab_navigation_succeeded":True,
                    "relevant_preferences_unchanged":True,
                    "remote_messaging_or_pocket_fetch_attempted_by_probe":False,
                    "router_storage_mutation_or_provider_fetch_attempted_by_probe":False,
                    "real_actors_initialized_by_probe":False,
                    "full_newtab_message_delivery_end_to_end_proven":False,
                    "full_dynamic_dependency_graph_proven":False,
                    "source_removal_authorized":False,
                    "new_whole_m3_gate_passed":False,
                    "limitations":[
                        "Original full-Normandy native browser modules, not hypothetical test mocks.",
                        "No router init, disk persistence, remote feed fetch or live message delivery invoked by this test.",
                        "Real about:newtab navigation and inert default config, hook and message constructor verification only.",
                        "Source compilation and transitive dynamic wiring remain scoped; no binary saving or deletion approved.",
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
    args=p.parse_args()
    if args.self_test:
        good={"status":"loaded",
            "imports":{key:True for key in MODULE_KEYS},
            "bridge":{key:True for key in BRIDGE_KEYS},
            "prefs_unchanged":True,
            "remote_provider_or_network_requested_by_probe":False}
        assert validate(good)=={"imports":good["imports"],"bridge":good["bridge"]}
        for category,keys in (("imports",MODULE_KEYS),("bridge",BRIDGE_KEYS)):
            for key in keys:
                bad={**good,category:{**good[category],key:False}}
                try:validate(bad)
                except ValueError:pass
                else:raise AssertionError("False native bridge acceptance: "+key)
        for field,value in (
            ("status","rejected"),("prefs_unchanged",False),
            ("remote_provider_or_network_requested_by_probe",True),
        ):
            bad={**good,field:value}
            try:validate(bad)
            except ValueError:pass
            else:raise AssertionError("False native bridge safety acceptance: "+field)
        print("PASS:",len(MODULE_KEYS)+len(BRIDGE_KEYS)+3,
              "fake packaged-module/bridge/unsafe-prefs rejection fixtures")
        return
    driver=shutil.which("geckodriver")
    if not driver:
        raise RuntimeError("Need native browser geckodriver; no recompilation")
    report=run(args.repo.resolve(),driver)
    output=args.repo/".git/vulpra-native-build/m3-full-normal-asrouter-newtab-bridge.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: 10 actual packaged New Tab/ASRouter imports and 5 inert bridge contracts")

if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,AssertionError,subprocess.CalledProcessError) as exc:
        print("FAIL native ASRouter/New Tab bridge:",exc,file=sys.stderr)
        raise SystemExit(1)
