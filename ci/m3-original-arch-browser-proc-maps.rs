// Original Vulpra browser /proc/<pid>/maps snapshot in private Arch Weston CI.
// Samples ONLY original-package executable processes, never installed browsers.
// Paths and PIDs are used in memory and NEVER exported; filenames are bounded.
// This is an incomplete time-bounded residency witness, not full dlopen closure.
use std::collections::{BTreeSet, HashSet};
use std::env;
use std::fs;
use std::path::Path;
use std::thread;
use std::time::{Duration, Instant};

const SRC: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const PACKAGE: &str = "/original";
const MAX_PROCESSES: usize = 128;
const MAX_MAP_BYTES: u64 = 8 * 1024 * 1024;
const MAX_NAMES: usize = 256;

fn safe_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 111
        && s.bytes().all(|b| b.is_ascii_alphanumeric() || b"._+-".contains(&b))
}
fn is_library(name: &str) -> bool {
    name.ends_with(".so") || name.contains(".so.") || matches!(name, "vulpra" | "vulpra-bin")
}
fn package_path(path: &str) -> bool {
    path.strip_prefix(PACKAGE).is_some_and(|rest| rest.starts_with('/'))
}
fn is_browser_exe(path: &Path) -> bool {
    path.to_str().is_some_and(|s| {
        package_path(s) &&
            matches!(s.rsplit('/').next(), Some("vulpra") | Some("vulpra-bin"))
    })
}
fn parse_maps(text: &str, package: &mut BTreeSet<String>,
              host: &mut BTreeSet<String>) -> Result<(), String> {
    for line in text.lines() {
        let mut parts = line.split_whitespace();
        // address, permissions, offset, device, inode, optional pathname
        let Some(path) = parts.nth(5) else { continue };
        if !path.starts_with('/') { continue } // ignore stack, heap, vdso, anon
        let name = path.rsplit('/').next().unwrap_or("");
        if !is_library(name) { continue }
        if !safe_name(name) { return Err("unsafe mapped library basename".into()) }
        if package_path(path) { package.insert(name.to_owned()); }
        else { host.insert(name.to_owned()); }
        if package.len() + host.len() > MAX_NAMES {
            return Err("too many mapped library basenames".into());
        }
    }
    Ok(())
}
#[derive(Default)]
struct Sample {
    processes: usize,
    unreadable: usize,
    pids: Vec<u32>, // private only: IDs never serialized
    package: BTreeSet<String>,
    host: BTreeSet<String>,
}
fn sample() -> Result<Sample, String> {
    let mut result = Sample::default();
    let entries = fs::read_dir("/proc").map_err(|_| "cannot enumerate isolated /proc")?;
    for e in entries {
        let e = e.map_err(|_| "failed to enumerate isolated process")?;
        let name = e.file_name();
        let Some(name) = name.to_str() else { continue };
        let Ok(pid) = name.parse::<u32>() else { continue };
        let root = e.path();
        let Ok(exe) = fs::read_link(root.join("exe")) else { continue };
        if !is_browser_exe(&exe) { continue }
        result.processes += 1;
        if result.processes > MAX_PROCESSES { return Err("too many browser processes".into()) }
        result.pids.push(pid);
        let map = root.join("maps");
        let Ok(meta) = fs::metadata(&map) else { result.unreadable += 1; continue };
        if meta.len() > MAX_MAP_BYTES { return Err("oversized browser mappings".into()) }
        // A child may exit between process enumeration and map read.
        match fs::read_to_string(map) {
            Ok(raw) => {
                if raw.len() > MAX_MAP_BYTES as usize {
                    return Err("oversized browser map content".into());
                }
                parse_maps(&raw, &mut result.package, &mut result.host)?;
            }
            Err(_) => { result.unreadable += 1; }
        }
    }
    Ok(result)
}
fn json_array(items: &BTreeSet<String>) -> String {
    format!("[{}]", items.iter().map(|s| format!("\"{s}\""))
        .collect::<Vec<_>>().join(","))
}
fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 || args[1] != PACKAGE
        || !args[2].starts_with("/reports/")
        || !args[2].ends_with(".json") {
        return Err("usage: original-proc-maps /original /reports/private-map.json".into());
    }
    let start = Instant::now();
    let mut ready_at: Option<Instant> = None;
    let mut samples = 0_usize;
    let mut max_parallel = 0_usize;
    let mut unreadable = 0_usize;
    let mut distinct_processes = HashSet::<u32>::new();
    let mut package = BTreeSet::<String>::new();
    let mut host = BTreeSet::<String>::new();
    while start.elapsed() < Duration::from_secs(18) {
        let shot = sample()?;
        if shot.processes > 0 {
            samples += 1;
            max_parallel = max_parallel.max(shot.processes);
            unreadable += shot.unreadable;
            distinct_processes.extend(shot.pids);
            package.extend(shot.package);
            host.extend(shot.host);
            if package.len() + host.len() > MAX_NAMES {
                return Err("too many unique resident libraries".into());
            }
            let core_present = ["libxul.so", "libmozgtk.so", "libmozwayland.so"]
                .iter().all(|n| package.contains(*n));
            if core_present && ready_at.is_none() { ready_at = Some(Instant::now()); }
            if ready_at.is_some_and(|t| t.elapsed() >= Duration::from_secs(3)) {
                break;
            }
        }
        thread::sleep(Duration::from_millis(200));
    }
    if samples < 4 || max_parallel == 0 || package.len() < 3 ||
       !["libxul.so", "libmozgtk.so", "libmozwayland.so"]
          .iter().all(|n| package.contains(*n)) || ready_at.is_none() {
        return Err("original browser never produced a bounded core Wayland ELF snapshot".into());
    }
    // The observer shares a private PID namespace with the test browser only.
    // Deliberately discard all numeric process IDs and map paths.
    let report = format!(concat!(
       "{{\n",
       " \"schema_version\":1,\n",
       " \"status\":\"original_arch_private_wayland_browser_proc_maps_residency\",\n",
       " \"original_source_commit\":\"{}\",\n",
       " \"original_archive_sha256\":\"{}\",\n",
       " \"browser_process_samples\":{},\n",
       " \"max_simultaneously_visible_original_browser_processes\":{},\n",
       " \"distinct_original_browser_processes_observed\":{},\n",
       " \"unreadable_original_process_maps_count\":{},\n",
       " \"package_mapped_library_basenames\":{},\n",
       " \"host_mapped_library_basenames\":{},\n",
       " \"original_package_libxul_mapped\":true,\n",
       " \"original_package_libmozgtk_mapped\":true,\n",
       " \"original_package_libmozwayland_mapped\":true,\n",
       " \"private_original_executable_only\":true,\n",
       " \"absolute_paths_or_pids_exported\":false,\n",
       " \"time_bounded_snapshot_not_all_runtime_libraries\":true,\n",
       " \"host_hyprland_or_gpu_not_tested\":true,\n",
       " \"complete_browser_feature_or_ffi_dependency_closure\":false,\n",
       " \"source_removal_authorized\":false,\n",
       " \"m3_sixth_gate_closed\":false\n",
       "}}\n"
      ), SRC, SHA, samples, max_parallel, distinct_processes.len(), unreadable,
       json_array(&package), json_array(&host));
    fs::write(&args[2], report).map_err(|_| "cannot write bounded private snapshot")?;
    println!("M3_ARCH_PROC_MAP=original_browser_core_residency_pass");
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("M3_ARCH_PROC_MAP_ERROR={e}");
        std::process::exit(1);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn basename_validation() {
        assert!(safe_name("libxul.so"));
        assert!(safe_name("libnss3.so.1"));
        assert!(!safe_name("../escaped"));
        assert!(!safe_name("fake library.so"));
    }
    #[test] fn source_scope() {
        assert!(package_path("/original/libxul.so"));
        assert!(!package_path("/originally/libxul.so"));
        assert!(is_browser_exe(Path::new("/original/vulpra")));
        assert!(!is_browser_exe(Path::new("/usr/bin/firefox")));
    }
    #[test] fn parse_only_resident_library_paths() {
        let raw = "7f0-7f1 r-xp 00000000 00:00 1 /original/libxul.so\n\
                   7f2-7f3 rw-p 00000000 00:00 0 [heap]\n\
                   7f4-7f5 r--p 00000000 00:00 1 /usr/lib/libc.so.6\n\
                   7f6-7f7 r--p 00000000 00:00 1 /other/document.txt\n";
        let mut p=BTreeSet::new(); let mut h=BTreeSet::new();
        parse_maps(raw,&mut p,&mut h).unwrap();
        assert_eq!(p.iter().cloned().collect::<Vec<_>>(),vec!["libxul.so"]);
        assert_eq!(h.iter().cloned().collect::<Vec<_>>(),vec!["libc.so.6"]);
    }
}