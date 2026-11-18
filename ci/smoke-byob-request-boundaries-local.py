#!/usr/bin/env python3
"""Bounded HTTP request attempt / endpoint-pref survey for archived Vulpra 160.

A real, checksum-verified native Firefox starts with disposable HOME/profile,
inside a Linux network namespace containing only loopback, with no external
routes. A temporary in-browser http-on-modify-request observer counts request
categories while a synthetic local HTTP fetch proves the observer is working.

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
URL_CLASSES = (*CATEGORIES, "absent", "empty", "unparseable", "non_http")
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
  const p = Services.prefs;  // privileged Marionette global
  const branch = p.getDefaultBranch("");
  const categories = [
    "local", "mozilla_account", "mozilla_sync", "mozilla_telemetry",
    "mozilla_other", "google_provider", "other_external"
  ];
  const counts = Object.fromEntries(categories.map(x => [x, 0]));
  const requested = {seen:0, observed_local_probe:false};
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
  const prefixes = endpointNames.map(name => {
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
      const effective = p.getStringPref(name, "");
      row.effective_class = classify(effective);
      if (branch.getPrefType(name) === p.PREF_STRING) {
        row.default_class = classify(branch.getStringPref(name));
      }
    }
    return row;
  });
  const settings = Object.fromEntries(keys.map(name => [
    name, {present:p.getPrefType(name)===p.PREF_BOOL,
           default_value:branch.getBoolPref(name, false),
           effective_value:p.getBoolPref(name, false),
           locked:p.prefIsLocked(name),
           user_override:p.prefHasUserValue(name)}
  ]));
  const {UIState} = ChromeUtils.importESModule(
    "resource://services-sync/UIState.sys.mjs");
  const {getFxAccountsSingleton} = ChromeUtils.importESModule(
    "resource://gre/modules/FxAccounts.sys.mjs");
  const signedOut = (await getFxAccountsSingleton().getSignedInUser()) === null;
  const syncUnconfigured = UIState.get()?.status === UIState.STATUS_NOT_CONFIGURED;

  safe.phase = "observer";
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
  try {
    safe.phase = "local_control";
    const response = await fetch(ciUrl, {cache:"no-store", redirect:"error"});
    const localFetchOk = response.status === 204;
    safe.phase = "bounded_observation";
    await new Promise(resolve => setTimeout(resolve, 1800));
    return done({
      account_signed_out: signedOut,
      sync_ui_unconfigured: syncUnconfigured,
      synthetic_local_fetch_ok: localFetchOk,
      synthetic_local_request_observed: requested.observed_local_probe,
      requests_observed: requested.seen,
      request_category_counts: counts,
      endpoint_prefs: prefixes,
      preference_contract: settings,
      observer_removed_in_finally: true,
      network_namespace_loopback_only: true,
      raw_urls_in_report: false,
      production_request_delivery_verified: false
    });
  } finally {
    Services.obs.removeObserver(observer, "http-on-modify-request");
    removed = true;
  }
})().catch(err => done({
  audit_failed: true, failed_phase: safe.phase,
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
    total = d.get("requests_observed")
    if type(total) is not int or total != sum(counts.values()):
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
        "request_category_counts": {c: 1 if c == "local" else 0
                                    for c in CATEGORIES},
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
        {**d, "observer_removed_in_finally":False},
        {**d, "raw_urls_in_report":True},
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
    print("PASS: bounded request/endpoint audit parser + 7 negative controls")


def helper():
    path = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_request_helper", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Native package helper unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def audit(repo: Path):
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
                                "extensions.update.enabled":False
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
                               "error_class":record.get("error_class")}
                              if isinstance(record, dict) else {})
                    raise RuntimeError("Native endpoint observer failed privacy contract: "
                                       + json.dumps(reason, sort_keys=True))
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
                    "audit":record,
                }
                (target / "byob-endpoint-observer-proof.json").write_text(
                    json.dumps(report, indent=2) + "\n")
                print("PASS: real Vulpra Firefox160 bounded HTTP observer and redacted pref survey")
                print("LIMIT: short in-browser observation window; external network blocked")
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


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 2:
        audit(Path(sys.argv[1]).resolve())
    else:
        raise SystemExit("usage: smoke-byob-request-boundaries-local.py --self-test | REPO")
