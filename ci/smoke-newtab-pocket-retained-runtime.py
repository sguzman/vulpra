#!/usr/bin/env python3
"""Real packaged Vulpra New Tab feed registration and fallback smoke.

Used for a checksum-verified archived runner-free build and for an original
full-Normandy archived baseline. The workflow must authenticate the source,
identity and physical package variant before this script executes.
No recommendation fetches, login or real user profile are requested.
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
spec=importlib.util.spec_from_file_location("vulpra_pocket_webdriver",
    ROOT/"smoke-webextension-package-local.py")
webdriver=importlib.util.module_from_spec(spec)
spec.loader.exec_module(webdriver)

SCRIPT=r"""
const {ActivityStream} = ChromeUtils.importESModule(
  "resource://newtab/lib/ActivityStream.sys.mjs");
const {TopStoriesFeed} = ChromeUtils.importESModule(
  "resource://newtab/lib/TopStoriesFeed.sys.mjs");
const {DiscoveryStreamFeed} = ChromeUtils.importESModule(
  "resource://newtab/lib/DiscoveryStreamFeed.sys.mjs");
const {AppConstants} = ChromeUtils.importESModule(
  "resource://gre/modules/AppConstants.sys.mjs");
// Exercise both factory-map branches on *new, uninitialized* instances.
// This is the testing.shouldInitializeFeeds flag, NOT the separate real
// TopStoriesFeed legacy/DiscoveryStream-disabled network fallback.
const gate="browser.newtabpage.activity-stream.testing.shouldInitializeFeeds";
const hadUserValue=Services.prefs.prefHasUserValue(gate);
const previous=Services.prefs.getBoolPref(gate,true);
let keys, minimal;
try {
  Services.prefs.setBoolPref(gate,true);
  keys=[...new ActivityStream().feeds.keys()];
  Services.prefs.setBoolPref(gate,false);
  minimal=[...new ActivityStream().feeds.keys()];
} finally {
  if (hadUserValue) Services.prefs.setBoolPref(gate,previous);
  else Services.prefs.clearUserPref(gate);
}
// Call the *actual shipped TopStoriesFeed method* with a deliberately
// inert object. Its init/properties hooks are counters, never network fetches.
const makeFake = (loaded=false) => ({
  storiesLoaded:loaded,
  propertiesInitialized:false,
  discoveryStreamEnabled:null,
  propertiesCalls:0,
  initCalls:0,
  store:{getState:()=>({Prefs:{values:new Proxy({}, {get:()=>false})}})},
  initializeProperties(){this.propertiesInitialized=true;this.propertiesCalls++;},
  init(){this.initCalls++;}
});
const broken=makeFake();
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  broken,{dsPref:"{invalid",userPref:true});
const disabled=makeFake();
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  disabled,{dsPref:'{"enabled":false}',userPref:true});
const loaded=makeFake(true);
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  loaded,{dsPref:'{"enabled":false}',userPref:true});
const userOff=makeFake();
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  userOff,{dsPref:'{"enabled":false}',userPref:false});
// Check the real modern-vs-legacy selection without initializing either feed.
const modernSelected=makeFake();
modernSelected.store.getState=()=>({Prefs:{values:{
  "discoverystream.enabled":true,
  "feeds.section.topstories":true
}}});
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  modernSelected,{dsPref:'{"enabled":true}',userPref:true});
// JSON-enabled Discovery Stream with the system pref off must select legacy.
const modernSystemOff=makeFake();
TopStoriesFeed.prototype.lazyLoadTopStories.call(
  modernSystemOff,{dsPref:'{"enabled":true}',userPref:true});
// Repeated legacy fallback must initialize properties only once.
const legacyRepeated=makeFake();
for (let i=0; i<2; i++) {
  TopStoriesFeed.prototype.lazyLoadTopStories.call(
    legacyRepeated,{dsPref:'{"enabled":false}',userPref:true});
}
// Exercise shipped modern DiscoveryStream getters with *inert preference
// state only*. No feed constructor, network request, cache I/O or dispatch.
const configGetter=Object.getOwnPropertyDescriptor(
  DiscoveryStreamFeed.prototype,"config")?.get;
const sponsorGetter=Object.getOwnPropertyDescriptor(
  DiscoveryStreamFeed.prototype,"showSponsoredStories")?.get;
const storiesGetter=Object.getOwnPropertyDescriptor(
  DiscoveryStreamFeed.prototype,"showStories")?.get;
if ([configGetter,sponsorGetter,storiesGetter].some(f=>typeof f!=="function")) {
  throw new Error("Packaged modern feed getter absent");
}
const modernState=(raw,enabled,sponsored=true,systemSponsored=true,
                   systemStories=true,userStories=true)=>({
  _prefCache:{},
  store:{getState:()=>({Prefs:{values:{
    "discoverystream.config":raw,
    "discoverystream.enabled":enabled,
    "showSponsored":sponsored,
    "system.showSponsored":systemSponsored,
    "feeds.system.topstories":systemStories,
    "feeds.section.topstories":userStories
  }}})}
});
const modern=modernState('{"enabled":true,"layout":"modern"}',true);
const modernConfig=configGetter.call(modern);
// A cached config must not reread (or unexpectedly execute) the store.
modern.store.getState=()=>{throw new Error("Modern config unexpectedly reread");};
const modernCached=configGetter.call(modern)===modernConfig;
const disabledSystem=configGetter.call(modernState('{"enabled":true}',false));
const disabledJson=configGetter.call(modernState('{"enabled":false}',true));
// Invalid JSON deliberately hits the shipped parse-error fallback, with no
// live pref modification and no feed initialization.
const malformed=configGetter.call(modernState("{invalid",true));
const bothSponsored=modernState("{}",true,true,true);
const userOptOut=modernState("{}",true,false,true);
const systemOptOut=modernState("{}",true,true,false);
const storiesOn=modernState("{}",true,true,true,true,true);
const storiesOff=modernState("{}",true,true,true,false,true);
const userStoriesOff=modernState("{}",true,true,true,true,false);
const experiment={changes:0,pocketNewTabExperimentChanged(){this.changes++;}};
DiscoveryStreamFeed.prototype.onPocketExperimentUpdated.call(
  experiment,null,"feature-experiment-loaded");
DiscoveryStreamFeed.prototype.onPocketExperimentUpdated.call(
  experiment,null,"feature-rollout-loaded");
const ignoredExperimentChanges=experiment.changes===0;
DiscoveryStreamFeed.prototype.onPocketExperimentUpdated.call(
  experiment,null,"feature-updated");
return {
  mode: "retained_builtin_newtab_feed_factories",
  legacy_malformed_config_stubbed_init:
    broken.discoveryStreamEnabled===false &&
    broken.propertiesCalls===1 && broken.initCalls===1,
  legacy_disabled_config_stubbed_init:
    disabled.discoveryStreamEnabled===false &&
    disabled.propertiesCalls===1 && disabled.initCalls===1,
  legacy_stories_already_loaded_skip:
    loaded.propertiesCalls===0 && loaded.initCalls===0,
  legacy_user_pref_disabled_skip:
    userOff.propertiesCalls===0 && userOff.initCalls===0,
  legacy_modern_enabled_avoids_old_properties:
    modernSelected.discoveryStreamEnabled===true &&
    modernSelected.propertiesCalls===0 && modernSelected.initCalls===1,
  legacy_modern_system_pref_off_uses_fallback:
    modernSystemOff.discoveryStreamEnabled===false &&
    modernSystemOff.propertiesCalls===1 && modernSystemOff.initCalls===1,
  legacy_repeated_fallback_does_not_reinitialize_properties:
    legacyRepeated.discoveryStreamEnabled===false &&
    legacyRepeated.propertiesCalls===1 && legacyRepeated.initCalls===2,
  modern_config_enabled_and_keeps_layout:
    modernConfig.enabled===true && modernConfig.layout==="modern",
  modern_config_disabled_by_system_pref:disabledSystem.enabled===false,
  modern_config_disabled_by_json:disabledJson.enabled===false,
  modern_malformed_json_fallback:
    Object.keys(malformed).length===1 && !malformed.enabled,
  modern_config_pref_cache_preserved:modernCached,
  modern_sponsor_requires_both_prefs:
    sponsorGetter.call(bothSponsored)===true &&
    sponsorGetter.call(userOptOut)===false &&
    sponsorGetter.call(systemOptOut)===false,
  modern_stories_respect_system_pref:
    storiesGetter.call(storiesOn)===true &&
    storiesGetter.call(storiesOff)===false,
  modern_stories_respect_user_optout_without_space_override:
    storiesGetter.call(userStoriesOff)===false,
  modern_experiment_notifications_guarded:
    ignoredExperimentChanges && experiment.changes===1,
  legacy_registered:keys.includes("feeds.system.topstories"),
  modern_registered:keys.includes("feeds.discoverystreamfeed"),
  top_sites_registered:keys.includes("feeds.system.topsites"),
  preferences_registered:keys.includes("feeds.prefs"),
  sponsored_adsfeed_retained:keys.includes("feeds.adsfeed"),
  legacy_factory_export:typeof TopStoriesFeed === "function",
  modern_factory_export:typeof DiscoveryStreamFeed === "function",
  newtab_adsfeed_omission_disabled:!AppConstants.VULPRA_NO_NEWTAB_ADSFEED,
  testing_minimal_feed_map: minimal.length === 2 &&
    minimal.includes("feeds.system.topsites") &&
    minimal.includes("feeds.prefs") &&
    !minimal.includes("feeds.system.topstories") &&
    !minimal.includes("feeds.discoverystreamfeed"),
  no_feed_initialized_or_fetched_by_probe:true
};
"""

CHECKS=(
  "legacy_registered","modern_registered","top_sites_registered",
  "preferences_registered","sponsored_adsfeed_retained",
  "legacy_factory_export","modern_factory_export",
  "newtab_adsfeed_omission_disabled","testing_minimal_feed_map",
  "legacy_malformed_config_stubbed_init",
  "legacy_disabled_config_stubbed_init",
  "legacy_stories_already_loaded_skip","legacy_user_pref_disabled_skip",
  "legacy_modern_enabled_avoids_old_properties",
  "legacy_modern_system_pref_off_uses_fallback",
  "legacy_repeated_fallback_does_not_reinitialize_properties",
  "no_feed_initialized_or_fetched_by_probe",
  "modern_config_enabled_and_keeps_layout",
  "modern_config_disabled_by_system_pref",
  "modern_config_disabled_by_json",
  "modern_malformed_json_fallback",
  "modern_config_pref_cache_preserved",
  "modern_sponsor_requires_both_prefs",
  "modern_stories_respect_system_pref",
  "modern_stories_respect_user_optout_without_space_override",
  "modern_experiment_notifications_guarded"
)

def validate(page,registration):
    if not isinstance(page,dict) or not page.get("document") or (
        not isinstance(page.get("url"),str) or
        not page["url"].startswith(("about:newtab","about:home"))
    ):
        raise ValueError("Real packaged New Tab did not show an HTML document")
    if not isinstance(registration,dict) or registration.get("mode")!=(
        "retained_builtin_newtab_feed_factories"):
        raise ValueError("Unexpected New Tab source/variant or import failure")
    for k in CHECKS:
        if registration.get(k) is not True:
            raise ValueError("Missing protected New Tab feed/factory: "+k)
    return {key:True for key in CHECKS}

def run(repo:Path,driver:str,variant="normandy-free"):
    if variant not in ("normandy-free","full-normandy"):
        raise ValueError("Unrecognized audited native browser variant")
    archive=webdriver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-newtab-fallback-") as tmp:
        root=Path(tmp)
        dest=root/"app"
        dest.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(dest)],
            check=True,stdout=subprocess.DEVNULL)
        ini=list(dest.rglob("application.ini"))
        if len(ini)!=1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
            raise ValueError("Non-Vulpra or ambiguous native browser package")
        native=webdriver.select_binary(ini[0].parent)
        home=root/"home";home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"personal-profile-sentinel-remains-unchanged\n")
        env=os.environ.copy()
        env.update(HOME=str(home), XDG_DATA_HOME=str(home/"xdg"),
            MOZ_HEADLESS="1", MOZ_DISABLE_NONLOCAL_CONNECTIONS="1",
            NO_PROXY="127.0.0.1,localhost",no_proxy="127.0.0.1,localhost")
        for key in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):env.pop(key,None)
        port=webdriver.find_port()
        proc=None
        session=None
        try:
            with (root/"geckodriver.log").open("wb") as log:
                proc=subprocess.Popen([driver,"--host","127.0.0.1",
                    "--port",str(port),"--allow-system-access"],
                    env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                webdriver.wait_ready(port,proc)
                v=webdriver.request(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox",
                        "moz:firefoxOptions":{
                            "binary":str(native),"args":["-headless","-no-remote"],
                            "prefs":{
                              "app.update.enabled":False,
                              "extensions.update.enabled":False,
                              "network.dns.disablePrefetch":True,
                              "browser.shell.checkDefaultBrowser":False,
                              "datareporting.healthreport.uploadEnabled":False,
                              "datareporting.policy.dataSubmissionEnabled":False,
                            }}}}},timeout_seconds=80)
                session=v["sessionId"]
                base="/session/"+session
                webdriver.request(port,"POST",base+"/url",{"url":"about:newtab"},
                    timeout_seconds=40)
                page=webdriver.request(port,"POST",base+"/execute/sync",{
                    "script":"return {url:location.href,document:!!document.documentElement,ready:document.readyState};",
                    "args":[]},timeout_seconds=25)
                webdriver.request(port,"POST",base+"/moz/context",{"context":"chrome"})
                try:
                    reg=webdriver.request(port,"POST",base+"/execute/sync",{
                        "script":SCRIPT,"args":[]},timeout_seconds=30)
                finally:
                    webdriver.request(port,"POST",base+"/moz/context",{"context":"content"})
                checked=validate(page,reg)
                if sentinel.read_bytes()!=b"personal-profile-sentinel-remains-unchanged\n":
                    raise ValueError("Browser altered unrelated profile sentinel")
                return {
                  "schema_version":1,
                  "status":("real_normal_full_normandy_native_newtab_factories_retained"
                      if variant=="full-normandy" else
                      "real_normandy_free_native_newtab_feed_factories_retained"),
                  "variant":variant,
                  "verified_archive_sha256":True,
                  "private_browser_profile_verified":True,
                  "gecko_nonlocal_connection_guard_enabled":True,
                  "full_default_normandy_runner_present":variant=="full-normandy",
                  "protected_newtab_factories_and_registry":checked,
                  "newtab_document_loaded":True,
                  "pocket_recommendation_data_downloaded_by_probe":False,
                  "actual_legacy_fallback_invoked":False,
                  "real_shipped_legacy_method_exercised_with_inert_side_effect_hooks":True,
                  "actual_modern_content_fetch_invoked":False,
                  "runtime_signed_in_user_data_used":False,
                  "complete_current_head_native_binary_proven":False,
                  "source_removal_authorized":False,
                  "new_m3_whole_gate_passed":False,
                  "limitations":[
                    ("Archived normal full-Normandy browser, not a complete current-main binary."
                     if variant=="full-normandy" else
                     "Archived compiled opt-in Normandy-free browser, not a normal full-Normandy archive."),
                    "Proves packaged feed factory/registration and about:newtab document, not live Pocket recommendations.",
                    "Legacy TopStoriesFeed method runs with inert hooks; modern DiscoveryStream getters run on inert preference state. Neither test initializes a feed or fetches remote stories.",
                    "No native source deletion, caller graph closure, cloud network or repeatable package savings.",
                  ]
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
    p.add_argument("--variant",choices=("normandy-free","full-normandy"),
                   default="normandy-free")
    a=p.parse_args()
    if a.self_test:
        good={k:True for k in CHECKS}
        good["mode"]="retained_builtin_newtab_feed_factories"
        page={"url":"about:newtab","document":True}
        assert validate(page,good)=={k:True for k in CHECKS}
        for key in CHECKS:
            invalid=dict(good);invalid[key]=False
            try:validate(page,invalid)
            except ValueError:pass
            else:raise AssertionError("False New Tab factory acceptance: "+key)
        for wrong in ({"url":"https://example.org/","document":True},
                      {"url":"about:newtab","document":False}):
            try:validate(wrong,good)
            except ValueError:pass
            else:raise AssertionError("False packaged New Tab document accepted")
        print("PASS:",len(CHECKS)+2,"New Tab fake-fallback/registration fixtures")
        return
    driver=shutil.which("geckodriver")
    if not driver:raise RuntimeError("Need installed geckodriver; cannot fake native test")
    report=run(a.repo.resolve(),driver,a.variant)
    output=a.repo/".git/vulpra-native-build/m3-newtab-pocket-preservation.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: real",a.variant,"native browser retains",len(CHECKS),
          "protected New Tab feed checks")

if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL packaged New Tab Pocket factory smoke:",e,file=sys.stderr)
        raise SystemExit(1)
