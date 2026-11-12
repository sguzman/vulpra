#!/usr/bin/env python3
"""Bounded Firefox 160 Linux content-process sandbox observation on CI.

Observes a real, verified, packaged Vulpra 160 browser with a localhost page,
a disposable HOME and profile, then correlates its WebDriver parent PID to
native content processes and /proc seccomp status. This does not probe syscall
denial, prove policy strength or authorize release/security-current claims.
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
import time

HERE = Path(__file__).resolve().parent
helper_path = HERE / "smoke-webextension-package-local.py"
spec = importlib.util.spec_from_file_location("vulpra_160_wd", helper_path)
if spec is None or spec.loader is None:
    raise RuntimeError("Missing Vulpra WebDriver helper")
wd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wd)


def status_fields(raw: str) -> dict:
    values = {}
    for line in raw.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key] = value.strip()
    def num(name):
        value = values.get(name, "")
        if not value.isascii() or not value.isdecimal():
            raise RuntimeError("Missing numeric process status field " + name)
        return int(value)
    return {
        "ppid": num("PPid"),
        "seccomp_mode": num("Seccomp"),
        "seccomp_filter_count": num("Seccomp_filters"),
        "no_new_privileges": num("NoNewPrivs"),
    }


def read_process(pid):
    root = Path("/proc") / str(pid)
    cmd = (root / "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace")
    exe = os.path.realpath(root / "exe")
    fields = status_fields((root / "status").read_text())
    return {"pid": pid, "exe": exe, "cmdline": cmd, **fields}


def content_processes(browser_binary, parent_pid):
    found = []
    target = os.path.realpath(browser_binary)
    for item in Path("/proc").iterdir():
        if not item.name.isdecimal():
            continue
        try:
            process = read_process(int(item.name))
            if process["exe"] != target:
                continue
            if "-contentproc" not in process["cmdline"]:
                continue
            if process["pid"] == parent_pid:
                continue
            found.append(process)
        except (OSError, RuntimeError, PermissionError):
            continue
    return found


def evaluate_sandbox(parent, children, pref_level):
    """Only leaf content workers count as sandboxed; surface spawners separately.

    Firefox's observed topology includes one direct child with NO seccomp
    filter which spawns real filtered content processes. This test must not
    conceal or mislabel that child as sandboxed, and must never claim actual
    syscall-denial enforcement or Mozilla filter-policy correctness.
    """
    if not isinstance(pref_level, int) or isinstance(pref_level, bool) or pref_level <= 0:
        raise RuntimeError("Firefox Linux content sandbox level disabled/unavailable")
    if not children:
        raise RuntimeError("No real native Firefox -contentproc descendants observed")
    pids = {p["pid"] for p in children}
    if len(pids) != len(children) or parent["pid"] in pids:
        raise RuntimeError("Duplicate or fabricated native process identities")
    spawning = [p for p in children if p["ppid"] == parent["pid"]]
    if not spawning:
        raise RuntimeError("No directly parented browser spawning process found")
    spawner_pids = {p["pid"] for p in spawning}
    workers = [p for p in children if p["pid"] not in spawner_pids]
    if not workers:
        raise RuntimeError("No separate content worker descendants found")
    # Require every spawner to have a worker, and every worker to be linked
    # to one of the browser's observed native child spawning processes.
    worker_ppids = {p["ppid"] for p in workers}
    if any(p["pid"] not in worker_ppids for p in spawning):
        raise RuntimeError("Unexplained direct browser content-process child")
    if any(p["ppid"] not in spawner_pids for p in workers):
        raise RuntimeError("Content-process worker parent not authenticated")
    if any(p["seccomp_mode"] != 2 or p["seccomp_filter_count"] < 1 or
           p["no_new_privileges"] != 1 for p in workers):
        raise RuntimeError("A live content worker lacked seccomp/NoNewPrivs enforcement")
    # Spawners are explicitly reported, including unfiltered spawners.
    unfiltered = [p for p in spawning if p["seccomp_mode"] != 2 or p["seccomp_filter_count"] < 1]
    return {
        "linux_content_sandbox_level": pref_level,
        "observed_native_content_process_count": len(children),
        "actual_content_worker_count": len(workers),
        "browser_child_spawning_process_count": len(spawning),
        "browser_child_unfiltered_spawning_process_count": len(unfiltered),
        "all_worker_processes_descend_from_browser_spawners": True,
        "all_observed_content_workers_have_seccomp_filters": True,
        "all_observed_content_workers_have_no_new_privileges": True,
        "unfiltered_browser_child_process_is_explicitly_reported": True,
        "spawning_process_statuses": [
            {
                "seccomp_mode": p["seccomp_mode"],
                "seccomp_filter_count": p["seccomp_filter_count"],
                "no_new_privileges": p["no_new_privileges"],
                "spawned_worker_count": sum(w["ppid"] == p["pid"] for w in workers),
            } for p in spawning
        ],
        "content_worker_statuses": [
            {
                "seccomp_mode": p["seccomp_mode"],
                "seccomp_filter_count": p["seccomp_filter_count"],
                "no_new_privileges": p["no_new_privileges"],
            } for p in workers
        ],
        "parent_process_seccomp_mode": parent["seccomp_mode"],
        "parent_process_filter_count": parent["seccomp_filter_count"],
        "seccomp_syscall_denial_actually_exercised": False,
        "content_sandbox_policy_strength_verified": False,
    }


def self_test():
    raw = "Name:\tvulpra\nPPid:\t400\nSeccomp:\t2\nSeccomp_filters:\t3\nNoNewPrivs:\t1\n"
    browser = {"pid": 327, "seccomp_mode": 0, "seccomp_filter_count": 0}
    spawner = {"pid": 400, "ppid": 327, "seccomp_mode": 0,
               "seccomp_filter_count": 0, "no_new_privileges": 0}
    worker = {"pid": 401, **status_fields(raw)}
    observed = evaluate_sandbox(browser, [spawner, worker], 6)
    assert observed["all_observed_content_workers_have_seccomp_filters"]
    assert observed["browser_child_unfiltered_spawning_process_count"] == 1
    for invalid, level in [
        ([spawner, {**worker, "seccomp_mode": 0}], 6),
        ([spawner, {**worker, "seccomp_filter_count": 0}], 6),
        ([spawner, {**worker, "no_new_privileges": 0}], 6),
        ([spawner, {**worker, "ppid": 1}], 6),
        ([spawner], 6),
        ([worker], 6),
        ([spawner, worker, {**spawner, "pid": 402}], 6),
        ([], 6),
        ([spawner, worker], 0),
    ]:
        try:
            evaluate_sandbox(browser, invalid, level)
        except RuntimeError:
            continue
        raise AssertionError("Forged, missing, orphaned or unfiltered worker accepted")
    print("PASS: topology-aware seccomp parser and nine negative process/sandbox cases")


def run(repo: Path, output: Path):
    archive = wd.verified_archive(repo)
    if not archive.name.startswith("vulpra-local-firefox160-"):
        raise RuntimeError("Not a pinned Firefox 160 packaged archive")
    gecko = shutil.which("geckodriver")
    if not gecko:
        raise RuntimeError("No SHA-256-verified geckodriver on PATH")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="vulpra160-sandbox-") as directory:
        work = Path(directory)
        unpacked = work / "archive"
        unpacked.mkdir()
        subprocess.run(["tar", "-xf", str(archive), "-C", str(unpacked)], check=True)
        inis = list(unpacked.rglob("application.ini"))
        if len(inis) != 1 or "Name=Vulpra" not in inis[0].read_text().splitlines():
            raise RuntimeError("Missing exact Vulpra native package identity")
        browser = wd.select_binary(inis[0].parent)
        home = work / "home"
        home.mkdir()
        original = home / ".mozilla/firefox/profiles.ini"
        original.parent.mkdir(parents=True)
        sentinel = b"pre-existing Firefox profile must not change in native sandbox test\n"
        original.write_bytes(sentinel)
        profile = work / "isolated-profile"
        profile.mkdir()
        env = os.environ.copy()
        env.update({
            "HOME": str(home), "XDG_DATA_HOME": str(home / ".local/share"),
            "MOZ_HEADLESS": "1", "NO_PROXY": "localhost,127.0.0.1",
            "no_proxy": "localhost,127.0.0.1",
        })
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "MOZ_REMOTE"):
            env.pop(name, None)
        server = wd.http.server.ThreadingHTTPServer(("127.0.0.1", 0), wd.LocalPage)
        server.paths = []
        threading.Thread(target=server.serve_forever, daemon=True).start()
        port = wd.find_port()
        process, session_id = None, None
        try:
            with (work / "geckodriver.log").open("wb") as logfile:
                process = subprocess.Popen(
                    [gecko, "--host", "127.0.0.1", "--port", str(port),
                     "--allow-system-access"], env=env,
                    stdout=logfile, stderr=subprocess.STDOUT, start_new_session=True,
                )
                wd.wait_ready(port, process)
                session = wd.request(port, "POST", "/session", {
                    "capabilities": {"alwaysMatch": {
                        "browserName": "firefox", "acceptInsecureCerts": False,
                        "moz:firefoxOptions": {
                            "binary": str(browser),
                            "args": ["-headless", "-no-remote", "-profile", str(profile)],
                            "prefs": {
                                "app.update.enabled": False,
                                "extensions.update.enabled": False,
                                "browser.shell.checkDefaultBrowser": False,
                            },
                        },
                    }}
                }, timeout_seconds=60)
                session_id = session.get("sessionId") if isinstance(session, dict) else None
                caps = session.get("capabilities", {}) if isinstance(session, dict) else {}
                if not session_id or not str(caps.get("browserVersion", "")).startswith("160."):
                    raise RuntimeError("Not a Firefox 160 WebDriver session")
                if caps.get("acceptInsecureCerts") is not False:
                    raise RuntimeError("Firefox WebDriver unexpectedly bypasses TLS checks")
                browser_pid = caps.get("moz:processID")
                if not isinstance(browser_pid, int) or browser_pid <= 1:
                    raise RuntimeError("WebDriver did not return a native browser process PID")
                parent = read_process(browser_pid)
                if os.path.realpath(parent["exe"]) != os.path.realpath(browser):
                    raise RuntimeError("Unexpected executable for Firefox 160 parent process")
                base = "/session/" + session_id
                wd.request(port, "POST", base + "/url", {
                    "url": f"http://127.0.0.1:{server.server_port}/extension",
                })
                title = wd.request(port, "POST", base + "/execute/sync", {
                    "script": "return document.title;", "args": [],
                })
                if title != "Vulpra extension smoke":
                    raise RuntimeError("Localhost page did not load as real browser content")
                wd.request(port, "POST", base + "/moz/context", {"context": "chrome"})
                try:
                    pref_level = wd.request(port, "POST", base + "/execute/sync", {
                        "script": """return Services.prefs.getIntPref(
                          "security.sandbox.content.level", 0);""",
                        "args": [],
                    })
                finally:
                    wd.request(port, "POST", base + "/moz/context", {"context": "content"})
                deadline = time.monotonic() + 15
                evidence = None
                last = []
                while time.monotonic() < deadline:
                    last = content_processes(browser, browser_pid)
                    try:
                        evidence = evaluate_sandbox(parent, last, pref_level)
                        break
                    except RuntimeError:
                        time.sleep(0.3)
                if evidence is None:
                    # One bounded, non-sensitive diagnostic snapshot only:
                    # never copy process command lines, paths or environments.
                    states = [
                        {"direct_child": child["ppid"] == browser_pid,
                         "seccomp": child["seccomp_mode"],
                         "filters": child["seccomp_filter_count"],
                         "nnp": child["no_new_privileges"]}
                        for child in last
                    ]
                    print("AUDIT: content-sandbox-pref-level=" + repr(pref_level) +
                          " content-process-states=" + json.dumps(states), flush=True)
                    raise RuntimeError(
                        "Native content-process sandbox evidence not confirmed; "
                        f"found {len(last)} native content processes"
                    )
                if original.read_bytes() != sentinel:
                    raise RuntimeError("Existing Firefox profile was altered")
                report = {
                    "schema_version": 1,
                    "status": "pass",
                    "native_package_sha256": digest,
                    "web_driver_browser_version": caps["browserVersion"],
                    "verified_real_localhost_content": True,
                    "original_firefox_profile_preserved": True,
                    **evidence,
                    "release_ready": False,
                    "security_current": False,
                    "limits": [
                        "Linux seccomp mode/filter presence, not attempted syscall denial",
                        "No proof each filter is the expected Mozilla sandbox policy",
                        "Not a full Safe Browsing or external-network egress test",
                        "Not a VAAPI/DMABuf or other platform security audit",
                    ],
                }
                if output.exists():
                    raise RuntimeError("Refusing to replace existing sandbox proof")
                output.write_text(json.dumps(report, indent=2) + "\n")
                print("PASS: real Firefox 160 content processes have observable seccomp filters", flush=True)
                print("LIMIT: does not prove sandbox policy correctness or syscall denial", flush=True)
        finally:
            if session_id:
                try:
                    wd.request(port, "DELETE", "/session/" + session_id)
                except RuntimeError:
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
        elif len(sys.argv) == 3:
            run(Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve())
        else:
            raise RuntimeError("Usage: SCRIPT --self-test OR SCRIPT REPO OUTPUT_JSON")
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
