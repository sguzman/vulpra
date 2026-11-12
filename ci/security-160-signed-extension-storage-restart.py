#!/usr/bin/env python3
"""Real Firefox 160 signed WebExtension storage/background restart probe.

Reuses the previously authenticated, SHA-256-verified native archive and a
Mozilla-signed exact-version XPI. Only disposable HOME/profile. A signed
extension page exercises its own WebExtension storage API before and after
separate complete Firefox processes; this is not general add-on compatibility,
a sandbox denial or release security certification.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import zipfile


HERE = Path(__file__).resolve().parent
HELPER = HERE / "security-160-persistent-extension-restart.py"
spec = importlib.util.spec_from_file_location("vulpra_signed_restart_helper", HELPER)
if spec is None or spec.loader is None:
    raise RuntimeError("Signed persistent-extension helper is missing")
helper = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = helper
spec.loader.exec_module(helper)
wd = helper.wd

EXPECTED_ID = "@testpilot-containers"
EXPECTED_VERSION = "8.4.0"
EXPECTED_POPUP = "popup.html"
EXPECTED_BACKGROUND = "js/background/index.html"
STORAGE_KEY = "__vulpra_ci_signed_extension_restart_probe"


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_probe_result(data, phase):
    need(isinstance(data, dict) and data.get("status") == "pass",
         "Signed extension page did not return a valid pass")
    for name in ("extension_identity_matches", "extension_page_context",
                 "background_page_loaded", "storage_local_api_available",
                 "storage_marker_correct", "no_unexpected_storage_overwrite"):
        need(data.get(name) is True, "Signed extension " + phase + " check failed: " + name)
    need(data.get("phase") == phase, "Signed extension probe phase mismatch")
    need(data.get("secret_token_returned") is False,
         "Extension probe must not copy marker token into evidence")
    return True


def verify_signed_message_result(value, phase):
    if not isinstance(value, dict) or value.get("status") != "pass":
        # No random marker, actual URLs or credentials in CI diagnostics.
        safe = {key: value.get(key) for key in (
            "status", "phase", "stage", "extension_identity_matches",
            "background_shortcuts_response", "content_message_sent",
            "error_class", "matching_local_tab_count") if key in value} if isinstance(value, dict) else {}
        raise RuntimeError("Signed background/content check did not pass: " +
                           json.dumps(safe, sort_keys=True))
    need(value.get("phase") == phase, "Signed message phase mismatch")
    need(value.get("extension_identity_matches") is True,
         "Signed message sender identity mismatch")
    need(value.get("background_shortcuts_response") is True,
         "No real signed background listener response")
    need(value.get("content_message_sent") is True,
         "Signed content tab message was not accepted")
    need(value.get("token_in_report") is False,
         "Signed message proof leaked probe marker")
    return True


def test_signed_message_negatives():
    valid = {
        "status": "pass", "phase": "before_restart",
        "extension_identity_matches": True,
        "background_shortcuts_response": True,
        "content_message_sent": True,
        "token_in_report": False,
    }
    verify_signed_message_result(valid, "before_restart")
    failures = 0
    forged = (
        None, [], {},
        {**valid, "status": "timeout"},
        {**valid, "phase": "after_restart"},
        {**valid, "extension_identity_matches": False},
        {**valid, "background_shortcuts_response": False},
        {**valid, "background_shortcuts_response": "true"},
        {**valid, "content_message_sent": False},
        {**valid, "content_message_sent": "true"},
        {**valid, "token_in_report": True},
        {**valid, "token_in_report": "false"},
    )
    for item in forged:
        try:
            verify_signed_message_result(item, "before_restart")
        except RuntimeError:
            failures += 1
        else:
            raise RuntimeError("Forged signed background/content test accepted")
    need(failures == 12, "Signed message fixture count drifted")
    print("PASS: 12 forged signed background/content message results rejected")


def signed_background_and_content_probe(port, sid, popup_url, server, token, phase):
    """Real background request/reply and signed content-script event/DOM proof.

    Keep a localhost document alive in its own tab; use the signed
    extension's unmodified popup to send messages. Never inject helper JS
    into the inspected web page other than a read-only DOM assertion.
    """
    need(phase in ("before_restart", "after_restart"), "Unknown content probe phase")
    base = "/session/" + sid
    page_url = f"http://127.0.0.1:{server.server_port}/extension"
    marker = "Vulpra signed content proof " + token
    wd.request(port, "POST", base + "/url", {"url": page_url}, timeout_seconds=35)
    first = wd.request(port, "GET", base + "/window")
    need(isinstance(first, str) and first, "No original document window")
    initial = wd.request(port, "POST", base + "/execute/sync", {
        "script": """return {
            url:document.URL, title:document.title,
            clean:document.querySelectorAll('.container-notification').length===0
        };""",
        "args": [],
    })
    need(isinstance(initial, dict) and initial.get("url") == page_url and
         initial.get("title") == "Vulpra extension smoke" and
         initial.get("clean") is True,
         "Localhost fixture unready or already contains signed content notification")
    created = wd.request(port, "POST", base + "/window/new", {"type": "tab"})
    popup_handle = created.get("handle") if isinstance(created, dict) else None
    need(isinstance(popup_handle, str) and popup_handle != first,
         "Did not create separate isolated extension popup tab")
    try:
        wd.request(port, "POST", base + "/url", {"url": popup_url}, timeout_seconds=35)
        reply = wd.request(port, "POST", base + "/execute/async", {
            "script": """
              const url=arguments[0], marker=arguments[1], phase=arguments[2];
              const done=arguments[arguments.length-1];
              let sent=false;
              const complete=(value)=>{
                if(sent)return;
                sent=true;clearTimeout(timer);done(value);
              };
              const timer=setTimeout(()=>complete({status:"timeout",phase}),14000);
              (async()=>{
                const result={status:"fail",phase,stage:"init",token_in_report:false};
                try{
                  result.extension_identity_matches=(
                    location.protocol==="moz-extension:" &&
                    browser.runtime.id==="@testpilot-containers");
                  if(!result.extension_identity_matches){complete(result);return;}
                  result.stage="background_request";
                  // The 8.4.0 signed background message handler implements
                  // getShortcuts as a real async storage-backed read.
                  const shortcuts=await browser.runtime.sendMessage({
                    method:"getShortcuts"
                  });
                  result.background_shortcuts_response=!!shortcuts &&
                    typeof shortcuts==="object" &&
                    Object.hasOwn(shortcuts,"open_container_0") &&
                    Object.hasOwn(shortcuts,"reopen_in_container_0") &&
                    typeof shortcuts.open_container_0==="string";
                  if(!result.background_shortcuts_response){complete(result);return;}
                  result.stage="tab_lookup";
                  // tabs.query({url}) uses WebExtension match-pattern rules;
                  // a localhost URL with an explicit port is not a valid
                  // pattern match. Enumerate only this disposable test
                  // profile's tabs and compare exact full URL instead.
                  const allTabs=await browser.tabs.query({});
                  const tabs=allTabs.filter(tab=>tab.url===url);
                  result.matching_local_tab_count=tabs.length;
                  if(tabs.length!==1 || !Number.isInteger(tabs[0].id)){
                    complete(result);return;
                  }
                  result.stage="tab_message";
                  // Signed content script from the XPI listens for this
                  // message and creates an actual DOM notification.
                  await browser.tabs.sendMessage(tabs[0].id,{text:marker});
                  result.content_message_sent=true;
                  result.status="pass";
                  result.stage="done";
                }catch(error){
                  result.status="error";
                  result.error_class=String(error?.name||"Error").slice(0,32);
                }
                complete(result);
              })();
            """,
            "args": [page_url, marker, phase],
        }, timeout_seconds=23)
        verify_signed_message_result(reply, phase)
        wd.request(port, "POST", base + "/window", {"handle": first})
        deadline = time.monotonic() + 13
        matched = False
        while time.monotonic() < deadline:
            state = wd.request(port, "POST", base + "/execute/sync", {
                "script": """
                  const expected=arguments[0];
                  return {
                    url:document.URL,
                    matched:[...document.querySelectorAll('.container-notification')]
                      .some(el=>el.textContent===expected)
                  };
                """,
                "args": [marker],
            })
            need(isinstance(state, dict) and state.get("url") == page_url,
                 "WebDriver navigated away from signed content-script fixture")
            if state.get("matched") is True:
                matched = True
                break
            time.sleep(0.2)
        need(matched, "Signed add-on content script did not create matching notification")
    finally:
        # Close only the temporary popup tab. Do not uninstall the add-on
        # from within its own extension document (Marionette would die).
        wd.request(port, "POST", base + "/window", {"handle": popup_handle})
        wd.request(port, "DELETE", base + "/window")
        wd.request(port, "POST", base + "/window", {"handle": first})
    print("PASS: real signed extension background request/reply and content-script DOM "
          + phase, flush=True)


def self_test():
    valid = {
        "status": "pass", "phase": "before_restart",
        "extension_identity_matches": True, "extension_page_context": True,
        "background_page_loaded": True, "storage_local_api_available": True,
        "storage_marker_correct": True, "no_unexpected_storage_overwrite": True,
        "secret_token_returned": False,
    }
    verify_probe_result(valid, "before_restart")
    rejected = 0
    for bad in (
        {**valid, "status": "fail"},
        {**valid, "phase": "after_restart"},
        {**valid, "background_page_loaded": False},
        {**valid, "storage_marker_correct": False},
        {**valid, "storage_marker_correct": "true"},
        {**valid, "extension_identity_matches": False},
        {**valid, "extension_page_context": False},
        {**valid, "storage_local_api_available": False},
        {**valid, "no_unexpected_storage_overwrite": False},
        {**valid, "secret_token_returned": True},
        {**valid, "secret_token_returned": "false"},
        {},
    ):
        try:
            verify_probe_result(bad, "before_restart")
        except RuntimeError:
            rejected += 1
        else:
            raise RuntimeError("Forged extension storage/background result accepted")
    need(rejected == 12, "Negative fixture count drifted")
    print("PASS: signed extension storage/background checker rejected 12 forged fixtures")
    test_signed_message_negatives()


def extension_popup_url(port, sid, signed_id):
    base = "/session/" + sid
    wd.request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        url = wd.request(port, "POST", base + "/execute/sync", {
            "script": """
              const id = arguments[0];
              const serialized = Services.prefs.getStringPref(
                "extensions.webextensions.uuids", "");
              const uuids = JSON.parse(serialized);
              const uuid = uuids[id];
              return typeof uuid === "string" &&
                /^[0-9a-f-]{36}$/.test(uuid)
                ? "moz-extension://" + uuid + "/popup.html" : null;
            """,
            "args": [signed_id],
        })
    finally:
        wd.request(port, "POST", base + "/moz/context", {"context": "content"})
    need(isinstance(url, str) and url.startswith("moz-extension://") and
         url.endswith("/popup.html"), "Signed extension lacks persistent popup origin")
    # Private navigation URL only, never written to archived evidence.
    return url


def exercise_extension_page(port, sid, popup_url, token, phase):
    need(phase in ("before_restart", "after_restart"), "Unknown probe phase")
    base = "/session/" + sid
    wd.request(port, "POST", base + "/url", {"url": popup_url}, timeout_seconds=35)
    result = wd.request(port, "POST", base + "/execute/async", {
        "script": """
          const token = arguments[0], phase = arguments[1];
          const finish = arguments[arguments.length - 1];
          const timeout = setTimeout(() => finish({status:"timeout"}), 14000);
          (async () => {
            const reply = {status:"fail", phase, secret_token_returned:false};
            try {
              const runtime = typeof browser === "object" &&
                browser && browser.runtime;
              reply.extension_identity_matches = !!runtime &&
                runtime.id === "@testpilot-containers";
              reply.extension_page_context =
                location.protocol === "moz-extension:" &&
                location.pathname === "/popup.html";
              reply.storage_local_api_available = !!(browser?.storage?.local);
              const bg = await runtime.getBackgroundPage();
              reply.background_page_loaded =
                !!bg && String(bg.location?.pathname) === "/js/background/index.html";
              if (!reply.extension_identity_matches ||
                  !reply.extension_page_context ||
                  !reply.storage_local_api_available ||
                  !reply.background_page_loaded) {
                clearTimeout(timeout); finish(reply); return;
              }
              const key = "__vulpra_ci_signed_extension_restart_probe";
              const old = await browser.storage.local.get(key);
              if (phase === "before_restart") {
                reply.no_unexpected_storage_overwrite =
                  !Object.prototype.hasOwnProperty.call(old, key);
                if (reply.no_unexpected_storage_overwrite) {
                  await browser.storage.local.set({[key]:token});
                }
                const current = await browser.storage.local.get(key);
                reply.storage_marker_correct = current[key] === token;
              } else {
                reply.no_unexpected_storage_overwrite = true;
                reply.storage_marker_correct = old[key] === token;
                if (reply.storage_marker_correct) {
                  await browser.storage.local.remove(key);
                  const after = await browser.storage.local.get(key);
                  reply.storage_marker_correct =
                    !Object.prototype.hasOwnProperty.call(after,key);
                }
              }
              reply.status = Object.entries(reply).every(([k,v]) =>
                k === "status" || k === "phase" ||
                k === "secret_token_returned" || v === true) ? "pass" : "fail";
            } catch (_) { reply.status = "error"; }
            clearTimeout(timeout);
            finish(reply);
          })();
        """,
        "args": [token, phase],
    }, timeout_seconds=24)
    verify_probe_result(result, phase)
    print("PASS: signed extension popup, background page and storage.local " + phase,
          flush=True)


def run(repo, signed_xpi, digest, output):
    need(not output.exists(), "Refusing existing proof overwrite")
    driver = shutil.which("geckodriver")
    need(driver is not None, "Checksum-pinned geckodriver missing")
    archive = wd.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"),
         "Wrong archived Firefox version")
    archive_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
    helper.checked_sha256(signed_xpi, digest)
    with zipfile.ZipFile(signed_xpi) as xpi:
        names = xpi.namelist()
        need("manifest.json" in names and any(x.startswith("META-INF/") for x in names),
             "Signed XPI manifest/signing metadata absent")
        manifest = json.loads(xpi.read("manifest.json"))
        print("AUDIT: signed AMO XPI manifest structure " + json.dumps({
            "version": manifest.get("version"),
            "browser_specific_gecko_id": manifest.get(
                "browser_specific_settings", {}).get("gecko", {}).get("id"),
            "legacy_gecko_id": manifest.get(
                "applications", {}).get("gecko", {}).get("id"),
            "popup": manifest.get("browser_action", {}).get("default_popup"),
            "background_page": manifest.get("background", {}).get("page"),
            "storage_permission": "storage" in manifest.get("permissions", []),
        }, sort_keys=True), flush=True)
        need(manifest.get("version") == EXPECTED_VERSION and
             manifest.get("browser_specific_settings", {}).get("gecko", {}).get("id") ==
             EXPECTED_ID and
             manifest.get("browser_action", {}).get("default_popup") == EXPECTED_POPUP and
             manifest.get("background", {}).get("page") == EXPECTED_BACKGROUND and
             "storage" in manifest.get("permissions", []),
             "Mozilla-signed XPI identity/popup/background/storage shape drifted")
        need("js/content-script.js" in names and
             "js/background/messageHandler.js" in names and
             any(record.get("js") == ["js/content-script.js"] and
                 "<all_urls>" in record.get("matches", []) and
                 record.get("run_at") == "document_start"
                 for record in manifest.get("content_scripts", [])),
             "Signed XPI missing required original content/background message code")
    with tempfile.TemporaryDirectory(prefix="vulpra160-signed-storage-") as temp:
        root = Path(temp)
        package = root / "package"
        package.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(package)],
                       check=True, timeout=80)
        apps = list(package.rglob("application.ini"))
        need(len(apps) == 1 and "Name=Vulpra" in apps[0].read_text().splitlines(),
             "Wrong signed-storage native browser identity")
        binary = wd.select_binary(apps[0].parent)
        home = root / "home"
        home.mkdir()
        profile = root / "disposable-vulpra-profile"
        profile.mkdir()
        original = home / ".mozilla/firefox/profiles.ini"
        original.parent.mkdir(parents=True)
        sentinel = b"unrelated Firefox profile must not be changed by signed storage QA\n"
        original.write_bytes(sentinel)
        token = secrets.token_hex(24)
        server = wd.http.server.ThreadingHTTPServer(("127.0.0.1", 0), wd.LocalPage)
        server.paths = []
        threading.Thread(target=server.serve_forever, daemon=True).start()
        signed_id = None
        popup_before = None
        with helper.session(driver, binary, profile, home,
                            root / "geckodriver-1.log", "signed storage first") as (port,sid):
            signed_id = wd.request(
                port, "POST", "/session/" + sid + "/moz/addon/install",
                {"path": str(signed_xpi), "temporary": False}, timeout_seconds=40)
            need(signed_id == EXPECTED_ID, "Signed extension returned unexpected ID")
            state = helper.checked_addon_state(
                helper.addon_status(port, sid, signed_id), True, True)
            need(state.get("version") == EXPECTED_VERSION and
                 state.get("app_disabled") is False and
                 state.get("user_disabled") is False,
                 "Signed extension not active at first launch")
            popup_before = extension_popup_url(port, sid, signed_id)
            signed_background_and_content_probe(
                port, sid, popup_before, server, token, "before_restart")
            exercise_extension_page(port, sid, popup_before, token, "before_restart")
        need(original.read_bytes() == sentinel,
             "Existing Firefox sentinel changed after first session")
        with helper.session(driver, binary, profile, home,
                            root / "geckodriver-2.log", "signed storage second") as (port,sid):
            state = helper.checked_addon_state(
                helper.addon_status(port, sid, signed_id), True, True)
            need(state.get("version") == EXPECTED_VERSION and
                 state.get("app_disabled") is False and
                 state.get("user_disabled") is False,
                 "Signed extension not active after restart")
            popup_after = extension_popup_url(port, sid, signed_id)
            need(popup_after == popup_before,
                 "Signed extension moz-extension origin changed across profile restart")
            signed_background_and_content_probe(
                port, sid, popup_after, server, token, "after_restart")
            exercise_extension_page(port, sid, popup_after, token, "after_restart")
            # Never uninstall an extension while Marionette is executing in
            # that very extension page: its document/global would disappear.
            wd.request(port, "POST", "/session/" + sid + "/url",
                       {"url": "about:blank"}, timeout_seconds=20)
            wd.request(port, "POST", "/session/" + sid + "/moz/addon/uninstall",
                       {"id": signed_id}, timeout_seconds=30)
            helper.checked_addon_state(helper.addon_status(port, sid, signed_id), False)
        need(original.read_bytes() == sentinel,
             "Existing Firefox sentinel changed after second session")
        server.shutdown()
        server.server_close()
        proof = {
            "schema_version":1,
            "status":"pass",
            "native_package_sha256":archive_hash,
            "signed_xpi_sha256":digest,
            "signed_extension_id":EXPECTED_ID,
            "signed_extension_version":EXPECTED_VERSION,
            "real_signed_addon_persisted_after_full_restart":True,
            "same_disposable_profile_across_two_full_browser_processes":True,
            "signed_popup_executed_extension_webdriver_js_before_and_after_restart":True,
            "signed_background_page_loaded_before_and_after_restart":True,
            "signed_storage_local_marker_written_before_restart":True,
            "signed_storage_local_marker_read_and_removed_after_restart":True,
            "signed_extension_origin_unchanged_across_restart":True,
            "signed_addon_uninstalled_after_test":True,
            "other_firefox_profile_sentinel_preserved":True,
            "actual_background_message_delivery_verified":True,
            "signed_extension_content_script_injection_verified":True,
            "signed_background_getShortcuts_response_before_and_after_restart":True,
            "signed_content_script_tab_message_notified_dom_before_and_after_restart":True,
            "whole_addon_ecosystem_certified":False,
            "sandbox_syscall_denial_executed":False,
            "safe_browsing_provider_ready":False,
            "security_current":False,
            "release_ready":False,
        }
        output.write_text(json.dumps(proof, indent=2) + "\n")
    print("PASS: signed Firefox 160 WebExtension popup + background, storage.local, real message roundtrip and content-script DOM across full restart")
    print("LIMIT: one AMO extension; no general compatibility, Safe Browsing or sandbox denial proof")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 5:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(),
                sys.argv[3], Path(sys.argv[4]).resolve())
        else:
            raise RuntimeError(
                "Usage: SCRIPT --self-test OR SCRIPT REPO SIGNED_XPI SHA256 OUTPUT_JSON")
    except (RuntimeError, ValueError, OSError, json.JSONDecodeError,
            zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        raise SystemExit(1)
