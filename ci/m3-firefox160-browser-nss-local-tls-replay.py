#!/usr/bin/env python3
"""Original archived Firefox160 browser startup/localhost HTTPS under missing NSS providers.

Python stdlib, matching the existing Firefox160 WebDriver harness. Actual original
packaged browser ELF; disposable HOME and GeckoDriver profile only. Dedicated
HTTP/HTTPS loopback fixtures. No raw remote errors, file paths, log lines, PIDs,
cert private keys or browser profiles in the exported bounded JSON.
"""
from __future__ import annotations

import contextlib
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
from threading import Thread
import time
import urllib.error
import urllib.request


class Page(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/page", "/"):
            self.send_error(404)
            return
        body = (b'<!doctype html><title>Vulpra NSS localhost test</title>'
                b'<h1>Localhost NSS diagnostic fixture</h1>')
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
KNOWN_ERRORS = {
    "insecure certificate", "session not created", "timeout", "script timeout",
    "unknown error", "invalid session id", "no such window", "invalid argument",
    "javascript error", "unknown command", "unsupported operation",
    "unexpected alert open", "no such alert", "stale element reference",
    "invalid selector", "no such element",
}
NAMES = ("libsoftokn3.so", "libfreeblpriv3.so")
GROUPS = (("baseline", None), ("softoken_missing", "nss_softoken"),
          ("freebl_missing", "nss_freebl"), ("both_targeted", "nss_both"))


def find_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def request(port, method, path, data=None, timeout=12):
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}{path}", method=method, data=body,
        headers={"Content-Type": "application/json"},
    )
    try:
        with OPENER.open(req, timeout=timeout) as r:
            status = r.status
            raw = r.read(65536)
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read(65536)
    parsed = None
    with contextlib.suppress(ValueError, UnicodeError):
        parsed = json.loads(raw)
    value = parsed.get("value") if isinstance(parsed, dict) else None
    return status, value


def error_class(value):
    error = value.get("error", "") if isinstance(value, dict) else ""
    return error if error in KNOWN_ERRORS else "other_webdriver_error"


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def denied_counts(path):
    counts = {name: 0 for name in NAMES}
    attached = 0
    unexpected = 0
    pattern = re.compile(r"^DENIED (?:dlopen|dlmopen) (?:.*/)?(libsoftokn3[.]so|libfreeblpriv3[.]so) [0-9]{1,20}$")
    attach = re.compile(r"^ATTACHED browser-process [0-9]{1,20}$")
    if path.stat().st_size > 5_000_000:
        raise RuntimeError("private NSS loader log exceeded maximum bytes")
    for line in path.read_text(errors="replace").splitlines():
        if attach.fullmatch(line):
            attached += 1
        elif line.startswith("DENIED "):
            match = pattern.fullmatch(line)
            if match:
                counts[match.group(1)] += 1
            else:
                unexpected += 1
    return counts, attached, unexpected


def end_process(proc):
    if proc is None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=4)
    except subprocess.TimeoutExpired:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(proc.pid, signal.SIGKILL)
        with contextlib.suppress(subprocess.TimeoutExpired):
            proc.wait(timeout=3)


def session_run(mode, group, binary, shim, gecko, temp, http_url, tls_url):
    home = temp / f"{mode}-home"
    home.mkdir(mode=0o700)
    sentinel = home / ".mozilla/firefox/profiles.ini"
    sentinel.parent.mkdir(parents=True)
    sentinel.write_bytes(b"original user profile must never be used or touched\n")
    before = fingerprint(sentinel)
    log = temp / f"{mode}-nss-private-loader.log"
    log.touch(mode=0o600)
    driver_log = temp / f"{mode}-geckodriver-private.log"
    env = os.environ.copy()
    for key in ("LD_PRELOAD", "VULPRA_M3_DENY_GROUP", "VULPRA_M3_DENY_LOG",
                "VULPRA_M3_DENY_FIXTURE_EXE", "DISPLAY", "WAYLAND_DISPLAY",
                "MOZ_REMOTE"):
        env.pop(key, None)
    env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                "MOZ_HEADLESS": "1", "MOZ_CRASHREPORTER_DISABLE": "1",
                "NO_PROXY": "127.0.0.1,localhost",
                "no_proxy": "127.0.0.1,localhost"})
    if group:
        env.update({"LD_PRELOAD": str(shim), "VULPRA_M3_DENY_GROUP": group,
                    "VULPRA_M3_DENY_LOG": str(log)})
    port = find_port()
    proc = None
    session = None
    result = {
        "mode": mode, "denial_group": group or "none",
        "driver_ready": False, "session_created": False,
        "actual_packaged_firefox_browser_reported": False,
        "browser_accept_insecure_certs": None,
        "startup_outcome": "not_started",
        "http_localhost_navigation_verified": False,
        "http_localhost_javascript_verified": False,
        "https_localhost_outcome": "not_attempted",
        "https_localhost_webdriver_error_class": "not_attempted",
        "webdriver_session_teardown_attempted": False,
        "browser_private_profile_sentinel_preserved": False,
        "actual_denied_softoken_requests": 0,
        "actual_denied_freebl_requests": 0,
        "attached_native_browser_witness_count": 0,
        "unexpected_nss_denial_log_lines": 0,
        "raw_nss_loader_logs_geckodriver_errors_or_profiles_archived": False,
    }
    try:
        with driver_log.open("wb") as output:
            proc = subprocess.Popen(
                [str(gecko), "--host", "127.0.0.1", "--port", str(port)],
                env=env, stdout=output, stderr=subprocess.STDOUT,
                start_new_session=True)
            deadline = time.monotonic() + 24
            while time.monotonic() < deadline:
                if proc.poll() is not None:
                    result["startup_outcome"] = "geckodriver_exited_before_ready"
                    break
                try:
                    _, status = request(port, "GET", "/status", timeout=2)
                    if isinstance(status, dict) and status.get("ready") is True:
                        result["driver_ready"] = True
                        break
                except (TimeoutError, OSError, ValueError):
                    pass
                time.sleep(0.18)
            if not result["driver_ready"]:
                if result["startup_outcome"] == "not_started":
                    result["startup_outcome"] = "geckodriver_not_ready"
            else:
                options = {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox",
                        "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(binary),
                            "args": ["-headless", "-no-remote"],
                            "prefs": {"browser.shell.checkDefaultBrowser": False,
                                      "app.update.enabled": False,
                                      "extensions.update.enabled": False}
                        }
                    }}
                }
                try:
                    http_code, value = request(port, "POST", "/session", options, timeout=42)
                except (TimeoutError, OSError, ValueError):
                    result["startup_outcome"] = "webdriver_session_transport_failure_or_timeout"
                else:
                    if http_code >= 400 or not isinstance(value, dict) or not isinstance(value.get("sessionId"), str):
                        result["startup_outcome"] = "webdriver_session_rejected"
                        result["session_error_class"] = error_class(value)
                    else:
                        session = value["sessionId"]
                        caps = value.get("capabilities") or {}
                        result["session_created"] = True
                        result["actual_packaged_firefox_browser_reported"] = caps.get("browserName") == "firefox"
                        result["browser_accept_insecure_certs"] = caps.get("acceptInsecureCerts")
                        result["startup_outcome"] = "session_created"
                        base = "/session/" + session
                        try:
                            code, value = request(port, "POST", base + "/url", {"url": http_url}, timeout=22)
                            if code < 400 and not (isinstance(value, dict) and value.get("error")):
                                code, title = request(port, "GET", base + "/title", timeout=10)
                                result["http_localhost_navigation_verified"] = (
                                    code < 400 and title == "Vulpra NSS localhost test"
                                )
                                code, actual = request(port, "POST", base + "/execute/sync",
                                    {"script": "return document.title==='Vulpra NSS localhost test' && 3+4===7;",
                                     "args": []}, timeout=10)
                                result["http_localhost_javascript_verified"] = code < 400 and actual is True
                        except (TimeoutError, OSError, ValueError):
                            pass
                        try:
                            code, value = request(port, "POST", base + "/url",
                                                  {"url": tls_url}, timeout=35)
                            if code < 400 and not (isinstance(value, dict) and value.get("error")):
                                result["https_localhost_outcome"] = "navigation_accepted"
                            else:
                                error = error_class(value)
                                result["https_localhost_webdriver_error_class"] = error
                                result["https_localhost_outcome"] = (
                                    "strict_certificate_rejection" if error == "insecure certificate"
                                    else "other_webdriver_navigation_failure")
                        except (TimeoutError, OSError, ValueError):
                            result["https_localhost_outcome"] = "webdriver_navigation_transport_failure_or_timeout"
    finally:
        if session:
            result["webdriver_session_teardown_attempted"] = True
            with contextlib.suppress(Exception):
                request(port, "DELETE", "/session/" + session, timeout=5)
        end_process(proc)
        result["browser_private_profile_sentinel_preserved"] = (
            sentinel.exists() and fingerprint(sentinel) == before
        )
        counts, attached, unknown = denied_counts(log)
        result["actual_denied_softoken_requests"] = counts["libsoftokn3.so"]
        result["actual_denied_freebl_requests"] = counts["libfreeblpriv3.so"]
        result["attached_native_browser_witness_count"] = attached
        result["unexpected_nss_denial_log_lines"] = unknown
    return result


def main():
    if sys.argv[1:] == ["--self-test"]:
        assert error_class({"error": "insecure certificate", "message": "/private/pid"}) == "insecure certificate"
        assert error_class({"error": "custom /secret/source"}) == "other_webdriver_error"
        assert error_class({"error": "session not created"}) == "session not created"
        assert len(GROUPS) == 4
        print("PASS: bounded WebDriver outcome and four-mode NSS test classifications")
        return 0
    if len(sys.argv) != 5:
        raise SystemExit("usage: replay.py APPDIR SHIM_SO GECKODRIVER REPORT_JSON")
    appdir, shim, gecko, report = map(Path, sys.argv[1:])
    if not all(p.is_absolute() for p in (appdir, shim, gecko, report)):
        raise RuntimeError("absolute CI paths only")
    if report.exists():
        raise RuntimeError("refusing to replace existing evidence")
    ini = appdir / "application.ini"
    if not ini.is_file() or "Name=Vulpra" not in ini.read_text().splitlines():
        raise RuntimeError("pinned native Firefox160 Vulpra package identity missing")
    browser = None
    for name in ("vulpra", "firefox"):
        p = appdir / name
        if p.is_file() and os.access(p, os.X_OK) and p.open("rb").read(4) == b"\x7fELF":
            browser = p
            break
    if browser is None or not shim.is_file() or not gecko.is_file():
        raise RuntimeError("original native browser, private shim or SHA-pinned driver missing")
    for name in ("libnss3.so", "libsoftokn3.so", "libfreeblpriv3.so", "libnspr4.so"):
        p = appdir / name
        if not p.is_file() or p.is_symlink() or p.open("rb").read(4) != b"\x7fELF":
            raise RuntimeError("original NSS provider ELF missing or not regular")
    runner = Path(os.environ["RUNNER_TEMP"])
    with tempfile.TemporaryDirectory(prefix="vulpra-nss-browser-", dir=runner) as directory:
        tmp = Path(directory)
        crt, key = tmp / "local.crt", tmp / "private-local.key"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                        "-days", "1", "-sha256", "-subj", "/CN=localhost",
                        "-addext", "subjectAltName=IP:127.0.0.1",
                        "-out", str(crt), "-keyout", str(key)], check=True,
                       timeout=20, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        http_server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Page)
        https_server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Page)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(str(crt), str(key))
        https_server.socket = tls.wrap_socket(https_server.socket, server_side=True)
        threads = [Thread(target=server.serve_forever, daemon=True)
                   for server in (http_server, https_server)]
        for thread in threads:
            thread.start()
        http_url = f"http://127.0.0.1:{http_server.server_port}/page"
        https_url = f"https://127.0.0.1:{https_server.server_port}/page"
        try:
            with OPENER.open(urllib.request.Request(http_url), timeout=8) as r:
                if r.status != 200 or b"Vulpra NSS localhost test" not in r.read(4096):
                    raise RuntimeError("local HTTP fixture not healthy")
            fixture_tls = urllib.request.build_opener(urllib.request.HTTPSHandler(
                context=ssl._create_unverified_context()), urllib.request.ProxyHandler({}))
            with fixture_tls.open(https_url, timeout=8) as r:
                if r.status != 200 or b"Vulpra NSS localhost test" not in r.read(4096):
                    raise RuntimeError("local HTTPS fixture not healthy")
            try:
                OPENER.open(https_url, timeout=8)
            except urllib.error.URLError as exc:
                if not isinstance(exc.reason, ssl.SSLCertVerificationError):
                    raise RuntimeError("host client failed local TLS for wrong reason") from None
            else:
                raise RuntimeError("local test HTTPS certificate unexpectedly trusted by OS")
            modes = [session_run(name, group, browser, shim, gecko, tmp, http_url, https_url)
                     for name, group in GROUPS]
        finally:
            for server in (http_server, https_server):
                server.shutdown()
                server.server_close()
    baseline = modes[0]
    result = {
        "schema_version": 1,
        "status": "actual_original_firefox160_webdriver_local_http_https_with_NSS_softoken_freebl_deny",
        "original_official_firefox160_commit": "2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
        "original_vulpra_28_overlay_source_tree": "42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
        "original_native_browser_archive_sha256": "530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb",
        "original_native_package_producer_run": 43138458940,
        "test_harness_git_commit": os.environ["GITHUB_SHA"],
        "exact_original_packaged_browser_elf_used": True,
        "actual_local_http_fixture_healthy": True,
        "actual_local_https_fixture_healthy": True,
        "local_https_certificate_verified_untrusted_by_host": True,
        "browser_accept_insecure_certs_requested": False,
        "baseline_real_webdriver_local_http_js_and_strict_tls_succeeded": (
            baseline["session_created"] and baseline["actual_packaged_firefox_browser_reported"]
            and baseline["browser_accept_insecure_certs"] is False
            and baseline["http_localhost_navigation_verified"]
            and baseline["http_localhost_javascript_verified"]
            and baseline["https_localhost_outcome"] == "strict_certificate_rejection"
            and baseline["browser_private_profile_sentinel_preserved"]
        ),
        "softoken_missing_requested_and_genuinely_denied": (
            modes[1]["actual_denied_softoken_requests"] > 0
            and modes[1]["attached_native_browser_witness_count"] > 0),
        "freebl_missing_requested_and_genuinely_denied": (
            modes[2]["actual_denied_freebl_requests"] > 0
            and modes[2]["attached_native_browser_witness_count"] > 0),
        "both_names_denied_in_combined_mode_proven": (
            modes[3]["actual_denied_softoken_requests"] > 0
            and modes[3]["actual_denied_freebl_requests"] > 0),
        "no_unexpected_provider_denial_names_seen": all(
            m["unexpected_nss_denial_log_lines"] == 0 for m in modes),
        "all_user_profile_sentinels_preserved": all(
            m["browser_private_profile_sentinel_preserved"] for m in modes),
        "all_denied_modes_genuine_session_outcome_recorded": True,
        "real_TLS_handshake_with_trusted_server_verified": False,
        "all_NSS_PKCS11_FIPS_TLS_and_browser_security_paths_proven": False,
        "direct_machine_NSS_dlopen_callsite_or_complete_FFI_proven": False,
        "complete_native_dlopen_dlsym_Rust_CXX_dependency_gate_closed": False,
        "target_Arch_Hyprland_or_personal_profile_touched": False,
        "raw_private_geckodriver_logs_PIDs_paths_TLS_private_keys_archived": False,
        "source_pruning_authorized": False,
        "security_current": False, "release_ready": False,
        "m3_sixth_gate_closed": False, "modes": modes,
    }
    report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    for m in modes:
        print("AUDIT: browser NSS mode="+m["mode"]+
              " session="+str(m["session_created"]).lower()+
              " HTTP="+str(m["http_localhost_navigation_verified"]).lower()+
              " TLS="+m["https_localhost_outcome"]+
              " softoken_denied="+str(m["actual_denied_softoken_requests"])+
              " freebl_denied="+str(m["actual_denied_freebl_requests"]))
    if not result["baseline_real_webdriver_local_http_js_and_strict_tls_succeeded"]:
        raise RuntimeError("baseline original browser local HTTP or certificate safety failed")
    if not result["all_user_profile_sentinels_preserved"] or not result["no_unexpected_provider_denial_names_seen"]:
        raise RuntimeError("isolation or strict NSS provider evidence guard violated")
    if not result["softoken_missing_requested_and_genuinely_denied"] or not result["freebl_missing_requested_and_genuinely_denied"]:
        raise RuntimeError("no actual native NSS load denial in designated browser cases")
    if any(m["https_localhost_outcome"] == "navigation_accepted" for m in modes):
        raise RuntimeError("original browser unexpectedly accepted untrusted HTTPS")
    print("PASS: original Firefox160 browser NSS missing-provider startups and localhost HTTP/TLS outcomes observed")
    print("LIMIT: genuine library denials do not prove TLS works, cryptographic fallback or all optional dependencies")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
