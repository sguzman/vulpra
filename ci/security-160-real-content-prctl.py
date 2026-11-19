#!/usr/bin/env python3
"""Attempt native Firefox 160 content-worker seccomp denial without a rebuild.

Runs the original checksummed archive in a disposable profile. Registers a
test-only JSWindowActor whose content-side module invokes the upstream
PR_CAPBSET_READ policy case. No pref relaxations, no release/merge, no host
kernel changes. Proves denial only if the child PID is Gecko-authenticated.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading

HERE = Path(__file__).resolve().parent


def import_file(filename, alias):
    spec = importlib.util.spec_from_file_location(alias, HERE / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError("Missing authenticated existing runtime helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


wd = import_file("smoke-webextension-package-local.py", "vulpra_seccomp_wd")
obs = import_file("security-160-content-process-seccomp.py", "vulpra_seccomp_roles")


def verify_evidence(parent, child, roles, process):
    """Fail closed for anything other than real Gecko-tab EINVAL denial."""
    if (not isinstance(parent, dict) or type(parent.get("rv")) is not int or
            parent["rv"] != 1):
        raise RuntimeError("Same-browser-parent PR_CAPBSET_READ positive control failed")
    if (not isinstance(child, dict) or child.get("observationKind") !=
            "native_prctl_capbset_read_in_real_content" or
            type(child.get("processType")) is not int or
            child["processType"] != 2 or
            type(child.get("modeAtInvocation")) is not int or
            child["modeAtInvocation"] != 2 or
            type(child.get("processId")) is not int or
            child["processId"] <= 1 or
            type(child.get("rv")) is not int or child["rv"] != -1 or
            type(child.get("errno")) is not int or child["errno"] != 22):
        raise RuntimeError("No verified EINVAL for blocked prctl in actual content actor")
    pid = child["processId"]
    if (not isinstance(roles, dict) or roles.get(pid) != "tab" or
            not isinstance(process, dict) or process.get("pid") != pid or
            process.get("seccomp_mode") != 2 or
            process.get("seccomp_filter_count", 0) < 1 or
            process.get("no_new_privileges") != 1):
        raise RuntimeError("Native content-worker PID/role/installed seccomp proof missing")
    return {
        "native_prctl_capbset_read_parent_allowed": True,
        "native_prctl_capbset_read_tab_returned_einval": True,
        "actual_chromeutils_tab_role_authenticated": True,
        "same_tab_pid_has_seccomp_mode_2": True,
        "same_tab_seccomp_mode_2_at_syscall": True,
        "same_tab_pid_has_no_new_privileges": True,
        "forbidden_content_worker_syscall_denial_verified": True,
    }


def verify_home_write_evidence(parent, child, roles, process):
    """Prove genuine content worker cannot create a disposable HOME canary.

    This is filesystem isolation/broker denial, not proof that seccomp alone
    (rather than namespaces/broker) caused the open failure.
    """
    if (not isinstance(parent, dict) or type(parent.get("rv")) is not int or
            parent["rv"] != 1 or not isinstance(parent.get("writeControl"), dict) or
            parent["writeControl"].get("openSucceeded") is not True or
            parent["writeControl"].get("unlinked") is not True):
        raise RuntimeError("Real browser parent could not open/close/unlink HOME canary")
    if (not isinstance(child, dict) or
            child.get("observationKind") !=
            "native_open_create_home_denial_in_real_content" or
            type(child.get("processType")) is not int or
            child["processType"] != 2 or
            type(child.get("modeAtInvocation")) is not int or
            child["modeAtInvocation"] != 2 or
            type(child.get("processId")) is not int or
            child["processId"] <= 1 or
            type(child.get("rv")) is not int or child["rv"] != -1 or
            type(child.get("errno")) is not int or
            child["errno"] not in (1, 2, 13, 30)):
        raise RuntimeError("No native content-worker HOME file-create denial")
    pid = child["processId"]
    if (not isinstance(roles, dict) or roles.get(pid) != "tab" or
            not isinstance(process, dict) or process.get("pid") != pid or
            process.get("seccomp_mode") != 2 or
            process.get("seccomp_filter_count", 0) < 1 or
            process.get("no_new_privileges") != 1):
        raise RuntimeError("Actual filtered native Gecko tab PID or role missing")
    return {
        "same_browser_parent_home_write_control_succeeded": True,
        "same_browser_parent_home_write_canary_removed": True,
        "native_open_create_home_content_worker_denied": True,
        "actual_chromeutils_tab_role_authenticated": True,
        "same_tab_pid_has_seccomp_mode_2": True,
        "same_tab_seccomp_mode_2_at_syscall": True,
        "same_tab_pid_has_no_new_privileges": True,
        "filesystem_denial_not_exclusively_attributed_to_seccomp": True,
    }


def self_test():
    parent = {"rv": 1, "errno": 0}
    child = {"observationKind": "native_prctl_capbset_read_in_real_content",
             "processType": 2, "processId": 8001, "modeAtInvocation": 2,
             "rv": -1, "errno": 22}
    proc = {"pid": 8001, "seccomp_mode": 2,
            "seccomp_filter_count": 1, "no_new_privileges": 1}
    accepted = verify_evidence(parent, child, {8001: "tab"}, proc)
    assert accepted["forbidden_content_worker_syscall_denial_verified"] is True
    for forged in [
        ({"rv": -1, "errno": 22}, child, {8001: "tab"}, proc),
        (parent, {**child, "rv": 0}, {8001: "tab"}, proc),
        (parent, {**child, "errno": 1}, {8001: "tab"}, proc),
        (parent, {**child, "errno": 38}, {8001: "tab"}, proc),
        (parent, {**child, "modeAtInvocation": 0}, {8001: "tab"}, proc),
        (parent, {**child, "modeAtInvocation": 1}, {8001: "tab"}, proc),
        (parent, {**child, "modeAtInvocation": True}, {8001: "tab"}, proc),
        (parent, {**child, "processType": 0}, {8001: "tab"}, proc),
        (parent, {**child, "processId": 8002}, {8001: "tab"}, proc),
        (parent, child, {8001: "rdd"}, proc),
        (parent, child, {8001: "socket"}, proc),
        (parent, child, {}, proc),
        (parent, child, {8001: "tab"}, {**proc, "seccomp_mode": 0}),
        (parent, child, {8001: "tab"}, {**proc, "no_new_privileges": 0}),
        (parent, child, {8001: "tab"}, {**proc, "seccomp_filter_count": 0}),
        (parent, child, {8001: "tab"}, {**proc, "pid": 8002}),
        (parent, {**child, "rv": True}, {8001: "tab"}, proc),
    ]:
        try:
            verify_evidence(*forged)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Counterfeit seccomp-denial result accepted")
    print("PASS: seventeen forged parent/child/PID/role/filter/errno controls rejected")

    control = {"rv": 1, "writeControl":
               {"openSucceeded": True, "unlinked": True}}
    attempt = {"observationKind": "native_open_create_home_denial_in_real_content",
               "processType": 2, "processId": 8001,
               "modeAtInvocation": 2, "rv": -1, "errno": 13}
    assert verify_home_write_evidence(control, attempt, {8001: "tab"}, proc)[
        "native_open_create_home_content_worker_denied"] is True
    for forged in [
        ({**control, "writeControl": {"openSucceeded": False,
                                     "unlinked": True}}, attempt, {8001: "tab"}, proc),
        ({**control, "writeControl": {"openSucceeded": True,
                                     "unlinked": False}}, attempt, {8001: "tab"}, proc),
        (control, {**attempt, "rv": 0}, {8001: "tab"}, proc),
        (control, {**attempt, "errno": 0}, {8001: "tab"}, proc),
        (control, {**attempt, "errno": True}, {8001: "tab"}, proc),
        (control, {**attempt, "processType": 0}, {8001: "tab"}, proc),
        (control, {**attempt, "modeAtInvocation": 0}, {8001: "tab"}, proc),
        (control, {**attempt, "processId": 8002}, {8001: "tab"}, proc),
        (control, attempt, {8001: "socket"}, proc),
        (control, attempt, {8001: "tab"}, {**proc, "seccomp_filter_count": 0}),
        (control, attempt, {8001: "tab"}, {**proc, "no_new_privileges": 0}),
    ]:
        try:
            verify_home_write_evidence(*forged)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Counterfeit HOME-write denial accepted")
    print("PASS: eleven forged native HOME-write controls rejected")



def run(repo, output, home_write=False):
    if output.exists():
        raise RuntimeError("Refusing to overwrite any existing sandbox evidence")
    archive = wd.verified_archive(repo)
    if not archive.name.startswith("vulpra-local-firefox160-"):
        raise RuntimeError("Expected source-pinned native Firefox 160 archive")
    gecko = shutil.which("geckodriver")
    if not gecko:
        raise RuntimeError("Missing verified geckodriver")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="vulpra160-real-prctl-") as td:
        work = Path(td)
        app = work / "app"
        app.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(app)], check=True)
        inis = list(app.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Not original native Vulpra browser")
        binary = wd.select_binary(inis[0].parent)
        # Only modify the disposable extraction: place test actors beside the
        # browser binary and bind them to a resource:// trusted module scheme.
        # Never modify the authenticated source/archive or sandbox preferences.
        module_dir = inis[0].parent / "vulpra-seccomp-test-only"
        module_dir.mkdir()
        for name in ("VulpraSeccompProbeChild.sys.mjs",
                     "VulpraSeccompProbeParent.sys.mjs"):
            shutil.copyfile(HERE / name, module_dir / name)
        home = work / "home"
        original = home / ".mozilla/firefox/profiles.ini"
        original.parent.mkdir(parents=True)
        sentinel = b"Must preserve pre-existing Firefox profile in syscall test\n"
        original.write_bytes(sentinel)
        canary_path = home / "vulpra-write-canary"
        if canary_path.exists():
            raise RuntimeError("HOME canary unexpectedly exists before test")
        profile = work / "isolated-profile"
        profile.mkdir()
        env = os.environ.copy()
        env.update({"HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
                    "MOZ_HEADLESS": "1", "NO_PROXY": "localhost,127.0.0.1",
                    "no_proxy": "localhost,127.0.0.1"})
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE",
                    "MOZ_DISABLE_CONTENT_SANDBOX", "MOZ_PERMISSIVE_CONTENT_SANDBOX"):
            env.pop(key, None)
        server = wd.http.server.ThreadingHTTPServer(("127.0.0.1", 0), wd.LocalPage)
        server.paths = []
        threading.Thread(target=server.serve_forever, daemon=True).start()
        port = wd.find_port()
        process, session_id = None, None
        try:
            with (work / "geckodriver.log").open("wb") as log:
                process = subprocess.Popen(
                    [gecko, "--host", "127.0.0.1", "--port", str(port),
                     "--allow-system-access"], env=env,
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                wd.wait_ready(port, process)
                session = wd.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(binary),
                            "args": ["-headless", "-no-remote", "-profile", str(profile)],
                            "prefs": {"app.update.enabled": False,
                                      "extensions.update.enabled": False,
                                      "browser.shell.checkDefaultBrowser": False}
                        }
                    }}
                }, timeout_seconds=60)
                session_id = session.get("sessionId")
                caps = session.get("capabilities", {})
                if (not session_id or not caps.get("browserVersion", "").startswith("160.") or
                        caps.get("acceptInsecureCerts") is not False):
                    raise RuntimeError("Native Firefox 160/TLS WebDriver identity mismatch")
                browser_pid = caps.get("moz:processID")
                if type(browser_pid) is not int or browser_pid <= 1:
                    raise RuntimeError("Native browser PID missing")
                base = "/session/" + session_id
                wd.request(port, "POST", base + "/moz/context", {"context": "chrome"})
                module_uri = module_dir.as_uri() + "/"
                result = wd.request(port, "POST", base + "/execute/sync", {
                    "script": """
                        const [directory, canary, homeWrite] = arguments;
                        const protocol = Services.io.getProtocolHandler("resource")
                            .QueryInterface(Ci.nsIResProtocolHandler);
                        protocol.setSubstitution("vulpra-seccomp-probe",
                            Services.io.newURI(directory));
                        ChromeUtils.registerWindowActor("VulpraSeccompProbe", {
                          allFrames: false,
                          safeForUntrustedWebProcess: true,
                          parent: {
                            esModuleURI: "resource://vulpra-seccomp-probe/VulpraSeccompProbeParent.sys.mjs"
                          },
                          child: {
                            esModuleURI: "resource://vulpra-seccomp-probe/VulpraSeccompProbeChild.sys.mjs"
                          }
                        });
                        const {ctypes} = ChromeUtils.importESModule(
                            "resource://gre/modules/ctypes.sys.mjs");
                        const libc = ctypes.open("libc.so.6");
                        try {
                          const prctl = libc.declare("prctl", ctypes.default_abi,
                            ctypes.int, ctypes.int,
                            ctypes.unsigned_long, ctypes.unsigned_long,
                            ctypes.unsigned_long, ctypes.unsigned_long);
                          const rv = prctl(23, 0, 0, 0, 0);
                          const errno = ctypes.errno;
                          if (!homeWrite) {
                            return {rv, errno};
                          }
                          const open = libc.declare("open", ctypes.default_abi,
                            ctypes.int, ctypes.char.ptr, ctypes.int,
                            ctypes.unsigned_int);
                          const close = libc.declare("close", ctypes.default_abi,
                            ctypes.int, ctypes.int);
                          const unlink = libc.declare("unlink", ctypes.default_abi,
                            ctypes.int, ctypes.char.ptr);
                          const fd = open(canary, 193, 384);
                          const openSucceeded = fd >= 0;
                          let unlinked = false;
                          if (openSucceeded) {
                            unlinked = close(fd) === 0 && unlink(canary) === 0;
                          }
                          return {rv, errno,
                            writeControl:{openSucceeded, unlinked}};
                        } finally { libc.close(); }
                    """, "args": [module_uri, str(canary_path), home_write]
                })
                if (not isinstance(result, dict) or
                        type(result.get("rv")) is not int or result["rv"] != 1):
                    raise RuntimeError("Original browser-parent native PR_CAPBSET_READ control failed")
                wd.request(port, "POST", base + "/moz/context", {"context": "content"})
                wd.request(port, "POST", base + "/url", {
                    "url": f"http://127.0.0.1:{server.server_port}/extension"})
                if wd.request(port, "POST", base + "/execute/sync", {
                        "script": "return document.title;", "args": []}) != "Vulpra extension smoke":
                    raise RuntimeError("Actual localhost content did not load")
                wd.request(port, "POST", base + "/moz/context", {"context": "chrome"})
                actor_result = wd.request(port, "POST", base + "/execute/async", {
                    "script": """
                        const done = arguments[arguments.length-1];
                        const [canary, homeWrite] = arguments;
                        (async () => {
                          const actor = gBrowser.selectedBrowser.browsingContext
                            .currentWindowGlobal.getActor("VulpraSeccompProbe");
                          return await actor.sendQuery(
                            homeWrite ? "VulpraTestDeniedHomeWrite" :
                              "VulpraTestBlockedPrctl",
                            {token:homeWrite ? "vulpra160-denied-home-write" :
                              "vulpra160-prctl-capbset-read",
                             canaryPath:canary});
                        })().then(done, e=>done({probeError:String(e?.name||"actor-failed")+" "+String(e?.message||"").replace(/file:\/\/[^ ]+/g,"[redacted-file-uri]").slice(0,150)}));
                    """, "args": [str(canary_path), home_write]
                }, timeout_seconds=45)
                census = wd.request(port, "POST", base + "/execute/async", {
                    "script": """
                      const done=arguments[arguments.length-1];
                      ChromeUtils.requestProcInfo().then(
                        ({pid,children})=>done({parent_pid:pid,
                         children:children.map(({pid,type})=>({pid,type}))}),
                        _=>done({error:"process-census-failed"}));
                    """, "args": []
                }, timeout_seconds=45)
                roles = obs.verify_chrome_process_roles(census, browser_pid)
                pid = actor_result.get("processId") if isinstance(actor_result, dict) else None
                if type(pid) is not int:
                    kind = actor_result.get("probeError", "missing-result") if isinstance(
                        actor_result, dict) else "unstructured-result"
                    if not isinstance(kind, str) or len(kind) > 180:
                        kind = "invalid-error-kind"
                    raise RuntimeError("No native content-side actor process ID: " + kind)
                proc = obs.read_process(pid)
                accepted = (verify_home_write_evidence(result, actor_result, roles, proc)
                            if home_write else verify_evidence(result, actor_result, roles, proc))
                if canary_path.exists():
                    raise RuntimeError("HOME write canary unexpectedly remains after test")
                if original.read_bytes() != sentinel:
                    raise RuntimeError("Existing Firefox profile marker altered")
                proof = {
                    "schema_version": 1, "status": "pass",
                    "native_package_sha256": digest,
                    "web_driver_browser_version": caps["browserVersion"],
                    "original_firefox_profile_preserved": True,
                    "linux_content_sandbox_enabled": True,
                    "no_sandbox_prefs_or_host_kernel_policy_relaxed": True,
                    **accepted,
                    "tested_syscall": ("open(O_CREAT|O_EXCL|O_WRONLY,HOME canary)"
                                       if home_write else "prctl(PR_CAPBSET_READ,CAP_CHOWN)"),
                    "expected_upstream_seccomp_result": (
                        None if home_write else "EINVAL"),
                    "expected_upstream_denial": ("native HOME write refused"
                                                 if home_write else "EINVAL"),
                    "actual_errno": actor_result["errno"],
                    "raw_pids_or_user_data_archived": False,
                    "security_current": False, "release_ready": False
                }
                output.write_text(json.dumps(proof, indent=2)+"\n")
                print("PASS: genuine Firefox 160 tab HOME-create denied" if home_write
                      else "PASS: genuine Firefox 160 tab prctl returned EINVAL")
        finally:
            if session_id:
                try:
                    wd.request(port, "DELETE", "/session/" + session_id)
                except (OSError, RuntimeError):
                    pass
            if process is not None:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                    process.wait(timeout=7)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--self-test"]:
            self_test()
        elif len(sys.argv) == 4 and sys.argv[1] == "--home-write":
            run(Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve(),
                home_write=True)
        elif len(sys.argv) == 3:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAIL: "+str(exc), file=sys.stderr)
        raise SystemExit(1)
