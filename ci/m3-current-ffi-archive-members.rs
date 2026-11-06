// Bounded read-only census of real current native Rust archive member definitions
// and the corresponding unstripped final libxul definitions.
// Source-pinned CI must authenticate the build separately. Matched definitions
// do NOT prove the complete linker selection graph or indirect FFI closure.
use std::{
    collections::BTreeMap, fs::{self, File}, io::{BufRead, BufReader, Read},
    path::Path, process::{Command, Stdio},
};

const SYMBOLS: [&str; 2] = ["GkRust_Init", "GkRust_Shutdown"];
const MAX_BYTES: u64 = 16 * 1024 * 1024 * 1024;
const MAX_NM_LINES: usize = 15_000_000;
const MAX_MEMBERS: usize = 1_000_000;

fn check_file(path: &Path, archive: bool) -> Result<u64, String> {
    let m = fs::metadata(path).map_err(|e| format!("Missing compiled native input: {e}"))?;
    if !m.is_file() || !(64..=MAX_BYTES).contains(&m.len()) {
        return Err("Native archive/ELF size or file type invalid".into());
    }
    let mut file = File::open(path).map_err(|e| e.to_string())?;
    let mut magic = [0u8; 20];
    file.read_exact(&mut magic).map_err(|e| e.to_string())?;
    if archive {
        if &magic[..8] != b"!<arch>\n" {
            return Err("Expected normal (non-thin) native ar archive".into());
        }
    } else if &magic[..4] != b"\x7fELF" || magic[4] != 2 || magic[5] != 1 ||
        !matches!((magic[16],magic[17]), (2,0) | (3,0)) ||
        magic[18] != 62 || magic[19] != 0 {
        return Err("Expected linked x86_64 little-endian ELF executable/shared object".into());
    }
    Ok(m.len())
}

fn safe_member(s: &str) -> bool {
    !s.is_empty() && s.len() <= 255 &&
        s.bytes().all(|b| b.is_ascii_alphanumeric() || b"._+-@$".contains(&b))
}

// GNU nm --print-file-name --format=posix:
// libgkrust.a[member.o]: GkRust_Init T <value> <size>
// libxul.so: GkRust_Init T <value> <size>
fn parse_nm(line: &str, archive: bool) -> Option<(&str, &str)> {
    let (owner, rest) = line.split_once(": ")?;
    let mut cols = rest.split_whitespace();
    let symbol = cols.next()?;
    let kind = cols.next()?;
    if !SYMBOLS.contains(&symbol) || !matches!(kind,"T"|"t"|"W"|"w") {
        return None;
    }
    if archive {
        let (_, member) = owner.rsplit_once('[')?;
        let member = member.strip_suffix(']')?;
        if !safe_member(member) { return None; }
        Some((symbol,member))
    } else if owner.ends_with("libxul.so") {
        Some((symbol,"libxul.so"))
    } else {
        None
    }
}

fn archive_members(path: &Path) -> Result<usize,String> {
    let mut cmd = Command::new("ar").arg("t").arg(path)
        .stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("Cannot run native ar: {e}"))?;
    let stdout = cmd.stdout.take().ok_or("ar emitted no stdout")?;
    let mut n=0usize;
    for line in BufReader::new(stdout).lines() {
        let line=line.map_err(|e| e.to_string())?;
        if !safe_member(&line) {
            let _=cmd.kill(); let _=cmd.wait();
            return Err("Unbounded or invalid archive member name".into());
        }
        n+=1;
        if n>MAX_MEMBERS {
            let _=cmd.kill(); let _=cmd.wait();
            return Err("Archive member count exceeded".into());
        }
    }
    if !cmd.wait().map_err(|e| e.to_string())?.success() || n==0 {
        return Err("Cannot list real native archive members".into());
    }
    Ok(n)
}

fn scan(path: &Path, archive: bool) -> Result<BTreeMap<String,String>,String> {
    let mut cmd=Command::new("nm")
        .args(["--print-file-name","--format=posix","--defined-only","--no-demangle"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("Cannot start GNU nm: {e}"))?;
    let stdout=cmd.stdout.take().ok_or("GNU nm stdout missing")?;
    let mut found=BTreeMap::new();
    for (n,line) in BufReader::new(stdout).lines().enumerate() {
        if n>=MAX_NM_LINES {
            let _=cmd.kill(); let _=cmd.wait();
            return Err("Excessive native symbol stream".into());
        }
        let line=line.map_err(|e| e.to_string())?;
        if let Some((symbol,member))=parse_nm(&line,archive) {
            if found.insert(symbol.to_owned(),member.to_owned()).is_some() {
                let _=cmd.kill(); let _=cmd.wait();
                return Err(format!("Duplicate native text definition: {symbol}"));
            }
        }
    }
    if !cmd.wait().map_err(|e| e.to_string())?.success() {
        return Err("GNU nm failed on real archive or ELF".into());
    }
    for symbol in SYMBOLS {
        if !found.contains_key(symbol) {
            return Err(format!("Missing compiled symbol in native artifact: {symbol}"));
        }
    }
    Ok(found)
}

fn digest(path:&Path) -> Result<String,String> {
    let out=Command::new("sha256sum").arg("--").arg(path).output()
        .map_err(|e| format!("sha256sum unavailable: {e}"))?;
    if !out.status.success() { return Err("Could not hash native input".into()); }
    let text=String::from_utf8(out.stdout).map_err(|e| e.to_string())?;
    let hash=text.split_whitespace().next().ok_or("Missing SHA")?;
    if hash.len()!=64 || !hash.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Malformed native digest".into());
    }
    Ok(hash.to_owned())
}

fn audit(source:&str, archive:&Path, elf:&Path, report:&Path) -> Result<(),String> {
    if source.len()!=40 || !source.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Source commit must be a full SHA-1".into());
    }
    let archive_bytes=check_file(archive,true)?;
    let elf_bytes=check_file(elf,false)?;
    let members=archive_members(archive)?;
    let defs=scan(archive,true)?;
    let elf_defs=scan(elf,false)?;
    let mut data=String::new();
    for (i,symbol) in SYMBOLS.iter().enumerate() {
        let owner=defs.get(*symbol).ok_or("Required archive symbol missing")?;
        if !safe_member(owner) || elf_defs.get(*symbol).map(String::as_str)!=Some("libxul.so") {
            return Err("Native FFI definition owner/linker consumer mismatch".into());
        }
        if i>0 {data.push_str(",\n");}
        data.push_str(&format!(
            "    {{\"symbol\":\"{}\",\"archive_member\":\"{}\",\"archive_definition_count\":1,\"consumer_definition_count\":1}}",
            symbol,owner
        ));
    }
    let report_text=format!(concat!(
        "{{\n  \"schema_version\":1,\n  \"status\":\"bounded_real_compiled_gkrust_archive_member_and_libxul_definitions\",\n",
        "  \"source_commit\":\"{}\",\n  \"rust_staticlib\":\"libgkrust.a\",\n",
        "  \"consumer_elf\":\"libxul.so\",\n  \"rust_archive_sha256\":\"{}\",\n",
        "  \"libxul_unstripped_sha256\":\"{}\",\n",
        "  \"rust_archive_bytes\":{},\n  \"libxul_unstripped_bytes\":{},\n",
        "  \"rust_archive_members\":{},\n  \"named_ffi_symbol_pairs\":2,\n",
        "  \"symbol_members\":[\n{}\n  ],\n",
        "  \"compiled_current_rust_archive_member_definitions_observed\":true,\n",
        "  \"compiled_current_elf_named_definitions_observed\":true,\n",
        "  \"complete_member_to_linker_selection_graph_proven\":false,\n",
        "  \"complete_rust_cpp_ffi_graph_proven\":false,\n",
        "  \"dynamic_or_indirect_ffi_closure_proven\":false,\n",
        "  \"additional_source_pruning_authorized\":false,\n",
        "  \"m3_sixth_gate_closed\":false\n}}\n"
    ),source,digest(archive)?,digest(elf)?,archive_bytes,elf_bytes,members,data);
    fs::write(report,report_text).map_err(|e|format!("Cannot write bounded FFI report: {e}"))?;
    println!("PASS: two real source-pinned gkrust archive member definitions and matching unstripped libxul definitions");
    println!("LIMIT: named definitions do not prove full archive member selection, all ABI calls or safe source deletion");
    Ok(())
}
fn main() {
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=5 {
        eprintln!("Usage: m3-current-ffi-archive-members SOURCE_SHA LIBGKRUST_A UNSTRIPPED_LIBXUL OUTPUT_JSON");
        std::process::exit(2);
    }
    if let Err(e)=audit(&args[1],Path::new(&args[2]),Path::new(&args[3]),Path::new(&args[4])) {
        eprintln!("FAIL: {e}");std::process::exit(1);
    }
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parser_accepts_only_expected_real_named_definitions() {
        assert_eq!(parse_nm("libgkrust.a[one.rcgu.o]: GkRust_Init T 0 8",true),Some(("GkRust_Init","one.rcgu.o")));
        assert_eq!(parse_nm("libxul.so: GkRust_Shutdown T 4 3",false),Some(("GkRust_Shutdown","libxul.so")));
        assert_eq!(parse_nm("libgkrust.a[one.rcgu.o]: GkRust_Init U",true),None);
        assert_eq!(parse_nm("libgkrust.a[one.rcgu.o]: unrelated T",true),None);
        assert_eq!(parse_nm("libxul.so: GkRust_Init T",true),None);
        assert_eq!(parse_nm("libgkrust.a[../bad]: GkRust_Init T",true),None);
    }
    #[test] fn real_compiled_native_archive_and_elf() {
        use std::time::{SystemTime,UNIX_EPOCH};
        let salt=SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let dir=std::env::temp_dir().join(format!("vulpra-m3-gkrust-{}-{}",std::process::id(),salt));
        fs::create_dir_all(&dir).unwrap();
        let src=dir.join("a.c");let obj=dir.join("one.o");
        let archive=dir.join("libgkrust.a");let elf=dir.join("libxul.so");let report=dir.join("report.json");
        fs::write(&src,"void GkRust_Init(void){} void GkRust_Shutdown(void){}").unwrap();
        assert!(Command::new("cc").args(["-fPIC","-c"]).arg(&src).arg("-o").arg(&obj).status().unwrap().success());
        assert!(Command::new("ar").arg("rcs").arg(&archive).arg(&obj).status().unwrap().success());
        assert!(Command::new("cc").args(["-shared","-o"]).arg(&elf).arg(&obj).status().unwrap().success());
        let source="0123456789abcdef0123456789abcdef01234567";
        audit(source,&archive,&elf,&report).unwrap();
        let content=fs::read_to_string(&report).unwrap();
        assert!(content.contains("\"rust_archive_members\":1"));
        assert!(content.contains("\"archive_member\":\"one.o\""));
        let wrong=dir.join("not-archive");
        fs::write(&wrong,b"not a genuine native archive").unwrap();
        assert!(audit(source,&wrong,&elf,&report).is_err());
        let other=dir.join("missing.c");let missing=dir.join("missing.o");
        fs::write(&other,"void unrelated(void){}").unwrap();
        assert!(Command::new("cc").args(["-fPIC","-c"]).arg(&other).arg("-o").arg(&missing).status().unwrap().success());
        let bad=dir.join("badlibxul.so");
        assert!(Command::new("cc").args(["-shared","-o"]).arg(&bad).arg(&missing).status().unwrap().success());
        assert!(audit(source,&archive,&bad,&report).is_err());
        fs::remove_dir_all(dir).unwrap();
    }
}
