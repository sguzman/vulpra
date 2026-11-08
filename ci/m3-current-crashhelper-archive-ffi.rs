// Bounded source-pinned current crashhelper Rust archive member provenance.
// GNU ar + nm inspect the actual staticlib and *unstripped linked executable*.
// Symbol ownership is NOT proof that every archive member was selected by ld,
// nor that every Rust/C++ call edge or conditional loader route is known.
use std::{
    collections::BTreeSet,
    fs::{self, File},
    io::{BufRead, BufReader, Read},
    path::Path,
    process::{Command, Stdio},
};

const EXPORT: &str = "crash_generator_logic_desktop";
const MAX_BYTES: u64 = 16 * 1024 * 1024 * 1024;
const MAX_LINES: usize = 15_000_000;
const MAX_MEMBERS: usize = 1_000_000;

fn bounded_file(path: &Path, archive: bool) -> Result<u64, String> {
    let m = fs::symlink_metadata(path).map_err(|e| format!("Missing compiled Rust/C++ ABI input: {e}"))?;
    if !m.file_type().is_file() || !(64..=MAX_BYTES).contains(&m.len()) {
        return Err("Required real native archive/ELF is missing, unbounded or symlinked".into());
    }
    let mut file = File::open(path).map_err(|e| e.to_string())?;
    let mut magic = [0u8; 20];
    file.read_exact(&mut magic).map_err(|e| e.to_string())?;
    if archive {
        if &magic[..8] != b"!<arch>\n" {
            return Err("Expected normal, non-thin ar static library".into());
        }
    } else if &magic[..4] != b"\x7fELF" || magic[4] != 2 || magic[5] != 1 ||
        !matches!((magic[16], magic[17]), (2, 0) | (3, 0)) ||
        magic[18] != 62 || magic[19] != 0 {
        return Err("Expected linked x86_64 little-endian crashhelper ELF".into());
    }
    Ok(m.len())
}

fn safe_member(name: &str) -> bool {
    !name.is_empty() && name.len() <= 255 &&
        name.bytes().all(|b| b.is_ascii_alphanumeric() || b"._+-@$".contains(&b))
}

fn archive_members(archive: &Path) -> Result<BTreeSet<String>, String> {
    let mut child = Command::new("ar").arg("t").arg(archive)
        .stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("GNU ar not available: {e}"))?;
    let stdout = child.stdout.take().ok_or("No GNU ar member list")?;
    let mut names = BTreeSet::new();
    for line in BufReader::new(stdout).lines() {
        let name = line.map_err(|e| e.to_string())?;
        if !safe_member(&name) || !names.insert(name) || names.len() > MAX_MEMBERS {
            let _ = child.kill(); let _ = child.wait();
            return Err("Invalid, duplicate or excessive real archive member names".into());
        }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() || names.is_empty() {
        return Err("GNU ar failed or archive has no object members".into());
    }
    Ok(names)
}

// GNU nm --print-file-name --format=posix:
// libcrash_helper_server.a[crate-xxx.rcgu.o]: crash_generator_logic_desktop T 0 10
// crashhelper: crash_generator_logic_desktop T 401abc 10
fn parse_nm(line: &str, archive: bool) -> Option<&str> {
    let (owner, rest) = line.split_once(": ")?;
    let mut cols = rest.split_whitespace();
    if cols.next()? != EXPORT { return None; }
    let kind = cols.next()?;
    if archive {
        if kind != "T" { return None; }
        let (_, suffix) = owner.rsplit_once('[')?;
        let member = suffix.strip_suffix(']')?;
        safe_member(member).then_some(member)
    } else {
        (owner.ends_with("crashhelper") && matches!(kind, "T" | "t"))
            .then_some("crashhelper")
    }
}

fn scan_symbol(path: &Path, archive: bool) -> Result<String, String> {
    let mut child = Command::new("nm")
        .args(["--print-file-name", "--format=posix", "--defined-only", "--no-demangle"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("GNU nm not available: {e}"))?;
    let output = child.stdout.take().ok_or("No GNU nm output")?;
    let mut found = None;
    for (i, line) in BufReader::new(output).lines().enumerate() {
        if i >= MAX_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Unbounded native symbol table".into());
        }
        let line = line.map_err(|e| e.to_string())?;
        if let Some(member) = parse_nm(&line, archive) {
            if found.replace(member.to_owned()).is_some() {
                let _ = child.kill(); let _ = child.wait();
                return Err("Duplicate named strong ABI text definitions".into());
            }
        }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() {
        return Err("GNU nm failed on actual archive or linked ELF".into());
    }
    found.ok_or_else(|| format!("Missing compiled named strong text definition: {EXPORT}"))
}

fn sha256(path: &Path) -> Result<String, String> {
    let out = Command::new("sha256sum").arg("--").arg(path).output()
        .map_err(|e| format!("sha256sum unavailable: {e}"))?;
    if !out.status.success() { return Err("Cannot hash native archive/ELF".into()); }
    let line = String::from_utf8(out.stdout).map_err(|e| e.to_string())?;
    let hash = line.split_whitespace().next().ok_or("Missing native SHA256")?;
    if hash.len() != 64 || !hash.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Invalid native SHA256".into());
    }
    Ok(hash.to_owned())
}

fn audit(source: &str, archive: &Path, elf: &Path, output: &Path) -> Result<(), String> {
    if source.len() != 40 || !source.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Exact source SHA must be 40 ASCII hex characters".into());
    }
    let archive_bytes = bounded_file(archive, true)?;
    let elf_bytes = bounded_file(elf, false)?;
    let members = archive_members(archive)?;
    let owner = scan_symbol(archive, true)?;
    if !members.contains(&owner) { return Err("ABI export owner is absent from real archive member list".into()); }
    if scan_symbol(elf, false)? != "crashhelper" {
        return Err("Expected a real linked crashhelper ABI definition".into());
    }
    let report = format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"status\":\"bounded_current_crashhelper_rust_staticlib_export_and_linked_elf_definition\",\n",
        "  \"source_commit\":\"{}\",\n  \"rust_staticlib\":\"libcrash_helper_server.a\",\n",
        "  \"consumer_elf\":\"crashhelper\",\n",
        "  \"rust_archive_sha256\":\"{}\",\n  \"unstripped_crashhelper_sha256\":\"{}\",\n",
        "  \"rust_archive_bytes\":{},\n  \"unstripped_crashhelper_bytes\":{},\n",
        "  \"rust_archive_members\":{},\n",
        "  \"export_name\":\"crash_generator_logic_desktop\",\n",
        "  \"export_strong_archive_definition_count\":1,\n",
        "  \"export_linked_elf_text_definition_count\":1,\n",
        "  \"export_archive_member\":\"{}\",\n",
        "  \"real_rust_archive_member_definition_observed\":true,\n",
        "  \"real_linked_elf_definition_observed\":true,\n",
        "  \"archive_member_selected_by_final_linker_proven\":false,\n",
        "  \"all_rust_archive_member_selection_edges_proven\":false,\n",
        "  \"complete_cpp_rust_ffi_graph_proven\":false,\n",
        "  \"conditional_or_indirect_ffi_closure_proven\":false,\n",
        "  \"source_pruning_authorized\":false,\n  \"m3_sixth_gate_closed\":false\n}}\n"
    ),source,sha256(archive)?,sha256(elf)?,archive_bytes,elf_bytes,members.len(),owner);
    fs::write(output, report).map_err(|e| format!("Cannot write bounded source evidence: {e}"))?;
    println!("PASS: actual crash helper Rust staticlib owner and matching linked ELF named text definition");
    println!("LIMIT: no complete archive selection, all FFI, feature pruning or milestone closure");
    Ok(())
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 5 {
        eprintln!("Usage: m3-current-crashhelper-archive-ffi SOURCE_SHA RUST_STATICLIB UNSTRIPPED_CRASHHELPER OUTPUT_JSON");
        std::process::exit(2);
    }
    if let Err(e) = audit(&args[1], Path::new(&args[2]), Path::new(&args[3]), Path::new(&args[4])) {
        eprintln!("FAIL: {e}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn archive_nm_parsing_accepts_only_real_strong_owned_export() {
        assert_eq!(parse_nm("libcrash_helper_server.a[owner.rcgu.o]: crash_generator_logic_desktop T 0 a", true),Some("owner.rcgu.o"));
        assert_eq!(parse_nm("crashhelper: crash_generator_logic_desktop t 0 a", false),Some("crashhelper"));
        assert_eq!(parse_nm("crashhelper: crash_generator_logic_desktop T 0 a", false),Some("crashhelper"));
        assert_eq!(parse_nm("libcrash_helper_server.a[owner.rcgu.o]: crash_generator_logic_desktop W 0 a",true),None);
        assert_eq!(parse_nm("libcrash_helper_server.a[owner.rcgu.o]: crash_generator_logic_desktop w 0 a",true),None);
        assert_eq!(parse_nm("libcrash_helper_server.a[../bad]: crash_generator_logic_desktop T 0 a",true),None);
        assert_eq!(parse_nm("crashhelper: crash_generator_logic_desktop W 0 a",false),None);
        assert_eq!(parse_nm("elsewhere: crash_generator_logic_desktop T 0 a",false),None);
        assert_eq!(parse_nm("libcrash_helper_server.a[owner.rcgu.o]: unrelated T 0 a",true),None);
        assert!(!safe_member("../escape"));
    }

    #[test]
    fn actual_rust_staticlib_and_linked_cpp_executable() {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let dir = std::env::temp_dir().join(format!("vulpra-crash-archive-{}-{now}",std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let rust = dir.join("ffi.rs");
        let archive = dir.join("libcrash_helper_server.a");
        let cpp = dir.join("main.cpp");
        let exe = dir.join("crashhelper");
        let report = dir.join("report.json");
        fs::write(&rust,"#[no_mangle]\npub extern \"C\" fn crash_generator_logic_desktop()->i32{11}\n").unwrap();
        assert!(Command::new("rustc").args(["--edition=2021","--crate-type=staticlib"])
            .arg(&rust).arg("-o").arg(&archive).status().unwrap().success());
        fs::write(&cpp,"extern \"C\" int crash_generator_logic_desktop();\nint main(){return crash_generator_logic_desktop();}\n").unwrap();
        assert!(Command::new("c++").arg("-O0").arg(&cpp).arg(&archive)
            .arg("-o").arg(&exe).status().unwrap().success());
        let src="0123456789abcdef0123456789abcdef01234567";
        audit(src,&archive,&exe,&report).unwrap();
        let json=fs::read_to_string(&report).unwrap();
        assert!(json.contains("\"real_rust_archive_member_definition_observed\":true"));
        assert!(json.contains("\"archive_member_selected_by_final_linker_proven\":false"));
        let no_link=dir.join("unused");
        fs::write(&cpp,"int main(){return 0;}\n").unwrap();
        assert!(Command::new("c++").arg(&cpp).arg("-o").arg(&no_link).status().unwrap().success());
        assert!(audit(src,&archive,&no_link,&dir.join("bad.json")).is_err());
        let weak=dir.join("weak.c");
        let weak_obj=dir.join("weak.o");
        let weak_ar=dir.join("weak.a");
        fs::write(&weak,"__attribute__((weak)) int crash_generator_logic_desktop(void){return 11;}\n").unwrap();
        assert!(Command::new("cc").arg("-c").arg(&weak).arg("-o").arg(&weak_obj).status().unwrap().success());
        assert!(Command::new("ar").arg("rcs").arg(&weak_ar).arg(&weak_obj).status().unwrap().success());
        assert!(audit(src,&weak_ar,&exe,&dir.join("weak.json")).is_err());
        assert!(audit(src,Path::new("/does-not-exist/libcrash_helper_server.a"),&exe,&dir.join("missing.json")).is_err());
        fs::remove_dir_all(dir).unwrap();
    }
}
