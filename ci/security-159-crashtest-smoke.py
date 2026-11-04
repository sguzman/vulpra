#!/usr/bin/env python3
"""Replay the exact Mozilla Bug 2079035 HTML in a private packaged browser.

This is a limited original-crashtest execution and DOM/liveness witness, not
a sanitizer run, proof of exploit resistance, or a security-current browser.
"""
from __future__ import annotations

import hashlib
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

FIXTURE = Path("testing/web-platform/tests/css/css-position/crashtests/"
               "inline-containing-block-delete-continuations-001.html")
BLOB_SHA1 = "31a14963b356d869475bac62ca44991d9275a285"
REPETITIONS = 3


def load_fixture(repo: Path) -> bytes:
    raw = (repo / FIXTURE).read_bytes()
    git_blob = b"blob " + str(len(raw)).encode() + b"\0" + raw
    if hashlib.sha1(git_blob).hexdigest() != BLOB_SHA1:
        raise RuntimeError("Upstream security crashtest Git blob changed")
    return raw


def valid_dom(value: object, url: str) -> bool:
    return (isinstance(value, dict) and value.get("url") == url
            and value.get("state") == "complete"
            and value.get("container") == "3000px"
            and value.get("absolute") == "60px"
            and value.get("text") == "zzzz"
            and type(value.get("height")) is int and value["height"] > 0)


def self_test(repo: Path) -> None:
    raw = load_fixture(repo)
    for line in (b"column-count: 3",
                 b'document.documentElement.offsetHeight',
                 b'mc.style.width = "3000px"',
                 b't.firstChild.data = "zzzz"',
                 b'm.style.width = "60px"'):
        assert line in raw, "Original crash trigger changed"
    url = "http://127.0.0.1:1/crashtest?iteration=0"
    good = dict(url=url, state="complete", container="3000px",
                absolute="60px", text="zzzz", height=150)
    assert valid_dom(good, url)
    for delta in ({"url": "https://external.invalid/"},
                  {"state": "loading"}, {"container": "150px"},
                  {"absolute": "20px"}, {"text": "other"},
                  {"height": 0}, {"height": "150"}):
        assert not valid_dom({**good, **delta}, url)
    assert not valid_dom(None, url)
    print("PASS: upstream security regression file exact; 8/8 forged"
          " DOM and liveness claims rejected; no browser run")


def existing_browser_driver(repo: Path):
    path = repo / "ci/smoke-webextension-package-local.py"
    spec = importlib.util.spec_from_file_location("vulpra_native_smoke", path)
    if not spec or not spec.loader:
        raise RuntimeError("Native smoke driver unavailable")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_browser(repo: Path) -> None:
    raw = load_fixture(repo)
    driver = existing_browser_driver(repo)
    geckodriver = shutil.which("geckodriver")
    if not geckodriver:
        raise RuntimeError("Official geckodriver must be on PATH")
    archive = driver.verified_archive(repo)
    evidence_dir = repo / ".git/vulpra-native-build"
    with tempfile.TemporaryDirectory(prefix="vulpra-cve-120572-") as temp:
        root = Path(temp)
        unpack = root / "package"
        unpack.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(unpack)],
                       timeout=120, check=True)
        ini = list(unpack.rglob("application.ini"))
        if len(ini) != 1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
            raise RuntimeError("Expected exactly one native Vulpra package")
        browser = driver.select_binary(ini[0].parent)
        home = root / "home"
        home.mkdir()
        sentinel_file = home / ".mozilla/firefox/profiles.ini"
        sentinel_file.parent.mkdir(parents=True)
        sentinel = b"original profile sentinel must not change\n"
        sentinel_file.write_bytes(sentinel)

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path.split("?", 1)[0] != "/crashtest":
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def log_message(self, *_args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        port = driver.find_port()
        env = os.environ.copy()
        env.update(dict(HOME=str(home), XDG_DATA_HOME=str(home / ".local/share"),
                        MOZ_HEADLESS="1", NO_PROXY="127.0.0.1,localhost",
                        no_proxy="127.0.0.1,localhost"))
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(key, None)
        process = None
        session = None
        try:
            with (evidence_dir / "security-159-css-geckodriver.log").open("wb") as log:
                process = subprocess.Popen(
                    [geckodriver, "--host", "127.0.0.1",
                     "--port", str(port)], env=env,
                    stdout=log, stderr=subprocess.STDOUT,
                    start_new_session=True)
                driver.wait_ready(port, process)
                result = driver.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser),
                            "args": ["-headless", "-no-remote"],
                            "prefs": {
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                            },
                        },
                    }}
                }, timeout_seconds=40)
                if not isinstance(result, dict) or not result.get("sessionId"):
                    raise RuntimeError("WebDriver session not established")
                caps = result.get("capabilities", {})
                if (caps.get("browserName") != "firefox" or
                        caps.get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Browser identity or TLS policy incorrect")
                session = "/session/" + str(result["sessionId"])
                checks = []
                for i in range(REPETITIONS):
                    url = (f"http://127.0.0.1:{server.server_port}/crashtest"
                           f"?iteration={i}")
                    driver.request(port, "POST", session + "/url",
                                   {"url": url}, timeout_seconds=35)
                    state = driver.request(port, "POST",
                                           session + "/execute/sync", {
                        "script": (
                            "return {url:document.URL,state:document.readyState,"
                            "container:document.getElementById('mc')?.style.width,"
                            "absolute:document.getElementById('m')?.style.width,"
                            "text:document.getElementById('t')?.firstChild?.data,"
                            "height:document.documentElement.offsetHeight};"
                        ), "args": [],
                    }, timeout_seconds=15)
                    if not valid_dom(state, url):
                        raise RuntimeError(
                            f"Upstream CSS crashtest did not complete ({i}): {state!r}")
                    if process.poll() is not None:
                        raise RuntimeError("Browser driver exited during crashtest")
                    checks.append({"iteration": i, "height": state["height"]})
                if sentinel_file.read_bytes() != sentinel:
                    raise RuntimeError("Private Firefox profile sentinel modified")
                source = subprocess.check_output(
                    ["git", "-C", str(repo), "rev-parse", "HEAD"],
                    text=True, timeout=10).strip()
                report = {
                    "schema_version": 1,
                    "status": "passed_bounded_original_crashtest_replay",
                    "source_commit": source,
                    "fixture_git_blob_sha1": BLOB_SHA1,
                    "fixture": str(FIXTURE), "iterations": checks,
                    "real_packaged_browser": True,
                    "accept_insecure_certs": False,
                    "temporary_profile_preserved": True,
                    "official_wpt_harness_used": False,
                    "memory_safety_exploit_rejection_proven": False,
                    "security_current": False, "release_ready": False,
                }
                output = evidence_dir / "security-159-css-crashtest-replay.json"
                output.write_text(json.dumps(report, indent=2) + "\n")
                print("PASS: exact original upstream CSS crashtest executed "
                      f"{REPETITIONS} times in real isolated packaged Vulpra")
                print("LIMIT: no ASAN, full WPT harness or exploit safety proof")
        finally:
            if session is not None:
                try:
                    driver.request(port, "DELETE", session, timeout_seconds=8)
                except Exception:
                    pass
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=8)
            server.shutdown()
            server.server_close()


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    if sys.argv[1:] == ["--self-test"]:
        self_test(repo)
    elif not sys.argv[1:]:
        run_browser(repo)
    else:
        raise SystemExit("Usage: security-159-crashtest-smoke.py [--self-test]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
