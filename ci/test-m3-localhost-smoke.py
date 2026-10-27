#!/usr/bin/env python3
"""Offline fixture for the M3 native-package localhost acceptance harness."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

MOCK = r'''#!/usr/bin/env python3
import pathlib, sys, os, struct, zlib
from urllib.parse import urljoin
from urllib.request import urlopen

# Simulate a headless screenshot client painting the requested page.
args = sys.argv
screenshot = pathlib.Path(args[args.index("--screenshot") + 1])
url = args[-1]
body = urlopen(url, timeout=5).read().decode()
assert "JavaScript navigation succeeded" in body, body
# Real Firefox may fetch a favicon outside the scripted redirect chain.
try:
    urlopen(urljoin(url, "/favicon.ico"), timeout=5).read()
except Exception:
    pass
def png_chunk(kind, payload):
    crc = zlib.crc32(kind + payload) & 0xffffffff
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)
header = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
png_bytes = (b"\x89PNG\r\n\x1a\n" +
             png_chunk(b"IHDR", header) +
             png_chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\xff")) +
             png_chunk(b"IEND", b""))
if os.environ.get("VULPRA_FIXTURE_INVALID_PNG") == "1":
    png_bytes = b"\x89PNG\r\n\x1a\nmock png body"
screenshot.write_bytes(png_bytes)
'''

def main():
    root = Path(__file__).resolve().parent.parent
    script = root / "ci" / "smoke-m3-localhost-package.py"
    assert script.is_file()
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-smoke-fixture-") as td:
        path = Path(td)
        repo = path / "repo"
        packages = repo / ".git" / "vulpra-native-build" / "packages"
        packages.mkdir(parents=True)
        browser = path / "browser" / "firefox"
        browser.mkdir(parents=True)
        (browser / "application.ini").write_text("[App]\nName=Vulpra\n")
        launcher = browser / "vulpra"
        launcher.write_text(MOCK)
        launcher.chmod(0o755)
        # The legacy package format has a separate native Firefox binary.
        # The mock vulpra file represents its isolated launcher.
        native = browser / "firefox"
        native.write_text(MOCK)
        native.chmod(0o755)
        archive = packages / "vulpra-local-fixture.tar.xz"
        with tarfile.open(archive, "w:xz") as tf:
            tf.add(browser, arcname="firefox")
        checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
        sidecar = Path(str(archive) + ".sha256")
        sidecar.write_text(f"{checksum}  {archive.name}\n")

        passing = subprocess.run([sys.executable, str(script), str(repo)],
                                 capture_output=True, text=True, timeout=35)
        if passing.returncode:
            raise RuntimeError("Expected test PASS:\n" + passing.stdout + passing.stderr)
        report = repo / ".git" / "vulpra-native-build" / "m3-localhost-acceptance.json"
        result = json.loads(report.read_text())
        assert result["result"] == "pass"
        assert result["local_request_sequence"] == ["/page"]
        assert result["incidental_favicon_requests"] == 1
        assert result["observed_http_requests"] == ["/page", "/favicon.ico"]
        assert result["screenshot_png_complete_and_crc_valid"]
        assert result["screenshot_dimensions"] == [1, 1]
        assert result["sha256"] == checksum
        assert result["profile_isolation"]
        bad_png = subprocess.run(
            [sys.executable, str(script), str(repo)],
            capture_output=True, text=True, timeout=35,
            env={**os.environ, "VULPRA_FIXTURE_INVALID_PNG": "1"})
        assert bad_png.returncode != 0, "Malformed PNG accepted"
        assert "Invalid screenshot PNG" in bad_png.stderr, bad_png.stderr

        sidecar.write_text("0" * 64 + "  " + archive.name + "\n")
        rejected = subprocess.run([sys.executable, str(script), str(repo)],
                                  capture_output=True, text=True, timeout=20)
        assert rejected.returncode != 0, "Checksum corruption must refuse browser launch"
        assert "Checksum mismatch" in rejected.stderr, rejected.stderr

    print("PASS: accepted checksum-verified fixture with local HTTP screenshot")
    print("PASS: corrupted checksum refused before executing packaged binary")
    print("PASS: test fixture did not create or modify user browser files")

if __name__ == "__main__":
    main()
