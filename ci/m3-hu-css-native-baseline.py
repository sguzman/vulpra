#!/usr/bin/env python3
"""Historical normal Vulpra packaged hu/hu-HU CSS hyphenation runtime baseline.

No omitted language resources and no external web access. This checks a
known-good baseline with a temporary profile, not whether removal is safe.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from urllib.request import Request, urlopen
from urllib.error import URLError,HTTPError

LONG_HU="megszentségteleníthetetlenségeskedéseitekért"
LONG_EN="characteristically"
PAGE=f"""<!doctype html><html><meta charset='utf-8'><title>Vulpra HU Hyphenation QA</title>
<style>
#samples > div {{font-family:serif;font-size:22px;line-height:28px;
 width:112px;display:block;white-space:normal;overflow-wrap:normal;word-break:normal;
 border:0;padding:0;margin:0;box-sizing:content-box;}}
.auto {{hyphens:auto;}}
.none {{hyphens:none;}}
</style><div id='samples'>
<div id='hu-auto' class='auto' lang='hu'>{LONG_HU}</div>
<div id='hu-none' class='none' lang='hu'>{LONG_HU}</div>
<div id='huhu-auto' class='auto' lang='hu-HU'>{LONG_HU}</div>
<div id='en-auto' class='auto' lang='en-US'>{LONG_EN}</div>
<div id='en-none' class='none' lang='en-US'>{LONG_EN}</div>
</div></html>""".encode("utf-8")

class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path!="/hu": self.send_error(404);return
        self.send_response(200)
        self.send_header("Content-Type","text/html; charset=utf-8")
        self.send_header("Content-Length",str(len(PAGE)))
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        self.wfile.write(PAGE)
    def log_message(self,*args):pass

def digest(path):
    side=Path(str(path)+".sha256")
    if not side.is_file():raise ValueError("No package SHA256 sidecar")
    parts=side.read_text().strip().split()
    if len(parts)!=2 or parts[1].lstrip("*")!=path.name:
        raise ValueError("Incorrect SHA256 sidecar filename")
    h=sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    if h.hexdigest()!=parts[0].lower():
        raise ValueError("Archive did not match sidecar")
    return h.hexdigest()

def webdriver(port,method,path,payload=None):
    data=json.dumps(payload).encode() if payload is not None else None
    req=Request(f"http://127.0.0.1:{port}{path}",data=data,method=method,
                headers={"Content-Type":"application/json"})
    with urlopen(req,timeout=28) as response:
        value=json.load(response)
    if not isinstance(value,dict) or "value" not in value:
        raise ValueError("Invalid WebDriver message")
    value=value["value"]
    if isinstance(value,dict) and value.get("error"):
        raise ValueError("WebDriver "+str(value.get("error"))+": "+str(value.get("message",""))[:250])
    return value

def available_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1",0))
        return int(s.getsockname()[1])

def wait_for_driver(port,proc):
    for i in range(120):
        if proc.poll() is not None:raise ValueError("geckodriver exited prematurely")
        try:
            if webdriver(port,"GET","/status").get("ready"):return
        except (OSError,ValueError,URLError):pass
        time.sleep(.15)
    raise ValueError("Local geckodriver not ready")

def select_binary(root):
    ini=list(root.rglob("application.ini"))
    if len(ini)!=1 or "Name=Vulpra" not in ini[0].read_text().splitlines():
        raise ValueError("Not a unique packaged Vulpra application")
    for name in ("vulpra","firefox"):
        f=ini[0].parent/name
        if f.is_file() and os.access(f,os.X_OK) and f.open("rb").read(4)==b"\x7fELF":
            return f
    raise ValueError("No actual native packaged Vulpra executable")

JS="""const done=arguments[arguments.length-1];
document.fonts.ready.then(() => {
  const result={};
  for (const id of ["hu-auto","hu-none","huhu-auto","en-auto","en-none"]) {
    const e=document.getElementById(id);
    if (!e) {done({error:"missing sample: "+id});return;}
    const c=getComputedStyle(e);
    const r=document.createRange();r.selectNodeContents(e);
    result[id]={width:e.clientWidth,scrollWidth:e.scrollWidth,
      scrollHeight:e.scrollHeight,offsetHeight:e.offsetHeight,
      hyphens:c.hyphens,language:e.lang,
      lineRects:r.getClientRects().length};
  }
  done(result);
}).catch(e=>done({error:String(e)}));"""

def validate(m):
    if not isinstance(m,dict) or set(m)!={"hu-auto","hu-none","huhu-auto",
                                           "en-auto","en-none"}:
        raise ValueError("Missing text/layout samples")
    for k,v in m.items():
        if not isinstance(v,dict):raise ValueError("Non-numeric layout sample")
        for x in ("width","scrollWidth","scrollHeight","offsetHeight","lineRects"):
            if type(v.get(x)) is not int or v[x]<=0:
                raise ValueError("Missing positive measurement: "+k+" "+x)
        if v["width"]!=112 or v["hyphens"]!=("none" if k.endswith("-none") else "auto"):
            raise ValueError("Unexpected CSS width/hyphen setting: "+k)
    if m["hu-auto"]["language"]!="hu" or m["huhu-auto"]["language"]!="hu-HU" or m["en-auto"]["language"]!="en-US":
        raise ValueError("Wrong browser layout sample language")
    if m["hu-auto"]["scrollHeight"]<=m["hu-none"]["scrollHeight"] or (
        m["hu-auto"]["scrollWidth"]>=m["hu-none"]["scrollWidth"]):
        raise ValueError("Packaged Hungarian hyphenation did not change long-word layout")
    if m["huhu-auto"]["scrollHeight"]<=m["hu-none"]["scrollHeight"] or (
        m["huhu-auto"]["scrollWidth"]>=m["hu-none"]["scrollWidth"]):
        raise ValueError("Package hu-HU locale fallback did not hyphenate")
    if m["en-auto"]["scrollHeight"]<=m["en-none"]["scrollHeight"]:
        raise ValueError("Default English hyphenation control not active")
    return {"hu_autobreak_observed":True,"hu_HU_autobreak_observed":True,
            "en_US_autobreak_control_observed":True,
            "layout_data":m,"missing_hungarian_pattern_fallback_verified":False,
            "guarded_pattern_omission_built":False,
            "compressed_archive_bytes_saved":None,
            "normal_package_altered":False}

def selftest():
    def sample(lang="hu",mode="auto",height=112,width=112,sw=112):
        return {"width":width,"scrollWidth":sw,"scrollHeight":height,
                "offsetHeight":height,"hyphens":mode,"language":lang,"lineRects":height//28}
    base={
        "hu-auto":sample(),
        "hu-none":sample(mode="none",height=28,sw=410),
        "huhu-auto":sample(lang="hu-HU"),
        "en-auto":sample(lang="en-US",height=56),
        "en-none":sample(lang="en-US",mode="none",height=28,sw=220)}
    validate(base)
    from copy import deepcopy
    mutants=[
        lambda x:x["hu-auto"].update(scrollHeight=28),
        lambda x:x["hu-auto"].update(scrollWidth=410),
        lambda x:x["huhu-auto"].update(scrollHeight=28),
        lambda x:x["en-auto"].update(scrollHeight=28),
        lambda x:x["hu-auto"].update(hyphens="none"),
        lambda x:x["huhu-auto"].update(language="en-US"),
        lambda x:x["hu-auto"].update(width=0),
        lambda x:x.pop("hu-auto"),
    ]
    for mutate in mutants:
        data=deepcopy(base);mutate(data)
        try:validate(data)
        except ValueError:continue
        raise AssertionError("Invalid packaged language geometry accepted")
    return len(mutants)

def actual(package,source_commit):
    gecko=shutil.which("geckodriver")
    if not gecko:raise ValueError("Install geckodriver for native offline CSS acceptance")
    check=digest(package)
    with tempfile.TemporaryDirectory(prefix="vulpra-hu-baseline-") as tmp:
        d=Path(tmp);app=d/"app";app.mkdir()
        with tarfile.open(package,"r:xz") as f:
            f.extractall(app,filter="data")
        browser=select_binary(app)
        home=d/"home";home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_text("existing Firefox profile untouched\n")
        env=os.environ.copy()
        env.update({"HOME":str(home),"XDG_DATA_HOME":str(home/".local/share"),
                    "MOZ_HEADLESS":"1","MOZ_DISABLE_NONLOCAL_CONNECTIONS":"1",
                    "NO_PROXY":"127.0.0.1,localhost","no_proxy":"127.0.0.1,localhost"})
        for k in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):env.pop(k,None)
        server=ThreadingHTTPServer(("127.0.0.1",0),Page)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        port=available_port();session=None;proc=None
        try:
            with (d/"geckodriver.log").open("wb") as log:
                proc=subprocess.Popen([gecko,"--host","127.0.0.1","--port",str(port)],
                    env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                wait_for_driver(port,proc)
                value=webdriver(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{"browserName":"firefox",
                    "moz:firefoxOptions":{"binary":str(browser),
                    "args":["-headless","-no-remote"],
                    "prefs":{"browser.shell.checkDefaultBrowser":False,
                             "app.update.enabled":False,"extensions.update.enabled":False}}}}})
                if not isinstance(value,dict) or not value.get("sessionId"):
                    raise ValueError("No real WebDriver browser session")
                session=value["sessionId"];base=f"/session/{session}"
                webdriver(port,"POST",base+"/timeouts",{"script":20000,"pageLoad":30000})
                webdriver(port,"POST",base+"/url",{"url":f"http://127.0.0.1:{server.server_port}/hu"})
                measures=webdriver(port,"POST",base+"/execute/async",{"script":JS,"args":[]})
                result=validate(measures)
                if sentinel.read_text()!="existing Firefox profile untouched\n":
                    raise ValueError("Existing Firefox profile sentinel changed")
                return {"schema_version":1,"status":"passed_historical_normal_hyphenation_runtime",
                        "package_sha256":check,"compiled_source_commit":source_commit,
                        "actual_packaged_vulpra_executed":True,
                        "runtime_limited_to_localhost":True,
                        "isolated_home_and_firefox_profile":True,
                        **result,
                        "limitations":["Observed historical unmodified normal browser only.",
                            "CSS language-specific hyphenation change is not approval to remove dictionary.",
                            "No absent-resource/fallback variant, alternate profile dictionaries or langpacks.",
                            "No current-main native binary or compressed saving measured."]}
        finally:
            if session and proc:
                try:webdriver(port,"DELETE",f"/session/{session}")
                except (OSError,ValueError,URLError,HTTPError):pass
            if proc:
                try:
                    os.killpg(proc.pid,signal.SIGTERM)
                    proc.wait(timeout=5)
                except (ProcessLookupError,subprocess.TimeoutExpired):
                    try:os.killpg(proc.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
            server.shutdown();server.server_close()

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--archive",type=Path)
    p.add_argument("--source-commit")
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:print("PASS:",selftest(),"language layout rejection fixtures")
    if not a.archive:
        if a.self_test:return
        p.error("--archive required")
    if not a.source_commit or len(a.source_commit)!=40:
        p.error("--source-commit must be 40-char Git SHA")
    report=actual(a.archive.resolve(),a.source_commit)
    if a.output:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: original Vulpra hu, hu-HU and en-US CSS hyphenation on localhost")
    print("LAYOUT METRICS:",json.dumps(report["layout_data"]))
    print("Not omission safety, typography equivalence or package savings")
if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError,tarfile.TarError) as e:
        print("FAIL native Hungarian hyphenation baseline:",e,file=sys.stderr)
        raise SystemExit(1)
