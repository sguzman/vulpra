#!/usr/bin/env python3
"""Offline-network real Bitwarden signed-addon smoke for an archived Vulpra BYOB browser.

Use only a version-specific official Mozilla XPI downloaded beforehand. Run the
browser + geckodriver inside a loopback-only network namespace. This checks
signed installation and BYOB coexistence, NOT Vaultwarden login/autofill.
"""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import zipfile
import hashlib

BITWARDEN_ID = "{446900e4-71c2-419f-a6a7-df9c091e268b}"
BITWARDEN_VERSION = "2026.10.2"


def helper():
    path = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_smoke_helpers", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Existing Vulpra WebDriver helper unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def valid_manifest(value):
    if not isinstance(value, dict) or value.get("version") != BITWARDEN_VERSION:
        return False
    gecko = value.get("browser_specific_settings", {}).get("gecko", {})
    legacy = value.get("applications", {}).get("gecko", {})
    return (gecko.get("id") or legacy.get("id")) == BITWARDEN_ID


def inspect_xpi(path: Path):
    # The XPI is not redistributed or uploaded as a CI artifact.
    if not path.is_file() or not (1_000_000 < path.stat().st_size < 100_000_000):
        raise RuntimeError("Official Bitwarden XPI missing or outside bounded size")
    with zipfile.ZipFile(path) as archive:
        manifest = json.loads(archive.read("manifest.json"))
    if not valid_manifest(manifest):
        raise RuntimeError("Official Bitwarden XPI version or Gecko ID mismatch")
    digest = hashlib.file_digest(path.open("rb"), "sha256").hexdigest()
    return {"version": BITWARDEN_VERSION, "gecko_id_matches": True,
            "xpi_sha256": digest}


def self_test():
    valid = {
        "manifest_version": 3,
        "version": BITWARDEN_VERSION,
        "browser_specific_settings": {"gecko": {"id": BITWARDEN_ID}},
    }
    assert valid_manifest(valid)
    for altered in (
        {**valid, "version": "2026.10.1"},
        {**valid, "browser_specific_settings": {"gecko": {"id": "other@invalid"}}},
        {**valid, "browser_specific_settings": {}},
        {}, None,
    ):
        assert not valid_manifest(altered), f"Accepted forged XPI identity: {altered}"
    print("PASS: official Bitwarden manifest version/Gecko ID negative controls")


def inspect_addon(h, port, base):
    h.request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        value = h.request(port, "POST", base + "/execute/async", {
            "script": """
              const done = arguments[arguments.length - 1];
              (async () => {
                const {AddonManager} = ChromeUtils.importESModule(
                  'resource://gre/modules/AddonManager.sys.mjs');
                const addon = await AddonManager.getAddonByID(
                  '{446900e4-71c2-419f-a6a7-df9c091e268b}');
                done(addon ? {
                  id_matches: addon.id === '{446900e4-71c2-419f-a6a7-df9c091e268b}',
                  version_matches: addon.version === '2026.10.2',
                  active: addon.isActive === true,
                  enabled: addon.userDisabled === false,
                  signed: addon.signedState === AddonManager.SIGNEDSTATE_SIGNED,
                  temporary: addon.temporarilyInstalled === true
                } : null);
              })().catch(error => done({error: String(error)}));
            """,
            "args": [],
        }, timeout_seconds=30)
        return value
    finally:
        h.request(port, "POST", base + "/moz/context", {"context": "content"})


def main(repo: Path, xpi: Path):
    h = helper()
    identity = inspect_xpi(xpi)
    archive = h.verified_archive(repo)
    root = repo / ".git/vulpra-native-build"
    root.mkdir(parents=True, exist_ok=True)
    driver_path = shutil.which("geckodriver")
    if not driver_path:
        raise RuntimeError("Verified geckodriver not found")
    with tempfile.TemporaryDirectory(prefix="vulpra-real-bitwarden-") as tmp:
        work = Path(tmp)
        stage = work / "app"
        stage.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(stage)],
                       check=True)
        applications = list(stage.rglob("application.ini"))
        if len(applications) != 1 or "Name=Vulpra" not in applications[0].read_text().splitlines():
            raise RuntimeError("Unrecognized packaged Vulpra browser")
        browser = h.select_binary(applications[0].parent)
        home = work / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        original = b"Existing Firefox profiles must remain untouched\n"
        sentinel.write_bytes(original)
        env = os.environ.copy()
        env.update({"HOME": str(home),
                    "XDG_DATA_HOME": str(home / ".local/share"),
                    "MOZ_HEADLESS": "1",
                    "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)
        port = h.find_port()
        driver, session, addon_id = None, None, None
        try:
            with (root / "byob-bitwarden-driver.log").open("wb") as logfile:
                driver = subprocess.Popen(
                    [driver_path, "--host", "127.0.0.1", "--port", str(port),
                     "--allow-system-access"],
                    env=env, stdout=logfile, stderr=subprocess.STDOUT,
                    start_new_session=True)
                h.wait_ready(port, driver)
                value = h.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser),
                            "args": ["-headless", "-no-remote"],
                            "prefs": {
                                "remote.prefs.recommended": False,
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                            }
                        }
                    }}
                }, timeout_seconds=60)
                if not isinstance(value, dict) or not value.get("sessionId") or (
                        value.get("capabilities", {}).get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Disposable Vulpra WebDriver session rejected")
                session = str(value["sessionId"])
                base = "/session/" + session
                h.verify_byob_defaults(port, base)
                addon_id = h.request(port, "POST", base + "/moz/addon/install",
                                     {"path": str(xpi), "temporary": False},
                                     timeout_seconds=60)
                if addon_id != BITWARDEN_ID:
                    raise RuntimeError("Real Bitwarden signed installation returned unexpected ID")
                deadline = time.monotonic() + 25
                observed = None
                while time.monotonic() < deadline:
                    observed = inspect_addon(h, port, base)
                    if isinstance(observed, dict) and (
                            observed.get("id_matches") is True and
                            observed.get("version_matches") is True and
                            observed.get("active") is True and
                            observed.get("enabled") is True and
                            observed.get("signed") is True and
                            observed.get("temporary") is False):
                        break
                    time.sleep(0.4)
                else:
                    raise RuntimeError("Real signed Bitwarden addon did not activate: " +
                                       repr(observed)[:300])
                h.verify_byob_defaults(port, base)
                h.request(port, "POST", base + "/moz/addon/uninstall",
                          {"id": BITWARDEN_ID})
                addon_id = None
                if inspect_addon(h, port, base) is not None:
                    raise RuntimeError("Bitwarden extension remained installed after removal")
                if sentinel.read_bytes() != original:
                    raise RuntimeError("Existing browser profile sentinel modified")
                proof = {
                    "schema_version": 1, "status": "pass",
                    "extension": {"official_amo_version": BITWARDEN_VERSION,
                                  "gecko_id_matches": True,
                                  "xpi_sha256": identity["xpi_sha256"],
                                  "real_signed_permanent_install": True,
                                  "active_and_enabled": True,
                                  "uninstall_verified": True},
                    "byob_defaults_pre_and_post_install": True,
                    "isolated_network_without_external_egress": True,
                    "disposable_browser_profile": True,
                    "personal_vault_accessed": False,
                    "vaultwarden_endpoint_tested": False,
                    "native_rebuild": False, "security_current": False,
                    "release_ready": False,
                }
                (root / "byob-bitwarden-proof.json").write_text(
                    json.dumps(proof, indent=2) + "\n")
                print("PASS: real signed Bitwarden Firefox extension installed and activated in archived Vulpra")
                print("LIMIT: no Vaultwarden endpoint, login or real vault autofill tested")
        finally:
            if session:
                if addon_id:
                    try:
                        h.request(port, "POST", "/session/" + session + "/moz/addon/uninstall",
                                  {"id": addon_id})
                    except RuntimeError:
                        pass
                try:
                    h.request(port, "DELETE", "/session/" + session)
                except RuntimeError:
                    pass
            if driver is not None:
                try:
                    os.killpg(driver.pid, signal.SIGTERM)
                    driver.wait(timeout=5)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(driver.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif len(sys.argv) == 3:
        main(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
    else:
        raise SystemExit("usage: smoke-byob-bitwarden-addon.py --self-test | REPO OFFICIAL_XPI")
