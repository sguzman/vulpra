#!/usr/bin/env python3
"""Bounded HTTP request attempt / endpoint-pref survey for archived Vulpra 160.

A real, checksum-verified native Firefox starts with disposable HOME/profile,
inside a Linux network namespace containing only loopback, with no external
routes. A temporary in-browser http-on-modify-request observer counts request
categories while a synthetic local HTTP fetch proves the observer is working.
The three arms run in fresh separate browser processes/profiles. Only the
middle arm disables the Push WebSocket connection in its *throwaway* profile.

Only category counts, known preference names and boolean state are returned.
Do not upload raw URLs, hostnames, query strings, credentials, ping data,
extension metadata, raw log files or personal profile data.

This is a limited observation window, NOT a complete startup capture, claims
about production egress, no-telemetry proof, deletion-policy test, or approval
to remove Sync, FxA, Mozilla provider integrations or Safe Browsing.
"""
from __future__ import annotations

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
from threading import Thread

ENDPOINT_PREFS = (
    "identity.fxaccounts.autoconfig.uri",
    "identity.fxaccounts.remote.root",
    "identity.fxaccounts.remote.profile.uri",
    "services.sync.tokenServerURI",
    "services.sync.serverURL",
    "toolkit.telemetry.server",
    "datareporting.healthreport.documentServerURI",
    "browser.ping-centre.production.endpoint",
    "app.normandy.api_url",
)
CATEGORIES = (
    "local", "mozilla_account", "mozilla_sync", "mozilla_telemetry",
    "mozilla_other", "google_provider", "other_external",
)
# Source-supported host families from current repository browser/app/profile/
# firefox.js and modules/libpref/init/all.js. These are hypothesis classes,
# NOT confirmed network consumers or a source match against the compiled 160.
OTHER_FAMILIES = (
    "webextension_storage_sync", "remote_settings", "addon_services",
    "normandy", "merino", "safebrowsing_lookup", "region_connectivity",
    "push_notifications", "mozilla_other_unresolved",
)
PHASES = ("positive_control", "early_idle", "late_idle")
URL_CLASSES = (*CATEGORIES, "absent", "empty", "unparseable", "non_http", "unreadable")
BYOB = (
    "identity.fxaccounts.enabled", "signon.rememberSignons",
    "signon.autofillForms", "signon.generation.enabled",
)
PROTECTED = (
    "browser.safebrowsing.phishing.enabled",
    "browser.safebrowsing.malware.enabled",
    "browser.safebrowsing.downloads.enabled",
)

SCRIPT = r"""
const done = arguments[arguments.length - 1];
const ciUrl = arguments[0];
const endpointNames = arguments[1];
const keys = arguments[2];
const safe = {phase:"init"};
(async () => {
  safe.phase = "prefs_global";
  const p = Services.prefs;  // privileged Marionette global
  const branch = p.getDefaultBranch("");
  const pushName = "dom.push.connection.enabled";
  safe.phase = "push_pref_state";
  const pushSetting = {
    default_value: branch.getBoolPref(pushName),
    effective_value: p.getBoolPref(pushName),
    user_override: p.prefHasUserValue(pushName),
    locked: p.prefIsLocked(pushName)
  };
  const categories = [
    "local", "mozilla_account", "mozilla_sync", "mozilla_telemetry",
    "mozilla_other", "google_provider", "other_external"
  ];
  const counts = Object.fromEntries(categories.map(x => [x, 0]));
  const requested = {seen:0, observed_local_probe:false};
  const phaseNames = ["positive_control", "early_idle", "late_idle"];
  const phaseCounts = Object.fromEntries(phaseNames.map(x => [
    x, Object.fromEntries(categories.map(c => [c, 0]))
  ]));
  const otherFamilies = [
    "webextension_storage_sync", "remote_settings", "addon_services",
    "normandy", "merino", "safebrowsing_lookup", "region_connectivity",
    "push_notifications", "mozilla_other_unresolved"
  ];
  const familyCounts = Object.fromEntries(otherFamilies.map(x => [x, 0]));
  let observedPhase = "positive_control";
  // Only fixed category names cross into reports. Never return the hostname.
  const otherFamily = raw => {
    let host;
    try { host = new URL(raw).hostname.toLowerCase(); }
    catch (_e) { return "mozilla_other_unresolved"; }
    const isHost = x => host === x || host.endsWith("." + x);
    if (isHost("webextensions.settings.services.mozilla.com"))
      return "webextension_storage_sync";
    if (isHost("firefox.settings.services.mozilla.com") ||
        isHost("settings.services.mozilla.com"))
      return "remote_settings";
    if (isHost("addons.mozilla.org"))
      return "addon_services";
    if (isHost("normandy.cdn.mozilla.net") ||
        isHost("normandy.content-signature.mozilla.org") ||
        isHost("normandy.services.mozilla.com"))
      return "normandy";
    if (isHost("merino.services.mozilla.com") ||
        isHost("ohttp-gateway-merino.services.mozilla.com"))
      return "merino";
    if (isHost("shavar.services.mozilla.com"))
      return "safebrowsing_lookup";
    if (isHost("location.services.mozilla.com") ||
        isHost("detectportal.firefox.com") ||
        isHost("mitmdetection.services.mozilla.com"))
      return "region_connectivity";
    if (isHost("push.services.mozilla.com"))
      return "push_notifications";
    return "mozilla_other_unresolved";
  };
  const classify = raw => {
    if (!raw) return "empty";
    let uri;
    try { uri = new URL(raw); } catch { return "unparseable"; }
    if (!["http:", "https:"].includes(uri.protocol)) return "non_http";
    const host = uri.hostname.toLowerCase();
    if (["127.0.0.1", "localhost", "[::1]"].includes(host)) return "local";
    if (host === "accounts.firefox.com" ||
        host.endsWith(".accounts.firefox.com")) return "mozilla_account";
    if (host === "token.services.mozilla.com" ||
        host.endsWith(".sync.services.mozilla.com") ||
        host === "sync.services.mozilla.com") return "mozilla_sync";
    if (host.endsWith(".telemetry.mozilla.org") ||
        host === "incoming.telemetry.mozilla.org") return "mozilla_telemetry";
    const mozilla = [
      "mozilla.org", "mozilla.com", "mozilla.net", "firefox.com",
      "firefoxusercontent.com"
    ];
    if (mozilla.some(x => host === x || host.endsWith("." + x)))
      return "mozilla_other";
    const google = ["google.com", "googleapis.com", "gstatic.com"];
    if (google.some(x => host === x || host.endsWith("." + x)))
      return "google_provider";
    return "other_external";
  };
  safe.phase = "endpoint_pref_inventory";
  const prefixes = endpointNames.map(name => {
    safe.pref_name = name;  // known audited key only, never pref value
    const type = p.getPrefType(name);
    const row = {
      name,
      present: type !== p.PREF_INVALID,
      kind: type === p.PREF_STRING ? "string" :
            type === p.PREF_BOOL ? "bool" :
            type === p.PREF_INT ? "int" : "absent",
      locked: p.prefIsLocked(name),
      user_override: p.prefHasUserValue(name),
      default_class: "absent",
      effective_class: "absent"
    };
    if (type === p.PREF_STRING) {
      // Never return the literal value. The hostname (and, critically,
      // its URL path, userInfo and query) do not cross this boundary.
      const safeClass = (prefBranch, prefName) => {
        try { return classify(prefBranch.getStringPref(prefName)); }
        catch (_e) {
          // Some legacy/complex string preferences reject getStringPref
          // but permit getCharPref. Never return the actual URL.
          try { return classify(prefBranch.getCharPref(prefName)); }
          catch (_ignored) { return "unreadable"; }
        }
      };
      row.effective_class = safeClass(p, name);
      if (branch.getPrefType(name) === p.PREF_STRING)
        row.default_class = safeClass(branch, name);
    }
    return row;
  });
  safe.phase = "bool_pref_contract";
  const settings = Object.fromEntries(keys.map(name => {
    safe.pref_name = name;
    return [name, {present:p.getPrefType(name)===p.PREF_BOOL,
                   default_value:branch.getBoolPref(name, false),
                   effective_value:p.getBoolPref(name, false),
                   locked:p.prefIsLocked(name),
                   user_override:p.prefHasUserValue(name)}];
  }));
  safe.pref_name = null;
  safe.phase = "sync_ui_import";
  const {UIState} = ChromeUtils.importESModule(
    "resource://services-sync/UIState.sys.mjs");
  safe.phase = "fxaccounts_import";
  const {getFxAccountsSingleton} = ChromeUtils.importESModule(
    "resource://gre/modules/FxAccounts.sys.mjs");
  safe.phase = "signed_out_account";
  const signedOut = (await getFxAccountsSingleton().getSignedInUser()) === null;
  safe.phase = "sync_ui_status";
  const syncUnconfigured = UIState.get()?.status === UIState.STATUS_NOT_CONFIGURED;

  safe.phase = "observer_setup";
  const ciHost = new URL(ciUrl).hostname;
  let removed = false;
  const observer = {
    observe(subject, topic) {
      if (topic !== "http-on-modify-request") return;
      try {
        const channel = subject.QueryInterface(Ci.nsIHttpChannel);
        const uri = channel.URI;
        const url = uri?.spec;
        if (!url) return;
        const kind = classify(url);
        if (!Object.hasOwn(counts, kind)) return;
        counts[kind] += 1;
        phaseCounts[observedPhase][kind] += 1;
        if (kind === "mozilla_other")
          familyCounts[otherFamily(url)] += 1;
        requested.seen += 1;
        if (kind === "local" && uri.host === ciHost &&
            uri.pathQueryRef === "/ci-observer-positive")
          requested.observed_local_probe = true;
      } catch (_e) {
        // Ignore non-HTTP subjects, without writing exception details.
      }
    },
    QueryInterface: ChromeUtils.generateQI(["nsIObserver"])
  };
  Services.obs.addObserver(observer, "http-on-modify-request");
  safe.phase = "observer_active";
  let localFetchOk = false;
  try {
    safe.phase = "local_control";
    const response = await fetch(ciUrl, {cache:"no-store", redirect:"error"});
    localFetchOk = response.status === 204;
    safe.phase = "early_idle";
    observedPhase = "early_idle";
    await new Promise(resolve => setTimeout(resolve, 1800));
    safe.phase = "late_idle";
    observedPhase = "late_idle";
    await new Promise(resolve => setTimeout(resolve, 8000));
  } finally {
    safe.phase = "observer_cleanup";
    Services.obs.removeObserver(observer, "http-on-modify-request");
    removed = true;
  }
  safe.phase = "report";
  // Do not claim cleanup merely because a finally block exists: the callback
  // fires only AFTER removeObserver has returned successfully.
  return done({
    account_signed_out: signedOut,
    sync_ui_unconfigured: syncUnconfigured,
    synthetic_local_fetch_ok: localFetchOk,
    synthetic_local_request_observed: requested.observed_local_probe,
    requests_observed: requested.seen,
    request_category_counts: counts,
    push_connection_pref: pushSetting,
    observer_phase_counts: phaseCounts,
    mozilla_other_family_counts: familyCounts,
    configured_observation_ms: {early_idle: 1800, late_idle: 8000},
    endpoint_prefs: prefixes,
    preference_contract: settings,
    observer_removed_in_finally: removed,
    network_namespace_loopback_only: true,
    raw_urls_in_report: false,
    production_request_delivery_verified: false
  });
})().catch(err => done({
  audit_failed: true, failed_phase: safe.phase,
  pref_name: safe.pref_name ?? null,
  error_class: String(err?.name || "Error").slice(0,40)
}));
"""


class Receiver(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/ci-observer-positive":
            self.send_error(404)
            return
        self.send_response(204)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *_args):
        pass


def valid(d):
    if not isinstance(d, dict) or d.get("audit_failed"):
        return False
    for name in ("account_signed_out", "sync_ui_unconfigured",
                 "synthetic_local_fetch_ok", "synthetic_local_request_observed",
                 "observer_removed_in_finally",
                 "network_namespace_loopback_only"):
        if d.get(name) is not True:
            return False
    for name in ("raw_urls_in_report", "production_request_delivery_verified"):
        if d.get(name) is not False:
            return False
    counts = d.get("request_category_counts")
    if (not isinstance(counts, dict) or set(counts) != set(CATEGORIES)
            or any(type(n) is not int or n < 0 or n > 100000 for n in counts.values())
            or counts["local"] < 1):
        return False
    push = d.get("push_connection_pref")
    if (not isinstance(push, dict) or set(push) != {
            "default_value", "effective_value", "user_override", "locked"}
            or type(push["default_value"]) is not bool
            or push["default_value"] is not True
            or type(push["effective_value"]) is not bool
            or type(push["user_override"]) is not bool
            or push["locked"] is not False):
        return False
    total = d.get("requests_observed")
    if type(total) is not int or total != sum(counts.values()):
        return False
    phase_counts = d.get("observer_phase_counts")
    family_counts = d.get("mozilla_other_family_counts")
    if (not isinstance(phase_counts, dict) or set(phase_counts) != set(PHASES)
            or not isinstance(family_counts, dict)
            or set(family_counts) != set(OTHER_FAMILIES)):
        return False
    for phase in PHASES:
        row = phase_counts[phase]
        if (not isinstance(row, dict) or set(row) != set(CATEGORIES)
                or any(type(n) is not int or n < 0 or n > 100000
                       for n in row.values())):
            return False
    if phase_counts["positive_control"]["local"] < 1:
        return False
    if any(sum(phase_counts[phase][kind] for phase in PHASES) != counts[kind]
           for kind in CATEGORIES):
        return False
    if (any(type(n) is not int or n < 0 or n > 100000
            for n in family_counts.values())
            or sum(family_counts.values()) != counts["mozilla_other"]):
        return False
    if d.get("configured_observation_ms") != {
            "early_idle": 1800, "late_idle": 8000}:
        return False
    rows = d.get("endpoint_prefs")
    if (not isinstance(rows, list) or len(rows) != len(ENDPOINT_PREFS)
            or [row.get("name") for row in rows if isinstance(row, dict)]
                != list(ENDPOINT_PREFS)):
        return False
    for row in rows:
        if (set(row) != {"name", "present", "kind", "locked",
                         "user_override", "default_class", "effective_class"}
                or not isinstance(row["present"], bool)
                or not isinstance(row["locked"], bool)
                or not isinstance(row["user_override"], bool)
                or row["kind"] not in {"string", "bool", "int", "absent"}
                or row["default_class"] not in URL_CLASSES
                or row["effective_class"] not in URL_CLASSES):
            return False
    prefs = d.get("preference_contract")
    if not isinstance(prefs, dict) or set(prefs) != set(BYOB + PROTECTED):
        return False
    for name, row in prefs.items():
        expected = name in PROTECTED
        if (not isinstance(row, dict) or set(row) != {
                "present", "default_value", "effective_value",
                "locked", "user_override"} or
                row != {"present": True, "default_value": expected,
                        "effective_value": expected, "locked": False,
                        "user_override": False}):
            return False
    # No raw URLs, hosts or network request payloads can enter the report.
    encoded = json.dumps(d, sort_keys=True)
    if any(x in encoded for x in ("http://", "https://", "://", "password")):
        return False
    return True


def self_test():
    d = {
        "account_signed_out": True, "sync_ui_unconfigured": True,
        "synthetic_local_fetch_ok": True,
        "synthetic_local_request_observed": True,
        "observer_removed_in_finally": True,
        "network_namespace_loopback_only": True,
        "raw_urls_in_report": False,
        "production_request_delivery_verified": False,
        "requests_observed": 1,
        "push_connection_pref": {
            "default_value": True, "effective_value": True,
            "user_override": False, "locked": False
        },
        "request_category_counts": {c: 1 if c == "local" else 0
                                    for c in CATEGORIES},
        "observer_phase_counts": {
            phase: {c: 1 if phase == "positive_control" and c == "local"
                    else 0 for c in CATEGORIES} for phase in PHASES
        },
        "mozilla_other_family_counts": {family: 0 for family in OTHER_FAMILIES},
        "configured_observation_ms": {"early_idle": 1800, "late_idle": 8000},
        "endpoint_prefs": [
            {"name":name, "present":False, "kind":"absent", "locked":False,
             "user_override":False, "default_class":"absent",
             "effective_class":"absent"} for name in ENDPOINT_PREFS
        ],
        "preference_contract": {
            k: {"present":True, "default_value":k in PROTECTED,
                "effective_value":k in PROTECTED, "locked":False,
                "user_override":False} for k in BYOB + PROTECTED
        }
    }
    assert valid(d)
    invalid = [
        {**d, "synthetic_local_request_observed":False},
        {**d, "request_category_counts":{**d["request_category_counts"], "local":0}},
        {**d, "account_signed_out":False},
        {**d, "push_connection_pref": {
            **d["push_connection_pref"], "locked": True}},
        {**d, "push_connection_pref": {
            **d["push_connection_pref"], "default_value": False}},
        {**d, "observer_removed_in_finally":False},
        {**d, "raw_urls_in_report":True},
        {**d, "observer_phase_counts": {**d["observer_phase_counts"],
                "late_idle": {**d["observer_phase_counts"]["late_idle"],
                              "local": 1}}},
        {**d, "mozilla_other_family_counts": {
                **d["mozilla_other_family_counts"],
                "mozilla_other_unresolved": 1}},
        {**d, "endpoint_prefs":[{**d["endpoint_prefs"][0],
                                 "default_class":"https://example.invalid"}] +
                              d["endpoint_prefs"][1:]},
        {**d, "endpoint_prefs":[{**d["endpoint_prefs"][0],
                                 "url":"https://accounts.firefox.com"}] +
                              d["endpoint_prefs"][1:]},
        {**d, "preference_contract":{**d["preference_contract"],
                  "identity.fxaccounts.enabled":{
                    **d["preference_contract"]["identity.fxaccounts.enabled"],
                    "effective_value":True}}},
    ]
    for candidate in invalid:
        assert not valid(candidate), "A fabricated privacy proof passed validation"
    print("PASS: three-arm Push request observation contract + 12 negative controls")


def helper():
    path = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_request_helper", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Native package helper unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit(repo: Path, push_override: bool | None = None, arm: str = 'default_first'):
    if arm not in ("default_first", "push_disabled", "default_repeat"):
        raise RuntimeError("Unrecognized CI Push differential arm")
    if (arm == "push_disabled") != (push_override is False):
        raise RuntimeError("Push arm and disposable preference override mismatch")
    h = helper()
    archive = h.verified_archive(repo)
    target = repo / ".git/vulpra-native-build"
    target.mkdir(parents=True, exist_ok=True)
    ip = subprocess.run(["ip", "-j", "link", "show"], capture_output=True,
                        text=True, check=True, timeout=12)
    if [x["ifname"] for x in json.loads(ip.stdout)] != ["lo"]:
        raise RuntimeError("No-egress observer requires loopback-only namespace")
    for family in ("-4", "-6"):
        route = subprocess.run(["ip", family, "route", "show"], capture_output=True,
                               text=True, check=True, timeout=12)
        if route.stdout.strip():
            raise RuntimeError("Observer requires no external routes")
    with tempfile.TemporaryDirectory(prefix="vulpra-bounded-endpoint-audit-") as tmp:
        work = Path(tmp)
        unpacked = work / "app"
        unpacked.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(unpacked)],
                       stdout=subprocess.DEVNULL, check=True)
        inis = list(unpacked.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text():
            raise RuntimeError("Vulpra source-verified native package not found")
        browser = h.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text("Do not touch real profiles\n")
        original = sentinel.read_bytes()
        receiver = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver)
        loopback_url = (f"http://127.0.0.1:{receiver.server_port}"
                        "/ci-observer-positive")
        listener = Thread(target=receiver.serve_forever, daemon=True)
        listener.start()
        env = os.environ.copy()
        env.update({
            "HOME":str(home), "XDG_DATA_HOME":str(home / ".local/share"),
            "MOZ_HEADLESS":"1", "NO_PROXY":"127.0.0.1,localhost",
            "no_proxy":"127.0.0.1,localhost",
        })
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(key, None)
        port = h.find_port()
        proc = None
        session = None
        try:
            with (target / "byob-endpoint-observer-geckodriver.log").open("wb") as log:
                proc = subprocess.Popen(
                    ["geckodriver", "--host", "127.0.0.1",
                     "--port", str(port), "--allow-system-access"],
                    env=env, stdout=log, stderr=subprocess.STDOUT,
                    start_new_session=True,
                )
                h.wait_ready(port, proc)
                response = h.request(port, "POST", "/session", {
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox", "acceptInsecureCerts":False,
                        "moz:firefoxOptions":{
                            "binary":str(browser),
                            "args":["-headless", "-no-remote"],
                            "prefs":{
                                "remote.prefs.recommended":False,
                                "browser.shell.checkDefaultBrowser":False,
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                **({"dom.push.connection.enabled": False}
                                   if push_override is False else {}),
                            }
                        }
                    }}
                }, timeout_seconds=65)
                if not isinstance(response, dict) or not response.get("sessionId"):
                    raise RuntimeError("Vulpra Firefox160 session did not start")
                if response.get("capabilities", {}).get("acceptInsecureCerts") is not False:
                    raise RuntimeError("Disabling TLS validation is prohibited")
                session = str(response["sessionId"])
                base = "/session/" + session
                h.verify_byob_defaults(port, base)
                h.request(port, "POST", base + "/moz/context", {"context":"chrome"})
                try:
                    record = h.request(port, "POST", base + "/execute/async", {
                        "script":SCRIPT,
                        "args":[loopback_url, list(ENDPOINT_PREFS),
                                list(BYOB + PROTECTED)],
                    }, timeout_seconds=45)
                finally:
                    h.request(port, "POST", base + "/moz/context", {"context":"content"})
                if not valid(record):
                    # Only bounded phase/error category. Never dump source
                    # URL values or request details into CI logs.
                    reason = ({"phase":record.get("failed_phase"),
                               "pref_name":record.get("pref_name"),
                               "error_class":record.get("error_class")}
                              if isinstance(record, dict) else {})
                    raise RuntimeError("Native endpoint observer failed privacy contract: "
                                       + json.dumps(reason, sort_keys=True))
                push_state = record["push_connection_pref"]
                expected_enabled = push_override is not False
                if (push_state["effective_value"] is not expected_enabled
                        or push_state["user_override"] is (push_override is not False)):
                    raise RuntimeError("Push disposable-profile preference state did not match test arm")
                h.verify_byob_defaults(port, base)
                if sentinel.read_bytes() != original:
                    raise RuntimeError("Disposable profiles.ini sentinel was modified")
                report = {
                    "schema":1, "status":"pass",
                    "real_native_browser":True,
                    "loopback_only_no_external_routes":True,
                    "source_verified_original_native_archive":True,
                    "no_personal_profile_or_credentials":True,
                    "raw_hosts_urls_or_ping_bodies_saved":False,
                    "full_lifecycle_egress_audited":False,
                    "provider_safety_verified":False,
                    "release_ready":False,
                    "disposable_push_optout_only":arm == "push_disabled",
                    "arm":arm,
                    "audit":record,
                }
                (target / f"byob-push-{arm}-proof.json").write_text(
                    json.dumps(report, indent=2) + "\n")
                print(f"PASS: disposable native Push arm {arm}; observer and local control verified")
                print("LIMIT: short in-browser observation; HTTP requests not successful connections")
                return report
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
            receiver.shutdown()
            receiver.server_close()


def differential(repo: Path):
    # No account credentials, network route, production endpoint or existing
    # profile is used. Each audit() starts and terminates its own Firefox
    # browser process, WebDriver session, ephemeral HOME and HTTP receiver.
    plans = (("default_first", None), ("push_disabled", False),
             ("default_repeat", None))
    summaries = []
    for arm, override in plans:
        report = audit(repo, push_override=override, arm=arm)
        r = report["audit"]
        if report["arm"] != arm or report["disposable_push_optout_only"] != (
                arm == "push_disabled"):
            raise RuntimeError("Corrupted Push differential arm identity")
        if not valid(r):
            raise RuntimeError("Real native Push differential arm invalid")
        push = r["push_connection_pref"]
        if (push["default_value"] is not True or
                push["effective_value"] is not (arm != "push_disabled") or
                push["user_override"] is not (arm == "push_disabled") or
                push["locked"] is not False):
            raise RuntimeError("Disposal-only Push state was not verified")
        summary = {
            "arm": arm,
            "push_pref_default_enabled": push["default_value"],
            "push_pref_effective_enabled": push["effective_value"],
            "push_pref_user_override": push["user_override"],
            "push_pref_locked": push["locked"],
            "local_positive_control_passed": r["synthetic_local_fetch_ok"]
                 and r["synthetic_local_request_observed"],
            "observer_removed": r["observer_removed_in_finally"],
            "push_http_attempts_observed":
                r["mozilla_other_family_counts"]["push_notifications"],
            "other_mozilla_http_attempts_observed":
                r["request_category_counts"]["mozilla_other"],
            "other_external_http_attempts_observed":
                r["request_category_counts"]["other_external"],
            "account_sync_telemetry_attempts_observed": sum(
                r["request_category_counts"][c] for c in
                ("mozilla_account", "mozilla_sync", "mozilla_telemetry")),
        }
        summaries.append(summary)
    evidence = {
        "schema_version": 1, "status": "pass",
        "source_verified_original_native_archive": True,
        "three_separate_ephemeral_browser_sessions": True,
        "all_arms_loopback_only_no_external_routes": True,
        "isolated_profile_only_push_preference_change": True,
        "production_push_default_unchanged": True,
        "real_browser_http_observer_tested": True,
        "no_user_profiles_accounts_or_credentials": True,
        "raw_url_hosts_ping_bodies_saved": False,
        "causal_attribution_established": False,
        "push_websocket_handshake_confirmed": False,
        "full_network_lifecycle_tested": False,
        "safe_browsing_provider_verified": False,
        "release_ready": False,
        "arms": summaries,
    }
    if [row["arm"] for row in summaries] != [p[0] for p in plans]:
        raise RuntimeError("Three-arm differential proof malformed")
    target = repo / ".git/vulpra-native-build"
    (target / "byob-push-differential-proof.json").write_text(
        json.dumps(evidence, indent=2) + "\n")
    print("PASS: three separate disposable Firefox160 Push control arms and no-egress proof")
    print("LIMIT: HTTP attempt counts do not prove WebSocket cause or production connectivity")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 3 and sys.argv[1] == "--differential":
        differential(Path(sys.argv[2]).resolve())
    else:
        raise SystemExit(
            "usage: smoke-byob-push-connection-differential.py --self-test | --differential REPO")

