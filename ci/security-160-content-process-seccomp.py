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
import re
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



def evaluate_worker_thread_seccomp(children, parent_pid, samples_by_pid):
    """Fail closed on any visible unfiltered content *thread*, not just PID.

    Thread statuses are read without ptrace or process injection. We check
    live Firefox worker thread groups only, NOT the unfiltered forkserver/
    spawning processes explicitly reported by evaluate_sandbox().
    """
    spawners = {p["pid"] for p in children if p["ppid"] == parent_pid}
    workers = [p for p in children if p["pid"] not in spawners]
    required = {p["pid"] for p in workers}
    if not required or set(samples_by_pid) != required:
        raise RuntimeError("Content-worker thread group missing or spoofed")
    checked_tids = set()
    count = 0
    group_stats = []
    for pid in sorted(required):
        tasks = samples_by_pid[pid]
        if not isinstance(tasks, list) or not tasks:
            raise RuntimeError("Content-worker task set is empty")
        tids = {t.get("tid") for t in tasks if isinstance(t, dict)}
        if pid not in tids or len(tids) != len(tasks) or any(
                not isinstance(tid, int) or isinstance(tid, bool) or tid <= 1
                for tid in tids):
            raise RuntimeError("Content-worker task group does not contain unique main TID")
        for task in tasks:
            tid = task["tid"]
            if tid in checked_tids:
                raise RuntimeError("Thread TID incorrectly shared between worker groups")
            checked_tids.add(tid)
            if (type(task.get("seccomp_mode")) is not int or
                    type(task.get("seccomp_filter_count")) is not int or
                    type(task.get("no_new_privileges")) is not int or
                    task["seccomp_mode"] != 2 or
                    task["seccomp_filter_count"] < 1 or
                    task["no_new_privileges"] != 1):
                raise RuntimeError("Live content-worker thread missing seccomp/NoNewPrivs")
            count += 1
        group_stats.append({"thread_count": len(tasks),
                            "minimum_observed_thread_seccomp_filters":
                                min(t["seccomp_filter_count"] for t in tasks)})
    if count < len(workers):
        raise RuntimeError("Fewer verified content threads than content workers")
    return {
        "observed_content_worker_thread_count": count,
        "observed_content_worker_thread_groups": len(group_stats),
        "all_observed_content_worker_threads_have_seccomp_filters": True,
        "all_observed_content_worker_threads_have_no_new_privileges": True,
        "all_observed_content_worker_thread_groups_include_main_tid": True,
        "worker_thread_groups": group_stats,
        "all_possible_transient_threads_exhaustively_audited": False,
        "seccomp_syscall_denial_actually_exercised": False,
        "content_sandbox_policy_strength_verified": False,
    }


def capture_worker_thread_seccomp(children, parent_pid):
    """Read /proc/<worker>/task/<tid>/status with no attachment or mutation.

    A thread that exits between listing and reading is ignored; process-main
    disappearance and a worker with no live tasks are hard failures. This is
    one bounded observation, not a perpetual thread-creation guarantee.
    """
    spawners = {p["pid"] for p in children if p["ppid"] == parent_pid}
    workers = [p for p in children if p["pid"] not in spawners]
    observed = {}
    for worker in workers:
        pid = worker["pid"]
        task_root = Path("/proc") / str(pid) / "task"
        tids = sorted(int(p.name) for p in task_root.iterdir()
                      if p.name.isdecimal())
        tasks = []
        for tid in tids:
            try:
                fields = status_fields(
                    (task_root / str(tid) / "status").read_text())
            except FileNotFoundError:
                # A thread may exit between enumeration and status read;
                # any disappeared main TID is not accepted.
                if tid == pid:
                    raise RuntimeError("Content-worker main thread vanished")
                continue
            tasks.append({"tid": tid,
                          "seccomp_mode": fields["seccomp_mode"],
                          "seccomp_filter_count": fields["seccomp_filter_count"],
                          "no_new_privileges": fields["no_new_privileges"]})
        observed[pid] = tasks
    return evaluate_worker_thread_seccomp(children, parent_pid, observed)



NAMESPACE_KINDS = ("user", "ipc", "net", "mnt", "pid")


def evaluate_worker_namespaces(parent_pid, children, parent_namespaces,
                               worker_namespaces, parent_root, worker_roots):
    """Compare procfs namespace symlink IDs; never publish inode IDs or paths.

    Kernel/graphics support may alter Firefox's namespace selection.
    A matching namespace is reported honestly and is NOT treated as
    unfiltered seccomp or an automatically failed namespace promise.
    """
    spawners = {x["pid"] for x in children if x["ppid"] == parent_pid}
    workers = {x["pid"] for x in children if x["pid"] not in spawners}
    if not workers or set(worker_namespaces) != workers or set(worker_roots) != workers:
        raise RuntimeError("Missing/forged authenticated worker namespace groups")
    if set(parent_namespaces) != set(NAMESPACE_KINDS):
        raise RuntimeError("Missing/extra parent namespace kind")
    if parent_root is not None and (
            not isinstance(parent_root, tuple) or len(parent_root) != 2 or
            any(type(v) is not int or v <= 0 for v in parent_root)):
        raise RuntimeError("Malformed parent root directory identity")
    for kind, identity in parent_namespaces.items():
        if identity is not None and (
                not isinstance(identity, str) or
                re.fullmatch(re.escape(kind) + r":\[[0-9]+\]", identity) is None):
            raise RuntimeError("Invalid procfs parent namespace identity")
    results = []
    accessible = 0
    for pid in sorted(workers):
        info = worker_namespaces[pid]
        if not isinstance(info, dict) or set(info) != set(NAMESPACE_KINDS):
            raise RuntimeError("Worker namespace kinds omitted/forged")
        statuses = {}
        for kind in NAMESPACE_KINDS:
            value = info[kind]
            if value is not None and (
                    not isinstance(value, str) or
                    re.fullmatch(re.escape(kind) + r":\[[0-9]+\]", value) is None):
                raise RuntimeError("Invalid worker namespace symlink identity")
            if parent_namespaces[kind] is not None and value is not None:
                statuses[kind] = value != parent_namespaces[kind]
                accessible += 1
            else:
                statuses[kind] = None
        root = worker_roots[pid]
        if root is not None and (
                not isinstance(root, tuple) or len(root) != 2 or
                any(type(v) is not int or v <= 0 for v in root)):
            raise RuntimeError("Invalid worker root identity")
        results.append({
            "namespace_differs_from_browser_parent": statuses,
            "worker_root_differs_from_browser_parent":
                root != parent_root if root is not None and
                parent_root is not None else None,
        })
    if accessible < len(workers):
        raise RuntimeError("Insufficient readable parent/worker procfs namespaces")
    kinds = {
        kind: sum(row["namespace_differs_from_browser_parent"][kind] is True
                  for row in results)
        for kind in NAMESPACE_KINDS
    }
    unknown = {
        kind: sum(row["namespace_differs_from_browser_parent"][kind] is None
                  for row in results)
        for kind in NAMESPACE_KINDS
    }
    return {
        "observed_content_worker_namespace_groups": len(workers),
        "observed_readable_namespace_comparisons": accessible,
        "content_worker_distinct_namespace_counts_by_kind": kinds,
        "content_worker_unreadable_namespace_counts_by_kind": unknown,
        "content_worker_distinct_root_directory_count":
            sum(row["worker_root_differs_from_browser_parent"] is True
                for row in results),
        "content_worker_unreadable_root_directory_count":
            sum(row["worker_root_differs_from_browser_parent"] is None
                for row in results),
        "content_worker_namespace_relative_to_browser": results,
        "namespace_observation_read_only": True,
        "process_namespace_policy_strength_verified": False,
        "all_kernel_namespace_features_guaranteed_available": False,
        "seccomp_syscall_denial_actually_exercised": False,
    }


def capture_worker_namespaces(children, browser_pid):
    """Read /proc symlinks and root metadata only; do not attach or ptrace."""
    spawners = {x["pid"] for x in children if x["ppid"] == browser_pid}
    workers = [x for x in children if x["pid"] not in spawners]

    def namespace(pid, kind):
        try:
            return os.readlink(f"/proc/{pid}/ns/{kind}")
        except OSError:
            return None

    def root_id(pid):
        try:
            info = os.stat(f"/proc/{pid}/root")
            return (info.st_dev, info.st_ino)
        except OSError:
            return None

    parent_namespaces = {kind: namespace(browser_pid, kind)
                         for kind in NAMESPACE_KINDS}
    child_namespaces = {
        p["pid"]: {kind: namespace(p["pid"], kind) for kind in NAMESPACE_KINDS}
        for p in workers
    }
    parent_root = root_id(browser_pid)
    child_roots = {p["pid"]: root_id(p["pid"]) for p in workers}
    return evaluate_worker_namespaces(
        browser_pid, children, parent_namespaces, child_namespaces,
        parent_root, child_roots)


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
    main = {"tid": 401, "seccomp_mode": 2,
            "seccomp_filter_count": 3, "no_new_privileges": 1}
    secondary = {**main, "tid": 402}
    valid = {401: [main, secondary]}
    evidence = evaluate_worker_thread_seccomp([spawner, worker], 327, valid)
    assert evidence["observed_content_worker_thread_count"] == 2
    assert evidence["all_observed_content_worker_threads_have_seccomp_filters"]
    forged = [
        {}, {401: []}, {401: [secondary]}, {999: [main, secondary]},
        {401: [main, main]},
        {401: [{**main, "tid": 0}, secondary]},
        {401: [main, {**secondary, "seccomp_mode": 0}]},
        {401: [main, {**secondary, "seccomp_filter_count": 0}]},
        {401: [main, {**secondary, "no_new_privileges": 0}]},
        {401: [main, {**secondary, "no_new_privileges": True}]},
        {401: [main, {**secondary, "seccomp_filter_count": "2"}]},
        {401: [main, {**secondary, "seccomp_mode": False}]},
    ]
    rejected = 0
    for case in forged:
        try:
            evaluate_worker_thread_seccomp([spawner, worker], 327, case)
        except RuntimeError:
            rejected += 1
            continue
        raise AssertionError("Forged or unprotected Firefox thread accepted")
    assert rejected == 12
    print("PASS: content-worker per-thread protection validator rejected 12 malformed/unfiltered fixtures")
    browser_ns = {name: f"{name}:[12345]" for name in NAMESPACE_KINDS}
    child_ns = dict(browser_ns)
    child_ns["net"] = "net:[54321]"
    child_ns["user"] = "user:[54321]"
    good_ns = evaluate_worker_namespaces(
        327, [spawner, worker], browser_ns, {401: child_ns},
        (1, 3), {401: (1, 2)})
    assert good_ns["content_worker_distinct_namespace_counts_by_kind"]["net"] == 1
    assert good_ns["content_worker_distinct_root_directory_count"] == 1
    # Equivalence and denied visibility must never be falsely converted
    # into proof of isolated namespaces.
    same_ns = evaluate_worker_namespaces(
        327, [spawner, worker], browser_ns, {401: browser_ns},
        (1, 3), {401: (1, 3)})
    assert same_ns["content_worker_distinct_namespace_counts_by_kind"]["net"] == 0
    assert same_ns["content_worker_distinct_root_directory_count"] == 0
    unreadable_root = evaluate_worker_namespaces(
        327, [spawner, worker], browser_ns, {401: child_ns},
        (1, 3), {401: None})
    assert unreadable_root["content_worker_unreadable_root_directory_count"] == 1
    assert unreadable_root["content_worker_distinct_root_directory_count"] == 0
    bad_cases = [
        (browser_ns, {}, (1, 3), {}),
        (browser_ns, {999: child_ns}, (1, 3), {999: (1, 2)}),
        ({}, {401: child_ns}, (1, 3), {401: (1, 2)}),
        (browser_ns, {401: {}}, (1, 3), {401: (1, 2)}),
        ({**browser_ns, "net": "ipc:[12345]"}, {401: child_ns},
         (1, 3), {401: (1, 2)}),
        (browser_ns, {401: {**child_ns, "net": "bad"}}, (1, 3),
         {401: (1, 2)}),
        (browser_ns, {401: {**child_ns, "net": True}}, (1, 3),
         {401: (1, 2)}),
        (browser_ns, {401: child_ns}, (1, 3), {401: (1, True)}),
        ({kind: None for kind in NAMESPACE_KINDS},
         {401: child_ns}, (1, 3), {401: (1, 2)}),
    ]
    rejected_ns = 0
    for browser, workers, base_root, roots in bad_cases:
        try:
            evaluate_worker_namespaces(
                327, [spawner, worker], browser, workers, base_root, roots)
        except RuntimeError:
            rejected_ns += 1
        else:
            raise AssertionError("Forged/missing namespace record was accepted")
    assert rejected_ns == 9
    print("PASS: 9 corrupted namespace fixtures rejected; inaccessible roots reported as unknown")


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
                # The preceding /proc/<pid>/status probe only covers group
                # leaders. Check every live /proc/<pid>/task/<tid>/status
                # from the same authenticated Firefox content workers.
                thread_evidence = capture_worker_thread_seccomp(last, browser_pid)
                namespace_evidence = capture_worker_namespaces(last, browser_pid)
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
                    **thread_evidence,
                    **namespace_evidence,
                    "release_ready": False,
                    "security_current": False,
                    "limits": [
                        "All *observed live threads* of authenticated content workers checked, not transient future threads",
                        "Linux seccomp mode/filter presence, not attempted syscall denial",
                        "Namespace identities are compared with browser parent; matching or unreadable namespace never mislabeled as isolated",
                        "Some user/network/IPC namespaces are conditional on kernel/graphics support; no semantics or blocked-syscall audit",
                        "No proof each filter is the expected Mozilla sandbox policy",
                        "Not a full Safe Browsing or external-network egress test",
                        "Not a VAAPI/DMABuf or other platform security audit",
                    ],
                }
                if output.exists():
                    raise RuntimeError("Refusing to replace existing sandbox proof")
                output.write_text(json.dumps(report, indent=2) + "\n")
                print("PASS: real Firefox 160 content workers and live threads have seccomp/NoNewPrivs; namespace comparisons recorded read-only", flush=True)
                print("AUDIT: worker namespace distinct-from-parent counts=" +
                      json.dumps(namespace_evidence["content_worker_distinct_namespace_counts_by_kind"], sort_keys=True) +
                      " unreadable=" + json.dumps(namespace_evidence["content_worker_unreadable_namespace_counts_by_kind"], sort_keys=True) +
                      " distinct-root-count=" + str(namespace_evidence["content_worker_distinct_root_directory_count"]), flush=True)
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
