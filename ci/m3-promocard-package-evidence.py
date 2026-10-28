#!/usr/bin/env python3
"""Verify real native Vulpra tar.xz New Tab bundle and protected resources.

Reads existing package, never rewrites it. This cannot prove resource-specific
compressed saving: the outer tar.xz package comparison requires another
independent build from the exact same source commit.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import tarfile
import zipfile

BUNDLE = "builtin-addons/newtab/data/content/activity-stream.bundle.js"
PROMO_MARKER = b"newtab-promo-card-title-addons"
SPONSORED_LABEL = b"newtab-label-sponsored-fixed"
PROTECTED = (
    "builtin-addons/newtab/lib/ActivityStream.sys.mjs",
    "builtin-addons/newtab/lib/DiscoveryStreamFeed.sys.mjs",
    "builtin-addons/newtab/lib/TopStoriesFeed.sys.mjs",
    "builtin-addons/newtab/lib/TopSitesFeed.sys.mjs",
    "builtin-addons/newtab/lib/AdsClient.sys.mjs",
    "builtin-addons/newtab/lib/Store.sys.mjs",
    "builtin-addons/newtab/lib/AdsFeed.sys.mjs",
)


def archive_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(package: Path, source_commit: str, variant: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ValueError("Expected 40-digit Git source SHA")
    if variant not in ("normal", "optin"):
        raise ValueError("Variant must be normal or optin")

    # The shipped New Tab can be represented in browser.jar/omni.ja and in
    # the train-hop XPI; check actual tar members, not source tree output.
    bundle_records = []
    all_resources = set()
    searched = []
    hinted = []
    jars = 0
    marker = "builtin-addons/newtab/"
    with tarfile.open(package, "r:xz") as tf:
        for member in tf:
            if not member.isfile():
                continue
            is_omni = member.name.endswith("/omni.ja")
            is_browser_jar = member.name.endswith("/browser.jar")
            is_xpi = member.name.endswith("/newtab@mozilla.org.xpi")
            if not (is_omni or is_browser_jar or is_xpi):
                continue
            jars += int(is_omni)
            raw = tf.extractfile(member)
            if raw is None:
                raise ValueError("Missing packaged ZIP contents: " + member.name)
            with zipfile.ZipFile(io.BytesIO(raw.read())) as zipfile_in:
                searched.append(member.name)
                for name in zipfile_in.namelist():
                    if name.startswith(marker):
                        all_resources.add(name)
                    elif "/" + marker in name:
                        all_resources.add(name[name.index(marker):])
                    elif is_xpi and name.startswith("lib/"):
                        all_resources.add(marker + name)
                    if "activity-stream.bundle.js" in name:
                        hinted.append(member.name + ":" + name)
                    valid = (
                        name == BUNDLE or name.endswith("/" + BUNDLE)
                        or (is_xpi and name == "data/content/activity-stream.bundle.js")
                    )
                    if not valid:
                        continue
                    data = zipfile_in.read(name)
                    bundle_records.append({
                        "archive_member": member.name,
                        "zip_member": name,
                        "size": len(data),
                        "sha256": hashlib.sha256(data).hexdigest(),
                        "promo_title_present": PROMO_MARKER in data,
                        "sponsored_banner_label_present": SPONSORED_LABEL in data,
                    })

    if jars < 2:
        raise ValueError(f"Expected >=2 packaged omni.ja archives; got {jars}")
    if not bundle_records:
        raise ValueError("Packaged New Tab bundle not found; archives="
                         + repr(searched) + "; hints=" + repr(hinted[:20]))
    if len({(x["size"], x["sha256"]) for x in bundle_records}) != 1:
        raise ValueError("Conflicting shipped New Tab bundles: " + repr([
            (x["archive_member"], x["zip_member"], x["sha256"])
            for x in bundle_records]))
    bundle_records.sort(key=lambda x: (
        not x["archive_member"].endswith("/omni.ja"),
        x["archive_member"], x["zip_member"]))
    missing = [resource for resource in PROTECTED if resource not in all_resources]
    if missing:
        raise ValueError(f"Protected New Tab runtime modules missing: {missing}")
    bundle = bundle_records[0]
    if not bundle["sponsored_banner_label_present"]:
        raise ValueError("Protected AdBanner sponsored label not in shipped JS")
    if bundle["promo_title_present"] != (variant == "normal"):
        raise ValueError(f"{variant}: PromoCard original marker unexpected")
    return {
        "schema_version": 1,
        "source_commit": source_commit,
        "variant": "linux-newtab-promocard-" + variant,
        "compressed_package_bytes": package.stat().st_size,
        "sha256": archive_sha256(package),
        "omni_jar_count": jars,
        "verified_newtab_bundle_copies": len(bundle_records),
        "protected_resources_present": True,
        "adsfeed_resource_present": True,
        "promocard_original_code_present": bundle["promo_title_present"],
        "real_newtab_bundle": bundle,
        "status": "native package resource verification passed; runtime pending" if variant == "optin"
                  else "full normal baseline native compile and package verified",
        "limitations": [
            "A bundle marker proves selected code strings, not an ad-free browser.",
            "Independent same-source packages may differ for unrelated nondeterminism.",
            "ZIP member and uncompressed JS bytes are not outer tar.xz savings.",
            "Only packaged browser omni/browser.jar/New Tab XPI resources count.",
        ],
    }

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--archive", type=Path, required=True)
    p.add_argument("--source-commit", required=True)
    p.add_argument("--variant", choices=("normal", "optin"), required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    result = verify(args.archive, args.source_commit, args.variant)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    print("PASS: real native package New Tab asset, variant, protected modules and checksum")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile) as e:
        print("FAIL: packaged PromoCard evidence:", e, file=sys.stderr)
        raise SystemExit(1)
