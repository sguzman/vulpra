#!/usr/bin/env python3
"""Read-only Safe Browsing readiness checks on archived exact-tree Firefox 160.

Tests a real branded native browser in disposable HOME/profile. Reads only
boolean effective prefs, feature/table counts, XPCOM availability and whether
Mozilla's checkGoogleSafeBrowsingKey() accepts the v5 provider. Never prints
the API key or provider URL, never edits Safe Browsing prefs, never requests
a malicious URL or inserts a classifier entry. Not threat-detection proof.
"""
from __future__ import annotations

import hashlib
import http.server
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time


def need(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


HERE = Path(__file__).resolve().parent
HELPER = HERE / "smoke-webextension-package-local.py"


def load_helper():
    spec = importlib.util.spec_from_file_location("vulpra_wd_safebrowsing", HELPER)
    need(spec is not None and spec.loader is not None, "Missing WebDriver utility")
    imported = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = imported
    spec.loader.exec_module(imported)
    return imported


class LocalPage(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_error(404)
            return
        contents = b"<!doctype html><meta charset=utf-8><title>SafeBrowsing readiness local page</title>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(contents)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(contents)

    def log_message(self, *_args):
        return


# This runs in WebDriver's privileged CHROME context only after a real
# Firefox 160 session starts. The module is observed, never initialized or
# reconfigured by the probe. No credentials/URLs leave the browser process.
READONLY_CHROME_JS = r"""
const prefs=Services.prefs;
const bool=name=>prefs.getBoolPref(name,false);
const char=name=>prefs.getCharPref(name,'');
const flags={
  phishing:bool('browser.safebrowsing.phishing.enabled'),
  malware:bool('browser.safebrowsing.malware.enabled'),
  downloads:bool('browser.safebrowsing.downloads.enabled'),
  update:bool('browser.safebrowsing.update.enabled') ||
    prefs.getPrefType('browser.safebrowsing.update.enabled')===prefs.PREF_INVALID,
  google5:bool('browser.safebrowsing.provider.google5.enabled')
};
const tables={
  phishing:char('urlclassifier.phishTable').split(',').map(s=>s.trim()).filter(Boolean),
  malware:char('urlclassifier.malwareTable').split(',').map(s=>s.trim()).filter(Boolean),
  download_block:char('urlclassifier.downloadBlockTable').split(',').map(s=>s.trim()).filter(Boolean)
};
const overridePrefs=[
  'browser.safebrowsing.phishing.enabled',
  'browser.safebrowsing.malware.enabled',
  'browser.safebrowsing.downloads.enabled',
  'browser.safebrowsing.provider.google5.enabled',
  'urlclassifier.phishTable','urlclassifier.malwareTable',
  'urlclassifier.downloadBlockTable'
];
const user_override_count=overridePrefs.filter(n=>prefs.prefHasUserValue(n)).length;
const service=name=>{
  try {
    if(name==='db') {
      return !!Cc['@mozilla.org/url-classifier/dbservice;1']
        .getService(Ci.nsIUrlClassifierDBService);
    }
    return !!Cc['@mozilla.org/url-classifier/listmanager;1']
      .getService(Ci.nsIUrlListManager);
  }catch(e){return false;}
};
let module_import_succeeded=false, module_initialized=false,
    key_accepted=false, update_url_usable=false, gethash_url_usable=false,
    named_features=[], module_error_class='';
try {
  const {SafeBrowsing}=ChromeUtils.importESModule(
    'resource://gre/modules/SafeBrowsing.sys.mjs');
  module_import_succeeded=!!SafeBrowsing;
  module_initialized=SafeBrowsing.initialized===true;
  key_accepted=SafeBrowsing.checkGoogleSafeBrowsingKey('google5')===true;
  const provider=SafeBrowsing.providers?.google5;
  update_url_usable=typeof provider?.updateURL==='string' &&
    provider.updateURL.startsWith('https://');
  gethash_url_usable=typeof provider?.gethashURL==='string' &&
    provider.gethashURL.startsWith('https://');
  named_features=(SafeBrowsing.features||[])
    .filter(f=>['phishing','malware','downloads'].includes(f.name))
    .map(f=>({
      name:f.name,enabled:f.enabled===true,update:f.update===true,
      registered_table_count:Array.isArray(f.list)?f.list.length:0
    }));
}catch(e){module_error_class=String(e.name||'module-error').slice(0,70);}
const feature=name=>named_features.find(f=>f.name===name);
const phishing=feature('phishing'),malware=feature('malware'),downloads=feature('downloads');
return {
  test_schema_version:1,
  runtime_prefs:flags,
  expected_table_presence:{
    phishing:tables.phishing.some(n=>n.includes('phish')),
    malware:tables.malware.some(n=>n.includes('malware')),
    download_block:tables.download_block.length>0
  },
  table_counts:{
    phishing:tables.phishing.length,
    malware:tables.malware.length,
    download_block:tables.download_block.length
  },
  default_user_pref_override_count:user_override_count,
  url_classifier_db_service_available:service('db'),
  url_classifier_list_manager_service_available:service('list'),
  safe_browsing_module_imported:module_import_succeeded,
  safe_browsing_module_initialized:module_initialized,
  google5_credential_check_accepted:key_accepted,
  google5_https_update_endpoint_present:update_url_usable,
  google5_https_hash_lookup_endpoint_present:gethash_url_usable,
  runtime_features:{
    phishing:phishing||null,
    malware:malware||null,
    downloads:downloads||null
  },
  module_error_class,
  secret_values_or_endpoint_urls_returned:false,
  no_malicious_url_or_threat_update_requested_by_probe:true
};
"""


def readiness_criteria(data: dict) -> tuple[bool, list[str]]:
    need(isinstance(data, dict) and data.get("test_schema_version") == 1,
         "Malformed privileged Firefox security configuration probe")
    fields = [
        "url_classifier_db_service_available",
        "url_classifier_list_manager_service_available",
        "safe_browsing_module_imported",
        "safe_browsing_module_initialized",
        "google5_credential_check_accepted",
        "google5_https_update_endpoint_present",
        "google5_https_hash_lookup_endpoint_present",
        "secret_values_or_endpoint_urls_returned",
        "no_malicious_url_or_threat_update_requested_by_probe",
    ]
    need(all(isinstance(data.get(k), bool) for k in fields),
         "Safe Browsing service/key evidence not strictly boolean")
    need(data["secret_values_or_endpoint_urls_returned"] is False and
         data["no_malicious_url_or_threat_update_requested_by_probe"] is True,
         "Secret handling or test network scope violated")
    need(data.get("default_user_pref_override_count") == 0,
         "Test profile has unexpected Safe Browsing preference overrides")
    prefs = data.get("runtime_prefs")
    tables = data.get("expected_table_presence")
    features = data.get("runtime_features")
    need(isinstance(prefs, dict) and isinstance(tables, dict) and
         isinstance(features, dict), "Missing runtime security maps")
    reasons = []
    for name in ("phishing", "malware", "downloads", "update", "google5"):
        need(isinstance(prefs.get(name), bool), "Runtime Safe Browsing flag absent: " + name)
        if not prefs[name]:
            reasons.append("effective_" + name + "_preference_disabled")
    for name in ("phishing", "malware", "download_block"):
        need(isinstance(tables.get(name), bool), "Missing URL classifier table boolean")
        if not tables[name]:
            reasons.append("missing_" + name + "_classification_table")
    for name in ("phishing", "malware", "downloads"):
        feature = features.get(name)
        if not isinstance(feature, dict):
            reasons.append("missing_" + name + "_runtime_feature")
            continue
        for k in ("enabled", "update"):
            need(isinstance(feature.get(k), bool),
                 "Missing runtime feature state: "+name+"."+k)
            if not feature[k]:
                reasons.append(name + "_runtime_" + k + "_disabled")
        count = feature.get("registered_table_count")
        need(type(count) is int and count >= 0, "Missing runtime registered table count")
        if count == 0:
            reasons.append(name + "_runtime_table_list_empty")
    checks = {
        "url_classifier_db_service_available": "url_classifier_database_unavailable",
        "url_classifier_list_manager_service_available": "url_classifier_list_manager_unavailable",
        "safe_browsing_module_imported": "safe_browsing_module_import_failed",
        "safe_browsing_module_initialized": "safe_browsing_module_not_initialized",
        "google5_credential_check_accepted": "google5_credential_missing_or_unaccepted",
        "google5_https_update_endpoint_present": "google5_effective_https_update_endpoint_unavailable",
        "google5_https_hash_lookup_endpoint_present": "google5_effective_https_hash_lookup_unavailable",
    }
    for flag, reason in checks.items():
        if not data[flag]:
            reasons.append(reason)
    return not reasons, reasons


def self_test():
    features = {
        name: {"name": name, "enabled": True, "update": True,
               "registered_table_count": 1}
        for name in ("phishing", "malware", "downloads")
    }
    baseline = {
        "test_schema_version": 1,
        "runtime_prefs": {k: True for k in
                          ("phishing", "malware", "downloads", "update", "google5")},
        "expected_table_presence": {k: True for k in
                                    ("phishing", "malware", "download_block")},
        "default_user_pref_override_count": 0,
        "url_classifier_db_service_available": True,
        "url_classifier_list_manager_service_available": True,
        "safe_browsing_module_imported": True,
        "safe_browsing_module_initialized": True,
        "google5_credential_check_accepted": True,
        "google5_https_update_endpoint_present": True,
        "google5_https_hash_lookup_endpoint_present": True,
        "runtime_features": features,
        "secret_values_or_endpoint_urls_returned": False,
        "no_malicious_url_or_threat_update_requested_by_probe": True,
    }
    ok, reasons = readiness_criteria(baseline)
    need(ok and not reasons, "Valid Safe Browsing readiness fixture did not pass")
    for forged in (
        {**baseline, "google5_credential_check_accepted": False},
        {**baseline, "google5_https_update_endpoint_present": False},
        {**baseline, "google5_https_hash_lookup_endpoint_present": False},
        {**baseline, "runtime_prefs": {**baseline["runtime_prefs"], "phishing": False}},
        {**baseline, "expected_table_presence": {**baseline["expected_table_presence"],
                                                 "malware": False}},
        {**baseline, "runtime_features": {**features,
                                          "phishing": {**features["phishing"],
                                                       "update": False}}},
        {**baseline, "url_classifier_db_service_available": False},
    ):
        ok, reasons = readiness_criteria(forged)
        need(not ok and reasons, "Forged or disabled browser protection got green readiness")
    for malformed in (
        {**baseline, "google5_credential_check_accepted": "true"},
        {**baseline, "secret_values_or_endpoint_urls_returned": True},
        {**baseline, "default_user_pref_override_count": 1},
    ):
        try:
            readiness_criteria(malformed)
        except RuntimeError:
            continue
        raise RuntimeError("Malformed or secret-bearing readiness report accepted")
    print("PASS: seven blocked provider/configuration fixtures and three invalid/secret fixtures")


def run(repo: Path, output: Path):
    wd = load_helper()
    archive = wd.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"),
         "Refusing non-Firefox 160 native browser package")
    package_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    gecko = shutil.which("geckodriver")
    need(gecko is not None, "Checksum-pinned geckodriver missing from PATH")
    need(not output.exists(), "Refusing existing readiness proof overwrite")
    with tempfile.TemporaryDirectory(prefix="vulpra160-safebrowsing-") as temp:
        work = Path(temp)
        destination = work / "unpacked"
        destination.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(destination)],
                       check=True)
        inis = list(destination.rglob("application.ini"))
        need(len(inis) == 1 and "Name=Vulpra" in inis[0].read_text().splitlines(),
             "Unexpected native application identity")
        browser = wd.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        profile = work / "disposable-profile"
        profile.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel_contents = b"Existing Firefox user profile MUST remain untouched\n"
        sentinel.write_bytes(sentinel_contents)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), LocalPage)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        driver_port = wd.find_port()
        environment = os.environ.copy()
        environment.update({
            "HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
            "MOZ_HEADLESS": "1", "NO_PROXY": "localhost,127.0.0.1",
            "no_proxy": "localhost,127.0.0.1",
        })
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            environment.pop(name, None)
        process = None
        session_id = None
        observed = None
        try:
            with (work / "driver.log").open("wb") as log:
                process = subprocess.Popen(
                    [gecko, "--host", "127.0.0.1", "--port", str(driver_port),
                     "--allow-system-access"],
                    env=environment, stdout=log, stderr=subprocess.STDOUT,
                    start_new_session=True)
                wd.wait_ready(driver_port, process)
                session = wd.request(driver_port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox",
                        "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser),
                            "args": ["-headless", "-no-remote", "-profile", str(profile)],
                            "prefs": {
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                                "browser.shell.checkDefaultBrowser": False,
                            },
                        },
                    }},
                }, timeout_seconds=70)
                session_id = session.get("sessionId") if isinstance(session, dict) else None
                caps = session.get("capabilities", {}) if isinstance(session, dict) else {}
                need(isinstance(session_id, str) and session_id,
                     "No native Firefox browser session")
                need(caps.get("browserName") == "firefox" and
                     str(caps.get("browserVersion", "")).startswith("160.") and
                     caps.get("acceptInsecureCerts") is False,
                     "Wrong browser version or insecure certificate setting")
                need(Path(caps.get("moz:profile", "")).resolve() == profile.resolve(),
                     "Browser used something other than disposable profile")
                base = "/session/" + session_id
                wd.request(driver_port, "POST", base + "/url",
                           {"url": f"http://127.0.0.1:{server.server_port}/"},
                           timeout_seconds=35)
                wd.request(driver_port, "POST", base + "/moz/context",
                           {"context": "chrome"})
                try:
                    for _ in range(8):
                        observed = wd.request(driver_port, "POST",
                                              base + "/execute/sync",
                                              {"script": READONLY_CHROME_JS, "args": []},
                                              timeout_seconds=25)
                        need(isinstance(observed, dict),
                             "Browser privileged probe returned no Safe Browsing record")
                        if observed.get("safe_browsing_module_initialized") is True:
                            break
                        time.sleep(0.5)
                finally:
                    wd.request(driver_port, "POST", base + "/moz/context",
                               {"context": "content"})
                need(sentinel.read_bytes() == sentinel_contents,
                     "Original Firefox profile sentinel was changed")
                ready, blockers = readiness_criteria(observed)
                report = {
                    "schema_version": 1,
                    "kind": "firefox160_native_safebrowsing_effective_configuration_audit",
                    "status": "configuration_ready" if ready else "configuration_blocked",
                    "package_sha256": package_sha,
                    "native_firefox160_webdriver_and_disposable_profile_verified": True,
                    "original_firefox_profile_preserved": True,
                    "strict_webdriver_tls_configuration": True,
                    "observed": observed,
                    "configuration_readiness_gate_passed": ready,
                    "blocking_reasons": blockers,
                    "actual_threat_list_download_verified": False,
                    "actual_malicious_navigation_denied_verified": False,
                    "network_protection_coverage_certified": False,
                    "security_current": False,
                    "release_ready": False,
                    "limits": [
                        "No Google API key contents or provider URLs were recorded",
                        "No malicious URLs submitted and no threat-list download requested by this test",
                        "Operational configuration is not evidence of current downloaded threat lists",
                        "No Safe Browsing phishing/malware warning page or negative navigation exercised",
                    ],
                }
                output.write_text(json.dumps(report, indent=2) + "\n")
                print("AUDIT: real Firefox 160 Safe Browsing configuration readiness "
                      + ("PASS" if ready else "BLOCKED"), flush=True)
                if blockers:
                    print("AUDIT: non-secret blocker identifiers: "
                          + ", ".join(blockers), flush=True)
        finally:
            if session_id:
                try:
                    wd.request(driver_port, "DELETE",
                               "/session/" + session_id, timeout_seconds=12)
                except (RuntimeError, OSError):
                    pass
            if process is not None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=7)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            server.shutdown()
            server.server_close()
        need(output.exists(), "No safe structured configuration report generated")
        if report["configuration_readiness_gate_passed"] is not True:
            raise RuntimeError("Actual Firefox 160 Safe Browsing configuration readiness BLOCKED")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 3:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
