// Copyright: project-local QA helper. Exact Linux x86_64 semantics used by
// Firefox 160 SandboxInfo.cpp CanCreateUserNamespace(), in an isolated child.
// NO Firefox build, privileges, kernel-setting changes or process injection.
// Diagnostic only: failure errno and read-only policy hints do not establish
// which LSM/kernel component caused the denial.
#![forbid(unsafe_op_in_unsafe_fn)]
#[cfg(not(all(target_os = "linux", target_arch = "x86_64")))]
compile_error!("This reference diagnostic requires the Linux x86_64 CI runner.");

use std::env;
use std::ffi::{c_char, c_int, c_long, c_void};
use std::fs;
use std::io;
use std::path::Path;
use std::process;

// Tiny child-to-parent pipe contains only CAP_SYS_ADMIN presence and the
// child's seccomp mode. Never inspect or export full process capabilities.
#[repr(C)]
#[derive(Clone, Copy)]
struct CapData {
    effective: u32,
    permitted: u32,
    inheritable: u32,
}
#[repr(C)]
struct CapHeader {
    version: u32,
    pid: i32,
}
#[derive(Debug)]
struct Probe {
    outcome: Outcome,
    child_cap_sys_admin: Option<bool>,
    child_seccomp_mode: Option<u8>,
    child_apparmor_profile_class: &'static str,
}
const SYS_OPENAT_X86_64: c_long = 257;
const AT_FDCWD: c_int = -100;
const SYS_CAPGET_X86_64: c_long = 125;
const SYS_PRCTL_X86_64: c_long = 157;
const PR_GET_SECCOMP: c_long = 21;
const LINUX_CAPABILITY_VERSION_3: u32 = 0x2008_0522;
const CAP_SYS_ADMIN: u32 = 21;


unsafe extern "C" {
    fn syscall(number: c_long, ...) -> c_long;
    fn unshare(flags: c_int) -> c_int;
    fn waitpid(pid: c_int, status: *mut c_int, options: c_int) -> c_int;
    fn _exit(status: c_int) -> !;
    fn pipe(fds: *mut c_int) -> c_int;
    fn read(fd: c_int, buf: *mut c_void, count: usize) -> isize;
    fn write(fd: c_int, buf: *const c_void, count: usize) -> isize;
    fn close(fd: c_int) -> c_int;
}

const SYS_CLONE_X86_64: c_long = 56;
const CLONE_NEWUSER: c_int = 0x1000_0000;
const CLONE_NEWPID: c_int = 0x2000_0000;
const SIGCHLD: c_int = 17;
const CHILD_UNSHARE_ERRNO_BASE: c_int = 64;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Outcome {
    CloneDenied(c_int),
    ChildUnshareDenied(c_int),
    BothSucceeded,
}

fn classify(clone_return: c_long, errno: c_int, wait_status: Option<c_int>) -> Result<Outcome, &'static str> {
    if clone_return == -1 {
        return if errno > 0 {
            Ok(Outcome::CloneDenied(errno))
        } else {
            Err("failed clone missing errno")
        };
    }
    if clone_return <= 0 {
        return Err("invalid non-parent clone result");
    }
    if errno != 0 {
        return Err("positive clone carries errno");
    }
    let status = wait_status.ok_or("child reaping failed")?;
    if status & 0x7f != 0 {
        return Err("child was not cleanly exited");
    }
    let exit = (status >> 8) & 0xff;
    if exit == 0 {
        return Ok(Outcome::BothSucceeded);
    }
    if exit >= CHILD_UNSHARE_ERRNO_BASE && exit < 254 {
        return Ok(Outcome::ChildUnshareDenied(exit - CHILD_UNSHARE_ERRNO_BASE));
    }
    Err("unknown child namespace probe exit status")
}

fn name_for_errno(errno: c_int) -> &'static str {
    match errno {
        1 => "EPERM",
        13 => "EACCES",
        22 => "EINVAL",
        38 => "ENOSYS",
        87 => "EUSERS",
        28 => "ENOSPC",
        12 => "ENOMEM",
        _ => "OTHER",
    }
}

fn child_apparmor_classification() -> u8 {
    // Read exactly one fixed procfs attribute using a raw syscall-style
    // libc open/read/close, before the child's unshare. NEVER emit the
    // actual LSM profile name, process title, path or raw label bytes.
    let paths: [&[u8]; 2] = [
        b"/proc/self/attr/apparmor/current\0",
        b"/proc/self/attr/current\0",
    ];
    for name in paths {
        let fd = unsafe {
            syscall(SYS_OPENAT_X86_64, c_long::from(AT_FDCWD),
                    name.as_ptr().cast::<c_char>(), 0, 0)
        } as c_int;
        if fd < 0 {
            continue;
        }
        let mut data = [0u8; 256];
        let n = unsafe { read(fd, data.as_mut_ptr().cast::<c_void>(), data.len()) };
        unsafe { close(fd) };
        if n <= 0 {
            continue;
        }
        let label = &data[..n as usize];
        if label.windows(b"unprivileged_userns".len())
                .any(|part| part == b"unprivileged_userns") {
            return 2; // Exact named restricted AppArmor profile observed.
        }
        if label.starts_with(b"unconfined") {
            return 1;
        }
        return 3; // A different profile, name deliberately withheld.
    }
    0 // Unknown/inaccessible, not assumed unconfined.
}

fn child_capability_snapshot() -> [u8; 3] {
    // Capabilities in this ephemeral *new* user namespace, not host
    // capabilities. CAP_SYS_ADMIN should be available for CLONE_NEWPID.
    let mut header = CapHeader {
        version: LINUX_CAPABILITY_VERSION_3,
        pid: 0,
    };
    let mut data = [CapData {
        effective: 0,
        permitted: 0,
        inheritable: 0,
    }; 2];
    let capget = unsafe {
        syscall(
            SYS_CAPGET_X86_64,
            &mut header as *mut CapHeader,
            data.as_mut_ptr(),
        )
    };
    let cap = if capget == 0 {
        if data[0].effective & (1u32 << CAP_SYS_ADMIN) != 0 {
            2 // capability present
        } else {
            1 // capability absent
        }
    } else {
        0 // CAPGET unavailable or denied; no invented negative claim
    };
    let seccomp = unsafe {
        syscall(SYS_PRCTL_X86_64, PR_GET_SECCOMP, 0, 0, 0, 0)
    };
    let seccomp_byte = if (0..=2).contains(&seccomp) {
        seccomp as u8
    } else {
        255 // unknown, not no filtering
    };
    [cap, seccomp_byte, child_apparmor_classification()]
}

fn decode_snapshot(raw: [u8; 3]) -> Result<(Option<bool>, Option<u8>, &'static str), &'static str> {
    let cap = match raw[0] {
        0 => None,
        1 => Some(false),
        2 => Some(true),
        _ => return Err("forged capability state in child pipe"),
    };
    let seccomp = match raw[1] {
        0..=2 => Some(raw[1]),
        255 => None,
        _ => return Err("invalid child seccomp state"),
    };
    let profile = match raw[2] {
        0 => "unreadable",
        1 => "unconfined",
        2 => "unprivileged_userns",
        3 => "other-redacted",
        _ => return Err("invalid child AppArmor classification"),
    };
    Ok((cap, seccomp, profile))
}

fn raw_user_namespace_probe() -> Result<Probe, &'static str> {
    // Exact two Firefox 160 operations, but added read-only observation
    // inside the disposable child to identify the missing CAP_SYS_ADMIN.
    let mut fds = [-1, -1];
    if unsafe { pipe(fds.as_mut_ptr()) } != 0 {
        return Err("cannot open isolated child diagnostic pipe");
    }
    let pid = unsafe {
        syscall(
            SYS_CLONE_X86_64,
            c_long::from(SIGCHLD | CLONE_NEWUSER),
            std::ptr::null_mut::<c_void>(),
            std::ptr::null_mut::<c_void>(),
            std::ptr::null_mut::<c_void>(),
            std::ptr::null_mut::<c_void>(),
        )
    };
    if pid < 0 {
        let errno = io::Error::last_os_error().raw_os_error().unwrap_or(0);
        unsafe {
            close(fds[0]);
            close(fds[1]);
        }
        return Ok(Probe {
            outcome: classify(-1, errno, None)?,
            child_cap_sys_admin: None,
            child_seccomp_mode: None,
            child_apparmor_profile_class: "not-applicable",
        });
    }
    if pid == 0 {
        // Single-threaded child: no allocator, file operations, output or
        // process environment manipulation after clone.
        unsafe { close(fds[0]) };
        let snapshot = child_capability_snapshot();
        // Bounded telemetry bytes, and only after namespace clone succeeds.
        let sent = unsafe {
            write(fds[1], snapshot.as_ptr().cast::<c_void>(), snapshot.len())
        };
        unsafe { close(fds[1]) };
        if sent != snapshot.len() as isize {
            unsafe { _exit(255) };
        }
        let ok = unsafe { unshare(CLONE_NEWPID) == 0 };
        if ok {
            unsafe { _exit(0) };
        }
        let errno = io::Error::last_os_error().raw_os_error().unwrap_or(0);
        let code = if errno > 0 && errno < 190 {
            CHILD_UNSHARE_ERRNO_BASE + errno
        } else {
            255
        };
        unsafe { _exit(code) };
    }
    unsafe { close(fds[1]) };
    let mut status: c_int = 0;
    loop {
        let got = unsafe { waitpid(pid as c_int, &mut status, 0) };
        if got == pid as c_int {
            break;
        }
        if got == -1 && io::Error::last_os_error().kind() == io::ErrorKind::Interrupted {
            continue;
        }
        unsafe { close(fds[0]) };
        return Err("namespace probe child wait failed");
    }
    let mut raw = [0u8; 3];
    let count = unsafe {
        read(fds[0], raw.as_mut_ptr().cast::<c_void>(), raw.len())
    };
    unsafe { close(fds[0]) };
    if count != raw.len() as isize {
        return Err("namespace probe child omitted capability snapshot");
    }
    let (cap, seccomp, profile) = decode_snapshot(raw)?;
    Ok(Probe {
        outcome: classify(pid, 0, Some(status))?,
        child_cap_sys_admin: cap,
        child_seccomp_mode: seccomp,
        child_apparmor_profile_class: profile,
    })
}

fn read_unsigned(path: &str) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse::<u64>().ok()
}
fn read_apparmor_enabled() -> Option<bool> {
    let raw = fs::read_to_string("/sys/module/apparmor/parameters/enabled").ok()?;
    match raw.trim() {
        "Y" => Some(true),
        "N" => Some(false),
        _ => None,
    }
}
fn read_apparmor_confinement() -> Option<bool> {
    let raw = fs::read_to_string("/proc/self/attr/current").ok()?;
    let label = raw.trim();
    if label.is_empty() {
        None
    } else {
        // Do not persist the raw profile name or process label.
        Some(!label.starts_with("unconfined"))
    }
}
fn optional_number(value: Option<u64>) -> String {
    value.map_or_else(|| "null".to_string(), |v| v.to_string())
}
fn optional_bool(value: Option<bool>) -> &'static str {
    match value {
        Some(true) => "true",
        Some(false) => "false",
        None => "null",
    }
}
fn output_stage(outcome: Outcome) -> (&'static str, Option<c_int>) {
    match outcome {
        Outcome::CloneDenied(errno) => ("clone_newuser_denied", Some(errno)),
        Outcome::ChildUnshareDenied(errno) => ("clone_succeeded_unshare_newpid_denied", Some(errno)),
        Outcome::BothSucceeded => ("clone_and_unshare_succeeded", None),
    }
}
fn negative_tests() -> Result<(), &'static str> {
    assert_eq!(classify(-1, 1, None)?, Outcome::CloneDenied(1));
    assert_eq!(classify(42, 0, Some(0))?, Outcome::BothSucceeded);
    assert_eq!(
        classify(42, 0, Some((CHILD_UNSHARE_ERRNO_BASE + 1) << 8))?,
        Outcome::ChildUnshareDenied(1)
    );
    let invalid = [
        (0, 0, None), (-1, 0, None), (42, 1, Some(0)),
        (42, 0, None), (42, 0, Some(9)),
        (42, 0, Some(1 << 8)), (42, 0, Some(255 << 8)),
    ];
    for (pid, errno, status) in invalid {
        if classify(pid, errno, status).is_ok() {
            return Err("forged child/namespace result accepted");
        }
    }
    assert_eq!(output_stage(Outcome::CloneDenied(1)).0, "clone_newuser_denied");
    assert_eq!(name_for_errno(1), "EPERM");
    assert_eq!(decode_snapshot([2, 2, 2])?, (Some(true), Some(2), "unprivileged_userns"));
    assert_eq!(decode_snapshot([1, 0, 1])?, (Some(false), Some(0), "unconfined"));
    assert_eq!(decode_snapshot([0, 255, 0])?, (None, None, "unreadable"));
    for malformed in [[3, 2, 2], [2, 4, 2], [255, 255, 1], [1, 254, 2], [2, 2, 8]] {
        if decode_snapshot(malformed).is_ok() {
            return Err("forged child capabilities or seccomp accepted");
        }
    }
    println!("PASS: namespace probe classifier rejects seven invalid outcomes and five malformed capability/profile snapshots");
    Ok(())
}

fn probe_to_json(probe: Probe) -> String {
    let (stage, errno) = output_stage(probe.outcome);
    let num = errno.map_or_else(|| "null".to_string(), |e| e.to_string());
    let errname = errno.map_or("NONE", name_for_errno);
    let apparmor = read_apparmor_enabled();
    let apparmor_limit = read_unsigned("/proc/sys/kernel/apparmor_restrict_unprivileged_userns");
    let userns_switch = read_unsigned("/proc/sys/kernel/unprivileged_userns_clone");
    let max_userns = read_unsigned("/proc/sys/user/max_user_namespaces");
    let confined = read_apparmor_confinement();
    format!(
        concat!(
            "{{\n",
            "  \"schema_version\": 1,\n",
            "  \"status\": \"pass\",\n",
            "  \"probe_kind\": \"firefox160_upstream_clone_newuser_then_unshare_newpid_x86_64\",\n",
            "  \"stage\": \"{}\",\n",
            "  \"errno_code\": {},\n",
            "  \"errno_name\": \"{}\",\n",
            "  \"kernel_unprivileged_userns_clone\": {},\n",
            "  \"kernel_max_user_namespaces\": {},\n",
            "  \"apparmor_module_enabled\": {},\n",
            "  \"apparmor_unprivileged_userns_restriction\": {},\n",
            "  \"diagnostic_process_apparmor_confined\": {},\n",
            "  \"child_effective_cap_sys_admin_in_new_userns\": {},\n",
            "  \"child_seccomp_mode_after_clone\": {},\n",
            "  \"child_apparmor_profile_class\": \"{}\",\n",
            "  \"raw_child_apparmor_profile_persisted\": false,\n",
            "  \"child_capability_read_only_observation\": true,\n",
            "  \"child_effective_capabilities_entire_set_exposed\": false,\n",
            "  \"child_exited_without_host_changes\": true,\n",
            "  \"test_did_not_modify_kernel_policy_or_sandbox\": true,\n",
            "  \"policy_root_cause_proven\": false,\n",
            "  \"same_as_firefox_parent_process_context_proven\": false,\n",
            "  \"linux_content_worker_namespace_isolation_verified\": false,\n",
            "  \"forbidden_content_worker_syscall_denial_verified\": false,\n",
            "  \"security_current\": false,\n",
            "  \"release_ready\": false\n",
            "}}\n"
        ),
        stage,
        num,
        errname,
        optional_number(userns_switch),
        optional_number(max_userns),
        optional_bool(apparmor),
        optional_number(apparmor_limit),
        optional_bool(confined),
        optional_bool(probe.child_cap_sys_admin),
        optional_number(probe.child_seccomp_mode.map(u64::from)),
        probe.child_apparmor_profile_class
    )
}

fn main() {
    let args: Vec<_> = env::args().collect();
    let outcome = match args.as_slice() {
        [_, arg] if arg == "--self-test" => negative_tests().map(|_| None),
        [_, arg, file] if arg == "--probe" => {
            if Path::new(file).exists() {
                Err("refusing to replace existing runner probe evidence")
            } else {
                raw_user_namespace_probe()
                    .and_then(|value| fs::write(file, probe_to_json(value))
                              .map_err(|_| "could not write ephemeral probe report"))
                    .map(|_| Some(()))
            }
        }
        _ => Err("usage: PROBE --self-test OR --probe NEW_OUTPUT.json"),
    };
    match outcome {
        Ok(_) => (),
        Err(error) => {
            eprintln!("FAIL: {error}");
            process::exit(1);
        }
    }
}
