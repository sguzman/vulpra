#!/usr/bin/env python3
"""Full browser restart on a verified archived Vulpra 160 native binary.

A temporary unsigned WebExtension MUST disappear after restart; same-origin
localStorage in the same disposable Firefox profile MUST survive. This is NOT
an AMO-signed extension persistence test or comprehensive security audit.
"""
import importlib.util
import hashlib
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


def load_probe(path: Path):
    spec = importlib.util.spec_from_file_location("vulpra_webdriver_probe", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("No verified WebDriver runtime helper")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    require(len(sys.argv) == 3, "usage: script REPO EXISTING_WEBDRIVER_HELPER")
    repo = Path(sys.argv[1]).resolve()
    helper = load_probe(Path(sys.argv[2]).resolve())
    archive = helper.verified_archive(repo)
    require(archive.name.startswith("vulpra-local-firefox160-"),
            "Refusing package without explicit Firefox 160 replay identity")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    geckodriver = shutil.which("geckodriver")
    require(geckodriver is not None, "Missing SHA-256 verified geckodriver")
    outdir = repo / ".git/vulpra-native-build"
    output = outdir / "firefox160-restart-proof.json"
    require(not output.exists(), "Refusing to overwrite previous restart evidence")

    with tempfile.TemporaryDirectory(prefix="vulpra160-restart-") as directory:
        root = Path(directory)
        app = root / "app"
        app.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(app)], check=True)
        ini = list(app.rglob("application.ini"))
        require(len(ini) == 1 and "Name=Vulpra" in ini[0].read_text().splitlines(),
                "Expected exactly one packaged native Vulpra identity")
        browser = helper.select_binary(ini[0].parent)
        home = root / "home"
        profile = root / "dedicated-firefox-profile"
        profile.mkdir()
        home.mkdir()
        original = home / ".mozilla/firefox/profiles.ini"
        original.parent.mkdir(parents=True)
        sentinel = b"existing Firefox profile: preserve across all restarts\n"
        original.write_bytes(sentinel)
        token = secrets.token_hex(18)
        addon = root / "unsigned-temporary-probe.xpi"
        helper.create_probe_extension(addon, token)

        server = helper.http.server.ThreadingHTTPServer(("127.0.0.1", 0), helper.LocalPage)
        server.paths = []
        threading.Thread(target=server.serve_forever, daemon=True).start()
        port = helper.find_port()
        env = os.environ.copy()
        env.update({
            "HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
            "MOZ_HEADLESS": "1", "NO_PROXY": "localhost,127.0.0.1",
            "no_proxy": "localhost,127.0.0.1",
        })
        for key in ("WAYLAND_DISPLAY", "DISPLAY", "MOZ_REMOTE"):
            env.pop(key, None)
        process = None
        session = None
        server_session_count = 0
        url = f"http://127.0.0.1:{server.server_port}/extension"
        def driver(method, endpoint, payload=None, timeout_seconds=15):
            return helper.request(port, method, endpoint, payload, timeout_seconds)
        def launch():
            payload = {
                "capabilities": {"alwaysMatch": {
                    "browserName": "firefox", "acceptInsecureCerts": False,
                    "moz:firefoxOptions": {
                        "binary": str(browser),
                        "args": ["-headless", "-no-remote", "-profile", str(profile)],
                        "prefs": {
                            "browser.shell.checkDefaultBrowser": False,
                            "app.update.enabled": False,
                            "extensions.update.enabled": False,
                            "media.autoplay.default": 0,
                        },
                    },
                }},
            }
            value = driver("POST", "/session", payload, timeout_seconds=45)
            require(isinstance(value, dict) and bool(value.get("sessionId")),
                    "WebDriver session not established")
            require(value.get("capabilities", {}).get("acceptInsecureCerts") is False,
                    "WebDriver insecure certs incorrectly enabled")
            return f"/session/{value['sessionId']}"
        def navigate(base):
            driver("POST", base + "/url", {"url": url}, timeout_seconds=35)
        def extension_proof(base):
            return driver("POST", base + "/execute/sync", {
                "script": "return document.documentElement.dataset.vulpraExtensionProof || null;",
                "args": [],
            })
        def storage(base, expression):
            return driver("POST", base + "/execute/sync", {
                "script": expression, "args": [],
            })
        def exit_session(base):
            driver("DELETE", base, timeout_seconds=30)
        try:
            process = subprocess.Popen(
                [geckodriver, "--host", "127.0.0.1", "--port", str(port)],
                env=env, stdout=(root / "geckodriver.log").open("wb"),
                stderr=subprocess.STDOUT, start_new_session=True,
            )
            helper.wait_ready(port, process)
            session = launch()
            server_session_count += 1
            navigate(session)
            require(extension_proof(session) is None,
                    "Unsigned extension unexpectedly present before installation")
            addon_id = driver("POST", session + "/moz/addon/install",
                              {"path": str(addon), "temporary": True})
            require(addon_id == "vulpra-local-smoke@testing.invalid",
                    "Temporary unsigned extension install identity mismatch")
            navigate(session)
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and extension_proof(session) != token:
                time.sleep(0.25)
            require(extension_proof(session) == token,
                    "Temporary unsigned extension did not execute before restart")
            saved = storage(session,
                            f"localStorage.setItem('vulpra160-restart', {json.dumps(token)}); return localStorage.getItem('vulpra160-restart');")
            require(saved == token, "Browser did not persist site localStorage")
            print("PASS: original native Firefox 160 session: temporary addon active and localStorage saved", flush=True)

            exit_session(session)
            session = None
            require(original.read_bytes() == sentinel,
                    "Existing Firefox profile changed after first browser exit")
            session = launch()
            server_session_count += 1
            navigate(session)
            require(storage(session, "return localStorage.getItem('vulpra160-restart');") == token,
                    "Same-origin site localStorage failed to survive a full browser restart")
            require(extension_proof(session) is None,
                    "Temporary unsigned WebExtension incorrectly persisted after full browser restart")
            # Fresh navigation rules out an only-temporary page state.
            navigate(session)
            require(extension_proof(session) is None,
                    "Temporary unsigned WebExtension reappeared after navigation")
            require(original.read_bytes() == sentinel,
                    "Existing Firefox profile changed after second browser launch")
            require(process.poll() is None,
                    "Geckodriver quit unexpectedly during two browser sessions")
            print("PASS: full native Firefox 160 restart preserves same-origin localStorage", flush=True)
            print("PASS: temporary unsigned WebExtension is absent after restart and fresh navigation", flush=True)
            output.write_text(json.dumps({
                "schema_version": 1,
                "status": "pass",
                "browser": "real native packaged Firefox 160 Vulpra",
                "package_sha256": digest,
                "browser_sessions_completed": server_session_count,
                "disposable_profile_reused": True,
                "same_origin_localstorage_persisted": True,
                "temporary_unsigned_webextension_executed_before_restart": True,
                "temporary_unsigned_webextension_absent_after_restart": True,
                "temporary_unsigned_webextension_absent_after_fresh_navigation": True,
                "existing_firefox_profile_preserved": True,
                "signed_addon_persistence_verified": False,
                "security_current": False,
                "release_ready": False,
                "limits": [
                    "Tests only a temporary unsigned WebExtension's non-persistence",
                    "Does not test permanently installed AMO-signed extensions",
                    "Does not establish profile upgrade/downgrade compatibility",
                    "No broad security or release approval",
                ],
            }, indent=2) + "\n")
        finally:
            if session is not None:
                try:
                    exit_session(session)
                except Exception:
                    pass
            if process is not None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            server.shutdown()
            server.server_close()
        require(output.is_file(), "No browser restart proof was written")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
