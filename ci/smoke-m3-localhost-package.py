#!/usr/bin/env python3
"""Verify JS navigation and profile isolation in an already staged Vulpra package.

No network beyond localhost. The script does not build, install, update or
change any browser; it verifies the staged archive's checksum and uses a
temporary extraction/home/profile for the full test.
"""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import struct
import zlib

class Page(BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.paths.append(self.path)
        if self.path == "/start":
            data = (b'<!doctype html><meta charset="utf-8"><title>M3 startup</title>'
                    b'<script>location.assign("/js-run");</script>')
            self.send_response(200)
        elif self.path == "/js-run":
            data = b""
            self.send_response(302)
            self.send_header("Location", "/page")
        elif self.path == "/page":
            data = (b'<!doctype html><meta charset="utf-8"><title>M3 destination</title>'
                    b'<h1 id="pass">JavaScript navigation succeeded</h1>')
            self.send_response(200)
        else:
            data = b"unexpected request"
            self.send_response(404)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if data:
            self.wfile.write(data)

    def log_message(self, *_args):
        return


def source_archive(repo):
    dest = repo / ".git" / "vulpra-native-build" / "packages"
    matches = sorted(dest.glob("vulpra-local-*.tar.xz"),
                     key=lambda p: p.stat().st_mtime, reverse=True)
    if not matches:
        raise RuntimeError("No staged candidate package in " + str(dest))
    archive = matches[0]
    sidecar = Path(str(archive) + ".sha256")
    if not sidecar.is_file():
        raise RuntimeError("Missing staged package checksum")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    parts = sidecar.read_text().split()
    if not parts or digest.lower() != parts[0].lower():
        raise RuntimeError("Checksum mismatch; refusing package launch")
    return archive, digest


def verify_png_screenshot(path):
    """Validate a complete PNG container, not just its eight magic bytes.

    This verifies screenshot framing and CRCs, not the visible page content.
    """
    if not path.is_file():
        raise RuntimeError("Invalid screenshot PNG: file missing")
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError("Invalid screenshot PNG: signature missing")
    cursor = 8
    dimensions = None
    has_image_data = False
    finished = False
    while cursor + 12 <= len(data):
        length = struct.unpack_from(">I", data, cursor)[0]
        kind = data[cursor + 4:cursor + 8]
        end = cursor + 12 + length
        if end > len(data):
            raise RuntimeError("Invalid screenshot PNG: truncated chunk")
        content = data[cursor + 8:cursor + 8 + length]
        crc = struct.unpack_from(">I", data, cursor + 8 + length)[0]
        if zlib.crc32(kind + content) & 0xffffffff != crc:
            raise RuntimeError("Invalid screenshot PNG: chunk CRC mismatch")
        if dimensions is None:
            if kind != b"IHDR" or length != 13:
                raise RuntimeError("Invalid screenshot PNG: missing IHDR")
            width, height = struct.unpack_from(">II", content)
            if not width or not height:
                raise RuntimeError("Invalid screenshot PNG: zero dimensions")
            dimensions = [width, height]
        if kind == b"IDAT":
            has_image_data = True
        if kind == b"IEND":
            if length or not has_image_data or end != len(data):
                raise RuntimeError("Invalid screenshot PNG: incomplete or trailing image data")
            finished = True
            break
        cursor = end
    if not finished:
        raise RuntimeError("Invalid screenshot PNG: missing complete IEND")
    return dimensions


def main():
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    archive, digest = source_archive(repo)
    with tempfile.TemporaryDirectory(prefix="vulpra-m3-js-") as tmp:
        temp = Path(tmp)
        home = temp / "home"
        app = temp / "package"
        app.mkdir()
        firefox_profile = home / ".mozilla" / "firefox" / "profiles.ini"
        firefox_profile.parent.mkdir(parents=True)
        sentinel = b"existing Firefox profile is not a Vulpra test fixture\n"
        firefox_profile.write_bytes(sentinel)
        with tarfile.open(archive, "r:xz") as tf:
            tf.extractall(app, filter="data")
        inis = list(app.rglob("application.ini"))
        if len(inis) != 1:
            raise RuntimeError("Expected one application.ini")
        appdir = inis[0].parent
        if "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Unexpected browser identity")
        binary = appdir / "vulpra"
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise RuntimeError("Isolated packaged launcher absent")
        server = ThreadingHTTPServer(("127.0.0.1", 0), Page)
        server.paths = []
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        png = temp / "screenshot.png"
        env = os.environ.copy()
        env.update(HOME=str(home), XDG_DATA_HOME=str(home / ".local" / "share"),
                   MOZ_HEADLESS="1", NO_PROXY="127.0.0.1,localhost",
                   no_proxy="127.0.0.1,localhost")
        for name in ("DISPLAY", "WAYLAND_DISPLAY"):
            env.pop(name, None)
        start = time.monotonic()
        try:
            proc = subprocess.run(
                ["timeout", "120", str(binary), "--headless", "--screenshot",
                 str(png), f"http://127.0.0.1:{server.server_port}/start"],
                capture_output=True, text=True, env=env, timeout=125,
            )
        finally:
            server.shutdown()
            server.server_close()
        elapsed = round(time.monotonic() - start, 3)
        if proc.returncode != 0:
            raise RuntimeError("Browser exited " + str(proc.returncode) + ": " + proc.stderr[-1200:])
        image_dimensions = verify_png_screenshot(png)
        # Firefox may independently request /favicon.ico while capturing the
        # screenshot. It is not evidence of JavaScript navigation and must
        # neither count as an extra functional step nor conceal unknown calls.
        expected = ["/start", "/js-run", "/page"]
        extras = [path for path in server.paths if path not in (*expected, "/favicon.ico")]
        navigated = [path for path in server.paths if path != "/favicon.ico"]
        if extras or navigated != expected:
            raise RuntimeError("Unexpected HTTP JS/navigation sequence " + repr(server.paths))
        if firefox_profile.read_bytes() != sentinel:
            raise RuntimeError("Firefox profile sentinel changed")
        report = {
            "schema_version": 1, "test": "real_packaged_js_redirect_localhost",
            "result": "pass", "package": archive.name, "sha256": digest,
            "local_request_sequence": navigated, "observed_http_requests": server.paths,
            "incidental_favicon_requests": server.paths.count("/favicon.ico"),
            "elapsed_seconds": elapsed,
            "profile_isolation": True, "screenshot_png_signature": True,
            "screenshot_png_complete_and_crc_valid": True,
            "screenshot_dimensions": image_dimensions,
            "limits": ["Does not prove full browser UI correctness",
                       "Does not prove Nimbus runtime integration",
                       "Not a same-toolchain package-size comparison"],
        }
    output = repo / ".git" / "vulpra-native-build" / "m3-localhost-acceptance.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print("PASS: real packaged JS navigation /start -> /js-run -> /page")
    print("PASS: signed-off archive checksum, valid PNG and Firefox profile isolation")
    print("Report: " + str(output))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired, tarfile.TarError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
