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
    bundle_records = []
    all_resources = set()
    jars = 0
    with tarfile.open(package, "r:xz") as tf:
        for member in tf:
            if not member.isfile() or not member.name.endswith("/omni.ja"):
                continue
            jars += 1
            raw = tf.extractfile(member)
            if raw is None:
                raise ValueError("Missing omni.ja file contents")
            with zipfile.ZipFile(io.BytesIO(raw.read())) as z:
                all_resources.update(z.namelist())
                if BUNDLE in z.namelist():
                    data = z.read(BUNDLE)
                    bundle_records.append({
                        "archive_member": member.name,
                        "size": len(data),
                        "sha256": hashlib.sha256(data).hexdigest(),
                        "promo_title_present": PROMO_MARKER in data,
                        "sponsored_banner_label_present": SPONSORED_LABEL in data,
                    })
    if jars < 2 or len(bundle_records) != 1:
        raise ValueError(f"Expected >=2 omni.ja and 1 New Tab bundle; got {jars}, {len(bundle_records)}")
    missing = [resource for resource in PROTECTED if resource not in all_resources]
    if missing:
        raise ValueError(f"Protected New Tab runtime modules missing: {missing}")
    bundle = bundle_records[0]
    if not bundle["sponsored_banner_label_present"]:
        raise ValueError("Protected AdBanner sponsored label not in generated JS")
    if bundle["promo_title_present"] != (variant == "normal"):
        raise ValueError(f"{variant}: PromoCard module marker presence unexpected")
    result = {
        "schema_version": 1,
        "source_commit": source_commit,
        "variant": "linux-newtab-promocard-" + variant,
        "compressed_package_bytes": package.stat().st_size,
        "sha256": archive_sha256(package),
        "omni_jar_count": jars,
        "protected_resources_present": True,
        "adsfeed_resource_present": True,
        "promocard_original_code_present": bundle["promo_title_present"],
        "real_newtab_bundle": bundle,
        "status": "native package resource verification passed; runtime pending" if variant == "optin"
                  else "full normal baseline native compile and package verified",
        "limitations": [
            "A bundle marker proves inclusion/exclusion of selected code strings, not general absence of all promotions.",
            "A compressed tar.xz delta must be computed separately between same-source builds.",
            "A physical ZIP member's size is not its marginal outer XZ size.",
        ],
    }
    return result


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
