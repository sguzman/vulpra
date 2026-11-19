#!/usr/bin/env python3
"""Isolated real Firefox 160 signed WebExtension persistence across full restarts.

Only an already-built, SHA-256 verified archive is accepted. Two WebDriver
processes use one disposable explicit Vulpra profile. No user profiles, browser
install, signing bypass, npm or native compilation are involved.

A temporary unsigned probe must vanish after restart, while an official signed
AMO extension installed non-temporarily must remain active. This tests restart
persistence, not general extension compatibility or security certification.
"""
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "vulpra_webdriver_helpers", HERE / "smoke-webextension-package-local.py"
)
if spec is None or spec.loader is None:
    raise RuntimeError("Missing existing Vulpra WebDriver helpers")
wd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wd)

EXPECTED_UPSTREAM_SOURCE = "2887d9de1f69c0e9776413da80e7ba0d1225dd9b"
EXPECTED_CANDIDATE_TREE = "42dd7439a27dde92f89ac5eed13f88117a4d7ab5"
TEMPORARY_ID = "vulpra-local-smoke@testing.invalid"


def checked_addon_state(value, expected_present, expected_active=None):
    if not isinstance(value, dict) or value.get("status") != "pass":
        raise RuntimeError("Firefox AddonManager returned invalid state: " + repr(value))
    if value.get("present") is not expected_present:
        raise RuntimeError("Unexpected addon persistence: " + repr(value))
    if expected_active is not None and value.get("active") is not expected_active:
        raise RuntimeError("Unexpected addon activation: " + repr(value))
    return value


def checked_sha256(path, expected):
    if len(expected) != 64 or any(x not in "0123456789abcdef" for x in expected):
        raise RuntimeError("Invalid expected SHA-256")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        raise RuntimeError("Signed XPI SHA-256 mismatch")
    return actual


def addon_status(port, session, addon_id):
    # Explicitly scoped to our disposable CI profile, never a real user profile.
    base = "/session/" + session
    wd.request(port, "POST", base + "/moz/context", {"context": "chrome"})
    try:
        value = wd.request(port, "POST", base + "/execute/async", {
            "script": """
              const id = arguments[0];
              const done = arguments[arguments.length - 1];
              let returned = false;
              const finish = answer => {
                if (!returned) { returned = true; done(answer); }
              };
              const timer = setTimeout(() => finish({status:"timeout"}), 12000);
              (async () => {
                try {
                  const {AddonManager} = ChromeUtils.importESModule(
                    "resource://gre/modules/AddonManager.sys.mjs");
                  const addon = await AddonManager.getAddonByID(id);
                  clearTimeout(timer);
                  finish(addon ? {
                    status:"pass", present:true, active:addon.isActive,
                    app_disabled:addon.appDisabled,
                    user_disabled:addon.userDisabled,
                    signed_state:addon.signedState,
                    type:addon.type, version:addon.version
                  } : {status:"pass", present:false, active:false});
                } catch (error) {
                  clearTimeout(timer);
                  finish({status:"error", reason:String(error)});
                }
              })();
            """,
            "args": [addon_id],
        }, timeout_seconds=20)
    finally:
        wd.request(port, "POST", base + "/moz/context", {"context": "content"})
    return value


@contextlib.contextmanager
def session(gecko, browser, profile, home, log, label):
    """Launch and fully terminate an actual Firefox process around one session."""
    gecko_port, marionette_port = wd.find_port(), wd.find_port()
    env = os.environ.copy()
    env.update({
        "HOME": str(home),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "MOZ_HEADLESS": "1",
        "NO_PROXY": "127.0.0.1,localhost",
        "no_proxy": "127.0.0.1,localhost",
    })
    for key in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
        env.pop(key, None)
    proc = None
    session_id = None
    with log.open("wb") as out:
        try:
            proc = subprocess.Popen(
                [str(gecko), "--host", "127.0.0.1", "--port",
                 str(gecko_port), "--allow-system-access"],
                env=env, stdout=out, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            wd.wait_ready(gecko_port, proc)
            result = wd.request(gecko_port, "POST", "/session", {
                "capabilities": {"alwaysMatch": {
                    "browserName": "firefox",
                    "acceptInsecureCerts": False,
                    "moz:firefoxOptions": {
                        "binary": str(browser),
                        "args": ["-headless", "-no-remote", "-profile",
                                 str(profile), "--marionette-port",
                                 str(marionette_port)],
                        "prefs": {
                            "browser.shell.checkDefaultBrowser": False,
                            "app.update.enabled": False,
                            "extensions.update.enabled": False,
                        },
                    },
                }}
            }, timeout_seconds=70)
            if not isinstance(result, dict) or not isinstance(result.get("sessionId"), str):
                raise RuntimeError("No WebDriver session established: " + repr(result))
            session_id = result["sessionId"]
            capabilities = result.get("capabilities", {})
            # A clean session is mandatory; never weaken certificate validation.
            if (capabilities.get("acceptInsecureCerts") is not False or
                    capabilities.get("browserName") != "firefox"):
                raise RuntimeError("WebDriver session unexpectedly weakened security")
            actual_profile = capabilities.get("moz:profile")
            if not actual_profile or Path(actual_profile).resolve() != profile.resolve():
                raise RuntimeError(
                    "Geckodriver did not use the specified persistent CI profile: " +
                    repr(actual_profile)
                )
            if not str(capabilities.get("browserVersion", "")).startswith("160."):
                raise RuntimeError("WebDriver did not launch Firefox 160")
            print("PASS: " + label + " launched native Firefox 160 with same explicit disposable profile", flush=True)
            yield gecko_port, session_id
        finally:
            if session_id is not None:
                try:
                    wd.request(gecko_port, "DELETE", "/session/" + session_id,
                               timeout_seconds=20)
                except RuntimeError:
                    pass
            if proc is not None:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                    proc.wait(timeout=8)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        pass
            # Avoid a false restart pass while the first browser holds the lock.
            time.sleep(0.5)


def run(repo, signed_xpi, expected_xpi_sha, report_path):
    geckodriver = wd.shutil.which("geckodriver")
    if not geckodriver:
        raise RuntimeError("Pinned geckodriver not available")
    archive = wd.verified_archive(repo)
    archive_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    signed_sha = checked_sha256(signed_xpi, expected_xpi_sha)
    with zipfile.ZipFile(signed_xpi) as signed:
        names = signed.namelist()
        if "manifest.json" not in names or not any(n.startswith("META-INF/") for n in names):
            raise RuntimeError("Mozilla XPI lacks manifest or signing metadata")
        manifest = json.loads(signed.read("manifest.json"))
        if not manifest.get("name") or not manifest.get("version"):
            raise RuntimeError("Signed XPI manifest metadata missing")
    with tempfile.TemporaryDirectory(prefix="vulpra-160-persistent-addon-") as tmp:
        work = Path(tmp)
        extracted = work / "package"
        extracted.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(extracted)], check=True)
        inis = list(extracted.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Expected exactly one native Vulpra application")
        browser = wd.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        profile = work / "vulpra-only-profile"
        profile.mkdir()
        original_ff = home / ".mozilla/firefox/profiles.ini"
        original_ff.parent.mkdir(parents=True)
        sentinel = b"existing Firefox profile must be untouched by Vulpra persistent addon test\n"
        original_ff.write_bytes(sentinel)
        unsigned = work / "unsigned-temporary.xpi"
        wd.create_probe_extension(unsigned, secrets.token_hex(16))

        signed_id = None
        before = {}
        after = {}
        with session(geckodriver, browser, profile, home,
                     work / "geckodriver-first.log", "first") as (port, sid):
            checked_addon_state(addon_status(port, sid, TEMPORARY_ID), False)
            # The exact same syntactically valid XPI MUST be refused when
            # permanent but allowed temporarily. This tests the actual
            # non-temporary rejection boundary without changing any pref.
            try:
                wd.request(port, "POST", "/session/" + sid + "/moz/addon/install",
                           {"path": str(unsigned), "temporary": False},
                           timeout_seconds=30)
            except RuntimeError as error:
                unsigned_permanent_error = str(error)[:350]
            else:
                raise RuntimeError("Unsigned WebExtension was accepted as a permanent install")
            checked_addon_state(addon_status(port, sid, TEMPORARY_ID), False)
            print("PASS: unsigned XPI rejected as non-temporary before temporary installation", flush=True)
            unsigned_id = wd.request(port, "POST",
                "/session/" + sid + "/moz/addon/install",
                {"path": str(unsigned), "temporary": True})
            if unsigned_id != TEMPORARY_ID:
                raise RuntimeError("Temporary unsigned probe ID mismatch")
            checked_addon_state(addon_status(port, sid, TEMPORARY_ID), True, True)
            signed_id = wd.request(port, "POST",
                "/session/" + sid + "/moz/addon/install",
                {"path": str(signed_xpi), "temporary": False},
                timeout_seconds=35)
            if not isinstance(signed_id, str) or not signed_id or signed_id == TEMPORARY_ID:
                raise RuntimeError("Permanent signed extension returned invalid ID")
            before = checked_addon_state(addon_status(port, sid, signed_id), True, True)
            if before.get("app_disabled") or before.get("user_disabled"):
                raise RuntimeError("Signed extension disabled immediately after install")
            print("PASS: Mozilla-signed XPI non-temporarily installed alongside unsigned temporary probe", flush=True)
        if original_ff.read_bytes() != sentinel:
            raise RuntimeError("Existing Firefox profile touched after first launch")
        with session(geckodriver, browser, profile, home,
                     work / "geckodriver-restart.log", "restarted") as (port, sid):
            after = checked_addon_state(addon_status(port, sid, signed_id), True, True)
            checked_addon_state(addon_status(port, sid, TEMPORARY_ID), False)
            if after.get("app_disabled") or after.get("user_disabled"):
                raise RuntimeError("Signed extension disabled after browser restart")
            if before.get("version") != after.get("version"):
                raise RuntimeError("Signed extension version changed across restart")
            wd.request(port, "POST", "/session/" + sid + "/moz/addon/uninstall",
                       {"id": signed_id})
            checked_addon_state(addon_status(port, sid, signed_id), False)
            print("PASS: signed extension active across complete Firefox restart; temporary unsigned addon absent", flush=True)
        if original_ff.read_bytes() != sentinel:
            raise RuntimeError("Existing Firefox profile changed")
        result = {
            "schema_version": 1, "status": "pass",
            "native_package_sha256": archive_sha,
            "signed_extension_sha256": signed_sha,
            "signed_extension_name": manifest["name"],
            "signed_extension_version": manifest["version"],
            "signed_extension_id": signed_id,
            "signed_install_non_temporary": True,
            "unsigned_non_temporary_install_rejected": True,
            "unsigned_non_temporary_rejection_reason": unsigned_permanent_error,
            "same_unsigned_xpi_installed_temporarily": True,
            "signed_extension_active_before_restart": before.get("active") is True,
            "signed_extension_active_after_restart": after.get("active") is True,
            "signed_extension_version_preserved": before.get("version") == after.get("version"),
            "temporary_unsigned_extension_removed_by_restart": True,
            "signed_extension_uninstalled_after_test": True,
            "separate_browser_processes_same_profile": True,
            "original_firefox_profile_preserved": True,
            "xpinstall_signing_requirement_not_disabled_by_test": True,
            "release_ready": False, "security_current": False,
            "limits": [
                "No full signed-AMO compatibility matrix",
                "No signed extension content/background feature coverage",
                "No persisted storage across restart proof",
                "No user profile or production installation",
                "No Safe Browsing or process sandbox security audit",
            ],
        }
        if report_path.exists():
            raise RuntimeError("Refusing to overwrite existing persistence proof")
        report_path.write_text(json.dumps(result, indent=2) + "\n")
    print("PASS: real Firefox 160 signed persistent addon and temporary addon restart contrast", flush=True)
    print("LIMIT: only isolated restart presence/active state, not complete signed-addon/security acceptance", flush=True)


def self_test():
    valid = {"status": "pass", "present": True, "active": True}
    checked_addon_state(valid, True, True)
    for value, expected in [
        ({"status": "pass", "present": False, "active": False}, True),
        ({"status": "pass", "present": True, "active": False}, True),
        ({"status": "error", "present": True, "active": True}, True),
        ({"status": "pass", "present": True, "active": True}, False),
    ]:
        try:
            checked_addon_state(value, expected, True if expected else None)
        except RuntimeError:
            pass
        else:
            raise RuntimeError("Forged extension status accepted by restart gate")
    print("PASS: persistent addon status gate rejects missing, inactive and malformed states")


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 5:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(),
                sys.argv[3], Path(sys.argv[4]).resolve())
        else:
            raise RuntimeError("usage: SCRIPT --self-test OR SCRIPT REPO SIGNED_XPI SHA256 OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError,
            zipfile.BadZipFile) as error:
        print("FAIL: " + str(error), file=sys.stderr)
        raise SystemExit(1)
