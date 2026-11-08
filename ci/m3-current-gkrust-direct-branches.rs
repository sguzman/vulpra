// Bounded current-source machine-code proof for three C++ startup/shutdown
// caller branches to the two independently verified gkrust ABI exports.
// The three named branches do NOT establish all Rust/C++ FFI or dlopen paths.
use std::{
    collections::BTreeMap,
    fs::{self, File},
    io::{BufRead, BufReader, Read},
    path::Path,
    process::{Command, Stdio},
};

const CALLERS: [(&str, &str); 3] = [
    ("NS_InitXPCOM", "GkRust_Init"),
    ("NS_InitMinimalXPCOM", "GkRust_Init"),
    ("mozilla::ShutdownXPCOM", "GkRust_Shutdown"),
];
const MAX_ELF_BYTES: u64 = 16 * 1024 * 1024 * 1024;
const MAX_NM_LINES: usize = 12_000_000;
const MAX_DISASSEMBLY_LINES: usize = 400_000;
const MAX_CANDIDATES: usize = 64;

fn check_elf(path: &Path) -> Result<u64, String> {
    let meta = fs::metadata(path)
        .map_err(|e| format!("Missing current unstripped {}: {e}", path.display()))?;
    if !meta.is_file() || meta.len() < 64 || meta.len() > MAX_ELF_BYTES {
        return Err("Invalid current compiled ELF type or size".into());
    }
    let mut file = File::open(path).map_err(|e| e.to_string())?;
    let mut h = [0u8;20];
    file.read_exact(&mut h).map_err(|e| e.to_string())?;
    if &h[..4] != b"\x7fELF" || h[4] != 2 || h[5] != 1 ||
        h[18] != 62 || h[19] != 0 || !matches!((h[16],h[17]), (2,0)|(3,0)) {
        return Err("Expected source-compiled x86_64 little-endian ELF".into());
    }
    Ok(meta.len())
}

fn demangle(raw: &str) -> Result<String, String> {
    let out=Command::new("c++filt").arg("-n").arg(raw).output()
        .map_err(|e| format!("GNU c++filt unavailable: {e}"))?;
    if !out.status.success() { return Err("c++filt failure".into()); }
    String::from_utf8(out.stdout).map(|s| s.trim().to_owned())
        .map_err(|e| e.to_string())
}

fn classify(s: &str) -> Option<usize> {
    if s=="NS_InitXPCOM" || s.starts_with("NS_InitXPCOM(") { Some(0) }
    else if s=="NS_InitMinimalXPCOM" || s.starts_with("NS_InitMinimalXPCOM(") { Some(1) }
    else if s.starts_with("mozilla::ShutdownXPCOM(") { Some(2) }
    else { None }
}

fn discover_callers(path: &Path) -> Result<BTreeMap<usize,String>,String> {
    check_elf(path)?;
    let mut p=Command::new("nm")
        .args(["--defined-only","--no-demangle","--format=posix"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("GNU nm unavailable: {e}"))?;
    let stdout=p.stdout.take().ok_or("GNU nm stdout missing")?;
    let mut result=BTreeMap::new();
    let mut possible=0usize;
    for (line_no,line) in BufReader::new(stdout).lines().enumerate() {
        if line_no>=MAX_NM_LINES {
            let _=p.kill();let _=p.wait();return Err("Unbounded native symbols".into());
        }
        let line=line.map_err(|e|e.to_string())?;
        let mut words=line.split_whitespace();
        let Some(raw)=words.next() else { continue };
        let Some(kind)=words.next() else { continue };
        if !matches!(kind,"T"|"t") || !(raw.contains("NS_InitXPCOM") ||
            raw.contains("NS_InitMinimalXPCOM") || raw.contains("ShutdownXPCOM")) { continue; }
        possible+=1;
        if possible>MAX_CANDIDATES {
            let _=p.kill();let _=p.wait();return Err("Too many native FFI caller candidates".into());
        }
        if let Some(idx)=classify(&demangle(raw)?) {
            if result.insert(idx,raw.to_owned()).is_some() {
                let _=p.kill();let _=p.wait();
                return Err(format!("Ambiguous actual current caller: {}",CALLERS[idx].0));
            }
        }
    }
    if !p.wait().map_err(|e| e.to_string())?.success() {
        return Err("Cannot inspect actual linked ELF text symbol names".into());
    }
    for (i,(name,_)) in CALLERS.iter().enumerate() {
        if !result.contains_key(&i) {
            return Err(format!("Missing compiled current C++ caller {name}"));
        }
    }
    Ok(result)
}

fn count_direct_branches(path: &Path, raw: &str, target: &str) -> Result<usize,String> {
    let mut p=Command::new("objdump")
        .arg("-d").arg("--no-show-raw-insn").arg(format!("--disassemble={raw}"))
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e|format!("GNU objdump unavailable: {e}"))?;
    let stdout=p.stdout.take().ok_or("objdump output missing")?;
    let mut count=0usize;
    let mut instruction_lines=0usize;
    for (n,line) in BufReader::new(stdout).lines().enumerate() {
        if n>=MAX_DISASSEMBLY_LINES {
            let _=p.kill();let _=p.wait();return Err("Unbounded machine disassembly".into());
        }
        let line=line.map_err(|e|e.to_string())?;
        let Some((pc,op))=line.split_once(':') else { continue };
        if pc.trim().is_empty() || !pc.trim().bytes().all(|b|b.is_ascii_hexdigit()) {
            continue;
        }
        instruction_lines+=1;
        let op=op.trim_start();
        let mn=op.split_whitespace().next().unwrap_or("");
        if !matches!(mn,"call"|"callq"|"jmp"|"jmpq") { continue; }
        if let Some(symbol)=op.rsplit_once('<')
            .and_then(|(_,s)|s.strip_suffix('>')) {
            if symbol==target { count+=1; }
        }
    }
    if !p.wait().map_err(|e|e.to_string())?.success() {
        return Err("objdump could not inspect actual compiled caller".into());
    }
    if instruction_lines==0 { return Err("Empty machine-code caller disassembly".into()); }
    Ok(count)
}

fn digest(path: &Path)->Result<String,String> {
    let out=Command::new("sha256sum").arg("--").arg(path).output()
        .map_err(|e|format!("sha256sum unavailable: {e}"))?;
    if !out.status.success() { return Err("Could not hash linked ELF".into()); }
    let v=String::from_utf8(out.stdout).map_err(|e|e.to_string())?;
    let hash=v.split_whitespace().next().ok_or("Missing ELF SHA-256")?;
    if hash.len()!=64 || !hash.bytes().all(|b|b.is_ascii_hexdigit()) {
        return Err("Invalid linked ELF digest".into());
    }
    Ok(hash.to_owned())
}

fn audit(sha: &str, path: &Path, out: &Path)->Result<(),String> {
    if sha.len()!=40 || !sha.bytes().all(|b|b.is_ascii_hexdigit()) {
        return Err("Expected exact source SHA-1".into());
    }
    let bytes=check_elf(path)?;
    let discovered=discover_callers(path)?;
    let mut counts=[0usize;3];
    for (&idx,raw) in &discovered {
        counts[idx]=count_direct_branches(path,raw,CALLERS[idx].1)?;
        if counts[idx]!=1 {
            return Err(format!("Current C++ caller {} has {} direct branches to {}",
                CALLERS[idx].0,counts[idx],CALLERS[idx].1));
        }
    }
    let json=format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"status\":\"three_current_compiled_cpp_direct_branches_to_named_gkrust_abi_exports\",\n",
        "  \"source_commit\":\"{}\",\n  \"linked_consumer\":\"libxul.so\",\n",
        "  \"unstripped_consumer_sha256\":\"{}\",\n  \"unstripped_consumer_bytes\":{},\n",
        "  \"caller_functions_verified\":3,\n",
        "  \"ns_init_xpcom_to_gkrust_init_branches\":{},\n",
        "  \"ns_init_minimal_xpcom_to_gkrust_init_branches\":{},\n",
        "  \"mozilla_shutdown_xpcom_to_gkrust_shutdown_branches\":{},\n",
        "  \"current_machine_code_direct_branch_targets_verified\":true,\n",
        "  \"all_cpp_rust_ffi_callers_enumerated\":false,\n",
        "  \"all_rust_archive_members_to_linker_edges_verified\":false,\n",
        "  \"conditional_or_indirect_ffi_closure_proven\":false,\n",
        "  \"source_pruning_authorized\":false,\n  \"m3_sixth_gate_closed\":false\n}}\n"
    ),sha,digest(path)?,bytes,counts[0],counts[1],counts[2]);
    fs::write(out,json).map_err(|e|format!("Cannot write bounded FFI branch report: {e}"))?;
    println!("PASS: current compiled XPCOM startup and shutdown C++ machine branches target both named gkrust ABI exports");
    println!("LIMIT: only three named direct branches in one current linked ELF, not complete FFI closure");
    Ok(())
}
fn main() {
    let args:Vec<String>=std::env::args().collect();
    if args.len()!=4 {
        eprintln!("Usage: m3-current-gkrust-direct-branches SOURCE_SHA UNSTRIPPED_LIBXUL OUTPUT_JSON");
        std::process::exit(2);
    }
    if let Err(e)=audit(&args[1],Path::new(&args[2]),Path::new(&args[3])) {
        eprintln!("FAIL: {e}");std::process::exit(1);
    }
}

#[cfg(test)] mod tests {
    use super::*;
    use std::time::{SystemTime,UNIX_EPOCH};
    #[test] fn classify_exact_cpp_callers() {
        assert_eq!(classify("NS_InitXPCOM(nsIServiceManager**)"),Some(0));
        assert_eq!(classify("NS_InitMinimalXPCOM()"),Some(1));
        assert_eq!(classify("mozilla::ShutdownXPCOM(nsIServiceManager*)"),Some(2));
        assert_eq!(classify("mozilla::NS_InitXPCOMOther()"),None);
        assert_eq!(classify("NS_InitXPCOMs()"),None);
    }
    #[test] fn actual_cpp_compiler_machine_branch_positive_and_negative() {
        let salt=SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let dir=std::env::temp_dir().join(format!("vulpra-current-machine-ffi-{}-{salt}",std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let cpp=dir.join("ffi.cpp");let elf=dir.join("libxul.so");
        fs::write(&cpp,r#"extern "C" __attribute__((noinline)) void GkRust_Init(){}
extern "C" __attribute__((noinline)) void GkRust_Shutdown(){}
__attribute__((used,noinline)) void NS_InitXPCOM(){GkRust_Init();}
__attribute__((used,noinline)) void NS_InitMinimalXPCOM(){GkRust_Init();}
namespace mozilla {__attribute__((used,noinline)) void ShutdownXPCOM(void*){GkRust_Shutdown();}}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared","-fPIC","-O0","-Wl,-Bsymbolic"])
            .arg(&cpp).arg("-o").arg(&elf).status().unwrap().success());
        let sha="0123456789abcdef0123456789abcdef01234567";
        let out=dir.join("accept.json");
        audit(sha,&elf,&out).unwrap();
        let report=fs::read_to_string(&out).unwrap();
        assert!(report.contains(r#""caller_functions_verified":3"#));
        assert!(report.contains(r#""current_machine_code_direct_branch_targets_verified":true"#));
        let wrong=dir.join("bad.cpp");let bad=dir.join("badlibxul.so");
        fs::write(&wrong,r#"extern "C" void GkRust_Init(){} extern "C" void GkRust_Shutdown(){}
__attribute__((used,noinline)) void NS_InitXPCOM(){} 
__attribute__((used,noinline)) void NS_InitMinimalXPCOM(){}
namespace mozilla {__attribute__((used,noinline)) void ShutdownXPCOM(void*){}}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared","-fPIC","-O0","-Wl,-Bsymbolic"])
            .arg(&wrong).arg("-o").arg(&bad).status().unwrap().success());
        assert!(audit(sha,&bad,&dir.join("reject.json")).is_err());
        assert!(audit(sha,Path::new("/missing/unstripped/libxul.so"),&dir.join("missing.json")).is_err());
        fs::remove_dir_all(dir).unwrap();
    }
}
