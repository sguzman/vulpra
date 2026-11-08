// Bounded exact-current compiled crashhelper C++ -> Rust ABI machine-call proof.
// A source-pinned native workflow must independently authenticate this ELF.
// This proves one linked executable seam, not Rust archive provenance or all FFI.
use std::{
    fs::{self, File},
    io::{BufRead, BufReader, Read},
    path::Path,
    process::{Command, Stdio},
};

const EXPORT: &str = "crash_generator_logic_desktop";
const MAX_ELF_BYTES: u64 = 16 * 1024 * 1024 * 1024;
const MAX_NM_LINES: usize = 12_000_000;
const MAX_DISASSEMBLY_LINES: usize = 400_000;

fn check_elf(path: &Path) -> Result<u64, String> {
    let metadata = fs::symlink_metadata(path).map_err(|e| format!("Missing compiled crashhelper: {e}"))?;
    if !metadata.file_type().is_file() || !(64..=MAX_ELF_BYTES).contains(&metadata.len()) {
        return Err("Expected a regular, non-symlink, bounded unstripped crashhelper".into());
    }
    let mut file = File::open(path).map_err(|e| e.to_string())?;
    let mut h = [0u8; 20];
    file.read_exact(&mut h).map_err(|e| e.to_string())?;
    if &h[..4] != b"\x7fELF" || h[4] != 2 || h[5] != 1 ||
        !matches!((h[16], h[17]), (2, 0) | (3, 0)) || h[18] != 62 || h[19] != 0 {
        return Err("Expected x86_64 little-endian linked crashhelper ELF".into());
    }
    Ok(metadata.len())
}

fn inspect_symbols(path: &Path) -> Result<(), String> {
    let mut child = Command::new("nm")
        .args(["--defined-only", "--no-demangle", "--format=posix"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e| format!("GNU nm unavailable: {e}"))?;
    let output = child.stdout.take().ok_or("GNU nm stdout missing")?;
    let mut main_count = 0;
    let mut export_count = 0;
    for (n, line) in BufReader::new(output).lines().enumerate() {
        if n >= MAX_NM_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Excessive linked crashhelper symbols".into());
        }
        let line = line.map_err(|e| e.to_string())?;
        let mut fields = line.split_whitespace();
        let Some(name) = fields.next() else { continue };
        let Some(kind) = fields.next() else { continue };
        if name == "main" && kind == "T" { main_count += 1; }
        if name == EXPORT && matches!(kind, "T" | "t") { export_count += 1; }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() {
        return Err("GNU nm failed on actual crashhelper ELF".into());
    }
    if main_count != 1 || export_count != 1 {
        return Err(format!("Expected one strong main and one named ABI text definition: main={main_count}, export={export_count}"));
    }
    Ok(())
}

fn is_direct_named_branch(op: &str, target: &str) -> bool {
    // The symbol must describe an immediate operand, never an indirect
    // register/memory call nor the comment following an indirect call.
    let mut words = op.split('#').next().unwrap_or("").split_whitespace();
    if !matches!(words.next(), Some("call" | "callq" | "jmp" | "jmpq")) { return false; }
    let Some(destination) = words.next() else { return false; };
    let address = destination.strip_prefix("0x").unwrap_or(destination);
    if address.is_empty() || !address.bytes().all(|b| b.is_ascii_hexdigit()) {
        return false;
    }
    words.next() == Some(format!("<{target}>").as_str()) && words.next().is_none()
}

fn inspect_main_branch(path: &Path) -> Result<usize, String> {
    let mut child = Command::new("objdump")
        .args(["-d", "--no-show-raw-insn", "--disassemble=main"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e| format!("GNU objdump unavailable: {e}"))?;
    let output = child.stdout.take().ok_or("GNU objdump stdout missing")?;
    let mut instruction_lines = 0;
    let mut branches = 0;
    for (n, line) in BufReader::new(output).lines().enumerate() {
        if n >= MAX_DISASSEMBLY_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Excessive crashhelper main disassembly".into());
        }
        let line = line.map_err(|e| e.to_string())?;
        let Some((pc, op)) = line.split_once(':') else { continue };
        if pc.trim().is_empty() || !pc.trim().bytes().all(|b| b.is_ascii_hexdigit()) { continue; }
        instruction_lines += 1;
        if is_direct_named_branch(op.trim_start(), EXPORT) { branches += 1; }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() {
        return Err("GNU objdump failed on actual crashhelper main".into());
    }
    if instruction_lines == 0 { return Err("Missing compiled crashhelper main instructions".into()); }
    if branches != 1 {
        return Err(format!("Expected exactly one direct main to {EXPORT} branch, observed {branches}"));
    }
    Ok(branches)
}

fn digest(path: &Path) -> Result<String, String> {
    let result = Command::new("sha256sum").arg("--").arg(path).output()
        .map_err(|e| format!("sha256sum unavailable: {e}"))?;
    if !result.status.success() { return Err("Failed to hash source-linked crashhelper".into()); }
    let txt = String::from_utf8(result.stdout).map_err(|e| e.to_string())?;
    let hash = txt.split_whitespace().next().ok_or("Missing crashhelper digest")?;
    if hash.len() != 64 || !hash.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Malformed crashhelper digest".into());
    }
    Ok(hash.to_owned())
}

fn audit(source: &str, elf: &Path, output: &Path) -> Result<(), String> {
    if source.len() != 40 || !source.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Expected exact 40-character compiled-source commit".into());
    }
    let size = check_elf(elf)?;
    inspect_symbols(elf)?;
    let count = inspect_main_branch(elf)?;
    let report = format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"status\":\"one_current_linked_crashhelper_main_direct_branch_to_named_ffi_definition\",\n",
        "  \"source_commit\":\"{}\",\n",
        "  \"consumer_elf\":\"crashhelper\",\n",
        "  \"unstripped_crashhelper_sha256\":\"{}\",\n",
        "  \"unstripped_crashhelper_bytes\":{},\n",
        "  \"main_strong_text_definitions\":1,\n",
        "  \"crash_generator_logic_desktop_text_definitions\":1,\n",
        "  \"main_to_crash_generator_logic_desktop_direct_branches\":{},\n",
        "  \"compiled_direct_branch_to_named_ffi_export_verified\":true,\n",
        "  \"real_rust_archive_member_proven\":false,\n",
        "  \"all_cpp_rust_ffi_edges_enumerated\":false,\n",
        "  \"conditional_or_indirect_ffi_closure_proven\":false,\n",
        "  \"source_pruning_authorized\":false,\n",
        "  \"m3_sixth_gate_closed\":false\n}}\n"
    ), source, digest(elf)?, size, count);
    fs::write(output, report).map_err(|e| format!("Cannot write bounded evidence: {e}"))?;
    println!("PASS: one actual linked crashhelper main direct branch to named crash-helper ABI definition");
    println!("LIMIT: no Rust archive provenance, complete FFI graph, source pruning or release proof");
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("Usage: m3-current-crashhelper-direct-branch SOURCE_SHA UNSTRIPPED_CRASHHELPER REPORT_JSON");
        std::process::exit(2);
    }
    if let Err(e) = audit(&args[1], Path::new(&args[2]), Path::new(&args[3])) {
        eprintln!("FAIL: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn parser_rejects_indirect_and_fake_labels() {
        assert!(is_direct_named_branch("call 1140 <crash_generator_logic_desktop>", EXPORT));
        assert!(is_direct_named_branch("jmp 0x1140 <crash_generator_logic_desktop>", EXPORT));
        assert!(!is_direct_named_branch("call *%rax # <crash_generator_logic_desktop>", EXPORT));
        assert!(!is_direct_named_branch("call *0x1140(%rip) # 1140 <crash_generator_logic_desktop>", EXPORT));
        assert!(!is_direct_named_branch("call 1140 <crash_generator_logic_desktop+0x2>", EXPORT));
        assert!(!is_direct_named_branch("call 1140 <other>", EXPORT));
        assert!(!is_direct_named_branch("je 1140 <crash_generator_logic_desktop>", EXPORT));
    }

    #[test]
    fn real_rust_staticlib_cpp_executable_positive_and_negatives() {
        let salt = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let root = std::env::temp_dir().join(format!("vulpra-crashhelper-{}-{salt}", std::process::id()));
        fs::create_dir_all(&root).unwrap();
        let rust = root.join("ffi.rs");
        let archive = root.join("libcrash_helper_server.a");
        let cxx = root.join("crash.cpp");
        let elf = root.join("crashhelper");
        let output = root.join("report.json");
        fs::write(&rust, "#[no_mangle]\npub extern \"C\" fn crash_generator_logic_desktop() -> i32 { 7 }\n").unwrap();
        assert!(Command::new("rustc").args(["--edition=2021", "--crate-type=staticlib"])
            .arg(&rust).arg("-o").arg(&archive).status().unwrap().success());
        fs::write(&cxx, "extern \"C\" int crash_generator_logic_desktop();\nint main(){return crash_generator_logic_desktop();}\n").unwrap();
        assert!(Command::new("c++").args(["-O0", "-no-pie"]).arg(&cxx).arg(&archive)
            .arg("-o").arg(&elf).status().unwrap().success());
        let source = "0123456789abcdef0123456789abcdef01234567";
        audit(source, &elf, &output).unwrap();
        let report = fs::read_to_string(&output).unwrap();
        assert!(report.contains("\"main_to_crash_generator_logic_desktop_direct_branches\":1"));
        assert!(report.contains("\"real_rust_archive_member_proven\":false"));
        let wrong_source = root.join("no-call.cpp");
        let wrong_elf = root.join("no-call-crashhelper");
        fs::write(&wrong_source,
            "extern \"C\" int crash_generator_logic_desktop();\nint main(){auto f=&crash_generator_logic_desktop;return f==nullptr;}\n").unwrap();
        assert!(Command::new("c++").args(["-O0", "-no-pie"]).arg(&wrong_source).arg(&archive)
            .arg("-o").arg(&wrong_elf).status().unwrap().success());
        assert!(audit(source, &wrong_elf, &root.join("reject.json")).is_err());
        let weak_source = root.join("weak.cpp");
        let weak_elf = root.join("weak-crashhelper");
        fs::write(&weak_source,
            "extern \"C\" __attribute__((weak,noinline)) int crash_generator_logic_desktop(){return 7;}\nint main(){return crash_generator_logic_desktop();}\n").unwrap();
        assert!(Command::new("c++").args(["-O0", "-no-pie"]).arg(&weak_source)
            .arg("-o").arg(&weak_elf).status().unwrap().success());
        assert!(audit(source, &weak_elf, &root.join("weak.json")).is_err());
        assert!(audit(source, Path::new("/no/such/current/crashhelper"), &root.join("missing.json")).is_err());
        fs::remove_dir_all(root).unwrap();
    }
}
