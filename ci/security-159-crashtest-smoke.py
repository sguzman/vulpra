#!/usr/bin/env python3
"""Replay original Mozilla CSS/SVG/layout crash fixtures in packaged Vulpra.

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

# Additional original Mozilla regressions; checked byte-for-byte as Git blobs.
EXTRA_FIXTURES = {
    "svg": (Path("layout/svg/crashtests/2079252.html"),
            "a8d78aae061029dcc7cb72e86a18647b2d483625",
            (b"t.getExtentOfChar(", b'd.firstChild.data = "ww"')),
    "table": (Path("testing/web-platform/tests/css/css-tables/crashtests/"
                   "border-collapse-dynamic-crash.html"),
              "6d716acb679c1f174e75a4d3d6ddfc85dcba7852",
              (b"c.colSpan = 60", b't.rows[5].cells[3].firstChild.data = "bbbb"')),
    "multicol": (Path("testing/web-platform/tests/css/css-multicol/crashtests/"
                      "block-break-before.html"),
                 "bfb5f0894b80bf39633afcf37be9fdcbb68ab96c",
                 (b'u0.scrollIntoView()', b'mc.style.width = "400px"')),
}
EXTRA_REPETITIONS = 2

# The table fixture's original onload handler needs two animation frames.
# Probe its observable effects without modifying the upstream test HTML.
EXTRA_PROBES = {
    "svg": (
        "return {url:document.URL,state:document.readyState,"
        "count:document.querySelectorAll('#t tspan').length,"
        "characters:document.getElementById('t').getNumberOfChars(),"
        "last:document.getElementById('t').lastElementChild?.textContent,"
        "height:document.documentElement.offsetHeight};", False),
    "table": (
        "const done=arguments[arguments.length-1];"
        "const deadline=Date.now()+7000;"
        "function read(){const t=document.getElementById('t');"
        "const c=t?.rows[3]?.cells[1];"
        "return {url:document.URL,state:document.readyState,"
        "colspan:c?.colSpan,css_class:c?.className,"
        "text:t?.rows[5]?.cells[3]?.firstChild?.data,"
        "left:document.getElementById('d')?.style.left,"
        "height:document.documentElement.offsetHeight};}"
        "function poll(){const s=read();"
        "if(s.colspan===60&&s.text==='bbbb'&&s.left==='10px')done(s);"
        "else if(Date.now()>deadline)done(s);"
        "else setTimeout(poll,45);}poll();", True),
    "multicol": (
        "return {url:document.URL,state:document.readyState,"
        "width:document.getElementById('mc')?.style.width,"
        "break_before:document.getElementById('g3')?.style.breakBefore,"
        "u0:!!document.getElementById('u0'),"
        "height:document.documentElement.offsetHeight};", False),
}


def load_extra_fixtures(repo: Path) -> dict[str, bytes]:
    verified = {}
    for name, (path, expected, triggers) in EXTRA_FIXTURES.items():
        raw = (repo / path).read_bytes()
        git_blob = b"blob " + str(len(raw)).encode() + b"\0" + raw
        if hashlib.sha1(git_blob).hexdigest() != expected:
            raise RuntimeError(f"Upstream {name} crashtest Git blob changed")
        for trigger in triggers:
            if trigger not in raw:
                raise RuntimeError(f"Original {name} crash trigger changed")
        verified[name] = raw
    return verified


def valid_extra_dom(name: str, value: object, url: str) -> bool:
    if not (isinstance(value, dict) and value.get("url") == url
            and value.get("state") == "complete"
            and type(value.get("height")) is int and value["height"] > 0):
        return False
    if name == "svg":
        return (value.get("count") == 49
                and type(value.get("characters")) is int
                and value["characters"] >= 49 and value.get("last") == "ww")
    if name == "table":
        return (value.get("colspan") == 60
                and value.get("css_class") == "x"
                and value.get("text") == "bbbb"
                and value.get("left") == "10px")
    if name == "multicol":
        return (value.get("width") == "400px"
                and value.get("break_before") == "always"
                and value.get("u0") is True)
    return False



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
    extra = load_extra_fixtures(repo)
    assert sorted(extra) == ["multicol", "svg", "table"]
    forged = 0
    for name in sorted(extra):
        case_url = f"http://127.0.0.1:1/regression/{name}?iteration=0"
        value = dict(url=case_url, state="complete", height=150)
        if name == "svg":
            value.update(count=49, characters=100, last="ww")
            corrupt = [dict(count=48), dict(last="x"), dict(characters=0)]
        elif name == "table":
            value.update(colspan=60, css_class="x", text="bbbb", left="10px")
            corrupt = [dict(colspan=1), dict(text="aaa"), dict(left="0px")]
        else:
            value.update(width="400px", break_before="always", u0=True)
            corrupt = [dict(width="200px"), dict(break_before="auto"),
                       dict(u0=False)]
        assert valid_extra_dom(name, value, case_url)
        for change in corrupt + [dict(url="https://external.invalid/"),
                                 dict(height=0), dict(state="loading")]:
            assert not valid_extra_dom(name, {**value, **change}, case_url)
            forged += 1
    assert forged == 18
    print("PASS: 4 exact original crashtest blobs and triggers;"
          " 26/26 forged DOM/liveness claims rejected; no browser run")


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
    extra = load_extra_fixtures(repo)
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
                route = self.path.split("?", 1)[0]
                if route == "/crashtest":
                    body = raw
                elif route.startswith("/regression/"):
                    body = extra.get(route.rsplit("/", 1)[-1])
                else:
                    body = None
                if body is None:
                    self.send_error(404)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

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
                extra_checks = []
                for name in sorted(extra):
                    script, asynchronous = EXTRA_PROBES[name]
                    trial = []
                    for i in range(EXTRA_REPETITIONS):
                        case_url = (
                            f"http://127.0.0.1:{server.server_port}"
                            f"/regression/{name}?iteration={i}"
                        )
                        driver.request(port, "POST", session + "/url",
                                       {"url": case_url}, timeout_seconds=35)
                        state = driver.request(
                            port, "POST",
                            session + ("/execute/async" if asynchronous
                                       else "/execute/sync"),
                            {"script": script, "args": []},
                            timeout_seconds=20)
                        if not valid_extra_dom(name, state, case_url):
                            raise RuntimeError(
                                f"Original {name} crashtest did not complete"
                                f" ({i}): {state!r}")
                        if process.poll() is not None:
                            raise RuntimeError(
                                f"Driver exited during {name} crashtest")
                        trial.append({"iteration": i, "height": state["height"]})
                    extra_checks.append({
                        "name": name,
                        "fixture": str(EXTRA_FIXTURES[name][0]),
                        "git_blob_sha1": EXTRA_FIXTURES[name][1],
                        "iterations": trial,
                    })
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
                additional_report = {
                    "schema_version": 1,
                    "status": "passed_bounded_original_extra_crashtests",
                    "source_commit": source,
                    "cases": extra_checks,
                    "real_packaged_browser": True,
                    "accept_insecure_certs": False,
                    "temporary_profile_preserved": True,
                    "original_mozilla_fixture_hashes_verified": True,
                    "official_wpt_harness_used": False,
                    "memory_safety_exploit_rejection_proven": False,
                    "security_current": False,
                    "release_ready": False,
                }
                additional_path = (
                    evidence_dir / "security-159-additional-crashtest-replay.json"
                )
                additional_path.write_text(
                    json.dumps(additional_report, indent=2) + chr(10))
                print("PASS: 3 additional original SVG/table/multicol"
                      " crashtests replayed twice in packaged Vulpra")
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
