#!/usr/bin/env python3
"""Bounded blob URL origin-isolation regression on archived Firefox 160.

This is NOT a reproduction, mitigation test or fix-proof for CVE-2026-124852
or CVE-2026-124855. It tests ordinary same-origin vs cross-origin blob fetch
and an opaque (sandboxed-frame) blob:null creator using only loopback HTTP,
a disposable HOME/profile, and the prebuilt verified Vulpra Firefox 160.
"""
from __future__ import annotations

import hashlib
import html
import http.server
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import urlsplit, parse_qs


def need(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def load_helper(path: Path):
    spec = importlib.util.spec_from_file_location("vulpra_webdriver_base", path)
    need(spec is not None and spec.loader is not None, "Missing WebDriver runtime helper")
    obj = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = obj
    spec.loader.exec_module(obj)
    return obj


class ProbePage(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlsplit(self.path)
        token = parse_qs(parsed.query).get("token", [""])[0]
        if parsed.path == "/":
            content = "<!doctype html><meta charset=utf-8><title>Isolated blob parent</title>"
        elif parsed.path == "/blob-source" and re.fullmatch(r"[0-9a-f]{24}", token):
            data = json.dumps(token)
            content = (
                "<!doctype html><meta charset=utf-8><title>Isolated blob creator</title>"
                "<script>(async()=>{"
                "const tok=" + data + ";"
                "const url=URL.createObjectURL(new Blob([tok],{type:'text/plain'}));"
                "let same=false;try{same=(await(await fetch(url)).text())===tok;}catch(e){}"
                "parent.postMessage({type:'blob-source',token:tok,url,same},'*');"
                "})();</script>"
            )
        else:
            self.send_error(404)
            return
        data = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_args):
        return


def probe_script():
    return r"""
const kind=arguments[0], origin=arguments[1], token=arguments[2];
const done=arguments[arguments.length-1];
let finished=false, frame=null;
const complete=value=>{
  if(finished)return; finished=true;
  window.removeEventListener('message',onMessage);
  if(frame)frame.remove();
  done(value);
};
const deadline=setTimeout(()=>complete({kind,error:'timeout'}),16000);
async function onMessage(e) {
  if(finished||!frame||e.source!==frame.contentWindow ||
      !e.data||e.data.token!==token||e.data.type!=='blob-source')return;
  if(kind==='cross-origin' && e.origin!==origin)return;
  if(kind==='opaque-origin' && e.origin!=='null')return;
  clearTimeout(deadline);
  let denied=false, read='',exception='';
  try {
    const res=await fetch(e.data.url);
    read=await res.text();
  } catch(err) {
    denied=true; exception=String(err.name||'fetch-failed');
  }
  complete({
    kind,creator_origin:e.origin,parent_origin:location.origin,
    blob_url_scheme:String(e.data.url).startsWith('blob:'),
    blob_url_opaque:String(e.data.url).startsWith('blob:null/'),
    creator_same_origin_fetch_ok:e.data.same===true,
    parent_cross_origin_fetch_denied:denied,
    parent_fetched_token:read===token,
    error_type:exception
  });
}
window.addEventListener('message',onMessage);
frame=document.createElement('iframe');
if(kind==='opaque-origin')frame.setAttribute('sandbox','allow-scripts');
frame.src=origin+'/blob-source?token='+encodeURIComponent(token);
document.body.appendChild(frame);
"""


def require_probe(result, kind):
    need(isinstance(result, dict) and result.get("kind") == kind,
         "Missing expected real browser origin result")
    need(result.get("creator_same_origin_fetch_ok") is True,
         "Creator frame could not retrieve its own real Blob")
    need(result.get("blob_url_scheme") is True,
         "Page did not create a real Blob URL")
    need(result.get("parent_cross_origin_fetch_denied") is True,
         "Parent was incorrectly able to fetch foreign Blob URL")
    need(result.get("parent_fetched_token") is False,
         "Foreign Blob content was exposed to parent")
    need(result.get("error_type") == "TypeError",
         "Cross-origin rejection did not report fetch TypeError")
    if kind == "opaque-origin":
        need(result.get("creator_origin") == "null" and
             result.get("blob_url_opaque") is True,
             "Sandboxed creator did not have an opaque blob:null principal")
    else:
        need(result.get("creator_origin", "").startswith("http://127.0.0.1:") and
             result.get("blob_url_opaque") is False,
             "Creator did not retain its distinct HTTP origin")


def self_test():
    example = {
        "kind":"cross-origin","creator_origin":"http://127.0.0.1:50411",
        "blob_url_scheme":True,"blob_url_opaque":False,
        "creator_same_origin_fetch_ok":True,
        "parent_cross_origin_fetch_denied":True,
        "parent_fetched_token":False,"error_type":"TypeError"
    }
    require_probe(example, "cross-origin")
    example_opaque = {**example,"kind":"opaque-origin",
                      "creator_origin":"null","blob_url_opaque":True}
    require_probe(example_opaque, "opaque-origin")
    for forged in [
        {**example,"parent_cross_origin_fetch_denied":False},
        {**example,"parent_fetched_token":True},
        {**example,"creator_same_origin_fetch_ok":False},
        {**example_opaque,"creator_origin":"http://127.0.0.1:50411"},
        {**example_opaque,"blob_url_opaque":False},
    ]:
        try:
            require_probe(forged, forged["kind"])
        except RuntimeError:
            continue
        raise RuntimeError("Forged cross-origin access evidence was accepted")
    print("PASS: five malformed or leaked Blob URL outcome fixtures rejected", flush=True)


def run(repo: Path, output: Path):
    helper = load_helper(Path(__file__).resolve().parent / "smoke-webextension-package-local.py")
    archive = helper.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"),
         "Refusing non-Firefox-160 native package")
    browser_archive_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    geckodriver = shutil.which("geckodriver")
    need(geckodriver is not None, "Missing pinned geckodriver on PATH")
    need(not output.exists(), "Refusing to overwrite already recorded test result")
    with tempfile.TemporaryDirectory(prefix="vulpra160-blob-origin-") as directory:
        work = Path(directory)
        unpacked = work / "unpacked"
        unpacked.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(unpacked)], check=True)
        inis = list(unpacked.rglob("application.ini"))
        need(len(inis)==1 and "Name=Vulpra" in inis[0].read_text().splitlines(),
             "No unique packaged Vulpra native browser identity")
        browser = helper.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        profile = work / "disposable-browser-profile"
        profile.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel_value = b"existing Firefox profile sentinel: do not modify\n"
        sentinel.write_bytes(sentinel_value)
        server_a = http.server.ThreadingHTTPServer(("127.0.0.1",0),ProbePage)
        server_b = http.server.ThreadingHTTPServer(("127.0.0.1",0),ProbePage)
        threads = []
        for server in (server_a,server_b):
            th = threading.Thread(target=server.serve_forever,daemon=True)
            th.start()
            threads.append(th)
        source_origin = "http://127.0.0.1:"+str(server_a.server_port)
        target_origin = "http://127.0.0.1:"+str(server_b.server_port)
        need(source_origin != target_origin, "Origins are not distinct")
        env = os.environ.copy()
        env.update({
            "HOME":str(home),"XDG_DATA_HOME":str(home/".local/share"),
            "MOZ_HEADLESS":"1","NO_PROXY":"localhost,127.0.0.1",
            "no_proxy":"localhost,127.0.0.1",
        })
        for key in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):
            env.pop(key,None)
        driver_port = helper.find_port()
        process = None
        session_id = None
        results = []
        try:
            with (work / "driver.log").open("wb") as log:
                process=subprocess.Popen(
                    [geckodriver,"--host","127.0.0.1","--port",str(driver_port),
                     "--allow-system-access"],
                    env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                helper.wait_ready(driver_port,process)
                session=helper.request(driver_port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox","acceptInsecureCerts":False,
                        "moz:firefoxOptions":{
                            "binary":str(browser),
                            "args":["-headless","-no-remote","-profile",str(profile)],
                            "prefs":{
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                "browser.shell.checkDefaultBrowser":False,
                            },
                        },
                    }},
                }, timeout_seconds=70)
                session_id=session.get("sessionId") if isinstance(session,dict) else None
                caps=session.get("capabilities",{}) if isinstance(session,dict) else {}
                need(isinstance(session_id,str) and session_id,
                     "Real geckodriver session unavailable")
                need(str(caps.get("browserVersion","")).startswith("160.") and
                     caps.get("acceptInsecureCerts") is False and
                     caps.get("browserName") == "firefox",
                     "Firefox 160 identity/TLS guard mismatch")
                need(Path(caps.get("moz:profile","")).resolve()==profile.resolve(),
                     "Browser did not use explicit disposable profile")
                base="/session/"+session_id
                helper.request(driver_port,"POST",base+"/timeouts",
                               {"script":25000,"pageLoad":35000})
                helper.request(driver_port,"POST",base+"/url",
                               {"url":target_origin+"/"},timeout_seconds=40)
                doc_origin=helper.request(driver_port,"POST",base+"/execute/sync",{
                    "script":"return location.origin;","args":[]})
                need(doc_origin==target_origin, "Did not navigate to distinct target origin")
                for kind in ("cross-origin","opaque-origin"):
                    token=os.urandom(12).hex()
                    result=helper.request(driver_port,"POST",base+"/execute/async",{
                        "script":probe_script(),"args":[kind,source_origin,token],
                    }, timeout_seconds=33)
                    require_probe(result,kind)
                    results.append({
                        "mode":kind,
                        "creator_can_fetch_own_blob":True,
                        "cross_origin_parent_cannot_fetch_blob":True,
                        "blob_null_opaque_origin_confirmed":
                            result.get("blob_url_opaque") is True,
                        "web_driver_fetch_exception":result["error_type"],
                    })
                    print("PASS: "+kind+" real Blob URL creator allowed but foreign parent fetch denied",flush=True)
                need(sentinel.read_bytes()==sentinel_value,
                     "Original Firefox profile sentinel changed")
                report={
                    "schema_version":1,
                    "kind":"firefox160_bounded_blob_url_origin_isolation_runtime_smoke",
                    "status":"pass","package_sha256":browser_archive_sha,
                    "real_native_firefox160_webdriver":True,
                    "two_distinct_loopback_http_origins":True,
                    "same_origin_blob_fetch_allowed":True,
                    "cross_origin_blob_fetch_denied":True,
                    "sandboxed_opaque_blob_null_creator_tested":True,
                    "sandboxed_opaque_blob_null_foreign_fetch_denied":True,
                    "original_firefox_profile_preserved":True,
                    "accept_insecure_certs_disabled":True,
                    "modes":results,
                    "cve2026_124852_fix_commit_provenance_verified":False,
                    "cve2026_124852_exploit_regression_executed":False,
                    "cve2026_124855_complete_fix_verified":False,
                    "all_blob_principal_security_semantics_verified":False,
                    "security_current":False,"release_ready":False,
                    "limits":[
                        "No reproduction of CVE-2026-124852 or CVE-2026-124855",
                        "No protected Bugzilla source commit attribution",
                        "No full cross-site or storage-partition matrix",
                        "Not a substitute for Mozilla security fix verification",
                    ],
                }
                output.write_text(json.dumps(report,indent=2)+"\n")
        finally:
            if session_id:
                try:
                    helper.request(driver_port,"DELETE","/session/"+session_id,
                                   timeout_seconds=12)
                except (RuntimeError, OSError):
                    pass
            if process is not None:
                try:
                    os.killpg(process.pid,signal.SIGTERM)
                    process.wait(timeout=7)
                except (ProcessLookupError,subprocess.TimeoutExpired):
                    try:os.killpg(process.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
            for server in (server_a,server_b):
                server.shutdown()
                server.server_close()
        need(output.is_file(), "No bounded JSON origin proof archived")
    print("LIMIT: only standard Blob URL origin-isolation behavior, not CVE exploit denial",flush=True)


if __name__ == "__main__":
    try:
        if sys.argv[1:]==["--self-test"]:
            self_test()
        elif len(sys.argv)==3:
            run(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (OSError,ValueError,RuntimeError,subprocess.CalledProcessError) as err:
        print("FAIL: "+str(err),file=sys.stderr)
        raise SystemExit(1)
