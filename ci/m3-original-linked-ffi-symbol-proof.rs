// Exact-source compiled FFI witness. Keeps symbol evidence bounded instead of
// uploading unstripped Firefox binaries or Rust static archives.
// Presence in the final consumer is not proof of every source-level call edge.
use std::collections::BTreeMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Command, Stdio};

const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SYMBOLS: [&str; 3] = ["GkRust_Init", "GkRust_Shutdown", "crash_generator_logic_desktop"];
const MAX_INPUT_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const MAX_NM_LINES: usize = 20_000_000;

fn check_input(path: &Path, archive: bool) -> Result<(), String> {
    let meta = fs::metadata(path).map_err(|e| format!("Missing native symbol input: {e}"))?;
    if !meta.is_file() || meta.len() < 8 || meta.len() > MAX_INPUT_BYTES {
        return Err("Native symbol input has invalid size or kind".into());
    }
    let mut f = File::open(path).map_err(|e| e.to_string())?;
    let mut magic = [0; 8];
    f.read_exact(&mut magic).map_err(|e| e.to_string())?;
    if archive && &magic != b"!<arch>\n" {
        return Err("Expected native static archive".into());
    }
    if !archive && &magic[..4] != b"\x7fELF" {
        return Err("Expected unstripped native ELF consumer".into());
    }
    Ok(())
}

// GNU nm --print-file-name --format=posix emits:
// path[member.o]: Symbol T value size
// path: Symbol T value size
fn parse_nm_line(line: &str) -> Option<(&str, char)> {
    let mut parts = line.split_whitespace();
    let owner = parts.next()?;
    if !owner.ends_with(':') { return None; }
    let name = parts.next()?;
    let kind = parts.next()?;
    if kind.len() != 1 { return None; }
    Some((name, kind.chars().next()?))
}

fn inspect(path: &Path, archive: bool) -> Result<BTreeMap<&'static str, usize>, String> {
    check_input(path, archive)?;
    let mut child = Command::new("nm")
        .args(["--print-file-name", "--format=posix", "--defined-only", "--no-demangle"])
        .arg(path)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn().map_err(|e| format!("Cannot run binutils nm: {e}"))?;
    let stdout = child.stdout.take().ok_or("Cannot read nm output")?;
    let mut found = BTreeMap::new();
    let mut lines = 0usize;
    for line in BufReader::new(stdout).lines() {
        let line = line.map_err(|e| e.to_string())?;
        lines += 1;
        if lines > MAX_NM_LINES {
            let _ = child.kill();
            let _ = child.wait();
            return Err("Refusing unexpectedly large nm symbol stream".into());
        }
        if let Some((name, kind)) = parse_nm_line(&line) {
            if matches!(kind, 'T' | 't' | 'W' | 'w') {
                for symbol in SYMBOLS {
                    if name == symbol { *found.entry(symbol).or_insert(0) += 1; }
                }
            }
        }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() {
        return Err("nm failed while reading real native symbols".into());
    }
    Ok(found)
}

fn require(map: &BTreeMap<&'static str, usize>, expected: &[&str], label: &str) -> Result<(), String> {
    for &symbol in expected {
        if map.get(symbol).copied().unwrap_or(0) != 1 {
            return Err(format!("{label}: expected exactly one defined native text symbol {symbol}"));
        }
    }
    Ok(())
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 7 || args[1] != SOURCE {
        return Err("usage: ffi-symbol-proof PINNED_SOURCE_SHA GKRUST_ARCHIVE UNSTRIPPED_LIBXUL CRASH_RUST_ARCHIVE UNSTRIPPED_CRASHHELPER OUTPUT_JSON".into());
    }
    let gkrust = inspect(Path::new(&args[2]), true)?;
    let libxul = inspect(Path::new(&args[3]), false)?;
    let crash_rust = inspect(Path::new(&args[4]), true)?;
    let crashhelper = inspect(Path::new(&args[5]), false)?;
    require(&gkrust, &SYMBOLS[..2], "libgkrust.a")?;
    require(&libxul, &SYMBOLS[..2], "unstripped libxul.so")?;
    require(&crash_rust, &SYMBOLS[2..], "libcrash_helper_server.a")?;
    require(&crashhelper, &SYMBOLS[2..], "unstripped crashhelper")?;
    // Source-level call sites are checked independently by the existing FFI
    // source witness. This test proves presence of named emitted definitions
    // in each archive and linked ELF, not callsite-level resolved relocations.
    let report = format!(
        "{{\n  \"schema_version\": 1,\n  \"source_commit\": \"{SOURCE}\",\n  \"status\": \"compiled_archive_and_consumer_named_definitions_verified\",\n  \"nm_external_defined_text_symbols_per_expected_input\": 1,\n  \"native_archive_to_elf_function_pairs\": 3,\n  \"gkrust_to_libxul\": [\"GkRust_Init\", \"GkRust_Shutdown\"],\n  \"crash_helper_server_to_crashhelper\": [\"crash_generator_logic_desktop\"],\n  \"complete_static_callsite_resolution_proven\": false,\n  \"conditional_dlopen_closure_proven\": false,\n  \"source_pruning_authorized\": false,\n  \"m3_sixth_gate_closed\": false\n}}\n"
    );
    fs::write(&args[6], report).map_err(|e| e.to_string())?;
    println!("PASS: 3 named source-pinned archive-to-consumer compiled definitions; full static closure NOT proven");
    Ok(())
}
fn main() {
    if let Err(e) = run() { eprintln!("FAIL: {e}"); std::process::exit(1); }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_nm_definition_and_rejects_unowned_lines() {
        assert_eq!(parse_nm_line("libgkrust.a[part.o]: GkRust_Init T 0 10"), Some(("GkRust_Init", 'T')));
        assert_eq!(parse_nm_line("libxul.so: GkRust_Shutdown W 12 5"), Some(("GkRust_Shutdown", 'W')));
        assert_eq!(parse_nm_line("GkRust_Init T 0 10"), None);
        assert_eq!(parse_nm_line("libxul.so: GkRust_Init .text 0"), None);
    }
    #[test]
    fn rejects_missing_or_duplicate_required_definitions() {
        let mut m = BTreeMap::new();
        assert!(require(&m, &["GkRust_Init"], "fixture").is_err());
        m.insert("GkRust_Init", 1);
        assert!(require(&m, &["GkRust_Init"], "fixture").is_ok());
        m.insert("GkRust_Init", 2);
        assert!(require(&m, &["GkRust_Init"], "fixture").is_err());
    }
    #[test]
    fn real_gnu_nm_parses_c_archive_and_linked_elf() {
        use std::process::Command;
        let dir = std::env::temp_dir().join(format!(
            "m3-ffi-real-nm-{}-{:?}", std::process::id(), std::thread::current().id()
        ));
        fs::create_dir_all(&dir).unwrap();
        let source = dir.join("ffi.c");
        let object = dir.join("ffi.o");
        let archive = dir.join("libgkrust.a");
        let linked = dir.join("libxul.so");
        fs::write(
            &source,
            "void GkRust_Init(void){}\\nvoid GkRust_Shutdown(void){}\\n",
        ).unwrap();
        let status = Command::new("cc")
            .args(["-fPIC", "-c"])
            .arg(&source).arg("-o").arg(&object)
            .status().unwrap();
        assert!(status.success(), "C compiler failed synthetic FFI fixture");
        let status = Command::new("ar").arg("rcs").arg(&archive)
            .arg(&object).status().unwrap();
        assert!(status.success(), "ar failed synthetic Rust staticlib fixture");
        let status = Command::new("cc").arg("-shared").arg(&object)
            .arg("-o").arg(&linked).status().unwrap();
        assert!(status.success(), "native ELF link failed");
        let defined_archive = inspect(&archive, true).unwrap();
        let defined_linked = inspect(&linked, false).unwrap();
        require(&defined_archive, &SYMBOLS[..2], "synthetic gkrust").unwrap();
        require(&defined_linked, &SYMBOLS[..2], "synthetic libxul").unwrap();
        assert_eq!(defined_archive.len(), 2);
        assert_eq!(defined_linked.len(), 2);
        fs::remove_dir_all(&dir).unwrap();
    }
    #[test]
    fn requires_real_elf_or_ar_magic() {
        let p = std::env::temp_dir().join(format!("m3-native-ffi-fixture-{}", std::process::id()));
        fs::write(&p, b"invalid!").unwrap();
        assert!(check_input(&p, true).is_err());
        assert!(check_input(&p, false).is_err());
        let _ = fs::remove_file(&p);
    }
}
