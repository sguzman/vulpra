#!/usr/bin/env python3
"""No-rebuild native Vulpra package acceptance and metrics on Linux.

Checks a real local HTTP navigation triggered by JavaScript, a subsequent
HTTP redirect, screenshot, profile protection and reproducible package
measurements. Synchronous XHR was removed: it was unreliable when Firefox
closed shortly after a headless screenshot and misclassified real navigation. No Git changes,
Firefox installation changes or external web requests are required.
"""
from __future__ import annotations

import hashlib
import http.server
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import urlsplit

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def verify_package(archive: Path) -> str:
    sidecar = Path(str(archive) + ".sha256")
    if not sidecar.is_file():
        raise RuntimeError(f"Package checksum sidecar missing: {sidecar}")
    expected = sidecar.read_text().split()[0].lower()
    if not re.fullmatch(r"[a-f0-9]{64}", expected):
        raise RuntimeError("Malformed package SHA-256 sidecar")
    digest = hashlib.sha256()
    with archive.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    actual = digest.hexdigest()
    if actual != expected:
        raise RuntimeError("Package SHA-256 mismatch")
    return actual


def source_revision(repo: Path) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        text=True, capture_output=True, check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def build_duration(logdir: Path) -> int | None:
    # Only count a *successful* mach invocation. Earlier failed incremental
    # work is preserved but is not the duration of the successful invocation.
    for path in sorted(logdir.glob("build-*.log"), key=lambda p: p.stat().st_mtime, reverse=True):
        data = path.read_text(errors="replace")[-8192:]
        match = re.search(r"Vulpra build exit code: 0 \(elapsed (\d+)s\)", data)
        if match:
            return int(match.group(1))
    return None


def sample_parent_rss(pid: int) -> int | None:
    """Best-effort single-process RSS sample; not total Firefox tree memory."""
    try:
        data = Path(f"/proc/{pid}/status").read_text()
    except (FileNotFoundError, PermissionError, ProcessLookupError):
        return None
    match = re.search(r"^VmRSS:\s+(\d+)\s+kB", data, re.MULTILINE)
    return int(match.group(1)) * 1024 if match else None


def serve_browser_test() -> tuple[http.server.ThreadingHTTPServer, list[str], threading.Lock]:
    requests_seen: list[str] = []
    lock = threading.Lock()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            path = urlsplit(self.path).path
            if path == "/start":
                body = (b'<!doctype html><meta charset="utf-8"><title>Vulpra start</title>'
                        b'<script>window.location.replace("/js-run")</script>')
            elif path == "/page":
                body = (b'<!doctype html><meta charset="utf-8"><title>Vulpra runtime</title>'
                        b'<style>body{background:#237c39;color:#fff;font-size:48px}</style>'
                        b'<h1 id="state">Navigation reached page</h1>'
                        b'<script>document.getElementById("state").textContent="Vulpra JS executed";</script>')
            elif path == "/js-run":
                # This route can only be reached after the JS redirect on /start.
                # Redirect server-side to make /page depend on a completed
                # JavaScript-triggered navigation, without a timing-sensitive XHR.
                with lock:
                    requests_seen.append(path)
                self.send_response(302)
                self.send_header("Location", "/page")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            elif path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
                return
            else:
                self.send_response(404)
                self.end_headers()
                return
            with lock:
                requests_seen.append(path)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt: str, *args: object) -> None:
            return

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    return server, requests_seen, lock


def main() -> int:
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Code/Apps/vulpra").resolve()
    logdir = repo / ".git/vulpra-native-build"
    archives = sorted(
        (logdir / "packages").glob("vulpra-local-*.tar.xz"),
        key=lambda p: p.stat().st_mtime, reverse=True,
    )
    if not archives:
        raise RuntimeError(f"No packaged Vulpra archive in {logdir / 'packages'}")
    archive = archives[0]
    digest = verify_package(archive)
    print(f"PASS: Package SHA-256 {digest}")
    logdir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    result_path = logdir / f"acceptance-{stamp}.json"
    browser_log_path = logdir / f"acceptance-browser-{stamp}.log"
    screenshot_path = logdir / f"acceptance-{stamp}.png"
    with tempfile.TemporaryDirectory(prefix="vulpra-accept-") as temp:
        work = Path(temp)
        extracted = work / "package"
        extracted.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(extracted)], check=True)
        ini_files = list(extracted.rglob("application.ini"))
        if len(ini_files) != 1:
            raise RuntimeError(f"Expected one application.ini in archive; got {len(ini_files)}")
        appdir = ini_files[0].parent
        if "Name=Vulpra" not in ini_files[0].read_text().splitlines():
            raise RuntimeError("Package does not identify as Vulpra")
        launcher = appdir / "vulpra-launch"
        browser = next((appdir / n for n in ("vulpra", "firefox") if os.access(appdir / n, os.X_OK)), None)
        if not launcher.is_file() or not os.access(launcher, os.X_OK) or browser is None:
            raise RuntimeError("Expected native browser executable plus isolated vulpra-launch wrapper")
        home = work / "home"
        home.mkdir()
        existing = home / ".mozilla/firefox/profiles.ini"
        existing.parent.mkdir(parents=True)
        original_profile_bytes = b"[Profile0]\nName=existing-firefox\nPath=existing-profile\n"
        existing.write_bytes(original_profile_bytes)
        data_home = home / ".local/share"
        env = dict(os.environ)
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(data_home),
                    "MOZ_HEADLESS": "1", "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)

        # Refuse a caller-supplied profile before starting the browser.
        denied = subprocess.run(
            [str(launcher), "--profile", str(work / "forbidden")],
            env=env, text=True, capture_output=True, timeout=10, check=False,
        )
        if denied.returncode == 0:
            raise RuntimeError("Security regression: profile selection escape was accepted")
        print("PASS: External profile-selection override refused")

        server, seen, lock = serve_browser_test()
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        start_url = f"http://127.0.0.1:{server.server_port}/start"
        timeout = int(os.environ.get("VULPRA_ACCEPT_TIMEOUT", "120"))
        if not 5 <= timeout <= 600:
            raise RuntimeError("VULPRA_ACCEPT_TIMEOUT must be 5..600 seconds")
        started = time.monotonic()
        max_parent_rss = None
        capture = work / "browser-output.log"
        try:
            with capture.open("wb") as output:
                proc = subprocess.Popen(
                    [str(launcher), "--headless", "--screenshot",
                     str(screenshot_path), start_url],
                    env=env, stdout=output, stderr=subprocess.STDOUT,
                    start_new_session=True,
                )
                try:
                    while proc.poll() is None:
                        rss = sample_parent_rss(proc.pid)
                        if rss is not None:
                            max_parent_rss = max(max_parent_rss or 0, rss)
                        if time.monotonic() - started > timeout:
                            raise subprocess.TimeoutExpired(proc.args, timeout)
                        time.sleep(0.1)
                    rc = proc.returncode
                finally:
                    if proc.poll() is None:
                        import signal
                        os.killpg(proc.pid, signal.SIGTERM)
                        try:
                            proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid, signal.SIGKILL)
                            proc.wait(timeout=5)
            shutil.copy2(capture, browser_log_path)
        finally:
            server.shutdown()
            server.server_close()
        runtime_seconds = round(time.monotonic() - started, 3)
        if rc != 0:
            raise RuntimeError(f"Browser exited {rc}; inspect {browser_log_path}")
        if not screenshot_path.is_file() or screenshot_path.open("rb").read(8) != PNG_MAGIC:
            raise RuntimeError("Browser did not produce a valid PNG screenshot")
        with lock:
            observations = list(seen)
        expected = ["/start", "/js-run", "/page"]
        if observations[:3] != expected:
            raise RuntimeError(
                "JavaScript-triggered navigation or HTTP redirect failed; "
                f"requests={observations}, required_first_three={expected}"
            )
        if existing.read_bytes() != original_profile_bytes:
            raise RuntimeError("Security regression: existing Firefox profile was modified")
        if not (data_home / "vulpra/default").is_dir():
            raise RuntimeError("Isolated Vulpra profile directory missing")
        print("PASS: Browser completed JavaScript-triggered navigation and HTTP redirect")
        print("PASS: Browser screenshot PNG saved and Firefox profile preserved")
        print(f"Browser startup/navigation/screenshot elapsed: {runtime_seconds}s")

        libxul = appdir / "libxul.so"
        result = {
            "schema_version": 1,
            "test": "real_native_packaged_browser_local_http_acceptance",
            "status": "pass",
            "source_commit": source_revision(repo),
            "platform": platform.platform(),
            "package_filename": archive.name,
            "package_sha256": digest,
            "package_size_bytes": archive.stat().st_size,
            "native_executable_name": browser.name,
            "native_executable_size_bytes": browser.stat().st_size,
            "libxul_size_bytes": libxul.stat().st_size if libxul.exists() else None,
            "successful_incremental_build_seconds": build_duration(logdir),
            "browser_startup_navigation_screenshot_seconds": runtime_seconds,
            "browser_parent_peak_rss_sampled_bytes": max_parent_rss,
            "rss_scope": "browser launcher parent process only, sampled every 0.1s; not full process tree",
            "navigation_requests": observations,
            "navigation_validation": "JS location.replace('/js-run') -> HTTP 302 /page",
            "assertions": {
                "package_sha256": True,
                "browser_identity": True,
                "profile_override_refused": True,
                "http_navigation": True,
                "javascript_triggered_navigation": True,
                "http_redirect_followed": True,
                "png_screenshot": True,
                "existing_firefox_profile_preserved": True,
                "isolated_vulpra_profile_created": True
            },
            "limits": ["no external-network testing", "no XMLHttpRequest or fetch API coverage",
                       "no extension lifecycle validation",
                       "no comprehensive browser security audit", "no GPU visual pixel validation"],
        }
        result_path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: Real package acceptance and baseline metrics written: {result_path}")
    print(f"Screenshot: {screenshot_path}")
    print(f"Browser log: {browser_log_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
