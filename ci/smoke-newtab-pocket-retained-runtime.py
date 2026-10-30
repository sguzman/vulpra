#!/usr/bin/env python3
"""Real packaged lean-Normandy Vulpra New Tab feed registration smoke.

This is *not* a normal full-Normandy binary: it is the source-matched
opt-in runner-free archive, with built-in New Tab/Pocket untouched.
No external recommendation fetches, login or real user profile permitted.
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
return {
  mode: "retained_full_newtab_in_optin_normandy_free_browser",
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
  "no_feed_initialized_or_fetched_by_probe"
)

def validate(page,registration):
    if not isinstance(page,dict) or not page.get("document") or (
        not isinstance(page.get("url"),str) or
        not page["url"].startswith(("about:newtab","about:home"))
    ):
        raise ValueError("Real packaged New Tab did not show an HTML document")
    if not isinstance(registration,dict) or registration.get("mode")!=(
        "retained_full_newtab_in_optin_normandy_free_browser"):
        raise ValueError("Unexpected New Tab source/variant or import failure")
    for k in CHECKS:
        if registration.get(k) is not True:
            raise ValueError("Missing protected New Tab feed/factory: "+k)
    return {key:True for key in CHECKS}

def run(repo:Path,driver:str):
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
                  "status":"real_normandy_free_native_newtab_feed_factories_retained",
                  "verified_archive_sha256":True,
                  "private_browser_profile_verified":True,
                  "gecko_nonlocal_connection_guard_enabled":True,
                  "full_default_normandy_runner_present":False,
                  "protected_newtab_factories_and_registry":checked,
                  "newtab_document_loaded":True,
                  "pocket_recommendation_data_downloaded_by_probe":False,
                  "actual_legacy_fallback_invoked":False,
                  "actual_modern_content_fetch_invoked":False,
                  "runtime_signed_in_user_data_used":False,
                  "complete_current_head_native_binary_proven":False,
                  "source_removal_authorized":False,
                  "new_m3_whole_gate_passed":False,
                  "limitations":[
                    "Actual compiled opt-in Normandy-free browser, not a normal full-Normandy archive.",
                    "Proves packaged feed factory/registration and about:newtab document, not live Pocket recommendations.",
                    "Does not activate the legacy DiscoveryStream-disabled fallback or remote sponsored sources.",
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
    a=p.parse_args()
    if a.self_test:
        good={k:True for k in CHECKS}
        good["mode"]="retained_full_newtab_in_optin_normandy_free_browser"
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
    report=run(a.repo.resolve(),driver)
    output=a.repo/".git/vulpra-native-build/m3-newtab-pocket-preservation.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: real opt-in Normandy-free native browser retains protected New Tab feed factories")

if __name__=="__main__":
    try:main()
    except (RuntimeError,OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL packaged New Tab Pocket factory smoke:",e,file=sys.stderr)
        raise SystemExit(1)
