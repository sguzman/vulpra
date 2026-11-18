#!/usr/bin/env python3
"""Read-only-in-production Firefox160 BYOB login UI acceptance.

Uses the *existing* checksum-verified native archive with an isolated HOME,
private localhost form and a disposable Gecko automation profile. It NEVER
reads real passwords, uses Vaultwarden, or clicks Save. The positive control
temporarily toggles signon.rememberSignons only inside that disposable profile.
"""
from __future__ import annotations

import http.server
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from urllib.parse import parse_qs


def load_existing_helpers():
    path = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_webext_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Existing WebDriver helper not available")
    helpers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helpers)
    return helpers


class FakeLogin(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?")[0] != "/login-form":
            self.send_error(404)
            return
        body = (
            b'<!doctype html><html><meta charset="utf-8">'
            b'<title>Vulpra fake login UI test</title>'
            b'<form id="vulpra-local-login" method="post" action="/login-accepted">'
            b'<input id="vulpra-local-username" name="username" autocomplete="username">'
            b'<input id="vulpra-local-password" name="password" type="password" autocomplete="current-password">'
            b'<button type="submit">Local fixture login</button></form></html>'
        )
        self._send(200, body)

    def do_POST(self):
        if self.path.split("?")[0] != "/login-accepted":
            self.send_error(404)
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 4096:
                self.send_error(400)
                return
            fields = parse_qs(self.rfile.read(size).decode("ascii"), strict_parsing=True)
        except (ValueError, UnicodeDecodeError):
            self.send_error(400)
            return
        if fields != {"username": ["vulpra-ci-fake-user"],
                      "password": ["vulpra-ci-fake-password"]}:
            self.send_error(400)
            return
        self.server.submitted_count += 1
        self._send(200, b'<!doctype html><title>Fixture accepted</title><h1 id="submitted">OK</h1>')

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        # Never log synthetic form values, even to test-runner stdout.
        pass


def valid_chrome_record(data, expect_prompt):
    return (isinstance(data, dict) and
            set(data) == {"chrome_ready", "prompt", "prompt_type", "pref",
                          "pref_overridden", "default_off"} and
            data.get("chrome_ready") is True and
            data.get("prompt") is expect_prompt and
            data.get("pref") is expect_prompt and
            data.get("pref_overridden") is expect_prompt and
            data.get("default_off") is True and
            (data.get("prompt_type") == "password-save" if expect_prompt
             else data.get("prompt_type") is None))


def self_test():
    off = {"chrome_ready": True, "prompt": False, "prompt_type": None,
           "pref": False, "pref_overridden": False, "default_off": True}
    on = {**off, "prompt": True, "prompt_type": "password-save",
          "pref": True, "pref_overridden": True}
    assert valid_chrome_record(off, False)
    assert valid_chrome_record(on, True)
    for value in (None, {}, {**off, "chrome_ready": False}, {**off, "prompt": True},
                  {**off, "default_off": False}, {**on, "prompt_type": "password-change"},
                  {**on, "pref_overridden": False}, {**on, "pref": False},
                  {**on, "extra": "fake"}):
        assert not valid_chrome_record(value, False)
        assert not valid_chrome_record(value, True)
    with http.server.ThreadingHTTPServer(("127.0.0.1", 0), FakeLogin) as server:
        server.submitted_count = 0
        from threading import Thread
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        from urllib.request import urlopen, Request
        base = f"http://127.0.0.1:{server.server_port}"
        with urlopen(base + "/login-form", timeout=8) as response:
            assert b'vulpra-local-login' in response.read()
        payload = b"username=vulpra-ci-fake-user&password=vulpra-ci-fake-password"
        with urlopen(Request(base + "/login-accepted", data=payload), timeout=8) as response:
            assert response.status == 200
        assert server.submitted_count == 1
        server.shutdown()
    print("PASS: strict BYOB login UI evidence parser and synthetic loopback POST fixture")
    print("LIMIT: offline fixture only; no browser UI acceptance")


CHROME_STATE = """
    const win = Services.wm.getMostRecentWindow('navigator:browser');
    const controller = win?.PopupNotifications;
    const browser = win?.gBrowser?.selectedBrowser;
    if (!controller || !browser || typeof controller.getNotification !== 'function') {
        return {chrome_ready: false, prompt: false, prompt_type: null,
                pref: false, pref_overridden: false, default_off: false};
    }
    const notif = controller.getNotification('password', browser);
    return {
        chrome_ready: true,
        prompt: !!notif,
        prompt_type: notif?.options?.passwordNotificationType ?? null,
        pref: Services.prefs.getBoolPref('signon.rememberSignons'),
        pref_overridden: Services.prefs.prefHasUserValue('signon.rememberSignons'),
        default_off: Services.prefs.getDefaultBranch('').getBoolPref('signon.rememberSignons') === false
    };
"""


def verify_runtime(h, port, session, server):
    base = f"/session/{session}"
    fixture = f"http://127.0.0.1:{server.server_port}"
    def js(script):
        return h.request(port, "POST", base + "/execute/sync",
                         {"script": script, "args": []}, timeout_seconds=20)

    def chrome(script):
        h.request(port, "POST", base + "/moz/context", {"context": "chrome"})
        try:
            return js(script)
        finally:
            h.request(port, "POST", base + "/moz/context", {"context": "content"})

    def submit(case):
        before = server.submitted_count
        h.request(port, "POST", base + "/url",
                  {"url": fixture + "/login-form?case=" + case}, timeout_seconds=30)
        # Firefox's upstream login-manager tests synthesize *user input*
        # before form.submit(). Plain JS element.value assignment is not
        # equivalent: LoginManager may ignore fields without input events.
        # WebDriver element.sendKeys supplies actual synthetic key input and
        # a real submit-button click, all on the loopback test-owned page.
        is_local = js("""
            const f = document.querySelector('form#vulpra-local-login');
            return !!(f && location.hostname === '127.0.0.1' &&
                f.method.toLowerCase() === 'post' &&
                new URL(f.action).pathname === '/login-accepted');
        """)
        if is_local is not True:
            raise RuntimeError("Fake login form is not the permitted localhost fixture")

        def element(selector):
            found = h.request(port, "POST", base + "/element",
                              {"using": "css selector", "value": selector})
            key = "element-6066-11e4-a52e-4f735466cecf"
            if not isinstance(found, dict) or not isinstance(found.get(key), str):
                raise RuntimeError("Synthetic fixture element missing: " + selector)
            return found[key]

        for selector, synthetic in (
                ("#vulpra-local-username", "vulpra-ci-fake-user"),
                ("#vulpra-local-password", "vulpra-ci-fake-password")):
            target = element(selector)
            h.request(port, "POST", base + "/element/" + target + "/value",
                      {"text": synthetic, "value": list(synthetic)},
                      timeout_seconds=20)
        button = element("button[type=submit]")
        h.request(port, "POST", base + "/element/" + button + "/click", {},
                  timeout_seconds=30)
        end = time.monotonic() + 15
        while time.monotonic() < end:
            try:
                state = js("return {ok: !!document.querySelector('#submitted'), path: location.pathname};")
                if (isinstance(state, dict) and state.get("ok") is True and
                        state.get("path") == "/login-accepted" and
                        server.submitted_count == before + 1):
                    return
            except RuntimeError:
                pass  # Navigation can briefly destroy a WebDriver execution context.
            time.sleep(0.2)
        raise RuntimeError("Fake localhost login did not reach verified POST response")

    if not valid_chrome_record(chrome(CHROME_STATE), False):
        raise RuntimeError("BYOB login UI test started with an invalid disabled state")
    observed_positive = False
    try:
        submit("byob-disabled")
        end = time.monotonic() + 2
        while time.monotonic() < end:
            if not valid_chrome_record(chrome(CHROME_STATE), False):
                raise RuntimeError("Vulpra displayed its own password-save UI with BYOB disabled")
            time.sleep(0.2)
        enabled = chrome("""
            if (Services.prefs.prefHasUserValue('signon.rememberSignons') ||
                Services.prefs.getDefaultBranch('').getBoolPref('signon.rememberSignons') !== false)
                return false;
            Services.prefs.setBoolPref('signon.rememberSignons', true);
            return Services.prefs.getBoolPref('signon.rememberSignons') === true;
        """)
        if enabled is not True:
            raise RuntimeError("Cannot enable positive control in disposable Gecko profile")
        submit("positive-control")
        end = time.monotonic() + 10
        while time.monotonic() < end:
            if valid_chrome_record(chrome(CHROME_STATE), True):
                observed_positive = True
                break
            time.sleep(0.25)
        if not observed_positive:
            raise RuntimeError("Positive control failed: login-save doorhanger was never observed")
    finally:
        # Do not save a login or leave the positive-control pref active.
        state = chrome("""
            const win = Services.wm.getMostRecentWindow('navigator:browser');
            const ctrl = win?.PopupNotifications;
            const browser = win?.gBrowser?.selectedBrowser;
            const notif = ctrl?.getNotification('password', browser);
            if (notif) ctrl.remove(notif);
            if (Services.prefs.prefHasUserValue('signon.rememberSignons'))
                Services.prefs.clearUserPref('signon.rememberSignons');
            return {
                default_off: Services.prefs.getDefaultBranch('').getBoolPref('signon.rememberSignons') === false,
                effective_off: Services.prefs.getBoolPref('signon.rememberSignons') === false,
                no_user_override: !Services.prefs.prefHasUserValue('signon.rememberSignons'),
                no_doorhanger: !ctrl?.getNotification('password', browser)
            };
        """)
        if not isinstance(state, dict) or not all(state.get(k) is True for k in (
                "default_off", "effective_off", "no_user_override", "no_doorhanger")):
            raise RuntimeError("BYOB login UI test did not cleanly restore nonlocked defaults")
    if server.submitted_count != 2:
        raise RuntimeError("Fake login submit count does not match both test cases")
    return {"verified": True, "local_fake_login_submissions": 2,
            "builtin_login_save_prompt_suppressed": True,
            "positive_control_shows_save_doorhanger": observed_positive,
            "default_disabled_restored": True,
            "real_vault_or_credentials_accessed": False}


def main(repo):
    h = load_existing_helpers()
    archive = h.verified_archive(repo)
    root = repo / ".git/vulpra-native-build"
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vulpra-login-ui-") as tmp:
        work = Path(tmp)
        stage = work / "app"
        stage.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(stage)], check=True)
        app_ini = list(stage.rglob("application.ini"))
        if len(app_ini) != 1 or "Name=Vulpra" not in app_ini[0].read_text():
            raise RuntimeError("Unrecognized packaged Vulpra browser")
        browser = h.select_binary(app_ini[0].parent)
        home = work / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"Existing Firefox profiles must stay unchanged\n")
        original = sentinel.read_bytes()
        env = os.environ.copy()
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                    "MOZ_HEADLESS": "1", "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)
        gecko = shutil.which("geckodriver")
        if not gecko:
            raise RuntimeError("SHA-256-verified geckodriver required on CI runner")
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FakeLogin)
        server.submitted_count = 0
        from threading import Thread
        Thread(target=server.serve_forever, daemon=True).start()
        port = h.find_port()
        driver_log = root / "byob-login-ui-geckodriver.log"
        driver = None
        session = None
        try:
            with driver_log.open("wb") as handle:
                driver = subprocess.Popen(
                    [gecko, "--host", "127.0.0.1", "--port", str(port), "--allow-system-access"],
                    env=env, stdout=handle, stderr=subprocess.STDOUT,
                    start_new_session=True)
                h.wait_ready(port, driver)
                value = h.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser), "args": ["-headless", "-no-remote"],
                            "prefs": {
                                "remote.prefs.recommended": False,
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False, "extensions.update.enabled": False
                            }
                        }
                    }}
                })
                if not isinstance(value, dict) or not value.get("sessionId") or (
                        value.get("capabilities", {}).get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Disposable real Vulpra WebDriver session failed")
                session = str(value["sessionId"])
                report = verify_runtime(h, port, session, server)
                if sentinel.read_bytes() != original:
                    raise RuntimeError("Existing Firefox profile sentinel modified")
                out = root / "byob-login-ui-proof.json"
                out.write_text(json.dumps({"schema_version": 1, "status": "pass",
                                           "proof": report,
                                           "profile_sentinel_preserved": True,
                                           "native_rebuild": False,
                                           "security_current": False,
                                           "release_ready": False}, indent=2) + "\n")
                print("PASS: packaged Vulpra disabled own login-save UI; positive Firefox doorhanger control worked")
                print("LIMIT: synthetic localhost test only, not actual Bitwarden or Vaultwarden")
        finally:
            if session:
                try:
                    h.request(port, "DELETE", f"/session/{session}")
                except RuntimeError:
                    pass
            if driver:
                try:
                    os.killpg(driver.pid, signal.SIGTERM)
                    driver.wait(timeout=5)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(driver.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        else:
            main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
