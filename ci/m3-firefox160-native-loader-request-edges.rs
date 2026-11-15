// Source-authenticated Firefox160 actual glibc LD_DEBUG=libs,files request
// relations for one private WebDriver workload. Only request edges whose
// targets initialized in the SAME trace can be called observed init edges.
// One PID can span a shell launcher and browser; no browser-only attribution.
// No paths, PIDs, raw symbols, environment or loader lines enter output.
// Application runtime is exercised externally by the pinned CI workflow.
use std::collections::BTreeSet;
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;

const SOURCE: &str = "2887d9de1f69c0e9776413da80e7ba0d1225dd9b";
const ARCHIVE: &str = "530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb";
const MAX_TRACES: usize = 128;
const MAX_SINGLE: u64 = 64 * 1024 * 1024;
const MAX_TOTAL: u64 = 512 * 1024 * 1024;
const MAX_LINE: usize = 32 * 1024;
const MAX_EDGES: usize = 15000;

#[derive(Default)]
struct Observed {
    trace_files_examined: usize,
    browser_process_traces: usize,
    init_names: BTreeSet<String>,
    needed: BTreeSet<(String, String)>,
    dynamic: BTreeSet<(String, String)>,
    uninitialized_dynamic_attempt_names: BTreeSet<String>,
}

fn safe_name(value: &str) -> Option<&str> {
    if value.is_empty() || value.len() > 2048 || value.contains('\\') ||
       value.split('/').any(|segment| segment == "..") {
        return None;
    }
    let name = value.rsplit('/').next()?;
    if name.is_empty() || name.len() > 111 ||
       !name.bytes().all(|byte| byte.is_ascii_alphanumeric() || b"._+-".contains(&byte)) {
        return None;
    }
    Some(name)
}

fn init_name(line: &str) -> Option<&str> {
    let (_, value) = line.split_once("calling init: ")?;
    safe_name(value.trim())
}

fn request_edge(line: &str) -> Option<(String, String, bool)> {
    let (_, tail) = line.split_once("file=")?;
    let (target, relation) = tail.split_once(" [")?;
    let (dynamic, requester_tail) = if let Some((_, rest)) = relation.split_once(";  dynamically loaded by ") {
        (true, rest)
    } else if let Some((_, rest)) = relation.split_once(";  needed by ") {
        (false, rest)
    } else {
        return None;
    };
    let requester = requester_tail.split_ascii_whitespace().next()?;
    let from = safe_name(requester)?;
    let to = safe_name(target)?;
    if from == to {
        return None;
    }
    Some((from.to_string(), to.to_string(), dynamic))
}

fn read_one(path: &Path) -> Result<Option<(BTreeSet<String>,
    BTreeSet<(String, String)>, BTreeSet<(String, String)>)>, String> {
    let mut init = BTreeSet::new();
    let mut needed = BTreeSet::new();
    let mut dynamic = BTreeSet::new();
    let file = File::open(path).map_err(|_| "unreadable temporary loader trace")?;
    let mut reader = BufReader::new(file);
    let mut bytes = Vec::new();
    loop {
        bytes.clear();
        let got = reader.read_until(b'\n', &mut bytes)
            .map_err(|_| "unable to read temporary loader trace")?;
        if got == 0 { break; }
        if got > MAX_LINE { return Err("oversized glibc trace line".into()); }
        let Ok(line) = std::str::from_utf8(&bytes) else { continue };
        if let Some(name) = init_name(line) { init.insert(name.to_string()); }
        if let Some((from, to, dyn_load)) = request_edge(line) {
            if dyn_load { dynamic.insert((from, to)); }
            else { needed.insert((from, to)); }
            if dynamic.len() + needed.len() > MAX_EDGES {
                return Err("excessive distinct loader relations".into());
            }
        }
    }
    if !init.contains("libxul.so") {
        return Ok(None); // e.g. python/geckodriver traces, not the browser
    }
    if init.len() < 3 || !init.contains("libc.so.6") {
        return Err("real Firefox160 libxul browser trace lacks native initialization context".into());
    }
    Ok(Some((init, needed, dynamic)))
}

fn inspect(folder: &Path) -> Result<Observed, String> {
    if !folder.is_dir() { return Err("missing ephemeral loader trace directory".into()); }
    let mut entries = Vec::new();
    let mut total = 0u64;
    for item in fs::read_dir(folder).map_err(|_| "cannot enumerate ephemeral traces")? {
        let entry = item.map_err(|_| "bad ephemeral loader entry")?;
        let path = entry.path();
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        let Some(pid) = name.strip_prefix("vulpra-loader.") else { continue };
        if pid.is_empty() || !pid.bytes().all(|b| b.is_ascii_digit()) { continue; }
        let meta = fs::symlink_metadata(&path)
            .map_err(|_| "unreadable loader trace metadata")?;
        if !meta.file_type().is_file() || meta.len() == 0 || meta.len() > MAX_SINGLE {
            return Err("missing, symlinked or oversized numeric-PID loader trace".into());
        }
        total = total.checked_add(meta.len()).ok_or("loader trace byte overflow")?;
        if total > MAX_TOTAL { return Err("loader trace aggregate exceeds bound".into()); }
        entries.push(path);
    }
    if entries.is_empty() || entries.len() > MAX_TRACES {
        return Err("missing or unbounded numeric-PID loader traces".into());
    }
    entries.sort();
    let mut out = Observed::default();
    out.trace_files_examined = entries.len();
    for path in entries {
        let Some((init, needed, dynamic)) = read_one(&path)? else { continue };
        out.browser_process_traces += 1;
        for name in &init { out.init_names.insert(name.to_string()); }
        for (from, to) in needed {
            if init.contains(&to) { out.needed.insert((from, to)); }
        }
        for (from, to) in dynamic {
            if init.contains(&to) {
                out.dynamic.insert((from, to));
            } else {
                out.uninitialized_dynamic_attempt_names.insert(to);
            }
        }
        if out.needed.len() + out.dynamic.len() > MAX_EDGES {
            return Err("excessive observed loader request edges".into());
        }
    }
    if out.browser_process_traces == 0 || !out.init_names.contains("libxul.so") ||
       !out.init_names.contains("libc.so.6") {
        return Err("no authenticated real browser native initialization trace".into());
    }
    if out.init_names.len() > 512 || out.uninitialized_dynamic_attempt_names.len() > 1024 {
        return Err("excessive observed native loader names".into());
    }
    Ok(out)
}

fn json_names(names: &BTreeSet<String>) -> String {
    names.iter().map(|n| format!("\"{n}\"")).collect::<Vec<_>>().join(",")
}
fn json_edges(edges: &BTreeSet<(String, String)>) -> String {
    edges.iter().map(|(from, to)| format!(
        "{{\"requester_basename\":\"{from}\",\"requested_library_basename\":\"{to}\"}}"
    )).collect::<Vec<_>>().join(",")
}

fn write_report(found: &Observed, target: &Path) -> Result<(), String> {
    let body = format!(concat!(
        "{{\n \"schema_version\":1,\n",
        " \"status\":\"firefox160_real_browser_native_glibc_initialized_loader_request_edges\",\n",
        " \"original_native_source_commit\":\"{}\",\n",
        " \"original_native_archive_sha256\":\"{}\",\n",
        " \"total_numeric_pid_traces_examined\":{},\n",
        " \"browser_pid_traces_with_actual_libxul_initialization\":{},\n",
        " \"observed_initialized_library_basename_count\":{},\n",
        " \"observed_initialized_library_basenames\":[{}],\n",
        " \"initialized_needed_request_edge_count\":{},\n",
        " \"initialized_needed_request_edges\":[{}],\n",
        " \"initialized_dynamic_request_edge_count\":{},\n",
        " \"initialized_dynamic_request_edges\":[{}],\n",
        " \"dynamically_requested_but_no_same_trace_init_basename_count\":{},\n",
        " \"dynamically_requested_but_no_same_trace_init_basenames\":[{}],\n",
        " \"only_same_browser_pid_trace_initialized_targets_classified_as_initialized\":true,\n",
        " \"glibc_reported_request_relationships_not_proven_callstacks\":true,\n",
        " \"same_pid_may_include_shell_launcher_and_native_browser\":true,\n",
        " \"all_runtime_attempts_or_error_paths_known\":false,\n",
        " \"all_conditional_dlopen_and_dlsym_edges_proven\":false,\n",
        " \"all_native_feature_fallbacks_exercised\":false,\n",
        " \"actual_symbol_binding_pairs_reconciled_by_this_report\":false,\n",
        " \"target_endeavouros_hyprland_verified\":false,\n",
        " \"raw_loader_logs_paths_pids_symbols_or_profile_data_exported\":false,\n",
        " \"source_pruning_authorized\":false,\n",
        " \"security_current\":false,\n",
        " \"release_ready\":false,\n",
        " \"m3_sixth_gate_closed\":false\n}}\n"
    ), SOURCE, ARCHIVE, found.trace_files_examined, found.browser_process_traces,
       found.init_names.len(), json_names(&found.init_names),
       found.needed.len(), json_edges(&found.needed),
       found.dynamic.len(), json_edges(&found.dynamic),
       found.uninitialized_dynamic_attempt_names.len(),
       json_names(&found.uninitialized_dynamic_attempt_names));
    File::create(target).and_then(|mut f| f.write_all(body.as_bytes()))
        .map_err(|_| "cannot write bounded sanitized loader report".into())
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 { return Err("usage: firefox160-loader-observer TRACE_DIR REPORT_JSON".into()); }
    let found = inspect(Path::new(&args[1]))?;
    write_report(&found, Path::new(&args[2]))?;
    println!("PASS: original Firefox160 runtime, {} browser trace(s), {} initialized names, {} needed and {} dynamic init-confirmed request edges, {} unconfirmed dynamic target names",
        found.browser_process_traces, found.init_names.len(), found.needed.len(),
        found.dynamic.len(), found.uninitialized_dynamic_attempt_names.len());
    println!("LIMIT: per-PID glibc observations, not full conditional loader calls, dlsym, FFI, feature fallback or release");
    Ok(())
}
fn main() {
    if let Err(err) = run() { eprintln!("FAIL: bounded Firefox160 native loader observation: {err}"); std::process::exit(1); }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> String {
        [
            " 123: file=libxul.so [0];  needed by /opt/vulpra/vulpra-bin [0]",
            " 123: file=libpulse.so.0 [0];  dynamically loaded by /opt/vulpra/libxul.so [0]",
            " 123: file=libmiss.so.1 [0];  dynamically loaded by /opt/vulpra/libxul.so [0]",
            " 123: file=libnss3.so [0];  needed by /opt/vulpra/libxul.so [0]",
            " 123: calling init: /lib/libpulse.so.0",
            " 123: calling init: /lib/libnss3.so",
            " 123: calling init: /lib/libc.so.6",
            " 123: calling init: /opt/vulpra/libxul.so",
            "",
        ].join("\n")
    }
    #[test]
    fn actual_loader_request_grammar_and_safety() {
        assert_eq!(init_name(" 123: calling init: /lib/libxul.so"), Some("libxul.so"));
        assert!(init_name(" 123: calling init: /secret/invalid path").is_none());
        assert!(safe_name("../../private").is_none());
        assert!(safe_name("/root/secret\\file").is_none());
        assert_eq!(request_edge(" 123: file=libpulse.so.0 [0];  dynamically loaded by /opt/libxul.so [0]"),
                   Some(("libxul.so".into(), "libpulse.so.0".into(), true)));
        assert_eq!(request_edge(" 123: file=libnss3.so [0];  needed by /opt/libxul.so [0]"),
                   Some(("libxul.so".into(), "libnss3.so".into(), false)));
    }
    #[test]
    fn same_pid_target_init_required_and_nonbrowser_excluded() {
        let root = std::env::temp_dir().join(format!("vulpra-loader-fixture-{}", std::process::id()));
        fs::create_dir_all(&root).unwrap();
        let good = root.join("vulpra-loader.123");
        let other = root.join("vulpra-loader.456");
        fs::write(&good, fixture()).unwrap();
        fs::write(&other, " 456: calling init: /lib/libc.so.6\n").unwrap();
        let result = inspect(&root).unwrap();
        assert_eq!(result.browser_process_traces, 1);
        assert_eq!(result.trace_files_examined, 2);
        assert!(result.needed.contains(&("libxul.so".into(), "libnss3.so".into())));
        assert!(result.dynamic.contains(&("libxul.so".into(), "libpulse.so.0".into())));
        assert!(result.uninitialized_dynamic_attempt_names.contains("libmiss.so.1"));
        assert!(!result.dynamic.iter().any(|(_, target)| target=="libmiss.so.1"));
        fs::write(&good, fixture().replace("calling init: /opt/vulpra/libxul.so", "no init")).unwrap();
        assert!(inspect(&root).is_err());
        fs::remove_file(&good).unwrap();
        fs::remove_file(&other).unwrap();
        fs::remove_dir(&root).unwrap();
    }
}
