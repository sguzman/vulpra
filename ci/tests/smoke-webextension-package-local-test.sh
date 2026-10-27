#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT="${1:?Absolute Python packaged WebExtension runner path}"
python3 - "$SCRIPT" <<'PY'
import hashlib
import http.server
import importlib.util
import json
import pathlib
import tempfile
import threading
import urllib.error
import urllib.request
import zipfile
import sys

spec = importlib.util.spec_from_file_location("vulpra_extension_smoke", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

with tempfile.TemporaryDirectory(prefix="vulpra-addon-tests-") as root:
    base = pathlib.Path(root)
    # A staged candidate's 'vulpra' may be a profile-guarding script.
    # Geckodriver must instead receive the native ELF binary.
    app = base / "unpacked"
    app.mkdir()
    guarded = app / "vulpra"
    native = app / "firefox"
    guarded.write_text("#!/bin/sh\\nexit 2\\n")
    guarded.chmod(0o755)
    native.write_bytes(bytes([0x7f]) + b"ELF" + b"\\0fixture")
    native.chmod(0o755)
    assert m.select_binary(app) == native
    native.unlink()
    try:
        m.select_binary(app)
    except RuntimeError as err:
        assert "native ELF" in str(err)
    else:
        raise AssertionError("Accepted isolated launcher as WebDriver native binary")
    native.write_bytes(bytes([0x7f]) + b"ELF" + b"\\0fixture")
    native.chmod(0o755)
    print("PASS: WebDriver chooses native ELF, rejects profile-guarding shell launcher")
    addon = base / "temp.xpi"
    token = "test-string-constant-2026"
    m.create_probe_extension(addon, token)
    with zipfile.ZipFile(addon) as z:
        assert set(z.namelist()) == {"manifest.json", "background.js", "content.js"}
        manifest = json.loads(z.read("manifest.json"))
        assert manifest["manifest_version"] == 2
        assert manifest["browser_specific_settings"]["gecko"]["id"] == "vulpra-local-smoke@testing.invalid"
        assert manifest["background"]["scripts"] == ["background.js"]
        assert "storage" in manifest["permissions"]
        assert "http://127.0.0.1/*" in manifest["permissions"]
        assert token in z.read("background.js").decode()
        assert token in z.read("content.js").decode()
        assert "browser.runtime.sendMessage" in z.read("content.js").decode()
        assert "browser.storage.local" in z.read("background.js").decode()
    print("PASS: generated XPI includes content, background and storage interfaces")

    # Reject delayed extension reinjection, not only immediate post-uninstall
    # leftovers. Check multiple observations before accepting an uninstall.
    no_proof = []
    def absent():
        no_proof.append(None)
        return None
    samples = m.verify_uninstall_stays_uninstalled(absent, seconds=0.03)
    assert samples >= 2 and len(no_proof) == samples
    pending = [None, token]
    def late_injection():
        return pending.pop(0)
    try:
        m.verify_uninstall_stays_uninstalled(late_injection, seconds=0.03)
    except RuntimeError as error:
        assert "still injected" in str(error)
    else:
        raise AssertionError("Delayed post-uninstall extension injection accepted")
    try:
        m.verify_uninstall_stays_uninstalled(absent, seconds=0)
    except ValueError:
        pass
    else:
        raise AssertionError("Zero-length uninstall observation accepted")
    print("PASS: repeated uninstall guard detects delayed reinjection")


    repo = base / "repo"
    pkgdir = repo / ".git/vulpra-native-build/packages"
    pkgdir.mkdir(parents=True)
    archive = pkgdir / "vulpra-local-fixture.tar.xz"
    archive.write_bytes(b"test synthetic archive bytes")
    archive.with_name(archive.name + ".sha256").write_text(
        hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n"
    )
    assert m.verified_archive(repo) == archive
    archive.write_bytes(b"corrupt bytes")
    try:
        m.verified_archive(repo)
    except RuntimeError as e:
        assert "SHA-256" in str(e)
    else:
        raise AssertionError("Corrupt package accepted")
    print("PASS: archive checksum verification rejects corruption")
    page_server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), m.LocalPage)
    page_server.paths = []
    threading.Thread(target=page_server.serve_forever, daemon=True).start()
    with urllib.request.urlopen(f"http://127.0.0.1:{page_server.server_port}/extension") as r:
        assert r.status == 200
        assert b"WebExtension test" in r.read()
    with urllib.request.urlopen(f"http://127.0.0.1:{page_server.server_port}/start") as r:
        assert b'location.assign("/js-run")' in r.read()
    with urllib.request.urlopen(f"http://127.0.0.1:{page_server.server_port}/js-run") as r:
        assert r.geturl().endswith("/page")
        assert b"JavaScript navigation succeeded" in r.read()
    assert page_server.paths[-3:] == ["/start", "/js-run", "/page"]
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{page_server.server_port}/wrong")
    except urllib.error.HTTPError as e:
        assert e.code == 404
    else:
        raise AssertionError("Non-probe route unexpectedly served")
    page_server.shutdown()
    page_server.server_close()
    print("PASS: localhost extension and JS/302 pages reject unrelated paths")
    class DriverMock(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            result = {"value": {"ready": True}}
            self.respond(result)
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            if self.path == "/session/fixture/moz/addon/install":
                assert body == {"path": "/tmp/dummy.xpi", "temporary": True}
                result = {"value": "vulpra-local-smoke@testing.invalid"}
            elif self.path == "/session/fixture/execute/sync":
                assert body["script"].startswith("return document.documentElement")
                result = {"value": token}
            else:
                result = {"value": {"error":"invalid argument", "message":"negative fixture"}}
            self.respond(result)
        def respond(self, result):
            data = json.dumps(result).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        def log_message(self, *_):
            pass
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), DriverMock)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    assert m.request(server.server_port, "GET", "/status") == {"ready": True}
    assert m.request(server.server_port, "POST", "/session/fixture/moz/addon/install",
                     {"path":"/tmp/dummy.xpi","temporary":True}) == "vulpra-local-smoke@testing.invalid"
    assert m.request(server.server_port, "POST", "/session/fixture/execute/sync",
                     {"script":"return document.documentElement.dataset.vulpraExtensionProof || null;", "args":[]}) == token
    try:
        m.request(server.server_port, "POST", "/session/bad", {})
    except RuntimeError as e:
        assert "invalid argument" in str(e)
    else:
        raise AssertionError("WebDriver error response accepted")
    server.shutdown()
    server.server_close()
    print("PASS: WebDriver addon install, JavaScript and error response handling")
    # Require both final browser DOM AND exact observed HTTP request sequence.
    original = m.request
    js_calls = []
    class FakePage:
        server_port = 8093
        paths = ["/start", "/js-run", "/page"]
    def fake_js_request(_port, method, route, payload=None, timeout_seconds=12):
        js_calls.append((method, route, payload))
        if route.endswith("/url"):
            assert method == "POST" and payload["url"].endswith("/start")
            return None
        if route.endswith("/execute/sync"):
            return {"url": "http://127.0.0.1:8093/page",
                    "title": "M3 destination",
                    "text": "JavaScript navigation succeeded"}
        raise AssertionError(route)
    try:
        m.request = fake_js_request
        result = m.verify_js_navigation(2011, "/session/mock", FakePage())
        assert result["verified"] and result["local_request_sequence"] == FakePage.paths
        assert js_calls[0][1] == "/session/mock/url"
        FakePage.paths = ["/start", "/js-run"]
        try:
            m.verify_js_navigation(2011, "/session/mock", FakePage())
        except RuntimeError as err:
            assert "navigation failed" in str(err)
        else:
            raise AssertionError("Accepted final DOM without final HTTP /page request")
    finally:
        m.request = original
    print("PASS: WebDriver JS redirect rejects incomplete HTTP navigation")
    # Validate CI-only Nimbus probe's privileged-context lifecycle without
    # invoking chrome context on normal M2 browsers.
    calls = []
    original_request = m.request
    def fake_request(port, method, route, payload=None, timeout_seconds=12):
        calls.append((method, route, payload))
        if route.endswith("/moz/context"):
            return None
        if route.endswith("/execute/async"):
            assert timeout_seconds > 14, "async Nimbus deadline must precede transport timeout"
            assert "ExperimentAPI.manager.store.ready()" in payload["script"]
            assert "ExperimentAPI.ready()" in payload["script"]
            return {"status":"pass","store_ready":True,"api_ready":True}
        raise AssertionError(route)
    try:
        m.request = fake_request
        answer = m.verify_nimbus_ready(2011, "/session/mock")
        assert answer["store_ready"] and answer["api_ready"]
        assert calls[0] == ("POST","/session/mock/moz/context",{"context":"chrome"})
        assert calls[-1] == ("POST","/session/mock/moz/context",{"context":"content"})
        calls.clear()
        def fake_failure(port, method, route, payload=None, timeout_seconds=12):
            calls.append((method, route, payload))
            if route.endswith("/execute/async"):
                return {"status":"timeout"}
            return None
        m.request = fake_failure
        try:
            m.verify_nimbus_ready(2011, "/session/mock")
        except RuntimeError as err:
            assert "Nimbus did not initialize" in str(err)
        else:
            raise AssertionError("Timed-out Nimbus accepted")
        assert calls[-1][2] == {"context":"content"}
    finally:
        m.request = original_request
    print("PASS: opt-in Nimbus privileged readiness guard, context reset and timeout refusal")
    # The promo opt-out probe must inspect the immutable compiled guard and
    # route both live message templates, then restore content context even
    # when one of the required checks fails.
    calls = []
    original_request = m.request
    def promo_mock(port, method, route, payload=None, timeout_seconds=12):
        calls.append((method, route, payload))
        if route.endswith("/moz/context"):
            return None
        if route.endswith("/execute/sync"):
            source = payload["script"]
            assert "AppConstants.VULPRA_NO_ASROUTER_PROMOS" in source
            assert "ASRouter.routeCFRMessage" in source
            assert '"sidebar_chatbot_promo"' in source
            assert '"smart_window_newtab_promo"' in source
            return {"status":"pass","compile_guard":True,"templates":2}
        raise AssertionError(route)
    try:
        m.request = promo_mock
        assert m.verify_asrouter_promo_optout(2011,"/session/mock")["templates"] == 2
        assert calls[0][2] == {"context":"chrome"}
        assert calls[-1][2] == {"context":"content"}
        calls.clear()
        def promo_failure(port, method, route, payload=None, timeout_seconds=12):
            calls.append((method, route, payload))
            if route.endswith("/execute/sync"):
                return {"status":"wrong-build-flag"}
            return None
        m.request = promo_failure
        try:
            m.verify_asrouter_promo_optout(2011,"/session/mock")
        except RuntimeError as err:
            assert "promotion opt-out dispatch failed" in str(err)
        else:
            raise AssertionError("Accepted runtime with missing immutable opt-out guard")
        assert calls[-1][2] == {"context":"content"}
    finally:
        m.request = original_request
    print("PASS: M3 packaged promo dispatch, immutable flag and context reset")

print("PASS: WebExtension offline regression suite")
PY
