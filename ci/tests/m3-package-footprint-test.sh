#!/usr/bin/env bash
set -Eeuo pipefail
PROBE="${1:?Pass absolute package-footprint Python script}"
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
repo="$T/repo"
p="$repo/.git/vulpra-native-build/packages"
mkdir -p "$p"
python3 - "$T" "$p" <<'PY'
import io, os, pathlib, sys, tarfile, zipfile, hashlib
root, pkgdir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
archive = pkgdir / "vulpra-local-fixture.tar.xz"
packed = io.BytesIO()
with zipfile.ZipFile(packed, "w", zipfile.ZIP_DEFLATED) as jar:
    jar.writestr("modules/GenAI.sys.mjs", "abc")
    jar.writestr("modules/services-sync/Sync.sys.mjs", "012345")
    jar.writestr("modules/Telemetry.sys.mjs", "telemetry")
    jar.writestr("modules/SomeOther.sys.mjs", "otherwise")
    jar.writestr("builtin-addons/newtab/lib/AdsFeed.sys.mjs", "sponsored module payload")
    jar.writestr("builtin-addons/newtab/lib/ActivityStream.sys.mjs", "retained core")

with tarfile.open(archive, "w:xz") as out:
    for name, data in (
        ("vulpra/vulpra", b"test executable"),
        ("vulpra/libxul.so", b"native library"),
        ("vulpra/browser/omni.ja", packed.getvalue()),
    ):
        info = tarfile.TarInfo(name)
        info.size = len(data)
        out.addfile(info, io.BytesIO(data))
    info = tarfile.TarInfo("vulpra/current")
    info.type = tarfile.SYMTYPE
    info.linkname = "vulpra"
    out.addfile(info)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
pathlib.Path(str(archive) + ".sha256").write_text(checksum + "  " + archive.name + "\n")
(root / "expected.txt").write_text(str(archive.stat().st_size))
PY
python3 "$PROBE" "$repo" > "$T/success.log" 2>&1 || { cat "$T/success.log"; exit 1; }
grep -Fq 'PASS: Verified existing Vulpra tarball' "$T/success.log"
python3 - "$repo/.git/vulpra-debloat/m3-package-footprint.json" "$T/expected.txt" <<'PY'
import json, pathlib, sys
d=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d["compressed_archive_bytes"] == int(pathlib.Path(sys.argv[2]).read_text())
assert d["regular_files"] == 3
assert d["symlink_or_hardlink_members"] == 1
assert d["archive_groups"]["browser"]["files"] == 1
assert d["omni_resources"][0]["resource_index"]["status"] == "readable"
a=d["omni_resources"][0]["resource_index"]
assert a["hints"]["genai"]["files"] == 1
assert a["hints"]["services-sync"]["files"] == 1
assert a["hints"]["telemetry"]["files"] == 1
assert a["hints"]["devtools"]["files"] == 0
newtab = a["newtab_lib_resources"]
assert newtab["count"] == 2
by_path = {x["path"]: x for x in newtab["entries"]}
ads = by_path["builtin-addons/newtab/lib/AdsFeed.sys.mjs"]
retained = by_path["builtin-addons/newtab/lib/ActivityStream.sys.mjs"]
assert ads["logical_bytes"] == len("sponsored module payload")
assert retained["logical_bytes"] == len("retained core")
assert ads["zip_compressed_entry_bytes"] > 0
assert retained["zip_compressed_entry_bytes"] > 0
assert ads["zip_crc32"] and len(ads["zip_crc32"]) == 8
assert newtab["logical_bytes"] == ads["logical_bytes"] + retained["logical_bytes"]
assert newtab["zip_compressed_entry_bytes"] == (
    ads["zip_compressed_entry_bytes"] + retained["zip_compressed_entry_bytes"]
)
assert "not outer tar.xz savings" in newtab["limits"]

assert sum(x["logical_bytes"] for x in d["archive_groups"].values()) == d["sum_regular_file_logical_bytes"]
assert len(d["limits"]) >= 3
PY
test -s "$repo/.git/vulpra-debloat/m3-package-footprint.md"
echo 'PASS: exact synthetic archive and omni.ja sizes and hints'
# Side-by-side forensic diff uses preexisting SHA-attested JSON reports. This
# synthetic lean variant omits only AdsFeed; the comparator never opens or
# modifies a package and never claims XZ attribution from ZIP entry bytes.
python3 - "$repo/.git/vulpra-debloat/m3-package-footprint.json" "$T" <<'PY'
import json, pathlib, sys
src=pathlib.Path(sys.argv[1])
out=pathlib.Path(sys.argv[2])
full=json.loads(src.read_text())
lean=json.loads(src.read_text())
idx=lean["omni_resources"][0]["resource_index"]["newtab_lib_resources"]
ads=[x for x in idx["entries"] if x["path"].endswith("/AdsFeed.sys.mjs")]
assert len(ads)==1
idx["entries"]=[x for x in idx["entries"] if x not in ads]
idx["count"]-=1
idx["logical_bytes"]-=ads[0]["logical_bytes"]
idx["zip_compressed_entry_bytes"]-=ads[0]["zip_compressed_entry_bytes"]
lean["compressed_archive_bytes"]-=123
lean["sha256"]="a"*64
(out/"full.json").write_text(json.dumps(full))
(out/"lean.json").write_text(json.dumps(lean))
(out/"ads-zip-compressed.txt").write_text(str(ads[0]["zip_compressed_entry_bytes"]))
PY
python3 "$(dirname "$PROBE")/m3-compare-package-footprints.py" \
  "$T/full.json" "$T/lean.json" "$T/compare.json"
python3 - "$T/compare.json" "$T/ads-zip-compressed.txt" <<'PY'
import json, pathlib, sys
d=json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d["adsfeed_resource_removed"]
assert len(d["removed"])==1 and d["removed"][0]["path"].endswith("AdsFeed.sys.mjs")
assert d["added"]==[] and d["changed"]==[]
assert d["unchanged_count"]==1
assert d["observed_outer_archive_byte_difference"]==123
assert d["removed_zip_entry_compressed_bytes"]==int(pathlib.Path(sys.argv[2]).read_text())
assert d["removed_zip_entry_compressed_bytes"]!=123
assert len(d["limitations"])>=5
PY
python3 - "$T/lean.json" "$T/duplicate.json" <<'PY'
import json, pathlib, sys
src=json.loads(pathlib.Path(sys.argv[1]).read_text())
idx=src["omni_resources"][0]["resource_index"]["newtab_lib_resources"]
idx["entries"].append(dict(idx["entries"][0]))
idx["count"]+=1
idx["logical_bytes"]+=idx["entries"][0]["logical_bytes"]
idx["zip_compressed_entry_bytes"]+=idx["entries"][0]["zip_compressed_entry_bytes"]
pathlib.Path(sys.argv[2]).write_text(json.dumps(src))
PY
if python3 "$(dirname "$PROBE")/m3-compare-package-footprints.py" \
  "$T/full.json" "$T/duplicate.json" "$T/badcompare.json" 2>"$T/duplicate-error"; then
  echo "FAIL: duplicate ZIP entry incorrectly accepted" >&2
  exit 1
fi
grep -Fq 'Resource duplicated' "$T/duplicate-error"
echo 'PASS: outer tar.xz vs ZIP resource diff isolated; duplicate and invalid reports rejected'
package="$p/vulpra-local-fixture.tar.xz"
printf '%064d  test.tar.xz\n' 0 > "$package.sha256"
set +e
python3 "$PROBE" "$repo" > "$T/bad.log" 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || { cat "$T/bad.log"; echo 'FAIL: accepted bad checksum'; exit 2; }
grep -Fq 'SHA256 mismatch' "$T/bad.log"
echo 'PASS: corrupt checksum rejects archive measurement'
rm "$package.sha256"
set +e
python3 "$PROBE" "$repo" > "$T/missing.log" 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || { cat "$T/missing.log"; echo 'FAIL: accepted missing checksum'; exit 3; }
grep -Fq 'Missing package SHA256 sidecar' "$T/missing.log"
echo 'PASS: missing checksum rejects archive measurement'
echo 'PASS: M3 package census read-only regressions'
