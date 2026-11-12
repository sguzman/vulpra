#!/usr/bin/env python3
"""Bounded browser canvas + WebGL cross-origin image security smoke.

Tests real native Firefox 160 under isolated private Wayland Weston/Pixman.
No profile, hardware, signed plugin, sandbox-bypass or CVE exploit behavior.
A successful check establishes standard HTML Canvas/CORS/WebGL restrictions,
NOT an identified fix for inaccessible Mozilla Bug 2001244/CVE-2026-124852.
"""
from __future__ import annotations

import hashlib
import http.server
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib


def need(test: bool, reason: str):
    if not test:
        raise RuntimeError(reason)


def make_png() -> bytes:
    """One RGBA opaque pixel; no generated image tool or network dependency."""
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    signature = bytes.fromhex("89504e470d0a1a0a")
    return signature + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) + \
        chunk(b"IDAT", zlib.compress(b"\x00\xcc\x33\x77\xff")) + chunk(b"IEND", b"")


PNG_PIXEL = make_png()


class ImageServer(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            body = (b"<!doctype html><meta charset=utf-8>"
                    b"<title>Vulpra Canvas security</title><h1>Canvas access probe</h1>")
            mime = "text/html; charset=utf-8"
        elif self.path in ("/same.png", "/foreign.png", "/cors.png"):
            body = PNG_PIXEL
            mime = "image/png"
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Cache-Control", "no-store")
        if self.path == "/cors.png":
            self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


BROWSER_JS = r"""
const allowed=arguments[0], foreign=arguments[1];
const done=arguments[arguments.length-1];
let concluded=false;
const result=v=>{if(!concluded){concluded=true;done(v);}};
async function load(src, useCors) {
  const image=new Image();
  if(useCors) image.crossOrigin='anonymous';
  return await new Promise((ok, fail)=>{
    image.onload=()=>ok(image);
    image.onerror=()=>fail(new Error('image-load-error:'+src));
    image.src=src;
  });
}
const pixel=(image)=>{
  const cv=document.createElement('canvas');
  cv.width=cv.height=1;
  const cx=cv.getContext('2d',{willReadFrequently:true});
  cx.drawImage(image,0,0);
  const bytes=Array.from(cx.getImageData(0,0,1,1).data);
  const url=cv.toDataURL();
  return {rgba:bytes,encoded:url.startsWith('data:image/png;')};
};
const denied=(image)=>{
  const cv=document.createElement('canvas');
  cv.width=cv.height=1;
  const cx=cv.getContext('2d',{willReadFrequently:true});
  cx.drawImage(image,0,0);
  const outcomes={};
  for(const [name,fn] of [
    ['getImageData',()=>cx.getImageData(0,0,1,1)],
    ['toDataURL',()=>cv.toDataURL()],
    ['toBlob',()=>cv.toBlob(()=>{})],
  ]) {
    try {fn();outcomes[name]='allowed';}
    catch(e){outcomes[name]=String(e.name||'exception');}
  }
  cx.clearRect(0,0,1,1);
  try{cx.getImageData(0,0,1,1);outcomes.clearRect='allowed';}
  catch(e){outcomes.clearRect=String(e.name||'exception');}
  return outcomes;
};
function webgl(imgAllowed,imgDenied) {
  const cv=document.createElement('canvas');
  cv.width=cv.height=2;
  let gl=null,reason='';
  const errors=[];
  cv.addEventListener('webglcontextcreationerror',e=>{reason=String(e.statusMessage||'context creation error').slice(0,160)});
  try{gl=cv.getContext('webgl2',{preserveDrawingBuffer:true});}
  catch(e){reason=String(e.name||e).slice(0,160);}
  if(!gl) return {available:false,reason};
  function texture(image){
    const tex=gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D,tex);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);
    let exception='',error=0;
    try {gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);}
    catch(e){exception=String(e.name||'exception');}
    error=gl.getError();
    gl.deleteTexture(tex);
    return {exception,gl_error:error};
  }
  return {available:true,
    same:texture(imgAllowed),
    cors:texture(imgCors),
    foreign:texture(imgDenied),
    no_error:gl.NO_ERROR};
}
let imgCors;
(async()=>{
  const same=await load(allowed+'/same.png',false);
  const noCors=await load(foreign+'/foreign.png',false);
  imgCors=await load(foreign+'/cors.png',true);
  const safe=pixel(same),cors=pixel(imgCors);
  const foreignResult=denied(noCors);
  let webglResult=null;
  for(let attempt=0;attempt<7;attempt++){
    webglResult=webgl(same,noCors);
    if(webglResult.available) break;
    await new Promise(r=>setTimeout(r,650));
  }
  return {same:safe,cors,foreign:foreignResult,
    webgl:webglResult,first_party_origin:location.origin};
})().then(result,r=>result).catch(e=>result({error:String(e)}));
"""


def check(data: dict, require_webgl: bool=True):
    need(isinstance(data, dict) and "error" not in data,
         "Browser JS failed to return clean Canvas result")
    same=data.get("same")
    cors=data.get("cors")
    for obj in (same,cors):
        need(isinstance(obj,dict) and obj.get("encoded") is True and
             obj.get("rgba")==[204,51,119,255],
             "Same-origin/CORS clean Canvas pixel readback failed")
    blocked=data.get("foreign")
    need(isinstance(blocked,dict), "No foreign origin proof")
    for name in ("getImageData","toDataURL","toBlob","clearRect"):
        need(blocked.get(name)=="SecurityError",
             "Canvas isolation bypass or missing negative outcome: "+name)
    w=data.get("webgl")
    need(isinstance(w,dict), "Missing actual WebGL context evidence")
    if require_webgl:
        need(w.get("available") is True, "WebGL2 unavailable in private Wayland run")
    if w.get("available") is True:
        for name in ("same","cors"):
            v=w.get(name)
            need(isinstance(v,dict) and v.get("exception")=="" and
                 v.get("gl_error")==w.get("no_error")==0,
                 "Approved "+name+" image did not upload as WebGL2 texture")
        v=w.get("foreign")
        need(isinstance(v,dict) and v.get("exception")=="SecurityError",
             "Cross-origin non-CORS image was accepted by WebGL2 texture upload")


def self_test():
    pixel={"rgba":[204,51,119,255],"encoded":True}
    blocked={k:"SecurityError" for k in ("getImageData","toDataURL","toBlob","clearRect")}
    w={"available":True,"same":{"exception":"","gl_error":0},
       "cors":{"exception":"","gl_error":0},
       "foreign":{"exception":"SecurityError","gl_error":0},"no_error":0}
    base={"same":pixel,"cors":pixel,"foreign":blocked,"webgl":w}
    check(base)
    forged=[
        {**base,"same":{**pixel,"rgba":[0,0,0,255]}},
        {**base,"cors":{**pixel,"encoded":False}},
        {**base,"foreign":{**blocked,"toDataURL":"allowed"}},
        {**base,"foreign":{**blocked,"clearRect":"allowed"}},
        {**base,"webgl":{**w,"available":False}},
        {**base,"webgl":{**w,"foreign":{"exception":"","gl_error":0}}},
        {**base,"webgl":{**w,"same":{"exception":"SecurityError","gl_error":0}}},
    ]
    for record in forged:
        try:
            check(record)
        except RuntimeError:
            pass
        else:
            raise RuntimeError("Forged Canvas/WebGL regression result accepted")
    print("PASS: seven forged Canvas/WebGL access and false-success fixtures rejected")


def run(repo: Path, output: Path):
    helper_path=Path(__file__).resolve().parent/"smoke-webextension-package-local.py"
    spec=importlib.util.spec_from_file_location("vulpra_canvas_wd", helper_path)
    need(spec is not None and spec.loader is not None, "No existing driver helper")
    wd=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=wd
    spec.loader.exec_module(wd)
    archive=wd.verified_archive(repo)
    need(archive.name.startswith("vulpra-local-firefox160-"), "Archive identity not Firefox 160")
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    driver=shutil.which("geckodriver")
    need(driver is not None, "Pinned driver not on path")
    need(bool(os.environ.get("WAYLAND_DISPLAY")) and bool(os.environ.get("XDG_RUNTIME_DIR")) and
         "MOZ_HEADLESS" not in os.environ, "Private non-headless Wayland test session required")
    need(not output.exists(), "Refusing to overwrite prior proof")
    with tempfile.TemporaryDirectory(prefix="vulpra160-canvas-private-") as tmp:
        root=Path(tmp)
        unpacked=root/"unpacked"
        unpacked.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(unpacked)],check=True)
        inis=list(unpacked.rglob("application.ini"))
        need(len(inis)==1 and "Name=Vulpra" in inis[0].read_text().splitlines(),
             "Wrong packaged Vulpra browser identity")
        binary=wd.select_binary(inis[0].parent)
        home=root/"home"
        home.mkdir()
        profile=root/"private-browser-profile"
        profile.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        original=b"Existing Firefox profile must not change during graphics smoke\n"
        sentinel.write_bytes(original)
        a=http.server.ThreadingHTTPServer(("127.0.0.1",0),ImageServer)
        b=http.server.ThreadingHTTPServer(("127.0.0.1",0),ImageServer)
        servers=(a,b)
        for server in servers:
            threading.Thread(target=server.serve_forever,daemon=True).start()
        origin_a="http://127.0.0.1:"+str(a.server_port)
        origin_b="http://127.0.0.1:"+str(b.server_port)
        need(origin_a!=origin_b, "Two distinct page origins required")
        env=os.environ.copy()
        env.update({"HOME":str(home),"XDG_DATA_HOME":str(home/".local/share"),
                    "GDK_BACKEND":"wayland","MOZ_ENABLE_WAYLAND":"1",
                    "XDG_SESSION_TYPE":"wayland",
                    "NO_PROXY":"localhost,127.0.0.1",
                    "no_proxy":"localhost,127.0.0.1"})
        env.pop("MOZ_HEADLESS",None)
        driver_port=wd.find_port()
        process=None
        session_id=None
        try:
            with (root/"geckodriver.log").open("wb") as log:
                process=subprocess.Popen([driver,"--host","127.0.0.1","--port",str(driver_port)],
                    env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
                wd.wait_ready(driver_port,process)
                session=wd.request(driver_port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{
                        "browserName":"firefox","acceptInsecureCerts":False,
                        "moz:firefoxOptions":{
                            "binary":str(binary),"args":["-no-remote","-profile",str(profile)],
                            "prefs":{
                                "app.update.enabled":False,
                                "extensions.update.enabled":False,
                                "browser.shell.checkDefaultBrowser":False,
                            },
                        }
                    }}
                },timeout_seconds=75)
                sid=session.get("sessionId") if isinstance(session,dict) else None
                caps=session.get("capabilities",{}) if isinstance(session,dict) else {}
                need(isinstance(sid,str) and sid,"No real Firefox WebDriver session")
                session_id=sid
                need(caps.get("browserName")=="firefox" and
                     str(caps.get("browserVersion","")).startswith("160.") and
                     caps.get("acceptInsecureCerts") is False,
                     "Wrong Firefox version or insecure certificate setting")
                need(Path(caps.get("moz:profile","")).resolve()==profile.resolve(),
                     "Browser did not use isolated private profile")
                base="/session/"+sid
                wd.request(driver_port,"POST",base+"/timeouts",{"script":30000,"pageLoad":40000})
                wd.request(driver_port,"POST",base+"/url",{"url":origin_a+"/"},timeout_seconds=45)
                value=wd.request(driver_port,"POST",base+"/execute/async",{
                    "script":BROWSER_JS,"args":[origin_a,origin_b]
                },timeout_seconds=40)
                check(value)
                need(value.get("first_party_origin")==origin_a,
                     "Wrong first-party origin of real browser test")
                screenshot=wd.request(driver_port,"GET",base+"/screenshot")
                need(isinstance(screenshot,str) and len(screenshot)>500,
                     "No non-headless graphical WebDriver screenshot produced")
                need(sentinel.read_bytes()==original,"Original Firefox profile sentinel changed")
                report={
                    "schema_version":1,
                    "kind":"firefox160_private_wayland_canvas_webgl_cross_origin_security_boundary",
                    "status":"pass",
                    "package_sha256":digest,
                    "firefox160_real_non_headless_wayland_browser":True,
                    "two_distinct_http_loopback_origins":True,
                    "same_origin_canvas_pixel_readback":True,
                    "cross_origin_cors_canvas_pixel_readback":True,
                    "cross_origin_without_cors_canvas_tainted":True,
                    "canvas_taint_survived_clear_rect":True,
                    "non_headless_webgl2_context_created":True,
                    "webgl2_same_and_cors_approved_texture_upload":True,
                    "webgl2_cross_origin_non_cors_texture_upload_denied":True,
                    "real_webdriver_graphical_png_screenshot":True,
                    "existing_firefox_profile_preserved":True,
                    "browser_certificate_verification_not_disabled":True,
                    "software_rendering_weston_only":True,
                    "browser_reported_security_errors":value["foreign"],
                    "webgl_browser_result":value["webgl"],
                    "cve2026_124852_fix_commit_provenance_verified":False,
                    "cve2026_124852_exploit_regression_executed":False,
                    "complete_canvas_webgl_security_policy_verified":False,
                    "security_current":False,"release_ready":False,
                    "limits":[
                        "Standard CORS and origin-clean checks, not CVE exploit reproduction",
                        "No Bugzilla 2001244 public fix provenance",
                        "Pixman Weston does not test hardware GPU, DMABuf or VAAPI",
                        "Not a broad canvas/WebGL protocol, shader or texture review",
                    ],
                }
                output.write_text(json.dumps(report,indent=2)+"\n")
                print("PASS: real Firefox 160 private Wayland 2D canvas taint and WebGL2 foreign image upload refusal",flush=True)
        finally:
            if session_id is not None:
                try:wd.request(driver_port,"DELETE","/session/"+session_id,timeout_seconds=15)
                except (RuntimeError,OSError):pass
            if process is not None:
                try:
                    os.killpg(process.pid,signal.SIGTERM)
                    process.wait(timeout=8)
                except (ProcessLookupError,subprocess.TimeoutExpired):
                    try:os.killpg(process.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
            for server in servers:
                server.shutdown()
                server.server_close()
        need(output.is_file(),"Missing actual graphical result")
    print("LIMIT: standard Canvas/WebGL origin rules only; not CVE 124852 exploit or fix-provenance verification",flush=True)


if __name__=="__main__":
    try:
        if sys.argv[1:]==["--self-test"]:
            self_test()
        elif len(sys.argv)==3:
            run(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test or SCRIPT REPO OUTPUT_JSON")
    except (OSError,ValueError,RuntimeError,subprocess.CalledProcessError) as e:
        print("FAIL: "+str(e),file=sys.stderr)
        raise SystemExit(1)
