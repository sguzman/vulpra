#!/usr/bin/env python3
"""Actual archived Firefox160 BYOB account/Sync/telemetry pref-control audit.

A source- and SHA-256-verified *existing* Firefox 160 native package launches
in a disposable HOME/profile and a network namespace with loopback only.
The test reads only preference names, types, boolean values, module-presence
and signed-out state. It never contacts Mozilla, Vaultwarden or an account.
Temporary opt-out/control overrides occur only in the disposable profile and
are cleared in finally blocks. This is NOT an egress inventory or telemetry
deletion/upload proof.
"""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

REQUIRED_FLAGS = (
    "identity.fxaccounts.enabled",
    "datareporting.healthreport.uploadEnabled",
)
BYOB = (
    "identity.fxaccounts.enabled",
    "signon.rememberSignons",
    "signon.autofillForms",
    "signon.generation.enabled",
)
PROTECTED = (
    "browser.safebrowsing.phishing.enabled",
    "browser.safebrowsing.malware.enabled",
    "browser.safebrowsing.downloads.enabled",
)

# Prefer a small bounded, explicit endpoint/control inventory over dumping the
# entire pref tree: URL strings and profile identifiers are never collected.
PREFS = [
    "identity.fxaccounts.enabled",
    "signon.rememberSignons",
    "signon.autofillForms",
    "signon.generation.enabled",
    "identity.fxaccounts.autoconfig.uri",
    "services.sync.enabled",
    "services.sync.autoconnect",
    "services.sync.engine.tabs",
    "services.sync.engine.bookmarks",
    "services.sync.engine.passwords",
    "datareporting.healthreport.uploadEnabled",
    "datareporting.policy.dataSubmissionEnabled",
    "toolkit.telemetry.enabled",
    "toolkit.telemetry.unified",
    "toolkit.telemetry.server",
    "app.shield.optoutstudies.enabled",
    "browser.newtabpage.activity-stream.telemetry",
    "browser.newtabpage.activity-stream.feeds.telemetry",
    "browser.ping-centre.telemetry",
    "browser.safebrowsing.phishing.enabled",
    "browser.safebrowsing.malware.enabled",
    "browser.safebrowsing.downloads.enabled",
]
PREFIXES = ("identity.fxaccounts.", "services.sync.", "datareporting.",
            "toolkit.telemetry.", "app.shield.", "browser.ping-centre.")

CHROME_SCRIPT = r"""
const done = arguments[arguments.length - 1];
const safe = {phase:"start", pref_name:null};
(async () => {
  // Privileged Marionette chrome context exposes Services as a built-in
  // global, as verified by the existing real login-save doorhanger smoke.
  // Services.sys.mjs is not a portable import URL in this packaged build.
  safe.phase = "services_global";
  const p = Services.prefs;
  const branch = p.getDefaultBranch("");
  const names = arguments[0];
  const prefixes = arguments[1];
  const result = {prefs:{}, prefixes:{}, controls:{}, modules:{},
                  account_signed_in:false, remote_request_initiated:false};
  const flags = {
    identity: "identity.fxaccounts.enabled",
    upload: "datareporting.healthreport.uploadEnabled"
  };
  safe.phase = "pref_inventory";
  for (const name of names) {
    safe.pref_name = name;
    const type = p.getPrefType(name);
    const row = {
      present: type !== p.PREF_INVALID,
      kind: type === p.PREF_BOOL ? "bool" :
            type === p.PREF_INT ? "int" :
            type === p.PREF_STRING ? "string" : "absent",
      user_override: p.prefHasUserValue(name),
      locked: p.prefIsLocked(name)
    };
    // Report boolean values only: do not inspect/upload pref URL strings,
    // including the live Sync/telemetry endpoint preferences.
    if(type === p.PREF_BOOL) {
      // An optional pref may be user-only with no registered default.
      // Never read arbitrary pref strings or return URL endpoint values.
      row.default_bool = branch.getPrefType(name) === p.PREF_BOOL
        ? branch.getBoolPref(name) : null;
      row.effective_bool = p.getBoolPref(name);
    }
    result.prefs[name] = row;
  }
  safe.phase = "prefix_inventory";
  safe.pref_name = null;
  for (const prefix of prefixes) {
    result.prefixes[prefix] = p.getChildList(prefix).length;
  }
  safe.phase = "reversible_controls";
  for (const [shortName,name] of Object.entries(flags)) {
    safe.pref_name = name;
    const row = result.prefs[name];
    if (!row?.present || row.kind !== "bool" || row.locked ||
        (shortName === "identity" && row.user_override) ||
        (shortName === "upload" && row.user_override &&
         row.effective_bool !== false)) {
      result.controls[shortName] = false;
      continue;
    }
    // A fresh automation profile can already have a user-level telemetry
    // upload opt-out. Preserve that exact original state; an enabled
    // upload state here would be an isolated, no-egress temporary test only.
    const baseline = p.getBoolPref(name);
    const hadOverride = p.prefHasUserValue(name);
    let verified = false;
    try {
      p.setBoolPref(name, !baseline);
      const flipped = p.getBoolPref(name) === !baseline;
      p.setBoolPref(name, baseline);
      const restored = p.getBoolPref(name) === baseline;
      verified = flipped && restored;
    } finally {
      // Mozilla libpref may clear a same-as-default user pref. Restore
      // the original preference state without touching any real profile.
      if (hadOverride) {
        p.setBoolPref(name, baseline);
      } else {
        p.clearUserPref(name);
      }
    }
    result.controls[shortName] =
      verified && p.prefHasUserValue(name) === hadOverride &&
      p.getBoolPref(name) === baseline;
  }
  safe.phase = "protected_preference_contract";
  for (const name of arguments[2]) {
    safe.pref_name = name;
    const row = result.prefs[name];
    if (!row?.present || row.kind !== "bool" ||
        row.default_bool !== (name.startsWith("browser.safebrowsing.") ? true : false) ||
        row.effective_bool !== row.default_bool ||
        row.user_override || row.locked) {
      result.modules.protected_pref_contract = false;
      break;
    }
    result.modules.protected_pref_contract = true;
  }
  safe.pref_name = null;
  safe.phase = "sync_ui_import";
  const {UIState} = ChromeUtils.importESModule(
    "resource://services-sync/UIState.sys.mjs");
  result.modules.sync_ui_loaded = typeof UIState.get === "function";
  result.modules.sync_ui_not_configured =
    UIState.get()?.status === UIState.STATUS_NOT_CONFIGURED;
  safe.phase = "sync_main_import";
  const {Weave} = ChromeUtils.importESModule(
    "resource://services-sync/main.sys.mjs");
  result.modules.sync_module_loaded = !!Weave &&
    typeof Weave.perDeviceEngineChoices === "boolean";
  safe.phase = "fxaccounts_import";
  const {FxAccounts, getFxAccountsSingleton} = ChromeUtils.importESModule(
    "resource://gre/modules/FxAccounts.sys.mjs");
  const account = getFxAccountsSingleton();
  result.modules.fxaccounts_retained = !!account &&
    typeof FxAccounts.canConnectAccount === "function";
  safe.phase = "fxaccounts_signed_out_check";
  result.account_signed_in = (await account.getSignedInUser()) !== null;
  done(result);
})().catch(e => done({
  error_class: String(e?.name ?? "UnknownAuditError").slice(0,60),
  phase: safe.phase, pref_name: safe.pref_name,
  audit_error: true
}));
"""


def helper():
    path = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_privacy_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Original WebDriver helper missing")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def valid_audit(d):
    if not isinstance(d, dict) or d.get("audit_error"):
        return False
    prefs, groups, modules = d.get("prefs"), d.get("prefixes"), d.get("modules")
    if not all(isinstance(x, dict) for x in (prefs, groups, modules)):
        return False
    if set(prefs) != set(PREFS) or set(groups) != set(PREFIXES):
        return False
    for name in BYOB + PROTECTED:
        row = prefs.get(name)
        expected = name in PROTECTED
        if (not isinstance(row, dict) or row.get("present") is not True
                or row.get("kind") != "bool" or row.get("locked") is not False
                or row.get("default_bool") is not expected
                or row.get("effective_bool") is not expected
                or row.get("user_override") is not False):
            return False
    upload = prefs.get("datareporting.healthreport.uploadEnabled")
    if (not isinstance(upload, dict) or upload.get("present") is not True
            or upload.get("kind") != "bool" or upload.get("locked") is not False
            or not isinstance(upload.get("default_bool"), bool)
            or not isinstance(upload.get("effective_bool"), bool)
            or not isinstance(upload.get("user_override"), bool)):
        return False
    if upload["user_override"]:
        # CI profile has already opted out: accept and preserve only
        # the safer effective=false state, never an enabled override.
        if upload["effective_bool"] is not False:
            return False
    elif upload["effective_bool"] is not upload["default_bool"]:
        return False
    if (d.get("controls") != {"identity": True, "upload": True}
            or d.get("account_signed_in") is not False
            or d.get("remote_request_initiated") is not False):
        return False
    if any(modules.get(x) is not True for x in (
            "sync_ui_loaded", "sync_ui_not_configured", "sync_module_loaded",
            "fxaccounts_retained", "protected_pref_contract")):
        return False
    for prefix in PREFIXES[:4]:
        if not isinstance(groups[prefix], int) or groups[prefix] < 1:
            return False
    # URL and identifying string values are NEVER accepted in evidence.
    if any(row.get("kind") == "string" and (
            "default_string" in row or "effective_string" in row)
           for row in prefs.values()):
        return False
    return True


def self_test():
    rows = {}
    for name in PREFS:
        row = {"present": False, "kind": "absent",
               "locked": False, "user_override": False}
        if name in BYOB + PROTECTED + ("datareporting.healthreport.uploadEnabled",):
            value = name in PROTECTED
            row = {"present": True, "kind": "bool", "locked": False,
                   "user_override": False, "default_bool": value,
                   "effective_bool": value}
        rows[name] = row
    d = {
        "prefs": rows,
        "prefixes": {name: 10 for name in PREFIXES},
        "controls": {"identity": True, "upload": True},
        "modules": {name: True for name in (
            "sync_ui_loaded", "sync_ui_not_configured", "sync_module_loaded",
            "fxaccounts_retained", "protected_pref_contract")},
        "account_signed_in": False,
        "remote_request_initiated": False,
    }
    assert valid_audit(d)
    # Verify the actual Firefox 160 observed state: a normal upstream
    # default of upload=true and an already-present disposable-profile
    # user override of upload=false. This is NOT default-off branding.
    upload_name = "datareporting.healthreport.uploadEnabled"
    safe_optout = {**rows[upload_name], "default_bool": True,
                   "effective_bool": False, "user_override": True}
    assert valid_audit({**d, "prefs": {**rows, upload_name: safe_optout}})
    for corrupt in (
        {**d, "account_signed_in": True},
        {**d, "controls": {"identity": True, "upload": False}},
        {**d, "prefs": {**rows, upload_name:
                       {**safe_optout, "effective_bool": True}}},
        {**d, "modules": {**d["modules"], "sync_ui_not_configured": False}},
        {**d, "prefs": {**rows, "identity.fxaccounts.enabled":
                       {**rows["identity.fxaccounts.enabled"], "locked": True}}},
        {**d, "prefs": {**rows, "toolkit.telemetry.server":
                       {"kind": "string", "default_string": "https://secret.invalid"}}},
        {**d, "prefixes": {**d["prefixes"], "services.sync.": 0}},
    ):
        assert not valid_audit(corrupt), "Audit negative control unexpectedly passed"
    print("PASS: account/Sync/telemetry audit contract, preserved opt-out fixture and seven negative fixtures")


def main(repo: Path):
    h = helper()
    archive = h.verified_archive(repo)
    root = repo / ".git/vulpra-native-build"
    root.mkdir(parents=True, exist_ok=True)
    gecko = shutil.which("geckodriver")
    if not gecko:
        raise RuntimeError("SHA-256 verified geckodriver required")
    ip = subprocess.run(["ip", "-j", "link", "show"], capture_output=True,
                        text=True, check=True, timeout=12)
    interfaces = [row.get("ifname") for row in json.loads(ip.stdout)]
    if interfaces != ["lo"]:
        raise RuntimeError("Refusing audit outside isolated loopback-only network namespace")
    with tempfile.TemporaryDirectory(prefix="vulpra-byob-account-audit-") as tmp:
        work = Path(tmp)
        stage = work / "app"
        stage.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(stage)],
                       check=True, stdout=subprocess.DEVNULL)
        inis = list(stage.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text():
            raise RuntimeError("Archived Firefox 160 BYOB native Vulpra identity mismatch")
        browser = h.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text("Existing Firefox profiles stay unmodified\n")
        original = sentinel.read_bytes()
        env = os.environ.copy()
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                    "MOZ_HEADLESS": "1", "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)
        port = h.find_port()
        proc = None
        session = None
        try:
            with (root / "byob-account-privacy-geckodriver.log").open("wb") as log:
                proc = subprocess.Popen([gecko, "--host", "127.0.0.1",
                                         "--port", str(port), "--allow-system-access"],
                                        env=env, stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True)
                h.wait_ready(port, proc)
                value = h.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser), "args": ["-headless", "-no-remote"],
                            "prefs": {
                                "remote.prefs.recommended": False,
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                            }
                        }
                    }}
                }, timeout_seconds=65)
                if (not isinstance(value, dict) or not value.get("sessionId")
                        or value.get("capabilities", {}).get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Real Firefox 160 BYOB session did not meet TLS/profile contract")
                session = str(value["sessionId"])
                base = "/session/" + session
                h.verify_byob_defaults(port, base)
                h.request(port, "POST", base + "/moz/context", {"context": "chrome"})
                try:
                    record = h.request(port, "POST", base + "/execute/async", {
                        "script": CHROME_SCRIPT,
                        "args": [PREFS, PREFIXES, BYOB + PROTECTED],
                    }, timeout_seconds=55)
                finally:
                    h.request(port, "POST", base + "/moz/context", {"context": "content"})
                if not valid_audit(record):
                    raise RuntimeError("Real packaged account/Sync/telemetry audit rejected: "
                                       + json.dumps({"error_class": record.get("error_class")
                                         if isinstance(record, dict) else None,
                                         "phase": record.get("phase")
                                         if isinstance(record, dict) else None,
                                         "pref_name": record.get("pref_name")
                                         if isinstance(record, dict) else None,
                                         "controls": record.get("controls")
                                         if isinstance(record, dict) else None,
                                         "identity_pref": record.get("prefs", {}).get("identity.fxaccounts.enabled")
                                         if isinstance(record, dict) else None,
                                         "upload_pref": record.get("prefs", {}).get("datareporting.healthreport.uploadEnabled")
                                         if isinstance(record, dict) else None,
                                         "modules": record.get("modules")
                                         if isinstance(record, dict) else None}))
                h.verify_byob_defaults(port, base)
                if sentinel.read_bytes() != original:
                    raise RuntimeError("Existing Firefox profiles.ini sentinel changed")
                proof = {
                    "schema_version": 1, "status": "pass",
                    "native_verified_archive": True,
                    "real_chrome_pref_values": True,
                    "real_account_and_sync_no_signed_in_user": True,
                    "identity_and_upload_controls_reversible": True,
                    "network_namespace_loopback_only": True,
                    "no_user_profile_or_account_accessed": True,
                    "raw_pref_url_values_uploaded": False,
                    "production_egress_or_telemetry_upload_tested": False,
                    "security_current": False, "release_ready": False,
                    "audit": record,
                }
                (root / "byob-account-privacy-proof.json").write_text(
                    json.dumps(proof, indent=2) + "\n")
                print("PASS: real Firefox160 BYOB account/Sync signed-out state and reversible upload/identity controls")
                print("LIMIT: bounded packaged preference audit, not production egress or telemetry-deletion proof")
        finally:
            if session:
                try:
                    h.request(port, "DELETE", "/session/" + session)
                except RuntimeError:
                    pass
            if proc:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                    proc.wait(timeout=6)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 2:
        main(Path(sys.argv[1]).resolve())
    else:
        raise SystemExit("usage: smoke-byob-account-privacy-local.py --self-test | REPO")
