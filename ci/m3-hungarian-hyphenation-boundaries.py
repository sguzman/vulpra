#!/usr/bin/env python3
"""Source-pinned Hungarian hyphenation package/consumer fallback audit.

The 1.05MB archived resource is intentionally NOT removed. This checks its
build inclusion, omnijar loading, locale fallback and missing-pattern behavior.
Not a proof of typographic regression or compressed archive savings.
"""
from __future__ import annotations
import argparse,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FILES={
 "intl":"intl/moz.build",
 "locale":"intl/locales/moz.build",
 "glue":"intl/hyphenation/glue/moz.build",
 "manager":"intl/hyphenation/glue/nsHyphenationManager.cpp",
 "loader":"intl/hyphenation/glue/nsHyphenator.cpp",
 "manifest":"browser/installer/package-manifest.in",
}
def sources():
    return {k:subprocess.check_output(["git","-C",str(ROOT),"show","HEAD:"+p],
        text=True,stderr=subprocess.PIPE) for k,p in FILES.items()}
def line(t,k,x):
    data=t[k]
    if data.count(x)!=1:raise ValueError("Missing/ambiguous hyphen source "+k+": "+x)
    return {"source":FILES[k],"line":data.count("\n",0,data.index(x))+1,"anchor":x}
def between(t,k,start,end,*needed):
    s=t[k]
    if s.count(start)!=1:raise ValueError("Missing/ambiguous scoped guard "+k+": "+start)
    a=s.index(start);b=s.find(end,a+len(start))
    if b<0:raise ValueError("Missing scoped terminator "+k+": "+end)
    for item in needed:
        if item not in s[a:b]:raise ValueError("Outside guarded scope "+k+": "+item)
    return line(t,k,start)
def audit(t):
    records=[]
    def put(name,decision,why,*anchors):
        records.append({"id":name,"decision":decision,"reason":why,"source_anchors":list(anchors)})
    put("native_glue_always_built","retain",
        "Hyphenation C++ manager/glue and Rust cbindgen are part of libxul for desktop.",
        line(t,"intl", '    "hyphenation/glue",'),
        line(t,"glue",'FINAL_LIBRARY = "xul"'),
        line(t,"glue",'CbindgenHeader("mapped_hyph.h", inputs=["/third_party/rust/mapped_hyph"])'))
    put("desktop_precompiled_vs_android_dictionary","conditional",
        "Desktop packs precompiled .hyf, unlike Android .dic; different first-use cost.",
        between(t,"locale",'if CONFIG["MOZ_BUILD_APP"] == "mobile/android":',
                'locales = [','hyphenation_ext = ".dic"','hyphenation_ext = ".hyf"'))
    put("hungarian_packaged_by_default","review",
        "Hungarian is one of default desktop locale patterns included through FINAL_TARGET_FILES.",
        line(t,"locale",'    "hu",'),
        line(t,"locale",'FINAL_TARGET_FILES.hyphenation += [filename.format(locale=locale) for locale in locales]'),
        line(t,"manifest",'@RESPATH@/hyphenation/*'))
    put("omnijar_and_profile_sources","retain",
        "Manager loads GRE and APP omni archives, external app/gre directories and profile.",
        line(t,"manager",'  LoadPatternListFromOmnijar(Omnijar::GRE);'),
        line(t,"manager",'  LoadPatternListFromOmnijar(Omnijar::APP);'),
        line(t,"manager",'  zip->FindInit("hyphenation/hyph_*.*", &find);'),
        line(t,"manager",'    profileDir->AppendNative("hyphenation"_ns);'))
    put("missing_locale_can_return_without_resource","conditional",
        "Manager uses aliases and progressive language fallback then returns nullptr. "
        "This is not a verified visual/CSS fallback in running browser.",
        between(t,"manager",'  nsCOMPtr<nsIURI> uri = mPatternFiles.Get(aLocale);',
                '  nsAutoCString hyphCapPref("intl.hyphenate-capitalized.");',
                'mHyphAliases.Get(aLocale)',
                'return GetHyphenator(fuzzyLocale);',
                'return nullptr;'))
    put("invalid_resource_not_silent_success","retain",
        "Manager drops invalid pattern URI and returns nullptr, loader has explicit "
        "assertion for broken dictionary. Deleting packaged patterns can alter "
        "typography and any language-specific content.",
        line(t,"manager",'  mPatternFiles.Remove(aLocale);'),
        line(t,"loader",'  msg.Insert("Invalid hyphenation resource: ", 0);'),
        line(t,"loader",'  NS_ASSERTION(false, msg.get());'))
    return {"schema_version":1,"project":"Vulpra",
        "source_only":True,"source_removal_authorized":False,
        "selected_hu_package_entry_logical_bytes_historical":1048764,
        "selected_hu_zip_entry_bytes_is_tar_saving":False,
        "layout_css_language_fallback_runtime_verified":False,
        "normal_browser_changed":False,
        "boundaries":records,
        "next":["Preserve default shipped Hungarian hyphenation until a reversible guard and localized CSS test exist.",
                "Verify correct native layout (hu, hu-HU) with hyphens:auto, a deliberately missing resource, and standard en-US text.",
                "Check profile/app/omnijar precedence and separate language-pack installation behavior.",
                "Compare actual same-source full/opt-in compressed tar.xz, not 1,048,764 logical bytes."],
        "limitations":["Source anchors are not a full call graph or platform resource census.",
                       "Alias fallback and return nullptr do not prove good typography or no regression.",
                       "No build, packaged omission, live CSS test, or byte delta recorded."]}
def test(t):
    cases=[
        ("intl", '    "hyphenation/glue",'),
        ("glue",'FINAL_LIBRARY = "xul"'),
        ("locale",'if CONFIG["MOZ_BUILD_APP"] == "mobile/android":'),
        ("locale",'    "hu",'),
        ("locale",'FINAL_TARGET_FILES.hyphenation += [filename.format(locale=locale) for locale in locales]'),
        ("manifest",'@RESPATH@/hyphenation/*'),
        ("manager",'  LoadPatternListFromOmnijar(Omnijar::GRE);'),
        ("manager",'  zip->FindInit("hyphenation/hyph_*.*", &find);'),
        ("manager",'    profileDir->AppendNative("hyphenation"_ns);'),
        ("manager",'return GetHyphenator(fuzzyLocale);'),
        ("manager",'  mPatternFiles.Remove(aLocale);'),
        ("loader",'  NS_ASSERTION(false, msg.get());'),
    ]
    for k,x in cases:
        if t[k].count(x)!=1:raise AssertionError("Bad mutation fixture "+x)
        altered=dict(t);altered[k]=t[k].replace(x,"__BROKEN_HYPH__",1)
        try:audit(altered)
        except ValueError:continue
        raise AssertionError("Missing Hungarian pattern dependency was accepted: "+x)
    return len(cases)
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--self-test",action="store_true")
    p.add_argument("--output",type=Path)
    a=p.parse_args()
    t=sources()
    o=audit(t)
    o["source_commit"]=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    if a.self_test:o["source_mutations_rejected"]=test(t)
    if a.output:
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.output.write_text(json.dumps(o,indent=2)+"\n")
    print("PASS: six source-pinned Hungarian hyphenation build/omnijar/fallback boundaries")
    if a.self_test:print("PASS:",o["source_mutations_rejected"],"unsafe source mutations rejected")
    print("NO REMOVAL: no language layout runtime or compressed savings claimed")
if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,subprocess.CalledProcessError) as e:
        print("FAIL M3 Hungarian pattern audit:",e,file=sys.stderr);raise SystemExit(1)
