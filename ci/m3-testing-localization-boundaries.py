#!/usr/bin/env python3
"""Pinned read-only M3 testing/WebDriver/localization build dependency contracts."""
from __future__ import annotations
import argparse
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
 "root":"moz.build",
 "browser":"browser/moz.build",
 "app":"browser/app.mozbuild",
 "toolkit":"toolkit/moz.build",
 "graph":"toolkit/toolkit.mozbuild",
 "testing":"testing/moz.build",
 "marionette":"testing/marionette/moz.build",
 "browser_locale":"browser/locales/moz.build",
 "browser_jar":"browser/locales/jar.mn",
 "browser_repack":"browser/locales/Makefile.in",
 "browser_l10n":"browser/locales/l10n.ini",
 "toolkit_locale":"toolkit/locales/moz.build",
 "toolkit_jar":"toolkit/locales/jar.mn",
 "package":"browser/installer/package-manifest.in",
 "browser_registry":"browser/l10n-registry.manifest",
 "toolkit_registry":"toolkit/l10n-registry.manifest",
}
DECISIONS = {"retain":"Keep wired build/runtime source",
             "conditional":"Audit exact config guard before considering changes",
             "separate_artifact":"Repack assets are a different measured artifact"}

def source_texts():
    return {key:subprocess.check_output(
        ["git","-C",str(ROOT),"show","HEAD:"+path],
        text=True,stderr=subprocess.PIPE) for key,path in FILES.items()}

def anchor(texts, source, literal):
    lines=[i+1 for i,line in enumerate(texts[source].splitlines()) if literal in line]
    if len(lines)!=1:
        raise ValueError(f"Missing/ambiguous {source}: {literal!r}, lines {lines}")
    return {"path":FILES[source],"line":lines[0],"anchor":literal}

def guarded(texts,source,start,end,*needed):
    raw=texts[source]
    if raw.count(start)!=1: raise ValueError(f"Missing guard {source}: {start!r}")
    a=raw.index(start)
    b=raw.find(end,a+len(start))
    if b<0: raise ValueError(f"Missing guard termination {source}: {end!r}")
    scope=raw[a:b]
    for item in needed:
        if item not in scope:
            raise ValueError(f"Scope escape in {source} guard {start!r}: {item!r}")
    return anchor(texts,source,start)

def validate(texts):
    result=[]
    def put(name,decision,why,*ev):
        if decision not in DECISIONS or not ev:
            raise ValueError("Unclassified/ungrounded boundary: "+name)
        result.append({"id":name,"decision":decision,"reason":why,"evidence":list(ev)})

    put("top_level_build_and_test_source","retain",
        "Root build traverses Python and testing even without ENABLE_TESTS; not dead code.",
        anchor(texts,"root",'    "testing",'),
        anchor(texts,"root",'    "python",'),
        anchor(texts,"root",'    "third_party/python",'),
        anchor(texts,"root",'    include("/" + CONFIG["MOZ_BUILD_APP"] + "/app.mozbuild")'))

    put("unconditional_testing_support","retain",
        "Manifest, mozbase, mozharness remain wired independently of test suites.",
        anchor(texts,"testing",'DIRS += ["manifest", "mozbase", "mozharness"]'),
        anchor(texts,"testing",'"test/python.toml"'))

    put("android_test_python_manifest","conditional",
        "Root testing manifest condition references Android test file on non-JS_STANDALONE.",
        guarded(texts,"testing",'if not CONFIG["JS_STANDALONE"]:',
                'SPHINX_TREES["/testing"] = "docs"',
                '"android-test/tests/python.toml"'))

    put("browser_entry_and_locale","retain",
        "Browser app includes Gecko toolkit; browser locale and screenshots test registered.",
        anchor(texts,"app",'include("/toolkit/toolkit.mozbuild")'),
        anchor(texts,"browser",'    "locales",'),
        anchor(texts,"browser",'    "tools/mozscreenshots",'))

    put("webdriver_remote_and_marionette","conditional",
        "ENABLE_WEBDRIVER brings remote agent, Firefox UI, Marionette and telemetry integration.",
        guarded(texts,"graph",'if CONFIG["ENABLE_WEBDRIVER"]:',
                'if (\n    CONFIG["MOZ_GECKODRIVER"]',
                '"/remote"','"/testing/firefox-ui"','"/testing/marionette"',
                '"/toolkit/components/telemetry/tests/marionette"'),
        anchor(texts,"marionette",'MARIONETTE_MANIFESTS += ["harness/marionette_harness/tests/unit/unit-tests.toml"]'))

    put("geckodriver_independent_config","conditional",
        "Geckodriver needs MOZ_GECKODRIVER and not TSAN/fuzzing; not the same guard as remote.",
        guarded(texts,"graph",'if (\n    CONFIG["MOZ_GECKODRIVER"]',
                'DIRS += [\n    "/media/gmp-clearkey/0.1",',
                'not CONFIG["MOZ_TSAN"]','not CONFIG["FUZZING_INTERFACES"]',
                '"/testing/geckodriver"'))

    put("test_suite_fixtures_guard","conditional",
        "WPT, xpcshell, Mochitest, profiles and modules sit under ENABLE_TESTS.",
        guarded(texts,"graph",
                'if CONFIG["ENABLE_TESTS"]:\n    DIRS += [\n        "/testing/mochitest"',
                '    if CONFIG["MOZ_MEMORY"]:',
                '"/testing/xpcshell"','"/testing/web-platform"',
                '"/testing/profiles"','"/testing/modules"'))

    put("webdriver_package_resources","conditional",
        "ENABLE_WEBDRIVER guards remote chrome package contents independently of suites.",
        guarded(texts,"package",'#ifdef ENABLE_WEBDRIVER','; Modules',
                '@RESPATH@/chrome/remote@JAREXT@',
                '@RESPATH@/chrome/remote.manifest'))

    put("browser_l10n_registry_and_jar","retain",
        "Fluent browser resources and its live l10n registry are packaged for default browser.",
        anchor(texts,"browser",'    "l10n-registry.manifest",'),
        anchor(texts,"browser_locale",'JAR_MANIFESTS += ["jar.mn"]'),
        anchor(texts,"browser_jar",'  browser                                          (%browser/**/*.ftl)'),
        anchor(texts,"browser_registry",
               'category l10n-registry 5-browser resource://app/localization/{locale}/ backgroundtask=0'))

    put("toolkit_l10n_registry_and_generated_defaults","retain",
        "Toolkit registry, JAR and generated multilocale/default.locale are wired sources.",
        anchor(texts,"toolkit",'    "l10n-registry.manifest",'),
        anchor(texts,"toolkit_locale",'JAR_MANIFESTS += ["jar.mn"]'),
        anchor(texts,"toolkit_locale",
               'GeneratedFile("multilocale.txt", script="gen_multilocale.py")'),
        anchor(texts,"toolkit_locale",
               'default_locale.script = "generate_default_locale.py"'),
        anchor(texts,"toolkit_registry",
               'category l10n-registry 0-toolkit resource://gre/localization/{locale}/ backgroundtask=0'))

    put("packaged_locale_content","retain",
        "Package manifest includes browser/toolkit localization, dictionary and default.locale.",
        anchor(texts,"package",'@RESPATH@/browser/localization/*'),
        anchor(texts,"package",'@RESPATH@/localization/*'),
        anchor(texts,"package",'@RESPATH@/dictionaries/*'),
        anchor(texts,"package",'@RESPATH@/default.locale'))

    put("locale_repack_langpack","separate_artifact",
        "Langpacks and language repacks use l10n.mk and stages, not normal archive totals.",
        anchor(texts,"browser_repack",
               'include $(topsrcdir)/toolkit/locales/l10n.mk'),
        anchor(texts,"browser_repack",'l10n-%: AB_CD=$*'),
        anchor(texts,"browser_repack",'langpack: langpack-$(AB_CD)'))

    put("locale_branding_toolkit_fallback","retain",
        "Existing l10n metadata references upstream branding and toolkit translation map.",
        anchor(texts,"browser_l10n",'     other-licenses/branding/firefox'),
        anchor(texts,"browser_l10n",'     browser/branding/official'),
        anchor(texts,"browser_l10n",'toolkit = toolkit/locales/l10n.ini'))

    put("localized_updater_ini","conditional",
        "MOZ_UPDATER still reads a Windows installer source in localized updater generation.",
        guarded(texts,"browser_locale",'if CONFIG["MOZ_UPDATER"]:',
                'with Files("**"):','"generate_ini.py"',
                '"../installer/windows/nsis/updater_append.ini"'))

    return {"schema_version":1,"project":"Vulpra",
        "source_only":True,
        "scope":"bounded testing, remote WebDriver, locale and language-pack build declarations",
        "boundaries":result,"decisions":DECISIONS,
        "removal_authorized":False,"native_runtime_tested":False,
        "compiled_package_savings_verified":False,
        "limitations":[
          "Guarded source anchors do not evaluate the generated build dependency graph.",
          "Not an exhaustive dynamic import/caller or binary linker dependency census.",
          "No locale file/package byte measurements or complete translation inventory.",
          "No live release-package testing, optional removal, or regressions from pruning."],
        "next":[
          "Preserve always-wired mozbase/mozharness/manifest and active WebDriver paths.",
          "Classify conditional test fixtures separately from build support.",
          "Audit l10n/branding fallback before pruning any default-locale resource.",
          "Inspect real package and langpack members and sizes before an omission trial."]}

def self_test(texts):
    changes=[
        ("root",'    "testing",'),
        ("testing",'DIRS += ["manifest", "mozbase", "mozharness"]'),
        ("testing",'if not CONFIG["JS_STANDALONE"]:'),
        ("app",'include("/toolkit/toolkit.mozbuild")'),
        ("browser",'    "locales",'),
        ("graph",'if CONFIG["ENABLE_WEBDRIVER"]:'),
        ("graph",'"/testing/geckodriver"'),
        ("graph",'"/testing/web-platform"'),
        ("package",'#ifdef ENABLE_WEBDRIVER'),
        ("package",'@RESPATH@/browser/localization/*'),
        ("browser_locale",'JAR_MANIFESTS += ["jar.mn"]'),
        ("browser_jar",'  browser                                          (%browser/**/*.ftl)'),
        ("toolkit_locale",'GeneratedFile("multilocale.txt", script="gen_multilocale.py")'),
        ("toolkit_registry",
          'category l10n-registry 0-toolkit resource://gre/localization/{locale}/ backgroundtask=0'),
        ("browser_repack",'langpack: langpack-$(AB_CD)'),
        ("browser_l10n",'toolkit = toolkit/locales/l10n.ini'),
        ("browser_locale",'"../installer/windows/nsis/updater_append.ini"'),
    ]
    for key,value in changes:
        if texts[key].count(value)!=1:
            raise AssertionError("Invalid negative fixture "+key+": "+value)
        corrupted=dict(texts)
        corrupted[key]=corrupted[key].replace(value,"__BROKEN_CONTRACT__",1)
        try:
            validate(corrupted)
        except ValueError:
            continue
        raise AssertionError("Invalid change accepted "+key+": "+value)
    return len(changes)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--self-test",action="store_true")
    ap.add_argument("--output")
    args=ap.parse_args()
    sha=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    texts=source_texts()
    data=validate(texts)
    data["source_commit"]=sha
    if args.self_test:
        data["invalid_mutations_rejected"]=self_test(texts)
    if args.output:
        path=Path(args.output);path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    print(f"PASS: {len(data['boundaries'])} guarded testing/localization boundaries, Git HEAD {sha}")
    if args.self_test:
        print(f"PASS: {data['invalid_mutations_rejected']} deliberately broken guards rejected")
    print("READ ONLY: no runtime test, deletion, or package saving claimed")

if __name__=="__main__":
    try: main()
    except (ValueError,AssertionError,OSError,subprocess.CalledProcessError) as exc:
        print("FAIL M3 testing/localization:",exc,file=sys.stderr)
        raise SystemExit(1)
