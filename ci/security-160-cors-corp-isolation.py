#!/usr/bin/env python3
"""Real packaged Firefox 160 localhost CORS and CORP network-boundary probes.

Reuses the original SHA-256-authenticated Vulpra Firefox 160 native archive.
Two independent 127.0.0.1 ephemeral ports are intentionally distinct origins.
No browser security prefs, installed Firefox, real network targets, or user
profiles are changed. These are bounded web-platform tests, NOT seccomp,
whole-browser security, advisory coverage, or release approval.
"""
from __future__ import annotations

import base64
from collections import Counter
import hashlib
import http.server
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = Path(__file__).resolve().parent
HELPER = HERE / "security-160-persistent-extension-restart.py"
spec = importlib.util.spec_from_file_location("vulpra160_cors_session", HELPER)
if spec is None or spec.loader is None:
    raise RuntimeError("Missing authentic native Firefox 160 session helper")
helper = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = helper
spec.loader.exec_module(helper)
wd = helper.wd

# Verified locally as a valid 1x1 GIF. Same exact bytes in all CORP variants.
IMAGE = base64.b64decode("R0lGODlhAQABAAD/ACwAAAAAAQABAAACAUwAOw==")
BODY = b"vulpra-cors-approved-response"


def need(condition, reason):
    if not condition:
        raise RuntimeError(reason)


class ResourceServer(http.server.BaseHTTPRequestHandler):
    def _record(self, path, method):
        with self.server.event_lock:
            self.server.events[(method, path)] += 1

    def do_OPTIONS(self):
        path = self.path.split("?", 1)[0]
        if self.server.role != "resource" or path not in (
                "/cors/preflight-allow", "/cors/preflight-deny"):
            self.send_error(404)
            return
        self._record(path, "OPTIONS")
        self.send_response(204)
        self.send_header("Cache-Control", "no-store")
        if path == "/cors/preflight-allow":
            self.send_header("Access-Control-Allow-Origin",
                             self.server.client_origin)
            self.send_header("Access-Control-Allow-Methods", "GET")
            self.send_header("Access-Control-Allow-Headers", "x-vulpra-ci-probe")
            self.send_header("Access-Control-Max-Age", "0")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        client = self.server.role == "client"
        if client and path == "/":
            body = (b'<!doctype html><html><head><meta charset="utf-8">'
                    b'<title>Vulpra two-origin isolation</title></head>'
                    b'<body><h1>Localhost boundary fixture</h1></body></html>')
            mime = "text/html; charset=utf-8"
            cors = None
            corp = None
        elif client and path == "/cors/same":
            body, mime, cors, corp = BODY, "text/plain", None, None
        elif client and path == "/image/same":
            body, mime, cors, corp = IMAGE, "image/gif", None, "same-origin"
        elif not client and path in (
            "/cors/deny", "/cors/allow", "/cors/wildcard-credentials",
            "/cors/preflight-allow", "/cors/preflight-deny", "/cors/no-cors"
        ):
            body, mime, corp = BODY, "text/plain", None
            cors = (
                self.server.client_origin
                if path in ("/cors/allow", "/cors/preflight-allow")
                else "*" if path == "/cors/wildcard-credentials" else None
            )
        elif not client and path in (
            "/image/unrestricted", "/image/cross-origin", "/image/same-origin"
        ):
            body, mime, cors = IMAGE, "image/gif", None
            corp = {
                "/image/unrestricted": None,
                "/image/cross-origin": "cross-origin",
                "/image/same-origin": "same-origin",
            }[path]
        elif path == "/favicon.ico":
            self.send_response(404)
            self.end_headers()
            return
        else:
            self.send_error(404)
            return
        self._record(path, "GET")
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if cors is not None:
            self.send_header("Access-Control-Allow-Origin", cors)
        if path == "/cors/wildcard-credentials":
            # Wildcard ACAO is invalid when fetch credentials mode is include,
            # even if no cookies were ever configured for this fixture.
            self.send_header("Access-Control-Allow-Credentials", "true")
        if corp is not None:
            self.send_header("Cross-Origin-Resource-Policy", corp)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


CORS_CASES = {
    "same_origin": ("ok", 200, True),
    "cross_origin_no_acao": ("blocked", "TypeError"),
    "cross_origin_exact_acao": ("ok", 200, True),
    "wildcard_acao_credentials_include": ("blocked", "TypeError"),
    "preflight_allowed": ("ok", 200, True),
    "preflight_denied": ("blocked", "TypeError"),
    "no_cors_opaque": ("opaque", 0, "opaque"),
}
IMAGE_CASES = {
    "same_origin_corp_same_origin": True,
    "cross_origin_unrestricted": True,
    "cross_origin_corp_cross_origin": True,
    "cross_origin_corp_same_origin": False,
}


def verify_cors(items):
    need(isinstance(items, dict) and set(items) == set(CORS_CASES),
         "Real CORS case set is absent or contains unknown cases")
    for name, expected in CORS_CASES.items():
        result = items[name]
        need(isinstance(result, dict) and result.get("outcome") == expected[0],
             "CORS outcome missing/wrong: " + name)
        if expected[0] == "ok":
            need(type(result.get("status")) is int and
                 result["status"] == expected[1] and
                 result.get("body_matches") is True and
                 result.get("response_type") == "basic" if name == "same_origin"
                 else type(result.get("status")) is int and
                      result["status"] == expected[1] and
                      result.get("body_matches") is True and
                      result.get("response_type") == "cors",
                 "Readable CORS response missing, wrong body, or wrong type: " + name)
        elif expected[0] == "blocked":
            need(result.get("error_name") == expected[1],
                 "Cross-origin fetch was not rejected with TypeError: " + name)
        else:
            need(type(result.get("status")) is int and
                 result["status"] == 0 and
                 result.get("response_type") == "opaque" and
                 result.get("unreadable_body") is True,
                 "no-cors response exposed data or failed opaque result")
    return True


def verify_images(items):
    need(isinstance(items, dict) and set(items) == set(IMAGE_CASES),
         "CORP image case set is missing/unexpected")
    for name, expected in IMAGE_CASES.items():
        result = items[name]
        need(isinstance(result, dict) and
             result.get("event") == ("load" if expected else "error") and
             result.get("loaded_1x1") is expected,
             "CORP policy cross-origin image mismatch: " + name)
    return True


def verify_server_requests(client, resource):
    need(isinstance(client, dict) and isinstance(resource, dict),
         "Missing actual local HTTP request observations")
    expected_client = {("GET", "/"): 1,
                       ("GET", "/cors/same"): 1,
                       ("GET", "/image/same"): 1}
    expected_resource = {
        ("GET", "/cors/deny"): 1,
        ("GET", "/cors/allow"): 1,
        ("GET", "/cors/wildcard-credentials"): 1,
        ("GET", "/cors/preflight-allow"): 1,
        ("OPTIONS", "/cors/preflight-allow"): 1,
        ("OPTIONS", "/cors/preflight-deny"): 1,
        ("GET", "/cors/no-cors"): 1,
        ("GET", "/image/unrestricted"): 1,
        ("GET", "/image/cross-origin"): 1,
        ("GET", "/image/same-origin"): 1,
    }
    # Explicitly reject an unauthorized GET after a blocked preflight.
    need(resource.get(("GET", "/cors/preflight-deny"), 0) == 0,
         "Blocked preflight incorrectly sent its protected GET")
    # No silent extra host requests; favicon requests are not recorded.
    need(client == expected_client and resource == expected_resource,
         "Local server request ledger mismatch (localhost route/method/count only): " +
         "client=" + repr(sorted(client.items())) +
         " expected_client=" + repr(sorted(expected_client.items())) +
         " resource=" + repr(sorted(resource.items())) +
         " expected_resource=" + repr(sorted(expected_resource.items())))
    return True


def self_test():
    cors = {
        name: (
            {"outcome": "ok", "status": 200,
             "body_matches": True,
             "response_type": "basic" if name == "same_origin" else "cors"}
            if expectation[0] == "ok" else
            {"outcome": "blocked", "error_name": "TypeError"}
            if expectation[0] == "blocked" else
            {"outcome": "opaque", "status": 0,
             "response_type": "opaque", "unreadable_body": True}
        )
        for name, expectation in CORS_CASES.items()
    }
    images = {name: {"event": "load" if ok else "error",
                     "loaded_1x1": ok} for name, ok in IMAGE_CASES.items()}
    client = {("GET", "/"): 1, ("GET", "/cors/same"): 1,
              ("GET", "/image/same"): 1}
    resource = {("GET", "/cors/deny"): 1, ("GET", "/cors/allow"): 1,
                ("GET", "/cors/wildcard-credentials"): 1,
                ("GET", "/cors/preflight-allow"): 1,
                ("OPTIONS", "/cors/preflight-allow"): 1,
                ("OPTIONS", "/cors/preflight-deny"): 1,
                ("GET", "/cors/no-cors"): 1,
                ("GET", "/image/unrestricted"): 1,
                ("GET", "/image/cross-origin"): 1,
                ("GET", "/image/same-origin"): 1}
    verify_cors(cors)
    verify_images(images)
    verify_server_requests(client, resource)
    count = 0
    cors_bad = [
        {**cors, "same_origin": {**cors["same_origin"], "body_matches": False}},
        {**cors, "same_origin": {**cors["same_origin"], "response_type": "cors"}},
        {**cors, "cross_origin_no_acao": {"outcome": "ok"}},
        {**cors, "cross_origin_no_acao": {"outcome": "blocked", "error_name": "SecurityError"}},
        {**cors, "cross_origin_exact_acao": {**cors["cross_origin_exact_acao"], "body_matches": False}},
        {**cors, "wildcard_acao_credentials_include": {"outcome": "ok"}},
        {**cors, "preflight_allowed": {"outcome": "blocked"}},
        {**cors, "preflight_denied": {"outcome": "ok"}},
        {**cors, "no_cors_opaque": {"outcome": "opaque", "status": 200,
                                  "response_type": "opaque", "unreadable_body": True}},
        {**cors, "no_cors_opaque": {**cors["no_cors_opaque"], "unreadable_body": False}},
        {"same_origin": cors["same_origin"]},
    ]
    for bad in cors_bad:
        try:
            verify_cors(bad)
        except RuntimeError:
            count += 1
        else:
            raise RuntimeError("Forged CORS browser outcome accepted")
    image_bad = [
        {**images, "same_origin_corp_same_origin":
            {"event": "error", "loaded_1x1": False}},
        {**images, "cross_origin_unrestricted":
            {"event": "error", "loaded_1x1": False}},
        {**images, "cross_origin_corp_cross_origin":
            {"event": "error", "loaded_1x1": False}},
        {**images, "cross_origin_corp_same_origin":
            {"event": "load", "loaded_1x1": True}},
        {**images, "cross_origin_corp_same_origin":
            {"event": "error", "loaded_1x1": "false"}},
        {"cross_origin_unrestricted": images["cross_origin_unrestricted"]},
    ]
    for bad in image_bad:
        try:
            verify_images(bad)
        except RuntimeError:
            count += 1
        else:
            raise RuntimeError("Forged CORP image outcome accepted")
    ledgers = [
        (client, {**resource, ("GET", "/cors/preflight-deny"): 1}),
        (client, {**resource, ("OPTIONS", "/cors/preflight-deny"): 0}),
        (client, {**resource, ("OPTIONS", "/cors/preflight-allow"): 0}),
        (client, {**resource, ("GET", "/image/same-origin"): 0}),
        ({**client, ("GET", "/cors/same"): 0}, resource),
    ]
    for a, b in ledgers:
        try:
            verify_server_requests(a, b)
        except RuntimeError:
            count += 1
        else:
            raise RuntimeError("Forged network request ledger accepted")
    need(count == 22, "Fixture negative count drifted")
    print("PASS: 22 invalid CORS, CORP and actual-network request outcomes rejected")


def run(repo, output):
    need(not output.exists(), "Refusing to replace any previous evidence")
    driver = shutil.which("geckodriver")
    need(driver is not None, "Checksum-pinned geckodriver missing")
    archive = wd.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"),
         "Wrong packaged candidate version")
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="vulpra160-cors-corp-") as temp:
        work = Path(temp)
        unpack = work / "browser"
        unpack.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(unpack)],
                       check=True, timeout=90)
        apps = list(unpack.rglob("application.ini"))
        need(len(apps) == 1 and "Name=Vulpra" in apps[0].read_text().splitlines(),
             "Packaged native Firefox 160 Vulpra identity mismatch")
        binary = wd.select_binary(apps[0].parent)
        home = work / "home"
        home.mkdir()
        profile = work / "profile"
        profile.mkdir()
        firefox_original = home / ".mozilla/firefox/profiles.ini"
        firefox_original.parent.mkdir(parents=True)
        sentinel = b"unrelated Firefox profile is not a target of CORS/CORP QA\n"
        firefox_original.write_bytes(sentinel)
        client = http.server.ThreadingHTTPServer(("127.0.0.1", 0), ResourceServer)
        resource = http.server.ThreadingHTTPServer(("127.0.0.1", 0), ResourceServer)
        need(client.server_port != resource.server_port,
             "Cross-origin servers inadvertently share the same port")
        client_origin = f"http://127.0.0.1:{client.server_port}"
        resource_origin = f"http://127.0.0.1:{resource.server_port}"
        for server, role in ((client, "client"), (resource, "resource")):
            server.role = role
            server.client_origin = client_origin
            server.events = Counter()
            server.event_lock = threading.Lock()
        threads = [
            threading.Thread(target=server.serve_forever, daemon=True)
            for server in (client, resource)
        ]
        for thread in threads:
            thread.start()
        try:
            with helper.session(driver, binary, profile, home,
                                work / "geckodriver.log",
                                "CORS/CORP cross-origin runtime") as (port, sid):
                base = "/session/" + sid
                wd.request(port, "POST", base + "/url",
                           {"url": client_origin + "/"}, timeout_seconds=35)
                page = wd.request(port, "POST", base + "/execute/sync", {
                    "script": """return {
                       origin:location.origin, title:document.title,
                       ready:document.readyState==="complete"
                    };""",
                    "args": [],
                })
                need(isinstance(page, dict) and
                     page.get("origin") == client_origin and
                     page.get("title") == "Vulpra two-origin isolation" and
                     page.get("ready") is True,
                     "Real Firefox WebDriver is not running in client-origin content")
                # The returned values contain bounded status/booleans only.
                cors = wd.request(port, "POST", base + "/execute/async", {
                    "script": """
                      const a=arguments[0], b=arguments[1];
                      const done=arguments[arguments.length-1];
                      let completed=false;
                      const timer=setTimeout(()=>finish({timeout:true}),20000);
                      function finish(value){
                        if(completed)return;
                        completed=true;clearTimeout(timer);done(value);
                      }
                      (async()=>{
                        async function probe(url,init={}){
                          try{
                            const response=await fetch(url,init);
                            if(init.mode==="no-cors"){
                              return {
                                outcome:"opaque",status:response.status,
                                response_type:response.type,
                                unreadable_body:response.body===null
                              };
                            }
                            const text=await response.text();
                            return {
                              outcome:"ok",status:response.status,
                              response_type:response.type,
                              body_matches:text==="vulpra-cors-approved-response"
                            };
                          }catch(error){
                            return {outcome:"blocked",error_name:error?.name};
                          }
                        }
                        const result={};
                        result.same_origin=await probe(a+"/cors/same");
                        result.cross_origin_no_acao=await probe(b+"/cors/deny");
                        result.cross_origin_exact_acao=await probe(b+"/cors/allow");
                        result.wildcard_acao_credentials_include=await probe(
                          b+"/cors/wildcard-credentials",
                          {credentials:"include"});
                        result.preflight_allowed=await probe(b+"/cors/preflight-allow",
                          {headers:{"x-vulpra-ci-probe":"one"}});
                        result.preflight_denied=await probe(b+"/cors/preflight-deny",
                          {headers:{"x-vulpra-ci-probe":"one"}});
                        result.no_cors_opaque=await probe(b+"/cors/no-cors",
                          {mode:"no-cors"});
                        finish(result);
                      })().catch(_=>finish({unexpected:true}));
                    """,
                    "args": [client_origin, resource_origin],
                }, timeout_seconds=32)
                verify_cors(cors)
                print("PASS: real Firefox 160 CORS allowed/denied, credential wildcard, "
                      "OPTIONS preflight and opaque no-cors fetch", flush=True)
                images = wd.request(port, "POST", base + "/execute/async", {
                    "script": """
                      const a=arguments[0], b=arguments[1];
                      const done=arguments[arguments.length-1];
                      let completed=false;
                      const timer=setTimeout(()=>finish({timeout:true}),16000);
                      function finish(value){
                        if(completed)return;
                        completed=true;clearTimeout(timer);done(value);
                      }
                      (async()=>{
                        function load(url){
                          return new Promise(resolve=>{
                            const img=new Image();
                            const timeout=setTimeout(()=>
                              resolve({event:"timeout",loaded_1x1:false}),4000);
                            img.onload=()=>{
                              clearTimeout(timeout);resolve({
                                event:"load",
                                loaded_1x1:img.naturalWidth===1&&img.naturalHeight===1
                              });
                            };
                            img.onerror=()=>{
                              clearTimeout(timeout);resolve({
                                event:"error",loaded_1x1:false
                              });
                            };
                            img.src=url;
                          });
                        }
                        const result={};
                        result.same_origin_corp_same_origin=await load(a+"/image/same");
                        result.cross_origin_unrestricted=await load(b+"/image/unrestricted");
                        result.cross_origin_corp_cross_origin=await load(b+"/image/cross-origin");
                        result.cross_origin_corp_same_origin=await load(b+"/image/same-origin");
                        finish(result);
                      })().catch(_=>finish({unexpected:true}));
                    """,
                    "args": [client_origin, resource_origin],
                }, timeout_seconds=27)
                verify_images(images)
                print("PASS: real Firefox 160 CORP same-origin denial vs cross-origin "
                      "and same-origin positive-control image loads", flush=True)
                need(firefox_original.read_bytes() == sentinel,
                     "Original Firefox profile sentinel modified")
        finally:
            client.shutdown()
            resource.shutdown()
            client.server_close()
            resource.server_close()
        with client.event_lock:
            client_calls = dict(client.events)
        with resource.event_lock:
            resource_calls = dict(resource.events)
        verify_server_requests(client_calls, resource_calls)
        print("PASS: actual localhost request ledger confirms CORS preflight "
              "denial sent OPTIONS but never forbidden GET", flush=True)
        need(firefox_original.read_bytes() == sentinel,
             "Original Firefox profile sentinel changed after browser exit")
        report = {
            "schema_version": 1,
            "status": "pass",
            "native_package_sha256": checksum,
            "client_and_resource_distinct_loopback_origins": True,
            "real_cors_same_origin_fetch_readable": True,
            "real_cors_cross_origin_without_acao_blocked": True,
            "real_cors_exact_allowed_origin_fetch_readable": True,
            "real_cors_wildcard_with_credentials_rejected": True,
            "real_cors_allowed_preflight_options_then_get": True,
            "real_cors_denied_preflight_options_without_get": True,
            "real_no_cors_fetch_is_opaque_without_readable_body": True,
            "real_corp_same_origin_image_loads_on_same_origin": True,
            "real_corp_cross_origin_image_loads_when_unrestricted": True,
            "real_corp_cross_origin_explicit_policy_allows_image": True,
            "real_corp_same_origin_policy_blocks_cross_origin_image": True,
            "local_server_request_ledger_exactly_matched": True,
            "unrelated_firefox_profile_preserved": True,
            "native_browser_security_prefs_unchanged": True,
            "kernel_seccomp_denial_exercised": False,
            "whole_cors_corp_policy_audited": False,
            "safe_browsing_provider_ready": False,
            "security_current": False,
            "release_ready": False,
            "limits": [
                "Only isolated localhost origin/port and these selected HTTP headers",
                "No user credentials, actual cookies, Internet sites or production profile",
                "A CORS block is a read restriction, not proof no GET was sent",
                "A CORP image block is a resource-load restriction, not a Linux sandbox test",
                "No comprehensive network security, CSP, CORP/COEP or kernel seccomp audit"
            ],
        }
        output.write_text(json.dumps(report, indent=2) + "\n")
    print("PASS: actual packaged Firefox 160 two-origin CORS/CORP enforcement", flush=True)
    print("LIMIT: not full origin-security or release acceptance", flush=True)


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 3:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        raise SystemExit(1)
