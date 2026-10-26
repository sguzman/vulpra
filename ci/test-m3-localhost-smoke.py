#!/usr/bin/env python3
"""Offline fixture for the M3 native-package localhost acceptance harness."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

MOCK = r'''#!/usr/bin/env python3
import pathlib, sys
from urllib.parse import urljoin
from urllib.request import urlopen

# Simulate a headless screenshot client that runs the known fixture's redirect.
args = sys.argv
screenshot = pathlib.Path(args[args.index("--screenshot") + 1])
url = args[-1]
body = urlopen(url, timeout=5).read().decode()
assert 'location.assign("/js-run")' in body, body
final = urlopen(urljoin(url, "/js-run"), timeout=5).read().decode()
assert "JavaScript navigation succeeded" in final, final
screenshot.write_bytes(b"\x89PNG\r\n\x1a\nmock png body")
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
        assert result["local_request_sequence"] == ["/start", "/js-run", "/page"]
        assert result["sha256"] == checksum
        assert result["profile_isolation"]
        sidecar.write_text("0" * 64 + "  " + archive.name + "\n")
        rejected = subprocess.run([sys.executable, str(script), str(repo)],
                                  capture_output=True, text=True, timeout=20)
        assert rejected.returncode != 0, "Checksum corruption must refuse browser launch"
        assert "Checksum mismatch" in rejected.stderr, rejected.stderr

    print("PASS: accepted checksum-verified fixture with real local JS redirect sequence")
    print("PASS: corrupted checksum refused before executing packaged binary")
    print("PASS: test fixture did not create or modify user browser files")

if __name__ == "__main__":
    main()
