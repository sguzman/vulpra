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
import urllib.error
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
        if response.status != 200:
            raise RuntimeError("Actual disposable Vaultwarden HTTPS readiness failed")
    # Strict, fresh standard trust context must reject the ephemeral CA.
    try:
        with urllib.request.urlopen(ENDPOINT + "/alive",
                                    context=ssl.create_default_context(), timeout=8):
            raise RuntimeError("Test's supposedly untrusted private CA was accepted globally")
    except urllib.error.URLError as exc:
        if not isinstance(exc.reason, ssl.SSLCertVerificationError):
            raise
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
                  resource: WebExtensionPolicy.getByID(addon.id)?.getURL(path) ?? null
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
            alive: document.readyState === 'complete' && document.body !== null
          };
        """,
        "args": [],
    })
    if not isinstance(state, dict) or not all(state.get(key) is True for key in (
            "secure", "tls", "localhost", "alive")):
        raise RuntimeError("Packaged Vulpra did not accept private-CA-trusted Vaultwarden HTTPS")


def _wd_element(h, port, base, selector):
    found = h.request(port, "POST", base + "/element",
                      {"using": "css selector", "value": selector},
                      timeout_seconds=20)
    key = "element-6066-11e4-a52e-4f735466cecf"
    if not isinstance(found, dict) or not isinstance(found.get(key), str):
        raise RuntimeError("Disposable registration control missing: " + selector)
    return found[key]


def _wd_type(h, port, base, selector, value):
    ident = _wd_element(h, port, base, selector)
    h.request(port, "POST", base + "/element/" + ident + "/value",
              {"text": value, "value": list(value)}, timeout_seconds=30)


def _wd_click(h, port, base, selector):
    ident = _wd_element(h, port, base, selector)
    h.request(port, "POST", base + "/element/" + ident + "/click", {},
              timeout_seconds=30)


def _await_registration_ui(h, port, base, selector, route, timeout=60):
    """Wait for the real Angular route and control; never return token/credential data."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            observed = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  const element = document.querySelector(arguments[0]);
                  return {
                    right_route: location.protocol === 'moz-extension:' &&
                                 location.hash.startsWith(arguments[1]),
                    control_present: !!(element && element.isConnected &&
                       element.getClientRects().length > 0)
                  };
                """,
                "args": [selector, route],
            }, timeout_seconds=15)
            if (isinstance(observed, dict) and
                    observed.get("right_route") is True and
                    observed.get("control_present") is True):
                return
        except RuntimeError:
            pass  # Real Angular navigation may destroy a just-observed document.
        time.sleep(0.35)
    raise RuntimeError("Timed out waiting for expected isolated signed-extension registration UI")


def register_fake_account_in_real_bitwarden(h, port, base, popup_url):
    """Real WebDriver user input, genuine extension registration/API and auto-login.

    Random fake credentials stay only in this short-lived, egress-isolated
    test process and Vaultwarden's intentionally volatile Docker filesystem.
    No email/password/registration token is included in a proof, log or artifact.
    """
    import secrets

    if not isinstance(popup_url, str) or not popup_url.startswith("moz-extension://"):
        raise RuntimeError("Cannot register outside active official extension origin")
    email = "vulpra-ci-" + secrets.token_hex(10) + "@example.invalid"
    password = "Vulpra-CI-" + secrets.token_urlsafe(32) + "!9Aa"
    signup = popup_url.split("#", 1)[0] + "#/signup"
    h.request(port, "POST", base + "/url", {"url": signup}, timeout_seconds=35)
    _await_registration_ui(h, port, base, "#register-start_form_input_email",
                           "#/signup", timeout=55)
    _wd_type(h, port, base, "#register-start_form_input_email", email)
    _wd_type(h, port, base, "#register-start_form_input_name", "Disposable Vulpra CI")
    _wd_click(h, port, base, "auth-registration-start form button[type='submit']")
    # The isolated Vaultwarden image runs without SMTP. Bitwarden receives
    # a one-use local verification token directly, as its official client
    # implements when server email verification is disabled.
    _await_registration_ui(h, port, base, "#input-password-form_new-password",
                           "#/finish-signup", timeout=70)
    _wd_type(h, port, base, "#input-password-form_new-password", password)
    _wd_type(h, port, base, "#input-password-form_new-password-confirm", password)

    # No breached-password lookups are authorized in this network-isolated QA.
    # Disable the optional UI checkbox by its actual WebDriver element click.
    disabled_leak_check = h.request(port, "POST", base + "/execute/sync", {
        "script": """
           const cb = document.querySelector('#input-password-form_check-for-breaches');
           return cb ? {present:true,checked:cb.checked} : {present:false};
        """,
        "args": [],
    })
    if not isinstance(disabled_leak_check, dict) or disabled_leak_check.get("present") is not True:
        raise RuntimeError("Cannot verify optional network password breach check")
    if disabled_leak_check.get("checked") is True:
        _wd_click(h, port, base, "#input-password-form_check-for-breaches")
    no_breach_lookup = h.request(port, "POST", base + "/execute/sync", {
        "script": """
          const cb = document.querySelector('#input-password-form_check-for-breaches');
          return !!cb && cb.checked === false;
        """,
        "args": [],
    })
    if no_breach_lookup is not True:
        raise RuntimeError("Optional breached-password lookup was not disabled")

    _wd_click(h, port, base, "auth-input-password form button[type='submit']")

    # RegistrationFinishComponent creates a real account, authenticates with
    # PasswordLoginCredentials and navigates through an auth-required vault route.
    # A login redirect, signup error, or unauthenticated landing must fail.
    deadline = time.monotonic() + 100
    while time.monotonic() < deadline:
        try:
            observed = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  return {
                    actual_extension: location.protocol === 'moz-extension:',
                    authenticated_vault_route:
                      location.hash.startsWith('#/tabs/vault') ||
                      location.hash.startsWith('#/tabs/current') ||
                      location.hash.startsWith('#/vault'),
                    login_route: location.hash.startsWith('#/login')
                  };
                """,
                "args": [],
            }, timeout_seconds=20)
            if isinstance(observed, dict) and (
                    observed.get("actual_extension") is True and
                    observed.get("authenticated_vault_route") is True):
                return {
                    "verified": True,
                    "real_bitwarden_client_registration": True,
                    "extension_authenticated_after_registration": True,
                    "webdriver_typed_both_registration_forms": True,
                    "disposable_invalid_tld_email_only": True,
                    "master_password_in_proof_or_logs": False,
                    "external_breach_lookup_enabled": False,
                }, {"email": email, "master_password": password}
            if isinstance(observed, dict) and observed.get("login_route") is True:
                raise RuntimeError("Actual Bitwarden account flow redirected to login instead of authenticated vault")
        except RuntimeError as exc:
            if "redirected to login" in str(exc):
                raise
        time.sleep(0.5)
    raise RuntimeError("Real Bitwarden registration did not establish authenticated vault UI")


class _DisposableLoginForm:
    """Intentionally fake local HTTP login origin; never accepts submissions."""

    @staticmethod
    def start():
        import http.server
        from threading import Thread

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path != "/ci-login":
                    self.send_error(404)
                    return
                content = (b'<!doctype html><html><head><meta charset="utf-8">'
                           b'<title>Disposable Vulpra autofill</title></head>'
                           b'<body><h1>Fake local login</h1>'
                           b'<form id="ci-local-login" action="/ci-submit" method="post">'
                           b'<label for="ci-user">Username</label>'
                           b'<input id="ci-user" name="username" type="text" '
                           b'autocomplete="username" required>'
                           b'<label for="ci-pass">Password</label>'
                           b'<input id="ci-pass" name="password" type="password" '
                           b'autocomplete="current-password" required>'
                           b'<button id="ci-submit" type="submit">Sign in</button>'
                           b'</form></body></html>')
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)

            def do_POST(self):
                # This form exists solely for fill detection; no login values
                # are collected, accepted or logged, even if mis-clicked.
                self.send_error(405, "Disposable CI form never accepts credentials")

            def log_message(self, *_args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        return server, "http://127.0.0.1:" + str(server.server_port) + "/ci-login"


def _diagnose_autofill_gap_without_secrets(h, port, base, popup_url, login_url):
    """Boolean-only debugging of browser focus and signed extension page analysis.

    This never invokes autofill, reads stored ciphers, exposes credentials,
    modifies browser prefs, or sends data outside the CI namespace.
    """
    report = {
        "web_driver_page_probe_executed": False,
        "web_driver_same_url_after_shortcut": False,
        "web_driver_still_local_page": False,
        "web_driver_page_focused": False,
        "chrome_probe_executed": False,
        "chrome_browser_window_found": False,
        "chrome_target_tab_present": False,
        "chrome_current_tab_is_local": False,
        "browser_selected_login_tab": False,
        "diagnostic_tab_created": False,
        "extension_probe_executed": False,
        "extension_query_tab_count": -1,
        "extension_query_has_any_local_tab": False,
        "extension_query_has_any_extension_tab": False,
        "extension_can_find_target_tab": False,
        "extension_target_is_active": False,
        "content_script_triage_answered": False,
        "form_detected": False,
        "username_field_detected": False,
        "password_field_detected": False,
    }

    try:
        page_state = h.request(port, "POST", base + "/execute/sync", {
            "script": """
              return {
                same_url: location.href === arguments[0],
                local_page: location.hostname === '127.0.0.1',
                focused: document.hasFocus()
              };
            """,
            "args": [login_url],
        }, timeout_seconds=15)
        if isinstance(page_state, dict):
            report["web_driver_page_probe_executed"] = True
            report["web_driver_same_url_after_shortcut"] = page_state.get("same_url") is True
            report["web_driver_still_local_page"] = page_state.get("local_page") is True
            report["web_driver_page_focused"] = page_state.get("focused") is True
    except RuntimeError:
        pass

    try:
        h.request(port, "POST", base + "/moz/context", {"context": "chrome"})
        try:
            selected = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  const {Services} = ChromeUtils.importESModule(
                    'resource://gre/modules/Services.sys.mjs');
                  const win = Services.wm.getMostRecentWindow('navigator:browser');
                  const browser = win?.gBrowser;
                  const current = browser?.selectedBrowser?.currentURI?.spec ?? '';
                  return {
                    window_found: !!browser,
                    selected_local: current.startsWith('http://127.0.0.1:'),
                    selected_match: current === arguments[0],
                    target_present: !!browser?.tabs?.length &&
                      [...browser.tabs].some(t =>
                        t.linkedBrowser?.currentURI?.spec === arguments[0])
                  };
                """,
                "args": [login_url],
            }, timeout_seconds=15)
            if isinstance(selected, dict):
                report["chrome_probe_executed"] = True
                report["chrome_browser_window_found"] = selected.get("window_found") is True
                report["chrome_target_tab_present"] = selected.get("target_present") is True
                report["chrome_current_tab_is_local"] = selected.get("selected_local") is True
                report["browser_selected_login_tab"] = selected.get("selected_match") is True
        finally:
            h.request(port, "POST", base + "/moz/context", {"context": "content"})
    except RuntimeError:
        pass

    original_window = None
    diagnostic_window = None
    try:
        original_window = h.request(port, "GET", base + "/window", timeout_seconds=15)
        new_tab = h.request(port, "POST", base + "/window/new",
                            {"type": "tab"}, timeout_seconds=15)
        if not isinstance(new_tab, dict) or not new_tab.get("handle"):
            raise RuntimeError("Could not open bounded extension diagnostic tab")
        diagnostic_window = new_tab["handle"]
        report["diagnostic_tab_created"] = True
        h.request(port, "POST", base + "/url",
                  {"url": popup_url.split("#", 1)[0] + "#/tabs/vault"},
                  timeout_seconds=30)
        result = h.request(port, "POST", base + "/execute/async", {
            "script": """
              const targetUrl=arguments[0];
              const done=arguments[arguments.length-1];
              (async()=>{
                const tabs=await browser.tabs.query({});
                const target=tabs.find(t=>t.url===targetUrl);
                const out={
                  target_found: !!target,
                  target_active: target?.active === true,
                  tab_count: tabs.length,
                  has_local: tabs.some(t=>t.url?.startsWith('http://127.0.0.1:')),
                  has_extension: tabs.some(t=>t.url?.startsWith('moz-extension://')),
                  triage_answered:false, form_detected:false,
                  username_detected:false, password_detected:false
                };
                if(target?.id != null){
                  try{
                    const t=await browser.tabs.sendMessage(target.id,
                      {command:'collectAutofillTriage'});
                    if(t?.pageDetails){
                      out.triage_answered=true;
                      out.form_detected=Object.keys(t.pageDetails.forms ?? {}).length>0;
                      const fields=t.pageDetails.fields ?? [];
                      out.username_detected=fields.some(f=>
                        f.htmlID==='ci-user' || f.htmlName==='username');
                      out.password_detected=fields.some(f=>
                        f.htmlID==='ci-pass' || f.htmlName==='password');
                    }
                  }catch(_err){}
                }
                done(out);
              })().catch(_err=>done(null));
            """,
            "args": [login_url],
        }, timeout_seconds=30)
        if isinstance(result, dict):
            report["extension_probe_executed"] = True
            report["extension_query_tab_count"] = result.get("tab_count", -1)
            report["extension_query_has_any_local_tab"] = result.get("has_local") is True
            report["extension_query_has_any_extension_tab"] = result.get("has_extension") is True
            report["extension_can_find_target_tab"] = result.get("target_found") is True
            report["extension_target_is_active"] = result.get("target_active") is True
            report["content_script_triage_answered"] = result.get("triage_answered") is True
            report["form_detected"] = result.get("form_detected") is True
            report["username_field_detected"] = result.get("username_detected") is True
            report["password_field_detected"] = result.get("password_detected") is True
    except RuntimeError:
        pass
    finally:
        if diagnostic_window:
            try:
                h.request(port, "DELETE", base + "/window", timeout_seconds=15)
            except RuntimeError:
                pass
        if original_window:
            try:
                h.request(port, "POST", base + "/window",
                          {"handle": original_window}, timeout_seconds=15)
            except RuntimeError:
                pass
    return report


def save_and_autofill_real_bitwarden_login(h, port, base, popup_url, *, verify_shortcut,
                                          graphical=False, browser_pid=None):
    """Use official Bitwarden add-cipher form and its real Firefox shortcut.

    No test JavaScript sets field values. The only expected password is typed
    into the actual Bitwarden editor and later compared read-only as a boolean.
    Any vault data exists only inside the throwaway CI network/container.
    """
    import secrets

    if not popup_url.startswith("moz-extension://"):
        raise RuntimeError("Official extension origin required for synthetic vault item")
    fake_user = "vulpra-ci-synthetic-user"
    fake_password = "CI-Only-" + secrets.token_urlsafe(26) + "A9!"
    server, login_url = _DisposableLoginForm.start()
    try:
        editor = popup_url.split("#", 1)[0] + "#/add-cipher?type=1"
        h.request(port, "POST", base + "/url", {"url": editor}, timeout_seconds=35)
        _await_registration_ui(h, port, base,
                               "vault-item-details-section input[formcontrolname='name']",
                               "#/add-cipher", timeout=55)
        _wd_type(h, port, base,
                 "vault-item-details-section input[formcontrolname='name']",
                 "Disposable CI Login")
        _wd_type(h, port, base,
                 "vault-login-details-section input[formcontrolname='username']",
                 fake_user)
        _wd_type(h, port, base,
                 "vault-login-details-section input[formcontrolname='password']",
                 fake_password)
        _wd_type(h, port, base,
                 "vault-autofill-uri-option input[formcontrolname='uri']",
                 login_url)
        # The editor's footer Save button exists outside the scrolling form.
        # Firefox headless can mark that footer as non-interactable. Send a
        # *real WebDriver Enter keystroke* to the URI input instead, triggering
        # the same Angular bitSubmit path without any JS click/submit bypass.
        save_ready = h.request(port, "POST", base + "/execute/sync", {
            "script": """
              const f=document.querySelector('form#cipherForm');
              const b=document.querySelector("popup-footer button[form='cipherForm'][type='submit']");
              return !!f && !!b && b.disabled === false &&
                !!f.querySelector("vault-autofill-uri-option input[formcontrolname='uri']");
            """,
            "args": [],
        })
        if save_ready is not True:
            raise RuntimeError("Bitwarden synthetic cipher form not ready for real submit")
        uri_input = _wd_element(
            h, port, base, "vault-autofill-uri-option input[formcontrolname='uri']")
        h.request(port, "POST", base + "/element/" + uri_input + "/value",
                  {"text": "\ue007", "value": ["\ue007"]},
                  timeout_seconds=25)

        saved = False
        deadline = time.monotonic() + 65
        while time.monotonic() < deadline:
            try:
                value = h.request(port, "POST", base + "/execute/sync", {
                    "script": """
                      return location.protocol === 'moz-extension:' &&
                        location.hash.startsWith('#/view-cipher?cipherId=');
                    """,
                    "args": [],
                }, timeout_seconds=15)
                if value is True:
                    saved = True
                    break
            except RuntimeError:
                pass
            time.sleep(0.4)
        if not saved:
            raise RuntimeError("Real Bitwarden login editor did not save a vault cipher")

        if not verify_shortcut:
            # Standalone storage gate: genuine extension editor produced a
            # saved-cipher route. Separate keyboard autofill remains OPEN.
            return {
                "verified": True,
                "real_extension_ui_saved_login": True,
                "real_extension_keyboard_shortcut_filled_form": False,
                "username_and_password_both_matched": False,
                "only_disposable_local_form": True,
                "saved_password_or_vault_token_in_report": False,
                "no_test_js_value_injection": True,
            }

        # Validate that the actual signed add-on registered the Firefox command,
        # rather than claiming the X11 keystroke succeeded without a binding.
        h.request(port, "POST", base + "/url",
                  {"url": popup_url.split("#", 1)[0] + "#/tabs/vault"},
                  timeout_seconds=30)
        shortcuts = h.request(port, "POST", base + "/execute/async", {
            "script": """
              const done = arguments[arguments.length - 1];
              browser.commands.getAll().then(commands => done(commands
                .filter(c => c.name === 'autofill_login')
                .map(c => ({enabled: !!c.shortcut,
                            expected: c.shortcut === 'Ctrl+Shift+L'}))))
                .catch(e => done({error: String(e).slice(0, 100)}));
            """, "args": [],
        }, timeout_seconds=25)
        if shortcuts != [{"enabled": True, "expected": True}]:
            raise RuntimeError("Real Bitwarden Firefox autofill keyboard command not bound to Ctrl+Shift+L")

        if graphical:
            # A Marionette-navigated window was not visible to the extension
            # (diagnostic: WebDriver URL matched, but browser.tabs.query had
            # no localhost URL). Create the page through *Bitwarden's real*
            # Firefox extension API, then attach WebDriver to that page.
            # Do not use JS to fill any form data or directly invoke autofill.
            created = h.request(port, "POST", base + "/execute/async", {
                "script": """
                  const url=arguments[0], done=arguments[arguments.length-1];
                  (async()=>{
                    const tab=await browser.tabs.create({url,active:true});
                    if(!Number.isInteger(tab?.id) || !Number.isInteger(tab?.windowId))
                      throw Error('No real browser tab created');
                    await browser.windows.update(tab.windowId,{focused:true});
                    const found=await browser.tabs.get(tab.id);
                    done({created:!!found,
                          correct_url:found?.url===url,
                          active:found?.active===true});
                  })().catch(e=>done({error:String(e).slice(0,110)}));
                """,
                "args": [login_url],
            }, timeout_seconds=30)
            if not isinstance(created, dict) or created.get("created") is not True:
                raise RuntimeError("Signed Bitwarden extension could not create real localhost tab: "
                                   + repr(created)[:180])
            deadline = time.monotonic() + 20
            attached = False
            while time.monotonic() < deadline and not attached:
                handles = h.request(port, "GET", base + "/window/handles",
                                    timeout_seconds=15)
                if not isinstance(handles, list):
                    raise RuntimeError("WebDriver did not return browser tab handles")
                for handle in handles:
                    try:
                        h.request(port, "POST", base + "/window",
                                  {"handle": handle}, timeout_seconds=15)
                        current = h.request(port, "GET", base + "/url",
                                            timeout_seconds=15)
                        if current == login_url:
                            attached = True
                            break
                    except RuntimeError:
                        continue
                if not attached:
                    time.sleep(0.25)
            if not attached:
                raise RuntimeError("WebDriver could not attach to Bitwarden-created localhost tab")
        else:
            h.request(port, "POST", base + "/url", {"url": login_url},
                      timeout_seconds=30)
        before = h.request(port, "POST", base + "/execute/sync", {
            "script": """
              const u=document.querySelector('#ci-user');
              const p=document.querySelector('#ci-pass');
              return {
                local: location.hostname === '127.0.0.1',
                fake_form: !!document.querySelector('form#ci-local-login'),
                initially_empty: !!u && !!p && u.value === '' && p.value === ''
              };
            """,
            "args": [],
        })
        if not isinstance(before, dict) or not all(
                before.get(k) is True for k in ("local", "fake_form", "initially_empty")):
            raise RuntimeError("Fake localhost login was not empty before actual Bitwarden autofill")

        if graphical:
            # Xvfb + a real X11 window manager; xdotool sends native XTEST
            # keyboard events after focusing *only* this session's Firefox
            # window, identified by the actual geckodriver browser PID.
            if (not os.environ.get("DISPLAY") or
                    not isinstance(browser_pid, int) or browser_pid <= 1):
                raise RuntimeError("Graphical autofill requires a valid display and browser PID")
            finder = ["xdotool", "search", "--onlyvisible", "--pid", str(browser_pid)]
            end = time.monotonic() + 15
            window_ids = []
            while time.monotonic() < end:
                result = subprocess.run(finder, capture_output=True, text=True,
                                        timeout=8, check=False)
                window_ids = [x.strip() for x in result.stdout.splitlines()
                              if x.strip().isdigit()]
                if result.returncode == 0 and window_ids:
                    break
                time.sleep(0.3)
            if not window_ids:
                raise RuntimeError("No visible test-owned Firefox X11 window for browser PID")
            target_window = window_ids[-1]
            # windowfocus alone does not necessarily set the EWMH active
            # browser window that Firefox uses for current-window tab lookup.
            subprocess.run(["xdotool", "windowactivate", "--sync", target_window],
                           check=True, capture_output=True, timeout=15)
            subprocess.run(["xdotool", "windowfocus", "--sync", target_window],
                           check=True, capture_output=True, timeout=15)
            subprocess.run(["xdotool", "key", "--clearmodifiers",
                            "--delay", "90", "ctrl+shift+l"],
                           check=True, capture_output=True, timeout=15)
        else:
            # Historical headless W3C keyboard route remains as a distinct
            # diagnostic; it does not count as native X11 command acceptance.
            h.request(port, "POST", base + "/actions", {
                "actions": [{"type": "key", "id": "vulpra-test-keyboard",
                             "actions": [
                                 {"type": "keyDown", "value": "\ue009"},
                                 {"type": "keyDown", "value": "\ue008"},
                                 {"type": "keyDown", "value": "l"},
                                 {"type": "keyUp", "value": "l"},
                                 {"type": "keyUp", "value": "\ue008"},
                                 {"type": "keyUp", "value": "\ue009"},
                             ]}]
            }, timeout_seconds=20)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            state = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  const u=document.querySelector('#ci-user');
                  const p=document.querySelector('#ci-pass');
                  return {
                    local: location.hostname === '127.0.0.1' &&
                           location.pathname === '/ci-login',
                    matched_username: !!u && u.value === arguments[0],
                    matched_password: !!p && p.value === arguments[1]
                  };
                """,
                "args": [fake_user, fake_password],
            }, timeout_seconds=15)
            if isinstance(state, dict) and all(state.get(k) is True for k in (
                    "local", "matched_username", "matched_password")):
                return {
                    "verified": True,
                    "real_extension_ui_saved_login": True,
                    "real_extension_keyboard_shortcut_filled_form": True,
                    "username_and_password_both_matched": True,
                    "only_disposable_local_form": True,
                    "saved_password_or_vault_token_in_report": False,
                    "no_test_js_value_injection": True,
                    "graphical_native_x11_shortcut": graphical,
                    "signed_addon_command_bound": True,
                }
            time.sleep(0.3)
        diagnostic = _diagnose_autofill_gap_without_secrets(
            h, port, base, popup_url, login_url)
        print("CI_BITWARDEN_AUTOFILL_DIAGNOSTIC=" + json.dumps(
            diagnostic, sort_keys=True), flush=True)
        raise RuntimeError("Actual Bitwarden Ctrl+Shift+L did not fill both synthetic fields")
    finally:
        server.shutdown()
        server.server_close()


def _complete_genuine_bitwarden_first_run_ui(h, port, base):
    """Perform real Bitwarden onboarding clicks; log only route/control booleans."""
    deadline = time.monotonic() + 35
    last = None
    counts = {"skip_default": 0, "carousel_login": 0}
    while time.monotonic() < deadline:
        last = h.request(port, "POST", base + "/execute/sync", {
            "script": """
              const visible = e => !!e && !!e.getClientRects().length;
              const email = document.querySelector("input[data-testid='login-email-input']");
              const skip = document.querySelector(
                "#default-password-manager-prompt_button_skip-for-now");
              const carousel = document.querySelector("app-intro-carousel");
              const carouselLogin = carousel ?
                document.querySelector(
                  "app-intro-carousel + button[type='button'] + button[type='button']") : null;
              return {
                route: location.hash.split('?')[0].slice(0,65),
                extension: location.protocol === 'moz-extension:',
                email_exists: !!email,
                email_visible: visible(email),
                skip_exists: !!skip,
                skip_visible: visible(skip),
                carousel_exists: !!carousel,
                carousel_login_exists: !!carouselLogin,
                carousel_login_visible: visible(carouselLogin),
                any_form: !!document.querySelector('form')
              };
            """,
            "args": [],
        }, timeout_seconds=20)
        if not isinstance(last, dict) or last.get("extension") is not True:
            raise RuntimeError("Independent Bitwarden onboarding left the signed extension origin")
        if last.get("email_visible") is True:
            return
        if last.get("skip_visible") is True:
            _wd_click(h, port, base, "#default-password-manager-prompt_button_skip-for-now")
            counts["skip_default"] += 1
        elif last.get("carousel_login_visible") is True:
            # The exact pinned client E2E uses the carousel-scoped Log in
            # button; CSS :last-of-type did not reliably identify this DOM.
            _wd_click(h, port, base,
                      "app-intro-carousel + button[type='button'] + button[type='button']")
            counts["carousel_login"] += 1
        else:
            time.sleep(0.35)
    print("CI_BITWARDEN_NEW_PROFILE_ONBOARDING=" + json.dumps(
        {"last": last, "click_counts": counts}, sort_keys=True), flush=True)
    raise RuntimeError("Real Bitwarden new-profile onboarding did not reach the login email form")


def sign_in_disposable_account_in_fresh_bitwarden(h, port, base, popup_url, account):
    """Real UI sign-in to a *previously created* Vaultwarden account in a new profile.

    The fake email/password stay in memory. No credential/token or vault DB goes
    to the report. This test never creates a new account in the second session.
    """
    if not isinstance(popup_url, str) or not popup_url.startswith("moz-extension://"):
        raise RuntimeError("Independent login requires the signed Bitwarden popup origin")
    if not isinstance(account, dict) or not account.get("email") or not account.get("master_password"):
        raise RuntimeError("Synthetic registration credentials unavailable for independent login")

    h.request(port, "POST", base + "/url",
              {"url": popup_url.split("#", 1)[0] + "#/login"}, timeout_seconds=35)
    _complete_genuine_bitwarden_first_run_ui(h, port, base)
    _await_registration_ui(h, port, base, "input[data-testid='login-email-input']",
                           "#/login", timeout=20)

    pristine = h.request(port, "POST", base + "/execute/sync", {
        "script": """
          const field = document.querySelector("input[data-testid='login-email-input']");
          return location.hash.startsWith('#/login') &&
            !!field && field.value === '' &&
            document.querySelectorAll("[data-testid='item-name']").length === 0;
        """,
        "args": [],
    }, timeout_seconds=15)
    if pristine is not True:
        raise RuntimeError("Independent Bitwarden browser was not an unregistered/login-only profile")

    _wd_type(h, port, base, "input[data-testid='login-email-input']", account["email"])
    _wd_click(h, port, base, "button[data-testid='login-continue-button']")
    _await_registration_ui(h, port, base, "input[data-testid='login-master-password-input']",
                           "#/login", timeout=60)
    _wd_type(h, port, base, "input[data-testid='login-master-password-input']",
             account["master_password"])
    _wd_click(h, port, base, "button[data-testid='login-submit-button']")

    deadline = time.monotonic() + 100
    authenticated = False
    while time.monotonic() < deadline:
        try:
            result = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  return location.protocol === 'moz-extension:' &&
                    (location.hash.startsWith('#/tabs/vault') ||
                     location.hash.startsWith('#/tabs/current') ||
                     location.hash.startsWith('#/vault'));
                """,
                "args": [],
            }, timeout_seconds=15)
            if result is True:
                authenticated = True
                break
        except RuntimeError:
            pass  # Angular may swap route while authenticated.
        time.sleep(0.4)
    if not authenticated:
        raise RuntimeError("Fresh signed Bitwarden extension never reached authenticated vault")

    h.request(port, "POST", base + "/url",
              {"url": popup_url.split("#", 1)[0] + "#/tabs/vault"},
              timeout_seconds=30)
    previous_record_visible = False
    deadline = time.monotonic() + 80
    while time.monotonic() < deadline:
        try:
            state = h.request(port, "POST", base + "/execute/sync", {
                "script": """
                  const items = [...document.querySelectorAll(
                    '[data-testid="item-name"]')];
                  return {
                    authenticated_route:
                      location.hash.startsWith('#/tabs/vault'),
                    original_record_visible:
                      items.some(n => n.textContent.trim() === 'Disposable CI Login')
                  };
                """,
                "args": [],
            }, timeout_seconds=15)
            if (isinstance(state, dict) and state.get("authenticated_route") is True
                    and state.get("original_record_visible") is True):
                previous_record_visible = True
                break
        except RuntimeError:
            pass
        time.sleep(0.4)
    if not previous_record_visible:
        raise RuntimeError("Independent Bitwarden sign-in did not display previously saved Vaultwarden cipher")

    return {
        "verified": True,
        "real_extension_master_password_sign_in": True,
        "real_browser_route_authenticated": True,
        "previous_saved_cipher_visible": True,
        "previous_account_reused_without_registration": True,
        "no_real_user_credentials": True,
        "no_secrets_logged_or_uploaded": True,
    }


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
        graphical = os.environ.get("VULPRA_BYOB_GRAPHICAL", "0") == "1"
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                    "NO_PROXY": "127.0.0.1,localhost",
                    "no_proxy": "127.0.0.1,localhost"})
        if graphical:
            if not env.get("DISPLAY"):
                raise RuntimeError("Expected isolated virtual X11 graphical display")
            env.pop("MOZ_HEADLESS", None)
            env.pop("WAYLAND_DISPLAY", None)
        else:
            env["MOZ_HEADLESS"] = "1"
            for var in ("DISPLAY", "WAYLAND_DISPLAY"):
                env.pop(var, None)
        env.pop("MOZ_REMOTE", None)
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
                session_request = {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser),
                            "args": ["-no-remote"] if graphical else ["-headless", "-no-remote"],
                            "profile": profile,
                            "prefs": {
                                "remote.prefs.recommended": False,
                                "browser.shell.checkDefaultBrowser": False,
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                            },
                        },
                    }}
                }
                value = h.request(port, "POST", "/session", session_request,
                                  timeout_seconds=60)
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
                registered = None
                account = None
                saved_item = None
                fresh_login = None
                if os.environ.get("VULPRA_BYOB_REGISTER_FAKE_ACCOUNT", "0") == "1":
                    registered, account = register_fake_account_in_real_bitwarden(
                        h, port, base, resource)
                    print("PASS: real Bitwarden registered and authenticated one disposable account in private Vaultwarden")
                if os.environ.get("VULPRA_BYOB_SAVE_FAKE_LOGIN", "0") == "1":
                    if registered is None:
                        raise RuntimeError("Saved-item test requires successfully registered disposable account")
                    verify_shortcut = os.environ.get("VULPRA_BYOB_VERIFY_REAL_AUTOFILL", "0") == "1"
                    saved_item = save_and_autofill_real_bitwarden_login(
                        h, port, base, resource, verify_shortcut=verify_shortcut,
                        graphical=graphical,
                        browser_pid=value.get("capabilities", {}).get("moz:processID"))
                    print("PASS: official Bitwarden created synthetic login cipher using real editor and server")
                    if verify_shortcut:
                        print("PASS: actual Firefox Bitwarden shortcut filled both localhost fields")
                h.verify_byob_defaults(port, base)

                if os.environ.get("VULPRA_BYOB_VERIFY_FRESH_LOGIN", "0") == "1":
                    if registered is None or saved_item is None or account is None:
                        raise RuntimeError("Independent fresh login requires a real saved record")
                    first_profile = value.get("capabilities", {}).get("moz:profile")
                    first_pid = value.get("capabilities", {}).get("moz:processID")
                    if not isinstance(first_profile, str) or not isinstance(first_pid, int):
                        raise RuntimeError("Original signed browser did not expose profile and PID")
                    # Close the entire original browser. No Firefox, extension
                    # storage, unlock state or session is reused for sign-in.
                    h.request(port, "DELETE", base, timeout_seconds=35)
                    session = None
                    installed = False

                    new_session = h.request(port, "POST", "/session",
                                            session_request, timeout_seconds=70)
                    if (not isinstance(new_session, dict) or not new_session.get("sessionId")
                            or new_session.get("capabilities", {}).get("acceptInsecureCerts") is not False):
                        raise RuntimeError("Fresh independent Vulpra browser session rejected")
                    session = str(new_session["sessionId"])
                    base = "/session/" + session
                    fresh_profile = new_session.get("capabilities", {}).get("moz:profile")
                    fresh_pid = new_session.get("capabilities", {}).get("moz:processID")
                    if (not isinstance(fresh_profile, str) or not isinstance(fresh_pid, int)
                            or first_profile == fresh_profile or first_pid == fresh_pid):
                        raise RuntimeError("New Vulpra session reused original browser/profile")
                    h.verify_byob_defaults(port, base)
                    test_browser_server_and_extension(h, port, base)
                    aid = h.request(port, "POST", base + "/moz/addon/install",
                                    {"path": str(xpi), "temporary": False}, timeout_seconds=60)
                    installed = aid == ADDON_ID
                    if not installed:
                        raise RuntimeError("Signed Bitwarden add-on not installed in new profile")
                    fresh_resource = addon_state_and_resource(h, port, base, popup)
                    verify_popup_managed_environment(h, port, base, fresh_resource)
                    fresh_login = sign_in_disposable_account_in_fresh_bitwarden(
                        h, port, base, fresh_resource, account)
                    fresh_login["independent_browser_process_and_profile"] = True
                    h.verify_byob_defaults(port, base)
                    print("PASS: independent new Vulpra browser/profile signed into existing disposable Vaultwarden and displayed saved cipher")

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
                    "vaultwarden_account_created": registered is not None and registered["real_bitwarden_client_registration"] is True,
                    "extension_authenticated_to_vaultwarden": registered is not None and registered["extension_authenticated_after_registration"] is True,
                    "disposable_registration": registered,
                    "disposable_login_record": saved_item,
                    "disposable_fresh_login": fresh_login,
                    "fresh_login_verified": fresh_login is not None and fresh_login["previous_saved_cipher_visible"] is True,
                    "record_saved_verified": saved_item is not None and saved_item["real_extension_ui_saved_login"] is True,
                    "record_autofill_verified": saved_item is not None and saved_item["username_and_password_both_matched"] is True,
                    "network_egress_permitted": False,
                    "graphical_virtual_x11_test": graphical,
                    "native_browser_recompiled": False,
                    "security_current": False, "release_ready": False,
                }
                (root / "byob-local-vaultwarden-proof.json").write_text(
                    json.dumps(proof, indent=2) + "\n")
                print("PASS: trusted HTTPS disposable Vaultwarden and real Bitwarden managed server endpoint in Vulpra")
                if registered is None:
                    print("LIMIT: no registration, login or vault-record autofill demonstrated")
                elif saved_item is None:
                    print("LIMIT: synthetic account only; saved-record/autofill untested")
                elif saved_item["username_and_password_both_matched"] is False:
                    print("LIMIT: synthetic cipher saved; manual browser shortcut autofill still unverified")
                else:
                    print("LIMIT: synthetic localhost fields and isolated ephemeral vault only; production integration not certified")
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
