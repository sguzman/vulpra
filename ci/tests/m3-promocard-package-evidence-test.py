#!/usr/bin/env python3
"""Synthetic, file-isolated tests for native PromoCard package evidence tools.

Creates tiny tar.xz/omni.ja fixtures. It NEVER runs a full Vulpra browser or
stands in for its real package/runtimes.
"""
from __future__ import annotations
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
ARCHIVE=ROOT/"ci/m3-promocard-package-evidence.py"
COMPARE=ROOT/"ci/m3-promocard-match-evidence.py"
SHA="a"*40
PROTECTED=(
    "ActivityStream.sys.mjs","DiscoveryStreamFeed.sys.mjs",
    "TopStoriesFeed.sys.mjs","TopSitesFeed.sys.mjs",
    "AdsClient.sys.mjs","Store.sys.mjs","AdsFeed.sys.mjs"
)

def synthesize(out: Path, variant: str) -> Path:
    package=out/(variant+".tar.xz")
    blob=io.BytesIO()
    with zipfile.ZipFile(blob,"w",zipfile.ZIP_DEFLATED) as jar:
        for name in PROTECTED:
            jar.writestr("builtin-addons/newtab/lib/"+name, "protected "+name)
        bundle="newtab-label-sponsored-fixed public-banner"
        if variant=="normal":
            bundle+=" newtab-promo-card-title-addons original-component"
        jar.writestr("builtin-addons/newtab/data/content/activity-stream.bundle.js",bundle)
    with tarfile.open(package,"w:xz") as tf:
        for name,raw in (
            ("vulpra/omni.ja",b""),
            ("vulpra/browser/omni.ja",blob.getvalue()),
        ):
            if not raw:
                raw=io.BytesIO().getvalue()
                # A second valid empty ZIP is required by the archive checker.
                extra=io.BytesIO()
                with zipfile.ZipFile(extra,"w"):
                    pass
                raw=extra.getvalue()
            info=tarfile.TarInfo(name)
            info.size=len(raw)
            tf.addfile(info,io.BytesIO(raw))
    return package

def repack_layout(out: Path, variant: str, layout: str) -> Path:
    """Synthetic relocation of actual ZIP entries, never native acceptance."""
    initial=synthesize(out,variant)
    with tarfile.open(initial,"r:xz") as tar:
        contents={m.name:tar.extractfile(m).read() for m in tar if m.isfile()}
    original=contents["vulpra/browser/omni.ja"]
    empty=io.BytesIO()
    with zipfile.ZipFile(empty,"w"):
        pass
    contents["vulpra/browser/omni.ja"]=empty.getvalue()
    if layout=="xpi":
        target="vulpra/browser/features/newtab@mozilla.org.xpi"
        outzip=io.BytesIO()
        with zipfile.ZipFile(io.BytesIO(original)) as z, \
             zipfile.ZipFile(outzip,"w") as dst:
            for name in z.namelist():
                assert name.startswith("builtin-addons/newtab/")
                dst.writestr(name.removeprefix("builtin-addons/newtab/"),z.read(name))
        contents[target]=outzip.getvalue()
    elif layout=="browserjar":
        contents["vulpra/browser/chrome/browser.jar"]=original
    elif layout=="prefixed":
        outzip=io.BytesIO()
        with zipfile.ZipFile(io.BytesIO(original)) as z, \
             zipfile.ZipFile(outzip,"w") as dst:
            for name in z.namelist():
                dst.writestr("chrome/browser/content/browser/"+name,z.read(name))
        contents["vulpra/browser/omni.ja"]=outzip.getvalue()
    else:
        raise ValueError(layout)
    target=out/(variant+"-"+layout+".tar.xz")
    with tarfile.open(target,"w:xz") as tar:
        for name,raw in contents.items():
            item=tarfile.TarInfo(name)
            item.size=len(raw)
            tar.addfile(item,io.BytesIO(raw))
    return target


def call(*args: str, success: bool=True) -> None:
    run=subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,
                       capture_output=True,text=True)
    if success and run.returncode:
        raise AssertionError(run.stderr+"\n"+run.stdout)
    if not success and not run.returncode:
        raise AssertionError("Invalid evidence incorrectly accepted")
    if success:
        print(run.stdout.strip().split("\n")[-1])

def main() -> None:
    with tempfile.TemporaryDirectory(prefix="vulpra-promocard-fixtures-") as d:
        out=Path(d)
        for v in ("normal","optin"):
            call(ARCHIVE,"--archive",synthesize(out,v),"--source-commit",SHA,
                 "--variant",v,"--output",out/(v+".json"))
        for layout in ("xpi","browserjar","prefixed"):
            for variant in ("normal","optin"):
                archive=repack_layout(out,variant,layout)
                report_path=out/(variant+"-"+layout+".json")
                call(ARCHIVE,"--archive",archive,"--source-commit",SHA,
                     "--variant",variant,"--output",report_path)
                report=json.loads(report_path.read_text())
                assert report["verified_newtab_bundle_copies"]==1
                assert report["promocard_original_code_present"]==(variant=="normal")
        print("PASS: XPI, browser.jar and prefixed omni ZIP layouts")

        f=json.loads((out/"normal.json").read_text())
        l=json.loads((out/"optin.json").read_text())
        assert f["promocard_original_code_present"]
        assert not l["promocard_original_code_present"]
        assert f["adsfeed_resource_present"] and l["adsfeed_resource_present"]
        assert f["protected_resources_present"] and l["protected_resources_present"]
        l["status"]="native runtime accepted; matched comparison pending"
        l["tested"]={key:True for key in
            ("wayland","js","newtab","webextensions","nimbus","firefox_profile_isolation")}
        (out/"optin.json").write_text(json.dumps(l))
        call(COMPARE,out/"normal.json",out/"optin.json",out/"matched.json",
             "--source-commit",SHA)
        report=json.loads((out/"matched.json").read_text())
        assert report["same_source"] and report["native_optin_runtime_passed"]
        assert report["normal_newtab_js_sha256"]!=report["optin_newtab_js_sha256"]
        bad=dict(l,source_commit="b"*40)
        (out/"bad.json").write_text(json.dumps(bad))
        call(COMPARE,out/"normal.json",out/"bad.json",out/"badout.json",
             "--source-commit",SHA,success=False)
        bad=dict(l,compressed_package_bytes=f["compressed_package_bytes"]+5)
        (out/"negative.json").write_text(json.dumps(bad))
        call(COMPARE,out/"normal.json",out/"negative.json",out/"negativeout.json",
             "--source-commit",SHA)
        assert json.loads((out/"negativeout.json").read_text())[
            "observed_full_minus_optin_package_bytes"] == -5
        print("PASS: synthetic omission/retention, mismatched SHA rejection, signed negative delta")
        print("MOCK FIXTURE ONLY: does not establish native package byte saving")

if __name__=="__main__":
    main()
