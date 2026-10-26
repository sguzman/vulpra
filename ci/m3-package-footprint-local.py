#!/usr/bin/env python3
"""Read-only census of a checksum-verified packaged Vulpra browser.
Never extracts, executes or changes the prebuilt browser or source tree.
"""
from collections import defaultdict
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import re
import sys
import tarfile
import zipfile

HINTS = ("genai", "services-sync", "normandy", "devtools", "telemetry",
         "fxaccounts", "newtab", "asrouter", "aboutwelcome")
MAX_JAR_BUFFER = 192 * 1024 * 1024

def sha256_file(path):
    hash_ = sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hash_.update(block)
    return hash_.hexdigest()

def archive_path(repo):
    directory = repo / ".git/vulpra-native-build/packages"
    matches = sorted(directory.glob("vulpra-local-*.tar.xz"),
                     key=lambda p: p.stat().st_mtime, reverse=True)
    if not matches:
        raise RuntimeError("No existing package under " + str(directory))
    return matches[0]

def verify(archive):
    sidecar = Path(str(archive) + ".sha256")
    if not sidecar.is_file():
        raise RuntimeError("Missing package SHA256 sidecar: " + str(sidecar))
    tokens = sidecar.read_text().split()
    if not tokens or not re.fullmatch("[0-9A-Fa-f]{64}", tokens[0]):
        raise RuntimeError("Malformed SHA256 sidecar")
    actual = sha256_file(archive)
    if actual.lower() != tokens[0].lower():
        raise RuntimeError("Package SHA256 mismatch; refusing measurements")
    return actual

def metric():
    return {"files": 0, "logical_bytes": 0}

def add(value, size):
    value["files"] += 1
    value["logical_bytes"] += size

def category(name):
    parts = name.lstrip("./").split("/")
    if parts[0] in ("firefox", "vulpra"):
        parts = parts[1:]
    return parts[0] if parts and parts[0] else "[root]"

def inspect_omni(data):
    output = {"status": "unreadable", "hints": {}, "note":
              "Path substring clues only; not removable savings."}
    try:
        with zipfile.ZipFile(BytesIO(data)) as jar:
            entries = [e for e in jar.infolist() if not e.is_dir()]
    except (zipfile.BadZipFile, OSError, ValueError, RuntimeError) as error:
        output["error"] = str(error)
        return output
    hints = {h: metric() for h in HINTS}
    categories = defaultdict(metric)
    for member in entries:
        add(categories[member.filename.strip("/").split("/")[0] or "[root]"], member.file_size)
        for hint in HINTS:
            if hint in member.filename.lower():
                add(hints[hint], member.file_size)
    output.update({
        "status": "readable",
        "entries": len(entries),
        "logical_bytes": sum(e.file_size for e in entries),
        "zip_compressed_entry_bytes": sum(e.compress_size for e in entries),
        "hints": hints,
        "first_path_components": dict(sorted(categories.items(),
                                      key=lambda t: -t[1]["logical_bytes"])[:25]),
    })
    return output

def census(archive):
    digest = verify(archive)
    groups = defaultdict(metric)
    largest = []
    jar_records = []
    regular = logical = links = 0
    with tarfile.open(archive, "r:xz") as tf:
        for member in tf:
            if member.issym() or member.islnk():
                links += 1
            if not member.isfile():
                continue
            regular += 1
            logical += member.size
            add(groups[category(member.name)], member.size)
            largest.append((member.size, member.name))
            if member.name.endswith("/omni.ja") or member.name == "omni.ja":
                entry = {"archive_path": member.name, "tar_logical_bytes": member.size}
                if member.size > MAX_JAR_BUFFER:
                    entry["resource_index"] = {"status": "skipped_memory_cap"}
                else:
                    source = tf.extractfile(member)
                    entry["resource_index"] = inspect_omni(source.read()) if source else {"status": "unavailable"}
                jar_records.append(entry)
    if regular == 0:
        raise RuntimeError("No regular files found inside tarball")
    return {
        "schema_version": 1,
        "test": "read_only_real_archive_resource_census",
        "package": archive.name, "sha256": digest,
        "compressed_archive_bytes": archive.stat().st_size,
        "regular_files": regular, "symlink_or_hardlink_members": links,
        "sum_regular_file_logical_bytes": logical,
        "archive_groups": dict(sorted(groups.items(), key=lambda t: -t[1]["logical_bytes"])[:30]),
        "largest_regular_files": [{"path": n, "logical_bytes": s}
            for s, n in sorted(largest, key=lambda t: (-t[0], t[1]))[:25]],
        "omni_resources": jar_records,
        "limits": [
            "No comparison build performed; existing package may predate source Git HEAD",
            "Logical bytes and ZIP hint matches do not equal disk blocks, RAM or removable package bytes",
            "Resource substring groups can overlap or omit indirectly named features",
            "No proof of dependency reachability or safe removal",
        ],
    }

def markdown(info):
    result = ["# Vulpra native package footprint", "",
              "Archive: " + info["package"], "SHA256: " + info["sha256"],
              "Compressed archive bytes: " + format(info["compressed_archive_bytes"], ","),
              "Sum of regular member logical bytes: " + format(info["sum_regular_file_logical_bytes"], ","),
              "No rebuild or source changes.", "",
              "## Archive categories", "",
              "| Category | Members | Logical bytes |", "| --- | ---: | ---: |"]
    for key, m in info["archive_groups"].items():
        result.append("| " + key + " | " + str(m["files"]) + " | " + str(m["logical_bytes"]) + " |")
    result += ["", "## Largest regular members", "",
               "| Path | Logical bytes |", "| --- | ---: |"]
    for x in info["largest_regular_files"][:15]:
        result.append("| " + x["path"] + " | " + str(x["logical_bytes"]) + " |")
    result += ["", "## Bundled resource-name hints", ""]
    for jar in info["omni_resources"]:
        result.append("Jar " + jar["archive_path"] + ": " + jar["resource_index"]["status"])
        idx = jar["resource_index"]
        if idx["status"] == "readable":
            result.append("Entries: " + str(idx["entries"]) + "; logical bytes: " + str(idx["logical_bytes"]))
            for name, m in idx["hints"].items():
                result.append("- " + name + ": " + str(m["files"]) + " entries, " +
                              str(m["logical_bytes"]) + " logical bytes")
    result += ["", "These path names are heuristic clues, never proof of removable code.",
               "Before/after package size and M2 regression evidence remain mandatory.", ""]
    return "\n".join(result)

def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Code/Apps/vulpra").resolve()
    archive = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else archive_path(repo)
    result = census(archive)
    dest = repo / ".git/vulpra-debloat"
    dest.mkdir(parents=True, exist_ok=True)
    jf = dest / "m3-package-footprint.json"
    mf = dest / "m3-package-footprint.md"
    jf.write_text(json.dumps(result, indent=2) + "\n")
    mf.write_text(markdown(result))
    print("PASS: Verified existing Vulpra tarball and measured regular files")
    print("Compressed archive bytes: " + str(result["compressed_archive_bytes"]))
    print("Logical regular member bytes: " + str(result["sum_regular_file_logical_bytes"]))
    print("Omni resource archives found: " + str(len(result["omni_resources"])))
    print("JSON: " + str(jf))
    print("Markdown: " + str(mf))
    print("No source, build output, existing package or profile changes.")

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, tarfile.TarError, EOFError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
