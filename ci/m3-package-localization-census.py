#!/usr/bin/env python3
"""Read-only SHA256-verified localization resource census for packaged Vulpra.

No extraction, execution, source editing or binary-sized removal claim. Logical
and nested ZIP compressed sizes cannot be interpreted as marginal tar.xz savings.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import re
import sys
import tarfile
import tempfile
import zipfile

JAR_LIMIT=192*1024*1024
KINDS=("browser_l10n","toolkit_l10n","default_locale",
       "dictionaries","hyphenation","legacy_chrome_locale","other")
def group(path):
    name="/"+path.strip("/")+"/"
    if "/browser/localization/" in name: return "browser_l10n"
    if "/localization/" in name: return "toolkit_l10n"
    if name.rstrip("/").endswith("/default.locale"): return "default_locale"
    if "/dictionaries/" in name: return "dictionaries"
    if "/hyphenation/" in name: return "hyphenation"
    if "/chrome/" in name and ("/locale/" in name or "/locales/" in name):
        return "legacy_chrome_locale"
    return "other"
def jar_group(path, container):
    category=group(path)
    # Both JARs can use the same localization/ prefix. Use the physical
    # browser/omni.ja container as provenance for browser-localized resources.
    if category == "toolkit_l10n" and (
        "/browser/omni.ja" in "/" + container.lstrip("./")
    ):
        return "browser_l10n"
    return category

def stat():
    return {"files":0,"logical_bytes":0,"inner_zip_compressed_bytes":0}
def record(report,kind,size,compressed=0):
    b=report[kind];b["files"]+=1;b["logical_bytes"]+=size
    b["inner_zip_compressed_bytes"]+=compressed

def verify_digest(archive):
    sidecar=Path(str(archive)+".sha256")
    if not sidecar.is_file(): raise ValueError("Missing SHA256 sidecar")
    raw=sidecar.read_text(encoding="ascii").splitlines()
    if len(raw)!=1: raise ValueError("Unexpected SHA256 sidecar lines")
    fields=raw[0].split()
    if len(fields)!=2 or not re.fullmatch("[0-9a-fA-F]{64}",fields[0]):
        raise ValueError("Invalid SHA256 sidecar")
    if Path(fields[1].lstrip("*")).name!=archive.name:
        raise ValueError("Sidecar does not identify verified archive")
    digest=sha256()
    with archive.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            digest.update(chunk)
    if digest.hexdigest()!=fields[0].lower():
        raise ValueError("Archive checksum mismatch")
    return digest.hexdigest()

def census(archive):
    digest=verify_digest(archive)
    outer={name:stat() for name in KINDS}
    inside={name:stat() for name in KINDS}
    jars=[]
    members=0
    with tarfile.open(archive,"r:xz") as tar:
        for member in tar:
            if not member.isfile(): continue
            members+=1
            record(outer,group(member.name),member.size)
            if member.name.endswith("/omni.ja"):
                if member.size>JAR_LIMIT:
                    jars.append({"archive_member":member.name,"status":"skipped_size_cap"})
                    continue
                inp=tar.extractfile(member)
                if inp is None: raise ValueError("Unextractable omni resource archive")
                with zipfile.ZipFile(BytesIO(inp.read())) as jar:
                    entries=[entry for entry in jar.infolist() if not entry.is_dir()]
                jar_counts={name:stat() for name in KINDS}
                for entry in entries:
                    bucket=jar_group(entry.filename,member.name)
                    record(inside,bucket,entry.file_size,entry.compress_size)
                    record(jar_counts,bucket,entry.file_size,entry.compress_size)
                jars.append({"archive_member":member.name,"status":"readable",
                             "entries":len(entries),
                             "locale_group_by_jar":{k:v for k,v in jar_counts.items()
                                                 if k!="other"}})
    if members==0: raise ValueError("Empty packaged browser archive")
    if not jars: raise ValueError("No packaged omni.ja resource archive")
    return {
      "schema_version":1,
      "test":"checksum_verified_packaged_locale_resource_census",
      "archive_name":archive.name,
      "sha256":digest,
      "compressed_archive_bytes":archive.stat().st_size,
      "tar_regular_members":members,
      "outer_tar_members":outer,
      "nested_omni_ja_members":inside,
      "omni_ja":jars,
      "localized_content_present": (
        outer["browser_l10n"]["files"]+
        outer["toolkit_l10n"]["files"]+
        inside["browser_l10n"]["files"]+
        inside["toolkit_l10n"]["files"] > 0
      ),
      "source_only":False,
      "archive_execution":False,
      "source_removal_authorized":False,
      "compiled_bytes_saved":None,
      "scope":"Observed complete regular-file members and bounded inner ZIP metadata",
      "limitations":[
        "Historical browser archive may not match HEAD source/flags.",
        "ZIP entry compressed bytes are not independent contributions to tar.xz size.",
        "Browser/toolkit label for localization/ entries uses the physical omni.ja container.",
        "Logical member bytes are not disk allocation or removable bytes.",
        "Some localized resources may use legacy or generated paths outside these categories.",
        "No language-pack archive or non-default locale content inspected.",
        "No image, binary, code, or remote network execution performed."
      ]}

def self_test():
    assert group("vulpra/browser/localization/en-US/browser.ftl")=="browser_l10n"
    assert group("vulpra/localization/en-US/toolkit.ftl")=="toolkit_l10n"
    assert group("vulpra/default.locale")=="default_locale"
    assert jar_group("localization/en-US/browser.ftl","vulpra/browser/omni.ja")=="browser_l10n"
    assert jar_group("localization/en-US/toolkit.ftl","vulpra/omni.ja")=="toolkit_l10n"
    assert group("vulpra/hyphenation/hyph_en_US.dic")=="hyphenation"
    assert group("vulpra/dictionaries/en-US.dic")=="dictionaries"
    with tempfile.TemporaryDirectory(prefix="vulpra-l10n-fixture-") as tmp:
        p=Path(tmp)/"sample.tar.xz"
        b=BytesIO()
        with zipfile.ZipFile(b,"w",zipfile.ZIP_DEFLATED) as jar:
            jar.writestr("localization/en-US/toolkit/global.ftl",b"one")
            jar.writestr("browser/localization/en-US/browser/browser.ftl",b"two")
        with tarfile.open(p,"w:xz") as tar:
            import tarfile as tf
            for name,data in (
                ("vulpra/default.locale",b"en-US"),
                ("vulpra/browser/localization/en-US/extra.ftl",b"three"),
                ("vulpra/omni.ja",b.getvalue())):
                info=tf.TarInfo(name)
                info.size=len(data)
                tar.addfile(info,BytesIO(data))
        digest=sha256(p.read_bytes()).hexdigest()
        side=Path(str(p)+".sha256")
        side.write_text(digest+"  "+p.name+"\n")
        found=census(p)
        assert found["outer_tar_members"]["default_locale"]["files"]==1
        assert found["outer_tar_members"]["browser_l10n"]["files"]==1
        assert found["nested_omni_ja_members"]["browser_l10n"]["files"]==1
        assert found["nested_omni_ja_members"]["toolkit_l10n"]["files"]==1
        assert found["localized_content_present"] is True
        assert found["compiled_bytes_saved"] is None
        side.write_text("0"*64+"  "+p.name+"\n")
        try: census(p)
        except ValueError as e: assert "checksum mismatch" in str(e)
        else: raise AssertionError("Tampered archive accepted")
        side.write_text(digest+"  wrong-name.tar.xz\n")
        try: census(p)
        except ValueError as e: assert "identify verified archive" in str(e)
        else: raise AssertionError("Wrong sidecar archive name accepted")
    return 9

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("archive",nargs="?",type=Path)
    parser.add_argument("--self-test",action="store_true")
    parser.add_argument("--output")
    args=parser.parse_args()
    if args.self_test: print(f"PASS: {self_test()} categorization/fixture safety cases")
    if args.archive:
        info=census(args.archive.resolve())
        if args.output:
            path=Path(args.output)
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(json.dumps(info,indent=2)+"\n")
        print("PASS: checksum-verified browser archive localization census")
        print("Archive bytes:",info["compressed_archive_bytes"])
        print("Tar members:",info["tar_regular_members"])
        print("Locale tar categories:",{k:v["logical_bytes"] for k,v in info["outer_tar_members"].items() if k!="other"})
        print("Locale omni categories:",{k:v["logical_bytes"] for k,v in info["nested_omni_ja_members"].items() if k!="other"})
        print("Locale JAR containers:",[(j["archive_member"],j.get("entries"),{
              k:v["logical_bytes"] for k,v in j.get("locale_group_by_jar",{}).items()
              if v["logical_bytes"]}) for j in info["omni_ja"]])
        print("No compiled saving, native runtime or safe removal inferred")
    elif not args.self_test:
        parser.error("Provide archive path or --self-test")
if __name__=="__main__":
    try: main()
    except (AssertionError,OSError,ValueError,tarfile.TarError,zipfile.BadZipFile) as e:
        print("FAIL M3 archive locale census:",e,file=sys.stderr)
        raise SystemExit(1)
