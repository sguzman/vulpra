#!/usr/bin/env python3
"""End-to-end WebExtension lifecycle against the existing packaged Vulpra.

Uses stock geckodriver's localhost WebDriver API via Python stdlib. No npm,
pip, modifications to the working source checkout or system Firefox profiles.
The probe tests unsigned temporary add-on installation, content scripts,
extension background messaging, storage.local, uninstall and profile safety.
"""
from __future__ import annotations

import hashlib
import http.server
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile

def request(port: int, method: str, route: str, payload: dict | None = None,
            timeout_seconds: float = 12) -> object:
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}{route}", data=data, method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds) as response:
            result = json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"WebDriver {method} {route}: {exc.code}: {exc.read()[:700]!r}") from exc
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"WebDriver {method} {route}: {exc}") from exc
    if not isinstance(result, dict) or "value" not in result:
        raise RuntimeError(f"Invalid WebDriver response to {route}: {result!r}")
    value = result["value"]
    if isinstance(value, dict) and value.get("error"):
        raise RuntimeError(f"WebDriver {route}: {value['error']}: {value.get('message', '')}")
    return value


def find_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_ready(port: int, proc: subprocess.Popen, seconds: float = 25) -> None:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"Geckodriver exited before session start (exit {proc.returncode})")
        try:
            value = request(port, "GET", "/status")
            if isinstance(value, dict) and value.get("ready"):
                return
        except RuntimeError:
            pass
        time.sleep(0.15)
    raise RuntimeError("Geckodriver /status did not become ready")


def select_binary(appdir: Path) -> Path:
    """Select the actual Linux native executable, not the protective wrapper.

    The staged candidate has a 'vulpra' Bash launcher that refuses --profile,
    which is correct for end users. Geckodriver supplies its own isolated
    temporary profile, so its automation executable must be the native ELF
    alongside that wrapper. This test always uses a disposable HOME.
    """
    for name in ("vulpra", "firefox"):
        binary = appdir / name
        if binary.is_file() and os.access(binary, os.X_OK):
            with binary.open("rb") as stream:
                if stream.read(4) == b"\x7fELF":
                    return binary
    raise RuntimeError("No actual native ELF Vulpra browser found beside application.ini")


def verified_archive(repo: Path) -> Path:
    pkgdir = repo / ".git/vulpra-native-build/packages"
    archives = sorted(pkgdir.glob("vulpra-local-*.tar.xz"),
                      key=lambda x: x.stat().st_mtime, reverse=True)
    if not archives:
        raise RuntimeError(f"No packaged Vulpra under {pkgdir}")
    archive = archives[0]
    sidecar = Path(str(archive) + ".sha256")
    if not sidecar.is_file():
        raise RuntimeError(f"Missing archive SHA-256 sidecar: {sidecar}")
    pieces = sidecar.read_text().split()
    if not pieces or len(pieces[0]) != 64:
        raise RuntimeError("Invalid SHA-256 sidecar")
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != pieces[0]:
        raise RuntimeError("Archive SHA-256 verification failed")
    return archive


def create_probe_extension(path: Path, token: str) -> None:
    addon_id = "vulpra-local-smoke@testing.invalid"
    manifest = {
        "manifest_version": 2,
        "name": "Vulpra Temporary Runtime Probe",
        "version": "1.0.0",
        "browser_specific_settings": {"gecko": {"id": addon_id}},
        "permissions": ["storage", "http://127.0.0.1/*"],
        "background": {"scripts": ["background.js"]},
        "content_scripts": [
            {"matches": ["http://127.0.0.1/*"], "js": ["content.js"], "run_at": "document_idle"}
        ],
    }
    background = (
        "browser.runtime.onMessage.addListener(async (message) => {"
        "if (!message || message.type !== 'vulpra-probe') return null;"
        f"await browser.storage.local.set({{proof: {json.dumps(token)}}});"
        "const value = await browser.storage.local.get('proof');"
        "return {proof:value.proof};});"
    )
    content = (
        "browser.runtime.sendMessage({type:'vulpra-probe'}).then(reply => {"
        f"if (reply && reply.proof === {json.dumps(token)}) "
        "document.documentElement.dataset.vulpraExtensionProof = reply.proof;"
        "}).catch(error => {"
        "document.documentElement.dataset.vulpraExtensionError = String(error);"
        "});"
    )
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as output:
        output.writestr("manifest.json", json.dumps(manifest))
        output.writestr("background.js", background)
        output.writestr("content.js", content)


class LocalPage(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = self.path.split("?")[0]
        self.server.paths.append(path)
        if path == "/extension":
            data = b'<!doctype html><html><meta charset="utf-8"><title>Vulpra extension smoke</title><h1>WebExtension test</h1></html>'
            status = 200
        elif path == "/start":
            data = (b'<!doctype html><meta charset="utf-8"><title>M3 startup</title>'
                    b'<script>location.assign("/js-run");</script>')
            status = 200
        elif path == "/js-run":
            data = b""
            status = 302
        elif path == "/page":
            data = (b'<!doctype html><meta charset="utf-8"><title>M3 destination</title>'
                    b'<h1 id="pass">JavaScript navigation succeeded</h1>')
            status = 200
        elif path == "/favicon.ico":
            data = b""
            status = 404
        else:
            self.send_error(404)
            return
        self.send_response(status)
        if path == "/js-run":
            self.send_header("Location", "/page")
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def log_message(self, *_args: object) -> None:
        pass



def verify_js_navigation(port: int, base: str, server: http.server.ThreadingHTTPServer) -> dict:
    """Require browser-executed JavaScript, followed HTTP 302 and final DOM.

    CLI --screenshot cannot provide this proof: it may exit while navigating.
    """
    request(port, "POST", base + "/url", {
        "url": f"http://127.0.0.1:{server.server_port}/start",
    }, timeout_seconds=35)
    deadline = time.monotonic() + 25
    reached = False
    last = None
    while time.monotonic() < deadline:
        last = request(port, "POST", base + "/execute/sync", {
            "script": "return {url: document.URL, title: document.title, text: document.querySelector('h1')?.textContent || null};",
            "args": [],
        })
        if (isinstance(last, dict) and
            last.get("url") == f"http://127.0.0.1:{server.server_port}/page" and
            last.get("title") == "M3 destination" and
            last.get("text") == "JavaScript navigation succeeded"):
            reached = True
            break
        time.sleep(0.25)
    observed = list(server.paths)
    functional = [path for path in observed if path != "/favicon.ico"]
    if not reached or functional != ["/start", "/js-run", "/page"]:
        raise RuntimeError(
            "Real WebDriver JS/302 navigation failed: "
            f"reached={reached}, current={last!r}, requests={observed!r}")
    return {"verified": True, "local_request_sequence": functional,
            "final_url": last["url"], "final_document_title": last["title"],
            "final_document_text": last["text"]}

def verify_nimbus_ready(port: int, base: str) -> dict:
    """CI-only privileged check: retained Nimbus actually initializes.

    Only run under an isolated browser process with geckodriver's explicit
    --allow-system-access switch. Never use privileged mode for regular
    M2 WebExtension testing or against an existing Firefox profile.
    """
    request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        result = request(port, "POST", base + "/execute/async", {
            "script": """
                const done = arguments[arguments.length - 1];
                let completed = false;
                const finish = value => {
                    if (!completed) { completed = true; done(value); }
                };
                const timer = setTimeout(() => finish({status: "timeout"}), 14000);
                (async () => {
                    try {
                        const { ExperimentAPI } = ChromeUtils.importESModule(
                            "resource://nimbus/ExperimentAPI.sys.mjs"
                        );
                        // Unconditional store.ready() cannot use ExperimentAPI's
                        // disabled-features early-return to falsely pass.
                        await ExperimentAPI.manager.store.ready();
                        await ExperimentAPI.ready();
                        clearTimeout(timer);
                        finish({status: "pass", store_ready: true, api_ready: true});
                    } catch (error) {
                        clearTimeout(timer);
                        finish({status: "error", reason: String(error)});
                    }
                })();
            """,
            "args": [],
        }, timeout_seconds=20)
    finally:
        request(port, "POST", base + "/moz/context", {"context": "content"})
    if not isinstance(result, dict) or result.get("status") != "pass" or not (
        result.get("store_ready") and result.get("api_ready")
    ):
        raise RuntimeError("Retained Nimbus did not initialize in lean browser: " + repr(result))
    return {"store_ready": True, "api_ready": True, "access": "CI-only isolated chrome context"}


def verify_asrouter_promo_optout(port: int, base: str) -> dict:
    """Exercise the actual packaged ASRouter guard in disposable chrome context.

    Resource omission is independently checked in the native package step.
    This verifies a remote promo template cannot dereference either omitted
    lazy module, while the retained ASRouter dispatcher still responds.
    """
    request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        result = request(port, "POST", base + "/execute/sync", {
            "script": """
                const { AppConstants } = ChromeUtils.importESModule(
                    "resource://gre/modules/AppConstants.sys.mjs"
                );
                if (!AppConstants.VULPRA_NO_ASROUTER_PROMOS) {
                    return {status: "wrong-build-flag"};
                }
                const { ASRouter } = ChromeUtils.importESModule(
                    "resource:///modules/asrouter/ASRouter.sys.mjs"
                );
                const templates = [
                    "sidebar_chatbot_promo", "smart_window_newtab_promo"
                ];
                for (const template of templates) {
                    const message = {id: "vulpra-m3-" + template,
                                     template, content: {}};
                    const routed = ASRouter.routeCFRMessage(
                        message, null, {id: "vulpra-m3-smoke"});
                    if (routed.message?.template !== template) {
                        return {status: "failed-dispatch", template};
                    }
                }
                return {status: "pass", compile_guard: true,
                        templates: templates.length};
            """,
            "args": [],
        }, timeout_seconds=20)
    finally:
        request(port, "POST", base + "/moz/context", {"context": "content"})
    if not isinstance(result, dict) or result.get("status") != "pass" or (
        result.get("compile_guard") is not True or result.get("templates") != 2
    ):
        raise RuntimeError("ASRouter promotion opt-out dispatch failed: " + repr(result))
    return result


def verify_newtab_adsfeed_optout(port: int, base: str) -> dict:
    """Exercise the packaged New Tab without its opt-in sponsored AdsFeed.

    A compile flag alone is not proof: require that the actual registered
    ActivityStream feeds omit AdsFeed while still exposing Top Sites and prefs,
    and that about:newtab loads in a disposable WebDriver browser.
    """
    request(port, "POST", base + "/url", {"url": "about:newtab"})
    page = request(port, "POST", base + "/execute/sync", {
        "script": """
            return {url: location.href, document: !!document.documentElement,
                    ready: document.readyState};
        """,
        "args": [],
    })
    if not isinstance(page, dict) or not page.get("document") or not (
        page.get("url", "").startswith("about:newtab") or
        page.get("url", "").startswith("about:home")
    ):
        raise RuntimeError("Packaged New Tab failed to render: " + repr(page))
    request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        state = request(port, "POST", base + "/execute/sync", {
            "script": """
                const { AppConstants } = ChromeUtils.importESModule(
                    "resource://gre/modules/AppConstants.sys.mjs"
                );
                if (!AppConstants.VULPRA_NO_NEWTAB_ADSFEED) {
                    return {status: "wrong-build-flag"};
                }
                const { ActivityStream } = ChromeUtils.importESModule(
                    "resource://newtab/lib/ActivityStream.sys.mjs"
                );
                const keys = [...new ActivityStream().feeds.keys()];
                return {
                    status: "pass",
                    omitted: !keys.includes("feeds.adsfeed"),
                    topsites: keys.includes("feeds.system.topsites"),
                    prefs: keys.includes("feeds.prefs"),
                    feed_count: keys.length,
                };
            """,
            "args": [],
        }, timeout_seconds=25)
    finally:
        request(port, "POST", base + "/moz/context", {"context": "content"})
    if not isinstance(state, dict) or state.get("status") != "pass" or not (
        state.get("omitted") and state.get("topsites") and state.get("prefs")
    ):
        raise RuntimeError("Packaged New Tab AdsFeed guard/fallback failed: " + repr(state))
    return {"page": page, "factory_guard": state}


def verify_uninstall_stays_uninstalled(proof, seconds: float = 2.0) -> int:
    """Require the removed extension to stay absent across an observation window.

    A single immediate read after navigation can return None before a delayed
    content script injects; it is not sufficient evidence that uninstall worked.
    """
    if seconds <= 0:
        raise ValueError("The uninstall observation window must be positive")
    deadline = time.monotonic() + seconds
    samples = 0
    while True:
        if proof() is not None:
            raise RuntimeError(
                "WebExtension content script still injected after uninstall"
            )
        samples += 1
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return samples
        time.sleep(min(0.25, remaining))


def main() -> int:
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Code/Apps/vulpra").resolve()
    gecko = shutil.which("geckodriver")
    if not gecko:
        candidate = repo / "obj-vulpra-linux/dist/bin/geckodriver"
        if candidate.is_file() and os.access(candidate, os.X_OK):
            gecko = str(candidate)
    if not gecko:
        raise RuntimeError(
            "Geckodriver not available. On EndeavourOS install official package "
            "with: yay -S --needed geckodriver. No npm or pip required."
        )
    nimbus_check = os.environ.get("VULPRA_M3_VERIFY_NIMBUS", "0") == "1"
    promo_check = os.environ.get("VULPRA_M3_VERIFY_NO_ASROUTER_PROMOS", "0") == "1"
    adsfeed_check = os.environ.get("VULPRA_M3_VERIFY_NO_NEWTAB_ADSFEED", "0") == "1"
    archive = verified_archive(repo)
    print(f"PASS: Verified existing archive {archive.name}", flush=True)
    logdir = repo / ".git/vulpra-native-build"
    stamp = time.strftime("%Y%m%d-%H%M%S")
    output = logdir / f"webextension-smoke-{stamp}.json"
    gecko_log = logdir / f"webextension-geckodriver-{stamp}.log"
    token = secrets.token_hex(16)
    with tempfile.TemporaryDirectory(prefix="vulpra-ext-smoke-") as temp:
        work = Path(temp)
        app = work / "app"
        app.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(app)], check=True)
        ini_files = list(app.rglob("application.ini"))
        if len(ini_files) != 1 or "Name=Vulpra" not in ini_files[0].read_text().splitlines():
            raise RuntimeError("Package identity is missing or not Vulpra")
        appdir = ini_files[0].parent
        browser = select_binary(appdir)
        home = work / "home"
        home.mkdir()
        fake_firefox = home / ".mozilla/firefox/profiles.ini"
        fake_firefox.parent.mkdir(parents=True)
        sentinel = b"existing Firefox profile: must never change\n"
        fake_firefox.write_bytes(sentinel)
        addon = work / "probe.xpi"
        create_probe_extension(addon, token)
        env = os.environ.copy()
        env.update({
            "HOME": str(home),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "MOZ_HEADLESS": "1",
            "NO_PROXY": "127.0.0.1,localhost",
            "no_proxy": "127.0.0.1,localhost",
        })
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), LocalPage)
        server.paths = []
        from threading import Thread
        Thread(target=server.serve_forever, daemon=True).start()
        port = find_port()
        session_id = None
        proc = None
        try:
            with gecko_log.open("wb") as driver_log:
                proc = subprocess.Popen([gecko, "--host", "127.0.0.1", "--port", str(port)] +
                                        (["--allow-system-access"] if nimbus_check or promo_check or adsfeed_check else []),
                                        env=env, stdout=driver_log, stderr=subprocess.STDOUT,
                                        start_new_session=True)
                wait_ready(port, proc)
                value = request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox",
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
                })
                if not isinstance(value, dict) or not value.get("sessionId"):
                    raise RuntimeError(f"WebDriver new session did not return session ID: {value!r}")
                session_id = str(value["sessionId"])
                reported = value.get("capabilities", {})
                if reported.get("browserName") != "firefox":
                    raise RuntimeError(f"Unexpected automation browser: {reported!r}")
                base = f"/session/{session_id}"
                js_result = verify_js_navigation(port, base, server)
                print("PASS: real WebDriver JS redirect, HTTP 302 and final DOM", flush=True)
                url = f"http://127.0.0.1:{server.server_port}/extension"
                def navigate(suffix: str) -> None:
                    request(port, "POST", base + "/url", {"url": url + "?step=" + suffix})

                def proof() -> object:
                    return request(port, "POST", base + "/execute/sync", {
                        "script": "return document.documentElement.dataset.vulpraExtensionProof || null;",
                        "args": [],
                    })

                navigate("before")
                if proof() is not None:
                    raise RuntimeError("Extension proof appeared before installation")
                print("PASS: Unsigned probe not present before installation", flush=True)
                addon_id = request(port, "POST", base + "/moz/addon/install", {
                    "path": str(addon), "temporary": True,
                })
                if addon_id != "vulpra-local-smoke@testing.invalid":
                    raise RuntimeError(f"Installed extension ID mismatch: {addon_id!r}")
                deadline = time.monotonic() + 15
                # Navigate again to guarantee fresh content-script injection.
                navigate("installed")
                while time.monotonic() < deadline and proof() != token:
                    time.sleep(0.25)
                if proof() != token:
                    raise RuntimeError("Extension content/background/storage proof not observed after installation")
                print("PASS: Temporary unsigned WebExtension installed; content script, background messaging and storage.local executed", flush=True)
                request(port, "POST", base + "/moz/addon/uninstall", {"id": addon_id})
                navigate("uninstalled")
                uninstall_samples = verify_uninstall_stays_uninstalled(proof)
                print(f"PASS: WebExtension uninstall remained inactive across {uninstall_samples} repeated checks", flush=True)
                nimbus_result = None
                if nimbus_check:
                    nimbus_result = verify_nimbus_ready(port, base)
                    print("PASS: Nimbus ExperimentStore and API initialized in real packaged browser", flush=True)
                promo_result = None
                if promo_check:
                    promo_result = verify_asrouter_promo_optout(port, base)
                    print("PASS: two omitted ASRouter promo template routes stayed harmless", flush=True)
                adsfeed_result = None
                if adsfeed_check:
                    adsfeed_result = verify_newtab_adsfeed_optout(port, base)
                    print("PASS: real about:newtab and guarded sponsored AdsFeed omission", flush=True)
                if fake_firefox.read_bytes() != sentinel:
                    raise RuntimeError("Existing Firefox profile sentinel modified")
                print("PASS: Temporary HOME and existing Firefox profile preserved", flush=True)
                report = {
                    "schema_version": 1, "status": "pass",
                    "package": archive.name,
                    "javascript_navigation": js_result,
                    "webextension": {"manifest_version": 2, "temporary_unsigned_install": True,
                                     "content_scripts": True, "background_messaging": True,
                                     "storage_local": True, "uninstall": True,
                                     "post_uninstall_observation_seconds": 2.0,
                                     "post_uninstall_samples": uninstall_samples},
                    "security": {"original_firefox_profile_preserved": True, "temporary_home": True},
                    "nimbus": nimbus_result,
                    "asrouter_promotion_optout": promo_result,
                    "newtab_adsfeed_optout": adsfeed_result,
                    "limits": ["Not a comprehensive security audit", "Does not test signed AMO extensions",
                               "Does not verify persisted extensions across restarts"],
                }
                output.write_text(json.dumps(report, indent=2) + "\n")
        finally:
            if session_id:
                try:
                    request(port, "DELETE", f"/session/{session_id}")
                except RuntimeError:
                    pass
            if proc is not None:
                try:
                    import signal
                    os.killpg(proc.pid, signal.SIGTERM)
                    proc.wait(timeout=5)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            server.shutdown()
            server.server_close()
    print(f"PASS: Real packaged Vulpra WebExtension runtime acceptance: {output}")
    print(f"Driver log: {gecko_log}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, urllib.error.URLError, subprocess.CalledProcessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
