#!/usr/bin/env python3
"""Real archived Firefox 160 + signed Bitwarden + disposable HTTPS Vaultwarden.

This bounded integration phase verifies trusted localhost TLS and official
managed self-hosted endpoint configuration in a real extension, without
registering/logging in, reading personal data or allowing network egress.

The invoking workflow must run this process in Vaultwarden's Docker
--network none namespace; all browser/driver processes inherit that network.
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request
import ssl
import zipfile

ADDON_ID = "{446900e4-71c2-419f-a6a7-df9c091e268b}"
VERSION = "2026.10.2"
XPI_SHA256 = "abf9d7273dd55ac0583ecc6997f7f7ae3d29de11e2ad0a4838b80e2b941daa73"
ENDPOINT = "https://127.0.0.1:8443"


def helper():
    source = Path(__file__).with_name("smoke-webextension-package-local.py")
    spec = importlib.util.spec_from_file_location("vulpra_byob_previous", source)
    if spec is None or spec.loader is None:
        raise RuntimeError("Existing Vulpra native WebDriver acceptance helper absent")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_quiet(args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=25)


def profile_with_temporary_ca(work, ca_cert):
    profile = work / "nss"
    profile.mkdir(mode=0o700)
    run_quiet(["certutil", "-N", "-d", "sql:" + str(profile), "--empty-password"])
    run_quiet(["certutil", "-A", "-d", "sql:" + str(profile), "-n",
               "Vulpra disposable Vaultwarden CI CA", "-t", "C,,",
               "-i", str(ca_cert)])
    files = [profile / f for f in ("cert9.db", "key4.db", "pkcs11.txt")]
    if not all(f.is_file() for f in files[:2]):
        raise RuntimeError("NSS disposable certificate database missing")
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            if f.is_file():
                z.write(f, f.name)
    return base64.b64encode(archive.getvalue()).decode("ascii")


def official_xpi(xpi):
    digest = hashlib.sha256(xpi.read_bytes()).hexdigest()
    if digest != XPI_SHA256:
        raise RuntimeError("Pinned official Bitwarden XPI digest mismatch")
    with zipfile.ZipFile(xpi) as z:
        manifest = json.loads(z.read("manifest.json"))
        if manifest.get("version") != VERSION:
            raise RuntimeError("Official Bitwarden version mismatch")
        settings = manifest.get("browser_specific_settings", {}).get("gecko", {})
        if settings.get("id") != ADDON_ID:
            raise RuntimeError("Official Bitwarden Gecko ID mismatch")
        action = manifest.get("action") or manifest.get("browser_action") or {}
        popup = action.get("default_popup")
        if not isinstance(popup, str) or popup.lstrip("/") not in z.namelist():
            raise RuntimeError("Official extension popup path unrecognized")
    return popup.lstrip("/")


def valid_policy(policy, url=ENDPOINT):
    try:
        return (policy["policies"]["3rdparty"]["Extensions"][ADDON_ID]
                == {"environment": {"base": url}})
    except (TypeError, KeyError):
        return False


def preflight():
    good = {"policies": {"3rdparty": {"Extensions": {
        ADDON_ID: {"environment": {"base": ENDPOINT}}
    }}}}
    assert valid_policy(good)
    assert not valid_policy(None)
    assert not valid_policy({"policies": {"3rdparty": {"Extensions": {}}}})
    forged = json.loads(json.dumps(good))
    forged["policies"]["3rdparty"]["Extensions"][ADDON_ID]["environment"]["base"] = "https://vault.bitwarden.com"
    assert not valid_policy(forged)
    print("PASS: signed-extension managed-endpoint source contract rejects wrong/missing origin")


def check_real_https(ca):
    trusted = ssl.create_default_context(cafile=str(ca))
    with urllib.request.urlopen(ENDPOINT + "/alive", context=trusted, timeout=12) as response:
        if response.status != 200 or b"Alive" not in response.read(1024):
            raise RuntimeError("Actual disposable Vaultwarden HTTPS readiness failed")
    # Strict, fresh standard trust context must reject the ephemeral CA.
    try:
        with urllib.request.urlopen(ENDPOINT + "/alive",
                                    context=ssl.create_default_context(), timeout=8):
            raise RuntimeError("Test's supposedly untrusted private CA was accepted globally")
    except ssl.SSLCertVerificationError:
        pass
    with urllib.request.urlopen(ENDPOINT + "/api/config", context=trusted, timeout=12) as response:
        config = json.load(response)
    if not isinstance(config, dict):
        raise RuntimeError("Disposable server returned no Bitwarden API config")
    return True


def addon_state_and_resource(h, port, base, popup):
    h.request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        result = h.request(port, "POST", base + "/execute/async", {
            "script": """
              const path = arguments[0], done=arguments[arguments.length-1];
              (async () => {
                const {AddonManager} = ChromeUtils.importESModule(
                  'resource://gre/modules/AddonManager.sys.mjs');
                const addon = await AddonManager.getAddonByID(
                  '{446900e4-71c2-419f-a6a7-df9c091e268b}');
                done(addon ? {
                  id: addon.id === '{446900e4-71c2-419f-a6a7-df9c091e268b}',
                  version: addon.version === '2026.10.2',
                  active: addon.isActive === true,
                  signed: addon.signedState === AddonManager.SIGNEDSTATE_SIGNED,
                  temporary: addon.temporarilyInstalled === true,
                  resource: addon.getResourceURI(path).spec
                } : null);
              })().catch(e => done({error: String(e).slice(0,100)}));
            """,
            "args": [popup],
        }, timeout_seconds=30)
    finally:
        h.request(port, "POST", base + "/moz/context", {"context": "content"})
    if not isinstance(result, dict) or not all(
            result.get(k) is True for k in ("id", "version", "active", "signed")):
        raise RuntimeError("Installed real signed Bitwarden state incorrect: " + repr(result)[:220])
    if result.get("temporary") is not False or not str(result.get("resource", "")).startswith("moz-extension://"):
        raise RuntimeError("No permanent real signed Bitwarden extension popup resource")
    return result["resource"]


def verify_popup_managed_environment(h, port, base, resource):
    h.request(port, "POST", base + "/url", {"url": resource}, timeout_seconds=30)
    deadline = time.monotonic() + 20
    last = None
    while time.monotonic() < deadline:
        last = h.request(port, "POST", base + "/execute/async", {
            "script": """
              const done = arguments[arguments.length-1];
              (async() => {
                if (location.protocol !== 'moz-extension:') {
                  done({origin: false}); return;
                }
                const environment = await browser.storage.managed.get('environment');
                done({origin: true, base: environment?.environment?.base ?? null,
                      proper_extension_api: !!browser.runtime?.id});
              })().catch(e => done({origin: location.protocol === 'moz-extension:',
                                   error: String(e).slice(0,100)}));
            """,
            "args": [],
        }, timeout_seconds=15)
        if isinstance(last, dict) and last.get("origin") is True and (
                last.get("base") == ENDPOINT and last.get("proper_extension_api") is True):
            return True
        time.sleep(0.4)
    raise RuntimeError("Real Bitwarden popup did not consume local managed environment: "
                       + repr(last)[:260])


def test_browser_server_and_extension(h, port, base):
    h.request(port, "POST", base + "/url", {"url": ENDPOINT + "/alive"}, timeout_seconds=30)
    state = h.request(port, "POST", base + "/execute/sync", {
        "script": """
          return {
            secure: window.isSecureContext,
            tls: location.protocol === 'https:',
            localhost: location.hostname === '127.0.0.1',
            alive: document.body?.textContent.includes('Alive') === true
          };
        """,
        "args": [],
    })
    if not isinstance(state, dict) or not all(state.get(key) is True for key in (
            "secure", "tls", "localhost", "alive")):
        raise RuntimeError("Packaged Vulpra did not accept private-CA-trusted Vaultwarden HTTPS")


def main(repo, xpi, ca):
    popup = official_xpi(xpi)
    check_real_https(ca)
    h = helper()
    archive = h.verified_archive(repo)
    root = repo / ".git/vulpra-native-build"
    root.mkdir(parents=True, exist_ok=True)
    gecko = shutil.which("geckodriver")
    if gecko is None:
        raise RuntimeError("Verified geckodriver required")
    with tempfile.TemporaryDirectory(prefix="vulpra-test-vaultwarden-") as temp:
        work = Path(temp)
        stage = work / "app"
        stage.mkdir()
        run_quiet(["tar", "-xf", str(archive), "-C", str(stage)])
        inis = list(stage.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text():
            raise RuntimeError("Original packaged Vulpra identity mismatch")
        appdir = inis[0].parent
        browser = h.select_binary(appdir)
        policy = {"policies": {"3rdparty": {"Extensions": {
            ADDON_ID: {"environment": {"base": ENDPOINT}}
        }}}}
        if not valid_policy(policy):
            raise RuntimeError("Refusing invalid managed endpoint policy")
        (appdir / "distribution").mkdir(exist_ok=True)
        (appdir / "distribution" / "policies.json").write_text(json.dumps(policy))
        profile = profile_with_temporary_ca(work, ca)
        home = work / "home"
        home.mkdir()
        sentinel = home / ".mozilla/firefox/profiles.ini"
        sentinel.parent.mkdir(parents=True)
        old = b"No existing Firefox profile may be modified\n"
        sentinel.write_bytes(old)
        env = os.environ.copy()
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                    "MOZ_HEADLESS": "1",
                    "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        for var in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(var, None)
        port = h.find_port()
        proc = None
        session = None
        installed = False
        try:
            with (root / "byob-local-vaultwarden-geckodriver.log").open("wb") as log:
                proc = subprocess.Popen(
                    [gecko, "--host", "127.0.0.1", "--port", str(port),
                     "--allow-system-access"], env=env,
                    stdout=log, stderr=subprocess.STDOUT,
                    start_new_session=True)
                h.wait_ready(port, proc)
                value = h.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser), "args": ["-headless", "-no-remote"],
                            "profile": profile,
                            "prefs": {
                                "remote.prefs.recommended": False,
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                            },
                        },
                    }}
                }, timeout_seconds=60)
                if not isinstance(value, dict) or not value.get("sessionId") or (
                        value.get("capabilities", {}).get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Packaged Vulpra disposable profile rejected")
                session = str(value["sessionId"])
                base = "/session/" + session
                h.verify_byob_defaults(port, base)
                test_browser_server_and_extension(h, port, base)
                aid = h.request(port, "POST", base + "/moz/addon/install",
                                {"path": str(xpi), "temporary": False}, timeout_seconds=60)
                installed = aid == ADDON_ID
                if not installed:
                    raise RuntimeError("Official signed Bitwarden install ID mismatch")
                resource = addon_state_and_resource(h, port, base, popup)
                verify_popup_managed_environment(h, port, base, resource)
                h.verify_byob_defaults(port, base)
                h.request(port, "POST", base + "/moz/addon/uninstall", {"id": ADDON_ID})
                installed = False
                if sentinel.read_bytes() != old:
                    raise RuntimeError("Existing Firefox profile sentinel modified")
                proof = {
                    "schema_version": 1, "status": "pass",
                    "actual_vaultwarden_https_service": True,
                    "real_browser_trusted_temporary_ca": True,
                    "real_bitwarden_signed_extension_installed": True,
                    "real_bitwarden_popup_managed_server_url": True,
                    "byob_defaults_preserved": True,
                    "original_browser_profile_preserved": True,
                    "vaultwarden_account_created": False,
                    "extension_authenticated_to_vaultwarden": False,
                    "record_autofill_verified": False,
                    "network_egress_permitted": False,
                    "native_browser_recompiled": False,
                    "security_current": False, "release_ready": False,
                }
                (root / "byob-local-vaultwarden-proof.json").write_text(
                    json.dumps(proof, indent=2) + "\n")
                print("PASS: trusted HTTPS disposable Vaultwarden and real Bitwarden managed server endpoint in Vulpra")
                print("LIMIT: no registration, login or vault-record autofill demonstrated")
        finally:
            if session:
                if installed:
                    try:
                        h.request(port, "POST", "/session/" + session + "/moz/addon/uninstall",
                                  {"id": ADDON_ID})
                    except RuntimeError:
                        pass
                try:
                    h.request(port, "DELETE", "/session/" + session)
                except RuntimeError:
                    pass
            if proc:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                    proc.wait(timeout=5)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        preflight()
    elif len(sys.argv) == 4:
        main(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(),
             Path(sys.argv[3]).resolve())
    else:
        raise SystemExit("usage: smoke-byob-vaultwarden-local.py --self-test | REPO XPI CA_CERT")
