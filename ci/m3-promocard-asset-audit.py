#!/usr/bin/env python3
"""Source-only reachability inventory for the optional New Tab PromoCard asset.

This checks literal source uses, NOT dynamic localization/asset reachability.
A resource absent from this grep is not automatically safe to delete.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
PROMO="browser/extensions/newtab/content-src/components/DiscoveryStreamComponents/PromoCard/PromoCard.jsx"
ASSET="browser/extensions/newtab/data/content/assets/firefox-mascot-prop-paintbucket-rgb.svg"
PATTERNS=[
    "firefox-mascot-prop-paintbucket-rgb.svg",
    "newtab-promo-card-dismiss-button",
    "newtab-promo-card-title-addons",
    "newtab-promo-card-body-addons",
    "newtab-promo-card-cta-addons",
]
SCOPES=[
    "browser/extensions/newtab",
    "browser/locales/en-US/browser/newtab",
    "browser/components/newtab",
]

def scan(root:Path) -> dict:
    commit=subprocess.check_output(["git","-C",str(root),"rev-parse","HEAD"],
                                    text=True).strip()
    if not re.fullmatch("[0-9a-f]{40}",commit):
        raise ValueError("Noncanonical source commit")
    subprocess.run(["git","-C",str(root),"cat-file","-e","HEAD:"+ASSET],
                   check=True,capture_output=True)
    results={}
    for term in PATTERNS:
        p=subprocess.run(["git","-C",str(root),"grep","-n","-F",term,
                          "HEAD","--",*SCOPES],capture_output=True,text=True)
        if p.returncode not in (0,1):
            raise ValueError("Git source scan failed: "+p.stderr)
        matches=[]
        for line in p.stdout.splitlines():
            parts=line.split(":",3)
            if len(parts)!=4 or parts[0]!="HEAD" or not parts[2].isdigit():
                raise ValueError("Noncanonical Git grep output: "+line[:90])
            matches.append({"path":parts[1],"line":int(parts[2]),
                            "snippet":parts[3][:180]})
        if not any(m["path"]==PROMO for m in matches):
            raise ValueError("Original PromoCard source no longer owns marker: "+term)
        results[term]={
            "count":len(matches),
            "other_source_refs":sum(m["path"]!=PROMO for m in matches),
            "matches":matches,
        }
    return {
        "schema_version":1,
        "source_commit":commit,
        "mode":"read_only_literal_source_references_not_runtime_reachability",
        "asset_path":ASSET,
        "asset_tracked":True,
        "original_promo_component":PROMO,
        "terms":results,
        "mascot_shared_outside_promocard":
            results[PATTERNS[0]]["other_source_refs"]>0,
        "removal_authorized":False,
        "limitations":[
            "Computed imports, dynamic content and generated bundles may not contain literal source references.",
            "English localization definitions are not the complete set of all locale/deployment consumers.",
            "The PromoCard JSX bundle omission does not authorize deletion of shared SVG, style or locale assets.",
            "This scan does not compile, package or run Firefox."
        ],
    }

def main() -> None:
    ap=argparse.ArgumentParser()
    ap.add_argument("--output",type=Path,required=True)
    a=ap.parse_args()
    d=scan(ROOT)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(d,indent=2)+"\n")
    for term,info in d["terms"].items():
        print(f"{term}: {info['count']} source lines, {info['other_source_refs']} outside PromoCard")
    print("PASS: source-pinned actual PromoCard mascot and l10n marker inventory")
    print("AUDIT ONLY: no asset/style/locale deletion authorized")

if __name__=="__main__":
    try:
        main()
    except (OSError,ValueError,subprocess.CalledProcessError) as e:
        print("FAIL: PromoCard asset source audit:",e,file=sys.stderr)
        raise SystemExit(1)
