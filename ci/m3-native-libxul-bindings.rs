// Bounded, privacy-preserving summary of glibc's actual LD_DEBUG=bindings output.
// Archive provenance is verified separately by the original-compiled CI workflow.
// No symbols, paths, PIDs, profiles, or raw loader log lines enter the report.
use std::collections::{BTreeSet, HashSet};
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;

const MAX_FILES: usize = 100;
const MAX_FILE_BYTES: u64 = 256 * 1024 * 1024;
const MAX_TOTAL_BYTES: u64 = 512 * 1024 * 1024;
const MAX_EVENTS: usize = 1_000_000;
const ORIGINAL_SHA: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const ORIGINAL_SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";

fn clean_basename(s: &str) -> Option<&str> {
    let name = s.rsplit('/').next()?;
    if name.is_empty() || name.len() > 111 ||
        !name.bytes().all(|c| c.is_ascii_alphanumeric() || b"._+-".contains(&c)) {
        return None;
    }
    Some(name)
}

// Exact glibc form: "binding file X [0] to Y [0]: normal symbol [name]".
// Other loader chatter, special symbol lines and other requesters are excluded.
fn binding(line: &str) -> Option<(&str, &str)> {
    let (_, tail) = line.split_once("binding file ")?;
    let (requester, tail) = tail.split_once(" [")?;
    let (namespace, tail) = tail.split_once("] to ")?;
    if namespace.is_empty() || !namespace.bytes().all(|b| b.is_ascii_digit()) { return None; }
    let (provider, tail) = tail.split_once(" [")?;
    let (namespace, tail) = tail.split_once("]: normal symbol `")?;
    if namespace.is_empty() || !namespace.bytes().all(|b| b.is_ascii_digit()) { return None; }
    let (symbol, _) = tail.split_once('\'')?;
    if symbol.is_empty() || symbol.len() > 2048 ||
        !symbol.bytes().all(|b| b.is_ascii_graphic() && b != b'\'') { return None; }
    if clean_basename(requester)? != "libxul.so" { return None; }
    Some((clean_basename(provider)?, symbol))
}

fn analyze(folder: &Path) -> Result<(usize, usize, usize, BTreeSet<String>), String> {
    let mut paths = vec![];
    let mut total_bytes = 0u64;
    for item in fs::read_dir(folder).map_err(|e| e.to_string())? {
        let p = item.map_err(|e| e.to_string())?.path();
        let Some(name) = p.file_name().and_then(|n| n.to_str()) else { continue };
        let Some(pid) = name.strip_prefix("m3-bindings.") else { continue };
        if pid.is_empty() || !pid.bytes().all(|b| b.is_ascii_digit()) { continue; }
        let meta = fs::symlink_metadata(&p).map_err(|e| e.to_string())?;
        if !meta.file_type().is_file() || meta.len() == 0 || meta.len() > MAX_FILE_BYTES {
            return Err("invalid native loader trace file".into());
        }
        total_bytes = total_bytes.checked_add(meta.len()).ok_or("trace size overflow")?;
        if total_bytes > MAX_TOTAL_BYTES { return Err("too much native loader trace data".into()); }
        paths.push(p);
    }
    if paths.is_empty() || paths.len() > MAX_FILES { return Err("no bounded numeric-PID native traces".into()); }
    paths.sort();
    let mut unique: HashSet<(String, String)> = HashSet::new();
    let mut providers = BTreeSet::new();
    let mut browser_traces = 0;
    let mut events = 0usize;
    for p in &paths {
        let mut saw_libxul = false;
        let mut reader = BufReader::new(File::open(p).map_err(|e| e.to_string())?);
        let mut raw = Vec::new();
        loop {
            raw.clear();
            let n = reader.read_until(b'\n', &mut raw).map_err(|e| e.to_string())?;
            if n == 0 { break; }
            if n > 32768 { return Err("oversized glibc trace line".into()); }
            let Ok(line) = std::str::from_utf8(&raw) else { continue };
            if let Some((provider, symbol)) = binding(line) {
                saw_libxul = true;
                events += 1;
                if events > MAX_EVENTS { return Err("too many libxul bindings".into()); }
                providers.insert(provider.to_string());
                unique.insert((provider.to_string(), symbol.to_string()));
            }
        }
        if saw_libxul { browser_traces += 1; }
    }
    if events == 0 || browser_traces == 0 || providers.is_empty() {
        return Err("no real original libxul normal-symbol binding found".into());
    }
    Ok((browser_traces, events, unique.len(), providers))
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 { return Err("usage: m3-native-libxul-bindings TRACE_DIR OUTPUT_JSON".into()); }
    let (traces, events, unique, providers) = analyze(Path::new(&args[1]))?;
    let names = providers.iter().map(|s| format!("\"{s}\"")).collect::<Vec<_>>().join(",");
    let result = format!(concat!(
        "{{\n  \"schema_version\": 1,\n",
        "  \"status\": \"observed_original_native_libxul_glibc_symbol_bindings\",\n",
        "  \"original_source_commit\": \"{}\",\n",
        "  \"original_archive_sha256\": \"{}\",\n",
        "  \"browser_pid_traces_with_libxul_bindings\": {},\n",
        "  \"libxul_normal_symbol_binding_events\": {},\n",
        "  \"distinct_symbol_provider_pairs_observed\": {},\n",
        "  \"observed_provider_basename_count\": {},\n",
        "  \"observed_provider_basenames\": [{}],\n",
        "  \"actual_runtime_binding_proven_for_this_workload\": true,\n",
        "  \"raw_loader_logs_exported\": false,\n",
        "  \"symbol_names_exported\": false,\n",
        "  \"complete_relocation_coverage_proven\": false,\n",
        "  \"lazy_and_transitive_feature_coverage_proven\": false,\n",
        "  \"end_to_end_crash_update_inference_media_proven\": false,\n",
        "  \"new_source_pruning_authorized\": false\n}}\n"
    ), ORIGINAL_SOURCE, ORIGINAL_SHA, traces, events, unique, providers.len(), names);
    let mut f = File::create(&args[2]).map_err(|e| e.to_string())?;
    f.write_all(result.as_bytes()).map_err(|e| e.to_string())?;
    println!("PASS: {events} observed libxul symbol-binding events over {traces} native traces; {unique} distinct symbol/provider pairs (names redacted)");
    Ok(())
}

fn main() { if let Err(e) = run() { eprintln!("FAIL: bounded libxul binding observation: {e}"); std::process::exit(1); } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn parse_glibc_bindings() {
        let line = "  123: binding file /tmp/vulpra/libxul.so [0] to /lib/x86_64-linux-gnu/libc.so.6 [0]: normal symbol `malloc' [GLIBC_2.2.5]";
        assert_eq!(binding(line), Some(("libc.so.6", "malloc")));
        assert_eq!(binding(" 123: binding file /usr/bin/bash [0] to /lib/libc.so.6 [0]: normal symbol `malloc'"), None);
        assert_eq!(binding(&line.replace("libxul.so", "other.so")), None);
        assert_eq!(binding(&line.replace("normal symbol", "bad symbol")), None);
        assert_eq!(binding(&line.replace("malloc", "../private/secret")), None);
        assert_eq!(binding(&line.replace(" [0] to ", " [X] to ")), None);
        assert_eq!(clean_basename("/bad/evil\\nprofile"), None);
    }
}
