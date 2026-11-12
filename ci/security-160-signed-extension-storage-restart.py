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
EXPECTED_BACKGROUND = "/js/background/index.html"
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
        need(manifest.get("version") == EXPECTED_VERSION and
             manifest.get("browser_specific_settings", {}).get("gecko", {}).get("id") ==
             EXPECTED_ID and
             manifest.get("browser_action", {}).get("default_popup") == EXPECTED_POPUP and
             manifest.get("background", {}).get("page") == EXPECTED_BACKGROUND and
             "storage" in manifest.get("permissions", []),
             "Mozilla-signed XPI identity/popup/background/storage shape drifted")
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
            exercise_extension_page(port, sid, popup_after, token, "after_restart")
            wd.request(port, "POST", "/session/" + sid + "/moz/addon/uninstall",
                       {"id": signed_id}, timeout_seconds=30)
            helper.checked_addon_state(helper.addon_status(port, sid, signed_id), False)
        need(original.read_bytes() == sentinel,
             "Existing Firefox sentinel changed after second session")
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
            "actual_background_message_delivery_verified":False,
            "signed_extension_content_script_injection_verified":False,
            "whole_addon_ecosystem_certified":False,
            "sandbox_syscall_denial_executed":False,
            "safe_browsing_provider_ready":False,
            "security_current":False,
            "release_ready":False,
        }
        output.write_text(json.dumps(proof, indent=2) + "\n")
    print("PASS: signed Firefox 160 WebExtension popup + background and storage.local across full restart")
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
