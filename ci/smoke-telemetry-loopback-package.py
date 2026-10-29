#!/usr/bin/env python3
"""Real packaged Vulpra telemetry probe: private profile, localhost-only sink.

Requires a prebuilt checksum-verified .git/vulpra-native-build/packages archive
and geckodriver. No source changes, compilation or user browser profile access.
All HTTP bodies and ping IDs are DISCARDED. Production network/deletion success
are NOT inferred from test-mode sender behavior.
"""
from __future__ import annotations

import contextlib
import http.server
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "vulpra_existing_webdriver_smoke", ROOT / "smoke-webextension-package-local.py")
webdriver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(webdriver)

KINDS = ("vulpra-probe", "deletion-request", "other")
LIMIT = 2 * 1024 * 1024


def kind(path: str) -> str:
    # Never retain ping IDs or request URLs; query text is not trusted evidence.
    from urllib.parse import urlsplit
    parts = urlsplit(path).path.split("/")
    return next((x for x in KINDS[:2] if x in parts), "other")


class Sink(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        size = self.headers.get("Content-Length", "")
        encoding = self.headers.get("Transfer-Encoding", "").lower()
        received = 0
        try:
            if size.isdecimal() and not encoding:
                remaining = int(size)
                if remaining > LIMIT:
                    raise ValueError("oversize")
                while remaining:
                    block = self.rfile.read(min(remaining, 65536))
                    if not block:
                        raise ConnectionError("truncated")
                    remaining -= len(block)
                    received += len(block)
            elif not size and encoding == "chunked":
                # Firefox may stream its compressed HTTP body without a length.
                # Do not decode or retain any part of the telemetry payload.
                while True:
                    line = self.rfile.readline(96)
                    if len(line) > 95 or not line.endswith(b"\r\n"):
                        raise ValueError("bad_framing")
                    try:
                        n = int(line.split(b";", 1)[0].strip(), 16)
                    except ValueError:
                        raise ValueError("bad_framing") from None
                    if received + n > LIMIT:
                        raise ValueError("oversize")
                    if n == 0:
                        if self.rfile.readline(96) != b"\r\n":
                            raise ValueError("bad_framing")
                        break
                    remaining = n
                    while remaining:
                        block = self.rfile.read(min(remaining, 65536))
                        if not block:
                            raise ConnectionError("truncated")
                        received += len(block)
                        remaining -= len(block)
                    if self.rfile.read(2) != b"\r\n":
                        raise ValueError("bad_framing")
            else:
                raise ValueError("bad_framing")
        except (ValueError, ConnectionError) as error:
            reason = str(error)
            if reason not in ("oversize", "bad_framing", "truncated"):
                reason = "bad_framing"
            with self.server.lock:
                self.server.rejections[reason] += 1
            self.send_response(413 if reason == "oversize" else 400)
            self.send_header("Content-Length", "0")
            self.end_headers()
            self.close_connection = True
            return
        with self.server.lock:
            self.server.requests.append(kind(self.path))
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        self.send_response(405)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *_):
        pass


@contextlib.contextmanager
def sink():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Sink)
    server.requests = []
    server.rejections = {"oversize": 0, "bad_framing": 0, "truncated": 0}
    server.lock = threading.Lock()
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def counts(server):
    with server.lock:
        samples = list(server.requests)
    return {name: samples.count(name) for name in KINDS}


def rejected_counts(server):
    with server.lock:
        return dict(server.rejections)


SCRIPT = r"""
const done = arguments[arguments.length - 1];
const endpoint = arguments[0], phase = arguments[1];
(async () => {
  if (!/^http:\/\/127\.0\.0\.1:\d+$/.test(endpoint)) {
    throw Error("Non-local telemetry target");
  }
  const Services = globalThis.Services ||
    ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs").Services;
  const {TelemetrySend, TelemetrySendImpl, SendScheduler} =
    ChromeUtils.importESModule("resource://gre/modules/TelemetrySend.sys.mjs");
  const {TelemetryController} = ChromeUtils.importESModule(
    "resource://gre/modules/TelemetryControllerParent.sys.mjs");
  const {TelemetryReportingPolicy} = ChromeUtils.importESModule(
    "resource://gre/modules/TelemetryReportingPolicy.sys.mjs");
  const {TelemetryUtils} = ChromeUtils.importESModule(
    "resource://gre/modules/TelemetryUtils.sys.mjs");
  const upload = TelemetryUtils.Preferences.FhrUploadEnabled;
  const master = TelemetryUtils.Preferences.DataSubmissionEnabled;
  const sample = {version:4, application:{}, id:"vulpra-fixture", type:"vulpra-probe"};
  const deletion = {...sample, type:"deletion-request"};
  const state = () => ({
    ordinary: TelemetrySend.sendingEnabled(sample),
    deletion: TelemetrySend.sendingEnabled(deletion),
    policy: TelemetryReportingPolicy.canUpload(),
    sender_ready: TelemetrySend.getShutdownState().sendingEnabled,
    server_matches_loopback: TelemetrySendImpl._server === endpoint,
    pending_count: TelemetrySend.pendingPingCount,
    in_flight_count: TelemetrySend.getShutdownState().pendingPingRequestCount,
    scheduler: SendScheduler.getShutdownState().sendTaskState,
    unified: Services.prefs.getBoolPref(TelemetryUtils.Preferences.Unified, false)
  });
  if (phase === "prepare") {
    const official = Services.telemetry.isOfficialTelemetry;
    const naturallyInitialized = TelemetrySend.getShutdownState().sendingEnabled;
    Services.prefs.setBoolPref(master, true);
    Services.prefs.setBoolPref(upload, true);
    Services.prefs.setBoolPref(TelemetryUtils.Preferences.DisableFuzzingDelay, true);
    let explicitlyInitialized = false;
    if (!naturallyInitialized) {
      // This is a DISPOSABLE PROFILE and deliberately test-only: inactive
      // normal startup is not proof of broken telemetry or successful deletion.
      // Use the actual controller to install its pref observers and initialize
      // sender/storage/IDs rather than creating a fake sender state.
      await TelemetryController.testSetup();
      explicitlyInitialized = true;
    }
    TelemetrySend.setServer(endpoint); // testSetup may replace the server
    TelemetrySend.setTestModeEnabled(true); // explicit debug-only override
    const before = state();
    if (!before.sender_ready || !before.server_matches_loopback) {
      done({status:"error", reason:"test_setup_sender_not_initialized",
        naturally_initialized:naturallyInitialized, test_setup_used:explicitlyInitialized,
        before, official_build:official, test_override:true});
      return;
    }
    // No ping IDs, URLs, profile identifiers or bodies enter the result.
    await TelemetryController.submitExternalPing("vulpra-probe", {synthetic:true});
    await TelemetrySend.testWaitOnOutgoingPings();
    done({status:"observed", official_build:official, test_override:true,
      naturally_initialized:naturallyInitialized,
      test_setup_used:explicitlyInitialized, before, after_submit:state()});
  } else if (phase === "disable") {
    let observer;
    const notified = new Promise(resolve => {
      observer = {observe: () => resolve(true)};
      Services.obs.addObserver(observer, TelemetryUtils.TELEMETRY_UPLOAD_DISABLED_TOPIC);
    });
    let saw = false;
    try {
      Services.prefs.setBoolPref(upload, false);
      saw = await Promise.race([notified,
        new Promise(resolve => setTimeout(() => resolve(false), 10000))]);
    } finally {
      Services.obs.removeObserver(observer, TelemetryUtils.TELEMETRY_UPLOAD_DISABLED_TOPIC);
    }
    if (!saw) throw Error("Opt-out observer not fired");
    await TelemetryController.testPromiseDeletionRequestPingSubmitted();
    await TelemetrySend.testWaitOnOutgoingPings();
    done({status:"observed", observer_seen:true, disabled:state()});
  } else if (phase === "master") {
    Services.prefs.setBoolPref(master, false);
    done({status:"observed", master_off:state()});
  } else {
    throw Error("Unknown test phase");
  }
})().catch(error => done({status:"error", error:String(error)}));
"""


def validate(observation: dict, before: dict, after: dict,
             rejections: dict | None = None):
    rejections = rejections or {}
    if observation.get("status") != "observed" or observation.get("observer_seen") is not True:
        raise RuntimeError("No real opt-out notification observed: " + repr(observation))
    for section in ("before", "disabled", "master_off"):
        value = observation.get(section)
        if not isinstance(value, dict) or any(type(value.get(k)) is not bool
            for k in ("ordinary", "deletion", "policy")):
            raise RuntimeError("Incomplete privileged browser state " + section)
    if observation["disabled"]["ordinary"] or not observation["disabled"]["deletion"]:
        raise RuntimeError("Deletion-request exemption or upload-disabled guard broken")
    if observation["master_off"]["policy"]:
        raise RuntimeError("Master data-submission policy still permits upload")
    if any(rejections.values()):
        raise RuntimeError("Local receiver rejected telemetry framing or body size: " + repr(rejections))
    if not observation["before"]["sender_ready"] or not observation["before"]["server_matches_loopback"]:
        raise RuntimeError("Telemetry sender not initialized or URL points off loopback")
    if after["vulpra-probe"] != before["vulpra-probe"]:
        raise RuntimeError("Ordinary telemetry reached sink after user opt-out")
    if observation["before"]["ordinary"] and observation["before"]["policy"] and not before["vulpra-probe"]:
        raise RuntimeError("Eligible synthetic upload never reached loopback sink")
    if not observation.get("test_override"):
        raise RuntimeError("Privileged test override provenance absent")
    if type(observation.get("naturally_initialized")) is not bool or (
        type(observation.get("test_setup_used")) is not bool
    ):
        raise RuntimeError("Missing automatic vs explicit test initialization provenance")
    if not observation["naturally_initialized"] and not observation["test_setup_used"]:
        raise RuntimeError("Sender turned on without a documented test-only controller setup")


def run(repo: Path, driver: str) -> dict:
    archive = webdriver.verified_archive(repo)  # full SHA256 sidecar check
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-telemetry-") as tmp:
        root = Path(tmp)
        extracted = root / "app"
        extracted.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(extracted)], check=True)
        ini = list(extracted.rglob("application.ini"))
        if len(ini) != 1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
            raise RuntimeError("Non-Vulpra or ambiguous application identity")
        binary = webdriver.select_binary(ini[0].parent)
        home = root / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"Vulpra telemetry test: unrelated profile untouched\n")
        env = os.environ.copy()
        env.update(HOME=str(home), XDG_DATA_HOME=str(home / "xdg"),
                   MOZ_HEADLESS="1", MOZ_DISABLE_NONLOCAL_CONNECTIONS="1",
                   NO_PROXY="127.0.0.1,localhost", no_proxy="127.0.0.1,localhost")
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(key, None)
        with sink() as server:
            endpoint = f"http://127.0.0.1:{server.server_port}"
            port = webdriver.find_port()
            proc = None
            session = None
            try:
                with (root / "geckodriver.log").open("wb") as logfile:
                    proc = subprocess.Popen([driver, "--host", "127.0.0.1",
                        "--port", str(port), "--allow-system-access"],
                        env=env, stdout=logfile, stderr=subprocess.STDOUT,
                        start_new_session=True)
                    webdriver.wait_ready(port, proc)
                    value = webdriver.request(port, "POST", "/session", {
                        "capabilities":{"alwaysMatch":{"browserName":"firefox",
                        "moz:firefoxOptions":{"binary":str(binary),
                            "args":["-headless","-no-remote"],"prefs":{
                                "toolkit.telemetry.server":endpoint,
                                "datareporting.healthreport.uploadEnabled":True,
                                "datareporting.policy.dataSubmissionEnabled":True,
                                "datareporting.policy.dataSubmissionPolicyBypassNotification":True,
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                "network.dns.disablePrefetch":True}}}}})
                    session = value["sessionId"]
                    base = f"/session/{session}"
                    webdriver.request(port, "POST", base + "/timeouts", {"script":70000})
                    webdriver.request(port, "POST", base + "/moz/context", {"context":"chrome"})
                    try:
                        def phase(label):
                            result = webdriver.request(port, "POST", base + "/execute/async",
                                {"script":SCRIPT, "args":[endpoint,label]}, timeout_seconds=85)
                            if not isinstance(result, dict) or result.get("status") != "observed":
                                raise RuntimeError(f"Native phase {label} failed: {result!r}")
                            return result
                        initial = phase("prepare")
                        for _ in range(40):
                            if counts(server)["vulpra-probe"]:
                                break
                            time.sleep(.2)
                        earlier = counts(server)
                        disabled = phase("disable")
                        time.sleep(1.5)
                        later = counts(server)
                        master = phase("master")
                        rejections = rejected_counts(server)
                    finally:
                        webdriver.request(port, "POST", base + "/moz/context", {"context":"content"})
                    state = {**initial, **disabled, **master}
                    report = {"schema_version":2, "status":"native_runtime_pending_validation",
                        "verified_package_sha256":True, "isolated_profile":True,
                        "nonlocal_connections_blocked_by_gecko_environment":True,
                        "loopback_receiver":"127.0.0.1", "runtime":state,
                        "before_optout_requests":earlier, "after_optout_requests":later,
                        "receiver_rejections":rejections,
                        "limitations":[
                            "Natural sender startup is recorded separately from deliberate testSetup() initialization.",
                            "Test-mode override is not proof of production upload behavior.",
                            "Only local HTTP type counts retained; no payload or ping identifiers stored.",
                            "Deletion-request eligibility and observer notification are not server-side deletion.",
                            "A queued deletion request might not be transmitted due to policy and scheduler.",
                            "No assertion about other browser connection surfaces beyond Gecko's nonlocal guard."]}
                    try:
                        validate(state, earlier, later, rejections)
                    except RuntimeError as failure:
                        report["status"] = "native_runtime_rejected"
                        report["failure_category"] = str(failure)
                    else:
                        report["status"] = "native_privileged_telemetry_runtime_observed"
                    if sentinel.read_bytes() != b"Vulpra telemetry test: unrelated profile untouched\n":
                        raise RuntimeError("Profile isolation failure")
                    return report
            finally:
                if session:
                    try:
                        webdriver.request(port, "DELETE", f"/session/{session}", timeout_seconds=8)
                    except (RuntimeError, OSError):
                        pass
                if proc:
                    proc.terminate()
                    try:
                        proc.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)


def main():
    repo = Path(sys.argv[1] if len(sys.argv)>1 else ".").resolve()
    driver = shutil.which("geckodriver")
    if not driver:
        raise RuntimeError("geckodriver unavailable; no native Vulpra build attempted")
    report = run(repo, driver)
    output = repo / ".git/vulpra-native-build/m3-telemetry-loopback.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    if report["status"] != "native_privileged_telemetry_runtime_observed":
        raise RuntimeError("Native telemetry evidence rejected: " +
                           report.get("failure_category", "unknown"))
    print("PASS: real packaged browser telemetry opt-out observer and sender policy")
    print("PASS: bounded localhost type counts and isolated temporary profile")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as e:
        print("FAIL: M3 telemetry loopback runtime:", e, file=sys.stderr)
        raise SystemExit(1)
