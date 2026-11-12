#!/usr/bin/env python3
"""Native packaged Firefox 160 CSP / HTML iframe sandbox security regression.

Tests explicit positive/negative real DOM behavior against localhost endpoints.
Uses the previously SHA-256-authenticated original Firefox 160 artifact only.
Never modifies installed browsers, Firefox profiles, or host security prefs.

This exercises a narrow web-platform security boundary; no general CSP or
sandbox certification, CVE closure, or release approval is inferred.
"""
from __future__ import annotations

import hashlib
import http.server
import importlib.util
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
import time

HERE = Path(__file__).resolve().parent
HELPER = HERE / "security-160-persistent-extension-restart.py"
spec = importlib.util.spec_from_file_location("vulpra160_sandbox_session", HELPER)
if spec is None or spec.loader is None:
    raise RuntimeError("Missing verified native-browser session helper")
helper = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = helper
spec.loader.exec_module(helper)
wd = helper.wd


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


class SecurityFixture(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.partition("?")[0]
        csp = None
        if path in ("/csp-open", "/csp-self", "/csp-none"):
            csp = {
                "/csp-open": None,
                "/csp-self": "script-src 'self'; object-src 'none'; base-uri 'none'",
                "/csp-none": "script-src 'none'; object-src 'none'; base-uri 'none'",
            }[path]
            label = path.removeprefix("/csp-")
            data = (
                '<!doctype html><html><head><meta charset="utf-8">'
                '<title>CSP fixture ' + label + '</title>'
                '<script>document.documentElement.dataset.inlineExecuted="yes";</script>'
                '<script src="/external.js"></script>'
                '</head><body><h1>Real CSP fixture</h1></body></html>'
            ).encode("utf-8")
            mime = "text/html; charset=utf-8"
        elif path == "/external.js":
            data = b'document.documentElement.dataset.externalExecuted = "yes";'
            mime = "application/javascript"
        elif path in ("/frame-script-opaque", "/frame-script-normal",
                      "/frame-script-blocked"):
            kind = path.removeprefix("/frame-script-")
            attr = {
                "opaque": 'sandbox="allow-scripts"',
                "normal": "",
                "blocked": 'sandbox="allow-same-origin"',
            }[kind]
            # Parent handler is installed *before* the iframe appears.
            data = (
                '<!doctype html><html><head><meta charset="utf-8">'
                '<title>Frame fixture ' + kind + '</title>'
                '<script>'
                'window.__vulpraFrameEvidence=null;'
                'window.addEventListener("message",event=>{'
                'if(event.source!==document.getElementById("target").contentWindow)'
                'return;'
                'if(event.data?.kind!=="vulpra-frame-probe")return;'
                'window.__vulpraFrameEvidence={'
                'origin:event.origin,denied:event.data.denied,'
                'type:event.data.type};'
                '});'
                '</script></head><body><h1>Frame parent</h1>'
                '<iframe id="target" ' + attr + ' src="/frame-child"></iframe>'
                '</body></html>'
            ).encode("utf-8")
            mime = "text/html; charset=utf-8"
        elif path == "/frame-child":
            data = (
                '<!doctype html><html><head><meta charset="utf-8">'
                '<title>Frame child</title></head><body>'
                '<script>'
                'let denied=false; let type="none";'
                'try{'
                'parent.document.documentElement.dataset.frameTouched="yes";'
                '}catch(e){denied=true;type=e?.name||"Error";}'
                'parent.postMessage({kind:"vulpra-frame-probe",denied,type},"*");'
                '</script><h1>Child present</h1></body></html>'
            ).encode("utf-8")
            mime = "text/html; charset=utf-8"
        elif path == "/favicon.ico":
            self.send_response(404)
            self.end_headers()
            return
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Cache-Control", "no-store")
        if csp is not None:
            self.send_header("Content-Security-Policy", csp)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_args):
        pass


def accepted_csp(proof):
    need(isinstance(proof, dict), "Missing real CSP browser evidence")
    expect = {
        "open": (True, True),
        "self": (False, True),
        "none": (False, False),
    }
    need(set(proof) == set(expect), "Wrong CSP branch set")
    for kind, wanted in expect.items():
        item = proof[kind]
        need(isinstance(item, dict) and item.get("loaded") is True,
             "Missing loaded CSP " + kind + " page")
        need(type(item.get("inline_executed")) is bool and
             type(item.get("external_executed")) is bool,
             "CSP state was not a boolean")
        need((item["inline_executed"], item["external_executed"]) == wanted,
             "CSP script policy did not match enforced runtime expectation: " + kind)
    return True


def accepted_frames(proof):
    need(isinstance(proof, dict), "Missing real iframe sandbox evidence")
    need(set(proof) == {"normal", "opaque", "blocked"}, "Wrong frame branch set")
    a, b, c = proof["normal"], proof["opaque"], proof["blocked"]
    need(all(isinstance(x, dict) for x in (a, b, c)),
         "Malformed browser sandbox result")
    need(a.get("loaded") is True and a.get("frame_touched") is True and
         a.get("message_origin_is_parent") is True and
         a.get("access_denied") is False,
         "Unsandboxed same-origin positive control did not read parent DOM")
    need(b.get("loaded") is True and b.get("frame_touched") is False and
         b.get("message_origin") == "null" and
         b.get("access_denied") is True and
         b.get("denial_error_type") == "SecurityError",
         "allow-scripts without allow-same-origin failed opaque-origin isolation")
    need(c.get("loaded") is True and c.get("frame_touched") is False and
         c.get("child_script_executed") is False and
         c.get("child_parent_dom_visible") is True,
         "allow-same-origin without allow-scripts failed script restriction")
    return True


def self_test():
    csp = {
        "open": {"loaded": True, "inline_executed": True, "external_executed": True},
        "self": {"loaded": True, "inline_executed": False, "external_executed": True},
        "none": {"loaded": True, "inline_executed": False, "external_executed": False},
    }
    frames = {
        "normal": {"loaded": True, "frame_touched": True,
                   "message_origin_is_parent": True, "access_denied": False},
        "opaque": {"loaded": True, "frame_touched": False,
                   "message_origin": "null", "access_denied": True,
                   "denial_error_type": "SecurityError"},
        "blocked": {"loaded": True, "frame_touched": False,
                    "child_script_executed": False,
                    "child_parent_dom_visible": True},
    }
    accepted_csp(csp)
    accepted_frames(frames)
    failures = 0
    invalid_csp = [
        {**csp, "open": {**csp["open"], "inline_executed": False}},
        {**csp, "self": {**csp["self"], "inline_executed": True}},
        {**csp, "self": {**csp["self"], "external_executed": False}},
        {**csp, "none": {**csp["none"], "external_executed": True}},
        {**csp, "none": {**csp["none"], "external_executed": "false"}},
        {**csp, "open": {**csp["open"], "loaded": False}},
        {"none": csp["none"]},
    ]
    invalid_frames = [
        {**frames, "normal": {**frames["normal"], "frame_touched": False}},
        {**frames, "normal": {**frames["normal"], "access_denied": True}},
        {**frames, "opaque": {**frames["opaque"], "frame_touched": True}},
        {**frames, "opaque": {**frames["opaque"], "message_origin": "http"}},
        {**frames, "opaque": {**frames["opaque"], "access_denied": False}},
        {**frames, "opaque": {**frames["opaque"], "denial_error_type": "TypeError"}},
        {**frames, "blocked": {**frames["blocked"], "child_script_executed": True}},
        {**frames, "blocked": {**frames["blocked"], "child_parent_dom_visible": False}},
        {"opaque": frames["opaque"]},
    ]
    for bad in invalid_csp:
        try:
            accepted_csp(bad)
        except RuntimeError:
            failures += 1
        else:
            raise RuntimeError("Forged CSP fixture accepted")
    for bad in invalid_frames:
        try:
            accepted_frames(bad)
        except RuntimeError:
            failures += 1
        else:
            raise RuntimeError("Forged frame fixture accepted")
    need(failures == 16, "Negative-control total drifted")
    print("PASS: 16 forged CSP/iframe sandbox outcomes correctly rejected")


def execute(port, sid, url, script, args=None):
    base = "/session/" + sid
    wd.request(port, "POST", base + "/url", {"url": url}, timeout_seconds=35)
    deadline = time.monotonic() + 8
    result = None
    while time.monotonic() < deadline:
        result = wd.request(port, "POST", base + "/execute/sync",
                            {"script": script, "args": args or []},
                            timeout_seconds=12)
        if isinstance(result, dict) and result.get("loaded") is True:
            return result
        time.sleep(0.15)
    raise RuntimeError("Native browser page not ready in isolated security fixture")


def run(repo: Path, output: Path):
    need(not output.exists(), "Refusing to overwrite any prior security evidence")
    gecko = shutil.which("geckodriver")
    need(gecko is not None, "Pinned native geckodriver not available")
    archive = wd.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"),
         "Refusing non-Firefox-160 archive")
    archive_hash = hashlib.sha256(archive.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="vulpra160-csp-frame-") as temp:
        work = Path(temp)
        packaged = work / "package"
        packaged.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(packaged)],
                       check=True, timeout=90)
        apps = list(packaged.rglob("application.ini"))
        need(len(apps) == 1 and "Name=Vulpra" in apps[0].read_text().splitlines(),
             "Pinned packaged Vulpra native identity missing")
        binary = wd.select_binary(apps[0].parent)
        home = work / "home"
        home.mkdir()
        original = home / ".mozilla/firefox/profiles.ini"
        original.parent.mkdir(parents=True)
        sentinel = b"unrelated Firefox profile must not change for CSP fixture\n"
        original.write_bytes(sentinel)
        profile = work / "disposable-profile"
        profile.mkdir()
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
                                                  SecurityFixture)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        origin = f"http://127.0.0.1:{server.server_port}"
        csp = {}
        frames = {}
        try:
            with helper.session(gecko, binary, profile, home,
                                work / "webdriver.log",
                                "CSP/iframe sandbox") as (port, sid):
                for kind in ("open", "self", "none"):
                    state = execute(port, sid, origin + "/csp-" + kind, """
                      return {
                        loaded:document.readyState==="complete" &&
                          document.title===arguments[0],
                        inline_executed:
                          document.documentElement.dataset.inlineExecuted==="yes",
                        external_executed:
                          document.documentElement.dataset.externalExecuted==="yes"
                      };
                    """, ["CSP fixture " + kind])
                    csp[kind] = state
                accepted_csp(csp)
                print("PASS: native Firefox 160 CSP open/self/none script contrasts",
                      flush=True)

                frame_script = """
                  const kind=arguments[0], parent=arguments[1];
                  const iframe=document.getElementById("target");
                  if(!iframe)return {loaded:false};
                  const msg=window.__vulpraFrameEvidence;
                  const loaded=iframe.contentWindow &&
                    iframe.contentWindow.location &&
                    iframe.contentWindow!==window &&
                    document.title==="Frame fixture "+kind &&
                    iframe.getBoundingClientRect().width>0;
                  if(kind==="blocked"){
                    let visible=false,executed=false;
                    try{
                      const doc=iframe.contentDocument;
                      visible=!!doc && doc.title==="Frame child";
                      executed=!!doc &&
                        !!doc.documentElement.dataset.frameTouched;
                    }catch(_){}
                    return {
                      loaded:!!loaded && !!visible,frame_touched:
                        document.documentElement.dataset.frameTouched==="yes",
                      child_script_executed:!!msg || executed,
                      child_parent_dom_visible:visible
                    };
                  }
                  return {
                    loaded:!!loaded && !!msg,
                    frame_touched:
                      document.documentElement.dataset.frameTouched==="yes",
                    message_origin_is_parent:kind==="normal" ?
                      !!msg && msg.origin===parent : false,
                    message_origin:msg?.origin||null,
                    access_denied:msg?.denied,
                    denial_error_type:msg?.type
                  };
                """
                for kind in ("normal", "opaque", "blocked"):
                    state = execute(port, sid,
                                    origin + "/frame-script-" + kind,
                                    frame_script, [kind, origin])
                    frames[kind] = state
                accepted_frames(frames)
                print("PASS: real iframe normal/opaque/script-blocked origin checks",
                      flush=True)
                need(original.read_bytes() == sentinel,
                     "Other Firefox-profile sentinel modified by sandbox test")
        finally:
            server.shutdown()
            server.server_close()
        need(original.read_bytes() == sentinel,
             "Other Firefox profile changed during isolated test")
        proof = {
            "schema_version": 1,
            "status": "pass",
            "native_package_sha256": archive_hash,
            "localhost_only": True,
            "real_csp_open_allows_inline_and_external_scripts": True,
            "real_csp_self_blocks_inline_allows_external": True,
            "real_csp_none_blocks_inline_and_external": True,
            "unsandboxed_same_origin_frame_access_allowed": True,
            "allow_scripts_without_same_origin_denied_parent_dom": True,
            "sandboxed_frame_opaque_message_origin_observed": True,
            "allow_same_origin_without_scripts_blocked_child_js": True,
            "unrelated_firefox_profile_preserved": True,
            "used_unmodified_native_firefox160_archive": True,
            "browser_security_prefs_unchanged": True,
            "sandboxed_frame_seccomp_syscall_denial_tested": False,
            "full_csp_sandbox_security_policy_audited": False,
            "provider_backed_safe_browsing_ready": False,
            "security_current": False,
            "release_ready": False,
            "limits": [
                "Only these local CSP and HTML iframe sandbox scenarios",
                "No Linux kernel seccomp syscall denial or policy audit",
                "No Firefox 160 advisory exploit reproduction",
                "No real-world sites, hardware GPU tests or user profiles"
            ],
        }
        output.write_text(json.dumps(proof, indent=2) + "\n")
    print("PASS: actual packaged Firefox 160 CSP and HTML sandbox enforcement",
          flush=True)
    print("LIMIT: narrow DOM security regression only; not release authorization",
          flush=True)


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 3:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
