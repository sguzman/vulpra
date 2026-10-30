#!/usr/bin/env python3
"""Read-only normal packaged Vulpra Sync/FxA/extension import smoke.

Uses checksum-verified historic *normal* browser and disposable geckodriver
HOME/profile. It neither authenticates a user nor contacts remote FxA/Sync,
executes a sync, or modifies the user-owned browser/source. This is not proof
of a current-source rebuilt binary or cloud synchronization behavior.
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
spec=importlib.util.spec_from_file_location("vulpra_sync_webdriver",
    ROOT/"smoke-webextension-package-local.py")
webdriver=importlib.util.module_from_spec(spec)
spec.loader.exec_module(webdriver)

# Only scalar, non-identifying API status booleans cross from privileged JS.
SCRIPT=r"""
const done=arguments[arguments.length-1];
(async () => {
  const result = {
    status:"loaded",
    sync_ui_module:false,
    sync_ui_default_not_configured:false,
    weave_lazy_module:false,
    fxa_singleton:false,
    fxa_no_signed_in_account:false,
    extension_storage_sync_loaded:false,
    accounts_glue_module:false,
    firefox_view_controller:false,
    network_or_account_login_attempted:false,
  };
  try {
    result.last_module="sync_ui";
    const {UIState}=ChromeUtils.importESModule(
      "resource://services-sync/UIState.sys.mjs");
    result.sync_ui_module = typeof UIState.get === "function" &&
      UIState.STATUS_NOT_CONFIGURED === "not_configured";
    const state = UIState.get();
    result.sync_ui_default_not_configured =
      state && state.status === UIState.STATUS_NOT_CONFIGURED;

    result.last_module="weave";
    const {Weave} = ChromeUtils.importESModule(
      "resource://services-sync/main.sys.mjs");
    result.weave_lazy_module = !!Weave && typeof Weave === "object" &&
      typeof Weave.perDeviceEngineChoices === "boolean";

    result.last_module="fxaccounts";
    const {FxAccounts, getFxAccountsSingleton} = ChromeUtils.importESModule(
      "resource://gre/modules/FxAccounts.sys.mjs");
    const fxAccounts=getFxAccountsSingleton();
    result.fxa_singleton = !!fxAccounts &&
      typeof fxAccounts.getSignedInUser === "function" &&
      typeof FxAccounts.canConnectAccount === "function";
    // Local profile lookup only; no login, token requests or sync attempt.
    const existingUser=await fxAccounts.getSignedInUser();
    result.fxa_no_signed_in_account=existingUser === null;

    result.last_module="extension_storage";
    const {ExtensionStorageSyncKinto, extensionStorageSyncKinto}=
      ChromeUtils.importESModule(
        "resource://gre/modules/ExtensionStorageSyncKinto.sys.mjs");
    result.extension_storage_sync_loaded =
      typeof ExtensionStorageSyncKinto === "function" &&
      !!extensionStorageSyncKinto;

    result.last_module="accounts_glue";
    const {AccountsGlue}=ChromeUtils.importESModule(
      "resource:///modules/AccountsGlue.sys.mjs");
    result.accounts_glue_module = !!AccountsGlue &&
      typeof AccountsGlue.init === "function" &&
      typeof AccountsGlue.observe === "function";

    result.last_module="firefox_view";
    const {SyncedTabsController}=ChromeUtils.importESModule(
      "resource:///modules/SyncedTabsController.sys.mjs");
    result.firefox_view_controller=
      typeof SyncedTabsController === "function";
  } catch (error) {
    result.status="rejected";
    result.error_category=String(error && error.name || "ModuleImportFailure").slice(0,60);
    // Do not preserve stack, email, profile paths or account state.
  }
  done(result);
})().catch(() => done({status:"rejected",
  error_category:"UnexpectedAsyncError"}));
"""

EXPECTED_KEYS=(
    "sync_ui_module",
    "sync_ui_default_not_configured",
    "weave_lazy_module",
    "fxa_singleton",
    "fxa_no_signed_in_account",
    "extension_storage_sync_loaded",
    "accounts_glue_module",
    "firefox_view_controller",
)

def validate(observed):
    if not isinstance(observed,dict) or observed.get("status")!="loaded":
        stage=observed.get("last_module","unknown") if isinstance(observed,dict) else "nonobject"
        category=observed.get("error_category","unknown") if isinstance(observed,dict) else "unknown"
        raise ValueError("Packaged Sync/FxAccounts import stage rejected: "+
                         str(stage)[:32]+" / "+str(category)[:32])
    for key in EXPECTED_KEYS:
        if observed.get(key) is not True:
            raise ValueError("Missing protected packaged Sync/FxA boundary: "+key)
    if observed.get("network_or_account_login_attempted") is not False:
        raise ValueError("Unexpected network/account login claim")
    if "error_category" in observed:
        raise ValueError("Unexpected error category on accepted runtime")
    return {key:True for key in EXPECTED_KEYS}

def run(repo:Path,driver:str):
    archive=webdriver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-sync-archive-") as tmp:
        root=Path(tmp)
        extracted=root/"unpacked"
        extracted.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(extracted)],
            check=True,stdout=subprocess.DEVNULL)
        ini=list(extracted.rglob("application.ini"))
        if len(ini)!=1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
            raise ValueError("Ambiguous or non-Vulpra native package")
        binary=webdriver.select_binary(ini[0].parent)
        home=root/"disposable-home"
        home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"unrelated profile stays unmodified\n")
        env=os.environ.copy()
        env.update({
            "HOME":str(home),"XDG_DATA_HOME":str(home/"xdg"),
            "MOZ_HEADLESS":"1","MOZ_DISABLE_NONLOCAL_CONNECTIONS":"1",
            "NO_PROXY":"127.0.0.1,localhost",
            "no_proxy":"127.0.0.1,localhost"})
        for key in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):
            env.pop(key,None)
        port=webdriver.find_port()
        proc=None
        session=None
        try:
            with (root/"geckodriver.log").open("wb") as logfile:
                proc=subprocess.Popen([driver,"--host","127.0.0.1",
                    "--port",str(port),"--allow-system-access"],
                    env=env,stdout=logfile,stderr=subprocess.STDOUT,
                    start_new_session=True)
                webdriver.wait_ready(port,proc)
                session_desc=webdriver.request(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox",
                        "moz:firefoxOptions":{
                            "binary":str(binary),
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
                    }}
                },timeout_seconds=80)
                session=session_desc["sessionId"]
                base="/session/"+session
                webdriver.request(port,"POST",base+"/timeouts",{"script":45000})
                webdriver.request(port,"POST",base+"/moz/context",{"context":"chrome"})
                try:
                    observed=webdriver.request(port,"POST",base+"/execute/async",
                        {"script":SCRIPT,"args":[]},timeout_seconds=55)
                finally:
                    webdriver.request(port,"POST",base+"/moz/context",{"context":"content"})
                summary=validate(observed)
                if sentinel.read_bytes()!=b"unrelated profile stays unmodified\n":
                    raise ValueError("Native browser changed unrelated profile")
                return {
                    "schema_version":1,
                    "status":"historical_normal_native_sync_fxa_module_smoke_passed",
                    "archive_sha256_verified":True,
                    "private_home_and_profile_verified":True,
                    "nonlocal_gecko_connections_blocked":True,
                    "account_credentials_or_user_profile_provided":False,
                    "any_login_or_remote_sync_attempted_by_probe":False,
                    "modules_verified":summary,
                    "actual_sync_upload_or_account_login_proven":False,
                    "current_head_complete_native_binary_proven":False,
                    "whole_m3_gate_passed":False,
                    "source_removal_authorized":False,
                    "limitations":[
                        "This is a historical normal browser binary, not an exact current HEAD native build.",
                        "Seven protected source module/blob paths are checked independently by CI.",
                        "Module import and empty-profile state do not prove network sync or storage.sync behavior.",
                        "The source contracts are not a complete runtime dependency map.",
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
    a=argparse.ArgumentParser()
    a.add_argument("repo",type=Path,nargs="?",default=Path.cwd())
    a.add_argument("--self-test",action="store_true")
    ns=a.parse_args()
    if ns.self_test:
        good={"status":"loaded","network_or_account_login_attempted":False,
              **{x:True for x in EXPECTED_KEYS}}
        assert validate(good)=={x:True for x in EXPECTED_KEYS}
        for key in EXPECTED_KEYS:
            bad=dict(good);bad[key]=False
            try:validate(bad)
            except ValueError:continue
            raise AssertionError("Accepted missing protected Sync boundary: "+key)
        for field,value in (("status","rejected"),("network_or_account_login_attempted",True)):
            bad=dict(good);bad[field]=value
            try:validate(bad)
            except ValueError:continue
            raise AssertionError("Accepted unsafe assertion: "+field)
        print("PASS:",len(EXPECTED_KEYS)+2,"offline native report safety fixtures")
        return
    driver=shutil.which("geckodriver")
    if not driver:
        raise RuntimeError("Geckodriver required; no native recompilation attempted")
    result=run(ns.repo.resolve(),driver)
    report=ns.repo/".git/vulpra-native-build/m3-sync-fxa-archive-runtime.json"
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(result,indent=2)+"\n")
    print("PASS: private normal Vulpra Sync/FxA/extension module runtime")
    print("Protected modules:",list(result["modules_verified"]))

if __name__=="__main__":
    try:main()
    except (AssertionError,ValueError,OSError,RuntimeError,subprocess.CalledProcessError) as exc:
        print("FAIL packaged Sync/FxAccounts smoke:",exc,file=sys.stderr)
        raise SystemExit(1)
