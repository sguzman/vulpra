// Copyright: project-local QA helper. Exact Linux x86_64 semantics used by
// Firefox 160 SandboxInfo.cpp CanCreateUserNamespace(), in an isolated child.
// NO Firefox build, privileges, kernel-setting changes or process injection.
// Diagnostic only: failure errno and read-only policy hints do not establish
// which LSM/kernel component caused the denial.
#![forbid(unsafe_op_in_unsafe_fn)]
#[cfg(not(all(target_os = "linux", target_arch = "x86_64")))]
compile_error!("This reference diagnostic requires the Linux x86_64 CI runner.");

use std::env;
use std::ffi::{c_int, c_long, c_void};
use std::fs;
use std::io;
use std::path::Path;
use std::process;

unsafe extern "C" {
    fn syscall(number: c_long, ...) -> c_long;
    fn unshare(flags: c_int) -> c_int;
    fn waitpid(pid: c_int, status: *mut c_int, options: c_int) -> c_int;
    fn _exit(status: c_int) -> !;
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

fn raw_user_namespace_probe() -> Result<Outcome, &'static str> {
    // Firefox 160 SandboxInfo.cpp uses raw clone(SIGCHLD | CLONE_NEWUSER)
    // and, in the child, unshare(CLONE_NEWPID). No id mappings or writes.
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
        return classify(-1, io::Error::last_os_error().raw_os_error().unwrap_or(0), None);
    }
    if pid == 0 {
        // No Rust allocator, filesystem or process environment work after
        // clone in the child. _exit avoids atexit handlers/parent teardown.
        let ok = unsafe { unshare(CLONE_NEWPID) == 0 };
        if ok {
            unsafe { _exit(0) };
        }
        let errno = io::Error::last_os_error().raw_os_error().unwrap_or(0);
        let code = if errno > 0 && errno < 190 {
            CHILD_UNSHARE_ERRNO_BASE + errno
        } else {
            255 // Distinguish an unclassified error from a clean denial.
        };
        unsafe { _exit(code) };
    }
    let mut status: c_int = 0;
    loop {
        let got = unsafe { waitpid(pid as c_int, &mut status, 0) };
        if got == pid as c_int {
            return classify(pid, 0, Some(status));
        }
        if got == -1 && io::Error::last_os_error().kind() == io::ErrorKind::Interrupted {
            continue;
        }
        return Err("child wait failed");
    }
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
    println!("PASS: exact-shaped namespace child-probe classifier rejected seven invalid states");
    Ok(())
}

fn probe_to_json(outcome: Outcome) -> String {
    let (stage, errno) = output_stage(outcome);
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
        optional_bool(confined)
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
