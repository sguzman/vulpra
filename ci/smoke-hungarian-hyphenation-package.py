#!/usr/bin/env python3
"""Real packaged Vulpra localized hyphenation layout probe on a private profile.

Does not alter packaged language data. Tests Hungarian/CSS against explicit
hyphens:none and an unknown-language negative control. Records geometry only.
No browser profile, webpage content, real network or source modifications.
"""
from __future__ import annotations
import importlib.util,json,os
from pathlib import Path
import shutil,subprocess,sys,tempfile

ROOT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location(
    "vulpra_existing_webdriver",ROOT/"smoke-webextension-package-local.py")
driver=importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)

SCRIPT=r"""
const samples={};
const testWord="megszentségteleníthetetlenségeskedéseitekért";
const english="internationalization";
function test(lang,mode,word) {
 const e=document.createElement("div");
 e.setAttribute("lang",lang);
 e.style.cssText="display:block; width:90px; box-sizing:content-box; "+
  "font-family:serif;font-size:18px;line-height:26px; "+
  "word-break:normal;overflow-wrap:normal;white-space:normal;"+
  "hyphens:"+mode+";";
 e.appendChild(document.createTextNode(word));
 document.body.appendChild(e);
 const range=document.createRange();
 range.selectNodeContents(e);
 const rects=range.getClientRects();
 const out={
   language:lang,mode:mode,
   rendered_hyphens:getComputedStyle(e).hyphens,
   rect_count:rects.length,
   height:e.getBoundingClientRect().height,
   scroll_width:e.scrollWidth,
   client_width:e.clientWidth,
   font_family:getComputedStyle(e).fontFamily
 };
 e.remove();
 return out;
}
document.body.style.cssText="margin:0;padding:0";
samples.hu_auto=test("hu","auto",testWord);
samples.hu_none=test("hu","none",testWord);
samples.hu_HU_auto=test("hu-HU","auto",testWord);
samples.zz_auto=test("zz-ZZ","auto",testWord);
samples.en_auto=test("en-US","auto",english);
samples.en_none=test("en-US","none",english);
return samples;
"""

def validate(r):
    if not isinstance(r,dict) or set(r)!={
        "hu_auto","hu_none","hu_HU_auto","zz_auto","en_auto","en_none"}:
        raise RuntimeError("Missing actual browser layout samples")
    for k,x in r.items():
        if not isinstance(x,dict):raise RuntimeError("Missing CSS layout "+k)
        if x.get("mode") not in ("auto","none") or x.get("rendered_hyphens")!=x["mode"]:
            raise RuntimeError("CSS hyphenation mode not applied "+k)
        if type(x.get("rect_count")) is not int or x["rect_count"]<1:
            raise RuntimeError("Missing DOM Range geometry "+k)
        if type(x.get("height")) not in (int,float) or x["height"]<10:
            raise RuntimeError("No rendered height "+k)
        if type(x.get("scroll_width")) is not int or x["scroll_width"]<0:
            raise RuntimeError("Missing scrollWidth "+k)
        if type(x.get("client_width")) is not int or not 85<=x["client_width"]<=95:
            raise RuntimeError("Incorrect test fixture width "+k)
    if r["hu_auto"]["language"]!="hu" or r["hu_none"]["language"]!="hu":
        raise RuntimeError("Incorrect Hungarian control")
    if r["zz_auto"]["language"]!="zz-ZZ":
        raise RuntimeError("Incorrect unsupported locale control")

def classify(r):
    a=r["hu_auto"]["height"];b=r["hu_none"]["height"]
    unknown=r["zz_auto"]["height"]
    english=r["en_auto"]["height"];en_none=r["en_none"]["height"]
    return {
        "hu_auto_wrapped_beyond_none":a>b+8,
        "hu_auto_wrapped_beyond_unknown_locale":a>unknown+8,
        "hu_HU_auto_wrapped_beyond_none":r["hu_HU_auto"]["height"]>b+8,
        "en_US_auto_wrapped_beyond_none":english>en_none+8,
        "geometric_hyphenation_was_conclusively_observed":a>b+8 and a>unknown+8,
        "interpretation":"Geometry only: text wrapping varies by native font/build. No shipped pattern omission performed."
    }

def selftest():
    fixture={}
    for name,lang,mode in [
        ("hu_auto","hu","auto"),("hu_none","hu","none"),
        ("hu_HU_auto","hu-HU","auto"),("zz_auto","zz-ZZ","auto"),
        ("en_auto","en-US","auto"),("en_none","en-US","none")
    ]:
        fixture[name]={"language":lang,"mode":mode,"rendered_hyphens":mode,
            "rect_count":1,"height":26,"scroll_width":355,
            "client_width":90,"font_family":"serif"}
    fixture["hu_auto"]["height"]=78
    assert classify(fixture)["hu_auto_wrapped_beyond_none"]
    validate(fixture)
    cases=[
       lambda x:x.pop("hu_auto"),
       lambda x:x["hu_auto"].update(rendered_hyphens="manual"),
       lambda x:x["hu_auto"].update(rect_count=0),
       lambda x:x["hu_none"].update(height=0),
       lambda x:x["hu_auto"].update(client_width=1000),
       lambda x:x["zz_auto"].update(language="hu"),
    ]
    from copy import deepcopy
    for mutate in cases:
        x=deepcopy(fixture);mutate(x)
        try:validate(x)
        except RuntimeError:continue
        raise AssertionError("Malformed CSS language evidence accepted")
    return len(cases)

def run(repo,gecko):
    archive=driver.verified_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-hyph-css-") as tmp:
        root=Path(tmp)
        app=root/"app";app.mkdir()
        subprocess.run(["tar","-xf",str(archive),"-C",str(app)],check=True)
        inis=list(app.rglob("application.ini"))
        if len(inis)!=1 or "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Not uniquely identified Vulpra package")
        binary=driver.select_binary(inis[0].parent)
        home=root/"home";home.mkdir()
        sentinel=home/".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        sentinel.write_bytes(b"preexisting Firefox sentinel must be preserved\n")
        env=os.environ.copy()
        env.update(HOME=str(home),XDG_DATA_HOME=str(home/"xdg"),
                   MOZ_HEADLESS="1",MOZ_DISABLE_NONLOCAL_CONNECTIONS="1",
                   NO_PROXY="127.0.0.1,localhost",no_proxy="127.0.0.1,localhost")
        for key in ("DISPLAY","WAYLAND_DISPLAY","MOZ_REMOTE"):env.pop(key,None)
        port=driver.find_port();proc=None;session=None
        try:
            with (root/"gecko.log").open("wb") as out:
                proc=subprocess.Popen([gecko,"--host","127.0.0.1","--port",str(port)],
                    env=env,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
                driver.wait_ready(port,proc,seconds=45)
                conn=driver.request(port,"POST","/session",{
                    "capabilities":{"alwaysMatch":{"browserName":"firefox",
                      "moz:firefoxOptions":{"binary":str(binary),
                        "args":["-headless","-no-remote"],
                        "prefs":{"browser.shell.checkDefaultBrowser":False,
                          "app.update.enabled":False,
                          "extensions.update.enabled":False}}}}},timeout_seconds=60)
                session=conn["sessionId"]
                route="/session/"+session
                driver.request(port,"POST",route+"/url",{"url":"about:blank"})
                r=driver.request(port,"POST",route+"/execute/sync",
                    {"script":SCRIPT,"args":[]},timeout_seconds=60)
                validate(r)
                if sentinel.read_bytes()!=b"preexisting Firefox sentinel must be preserved\n":
                    raise RuntimeError("Touched unrelated Firefox profile")
                return {"schema_version":1,
                    "status":"real_native_hungarian_css_layout_diagnostic_completed",
                    "source_package_archive":archive.name,
                    "actual_browser_geometry":r,
                    "comparisons":classify(r),
                    "real_browser_executed":True,
                    "private_profile_preserved":True,
                    "nonlocal_connections_blocked":True,
                    "packaged_hungarian_pattern_not_removed":True,
                    "source_removal_authorized":False,
                    "compressed_tar_xz_savings":None,
                    "limitations":[
                     "Real browser measurements with shipped Hungarian pattern, not omission.",
                     "Layout differs by fonts, language aliases, CSS and environment.",
                     "Unknown language negative control is not an actual omitted hu pattern.",
                     "No test of actual hu file omission, native rebuild or paired archive saving."]}
        finally:
            if session:
                try:driver.request(port,"DELETE","/session/"+session,timeout_seconds=7)
                except (RuntimeError,OSError):pass
            if proc:
                proc.terminate()
                try:proc.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    proc.kill();proc.wait(timeout=5)

def main():
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("repo",nargs="?",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:print("PASS:",selftest(),"negative CSS geometry fixtures")
    if not a.repo:
        if not a.self_test:p.error("repository required")
        return
    gecko=shutil.which("geckodriver")
    if not gecko:raise RuntimeError("Missing stock geckodriver")
    repo=a.repo.resolve()
    report=run(repo,gecko)
    p=repo/".git/vulpra-native-build/m3-hungarian-hyphenation-native-css.json"
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(report,indent=2)+"\n")
    print("PASS: real packaged Vulpra native Hungarian/English CSS layout measured")
    print("WRAP COMPARISONS:",json.dumps(report["comparisons"],sort_keys=True))
    print("No hu pattern omitted; CSS render measurement, not safe removal proof")
if __name__=="__main__":
    try:main()
    except (OSError,RuntimeError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL M3 Hungarian CSS:",e,file=sys.stderr);raise SystemExit(1)
