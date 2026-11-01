// Inventory direct native calls/tail branches to Linux/NSPR loader entrypoints
// from one real unstripped, source-pinned libxul.so. Not full dlopen closure.
// Std-only and intentionally bounded: no binaries or raw disassembly uploaded.
use std::collections::BTreeMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Command, Stdio};

const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const MAX_ELF_BYTES: u64 = 16 * 1024 * 1024 * 1024;
const MAX_LINES: usize = 35_000_000;
const MAX_DISTINCT_EDGES: usize = 5_000;
const MAX_BRANCHES: u64 = 100_000;

#[derive(Default)]
struct Census {
    branches: u64,
    instruction_lines: u64,
    ffmpeg_nspr_init_calls: u64,
    edges: BTreeMap<(String, String, String), u64>,
}

fn check_elf(path: &Path) -> Result<u64, String> {
    let meta = fs::metadata(path).map_err(|e| format!("Original native ELF missing: {e}"))?;
    if !meta.is_file() || !(64..=MAX_ELF_BYTES).contains(&meta.len()) {
        return Err("Invalid original native ELF kind/size".into());
    }
    let mut h = [0u8; 20];
    File::open(path).map_err(|e| e.to_string())?
        .read_exact(&mut h).map_err(|e| e.to_string())?;
    if &h[..4] != b"\x7fELF" || h[4] != 2 || h[5] != 1
        || h[16..18] != [3, 0] || h[18..20] != [62, 0]
    {
        return Err("Expected Linux x86-64 little-endian ELF64 shared object".into());
    }
    Ok(meta.len())
}
fn source_symbol(line: &str) -> Option<&str> {
    let t = line.trim();
    let (address, candidate) = t.split_once(" <")?;
    if address.len() < 8 || !address.chars().all(|c| c.is_ascii_hexdigit()) {
        return None;
    }
    let symbol = candidate.strip_suffix(">:")?;
    if symbol.is_empty() || symbol.len() > 512 || symbol.chars().any(|c| c.is_control()) {
        return None;
    }
    Some(symbol)
}
fn named_loader_target(raw: &str) -> Option<&'static str> {
    // Do not mistake a call into the middle of a function for its entrypoint.
    if raw.contains('+') || raw.contains('-') { return None; }
    let base = raw.split('@').next().unwrap_or(raw);
    match base {
        "PR_LoadLibraryWithFlags" => Some("PR_LoadLibraryWithFlags"),
        "PR_LoadLibrary" => Some("PR_LoadLibrary"),
        "PR_LoadLibraryByPathname" => Some("PR_LoadLibraryByPathname"),
        "dlopen" => Some("dlopen"),
        "dlmopen" => Some("dlmopen"),
        _ => None,
    }
}
fn parse_branch(line: &str) -> Option<(&'static str, &'static str)> {
    let (addr, text) = line.split_once(':')?;
    let addr = addr.trim();
    if addr.is_empty() || !addr.chars().all(|c| c.is_ascii_hexdigit()) { return None; }
    let op = text.split_whitespace().next()?;
    let kind = match op {
        "call" | "callq" => "call",
        "jmp" | "jmpq" => "tail-jump",
        _ => return None,
    };
    let label = text.rsplit_once('<')?.1.strip_suffix('>')?;
    Some((kind, named_loader_target(label)?))
}
fn inspect(path: &Path) -> Result<Census, String> {
    check_elf(path)?;
    let mut child = Command::new("objdump")
        .args(["-d", "--no-show-raw-insn"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e| format!("GNU objdump missing: {e}"))?;
    let stdout = child.stdout.take().ok_or("Missing objdump stream")?;
    let mut census = Census::default();
    let mut current = String::new();
    for (n, line) in BufReader::new(stdout).lines().enumerate() {
        if n >= MAX_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Exceeded bounded native disassembly line budget".into());
        }
        let line = line.map_err(|e| e.to_string())?;
        if let Some(symbol) = source_symbol(&line) {
            current.clear();
            current.push_str(symbol);
            continue;
        }
        if let Some((kind, target)) = parse_branch(&line) {
            if current.is_empty() {
                let _ = child.kill(); let _ = child.wait();
                return Err("Native loader callsite lacks a named owning disassembly function".into());
            }
            census.branches += 1;
            if census.branches > MAX_BRANCHES {
                let _ = child.kill(); let _ = child.wait();
                return Err("Exceeded bounded direct native loader branches".into());
            }
            if current.contains("FFmpegRuntimeLinker") && current.contains("4Init")
                && target == "PR_LoadLibraryWithFlags" && kind == "call"
            {
                census.ffmpeg_nspr_init_calls += 1;
            }
            *census.edges.entry((current.clone(), target.into(), kind.into())).or_default() += 1;
            if census.edges.len() > MAX_DISTINCT_EDGES {
                let _ = child.kill(); let _ = child.wait();
                return Err("Exceeded bounded native loader caller identities".into());
            }
        }
        if let Some((addr, _)) = line.split_once(':') {
            if !addr.trim().is_empty() && addr.trim().chars().all(|c| c.is_ascii_hexdigit()) {
                census.instruction_lines += 1;
            }
        }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() {
        return Err("GNU objdump failed on native executable disassembly".into());
    }
    if census.instruction_lines == 0 { return Err("Empty native disassembly".into()); }
    if census.ffmpeg_nspr_init_calls != 1 {
        return Err(format!("Expected one independently accepted FFmpegRuntimeLinker::Init -> NSPR call, found {}", census.ffmpeg_nspr_init_calls));
    }
    Ok(census)
}
fn sha256sum(path: &Path) -> Result<String, String> {
    let out = Command::new("sha256sum").arg("--").arg(path).output()
        .map_err(|e| format!("sha256sum unavailable: {e}"))?;
    if !out.status.success() { return Err("sha256sum of linked input failed".into()); }
    let text = String::from_utf8(out.stdout).map_err(|e| e.to_string())?;
    let hash = text.split_whitespace().next().ok_or("Missing ELF SHA-256")?;
    if hash.len()!=64 || !hash.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("Invalid ELF SHA-256".into());
    }
    Ok(hash.to_string())
}
fn quote(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}
fn report(c: &Census, hash: &str, len: u64) -> String {
    let mut rows = Vec::new();
    for ((owner, target, kind), count) in &c.edges {
        rows.push(format!(
            "    {{\"caller_symbol\":{},\"loader_api\":{},\"branch_kind\":{},\"native_branches\":{}}}",
            quote(owner), quote(target), quote(kind), count
        ));
    }
    format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"source_commit\":\"{}\",\n",
        "  \"binary\":\"libxul.so\",\n",
        "  \"unstripped_native_elf_sha256\":\"{}\",\n",
        "  \"unstripped_native_elf_bytes\":{},\n",
        "  \"status\":\"compiled_direct_loader_api_callsite_census\",\n",
        "  \"native_instruction_lines\":{},\n",
        "  \"direct_loader_branches\":{},\n",
        "  \"distinct_caller_loader_kind_records\":{},\n",
        "  \"independently_accepted_ffmpeg_to_nspr_call_count\":{},\n",
        "  \"direct_loader_callsite_records\":[\n{}\n  ],\n",
        "  \"indirect_loader_calls_enumerated\":false,\n",
        "  \"every_dynamic_loader_api_enumerated\":false,\n",
        "  \"actual_dynamic_library_names_verified\":false,\n",
        "  \"conditional_runtime_routes_exercised\":false,\n",
        "  \"all_elf_consumers_covered\":false,\n",
        "  \"arch_workstation_verified\":false,\n",
        "  \"source_pruning_authorized\":false,\n",
        "  \"m3_sixth_gate_closed\":false\n}}\n"),
        SOURCE, hash, len, c.instruction_lines, c.branches, c.edges.len(),
        c.ffmpeg_nspr_init_calls, rows.join(",\n")
    )
}
fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 4 || args[1] != SOURCE {
        return Err("usage: compiled-loader-census PINNED_SOURCE_SHA UNSTRIPPED_LIBXUL REPORT_JSON".into());
    }
    let path = Path::new(&args[2]);
    let len = check_elf(path)?;
    let c = inspect(path)?;
    let hash = sha256sum(path)?;
    let body = report(&c, &hash, len);
    fs::write(&args[3], body).map_err(|e| e.to_string())?;
    println!("PASS: {} linked direct native loader-api branches, {} caller/api/kind records, FFmpeg NSPR call 1; no complete loader graph or pruning", c.branches, c.edges.len());
    Ok(())
}
fn main() { if let Err(e)=run() { eprintln!("FAIL: {e}"); std::process::exit(1); } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parser_rejects_similar_names_and_indirect_calls() {
        assert_eq!(source_symbol("0000000000001100 <_ZN7mozilla19FFmpegRuntimeLinker4InitEv>:"), Some("_ZN7mozilla19FFmpegRuntimeLinker4InitEv"));
        assert_eq!(parse_branch("    113f:\tcall   1040 <PR_LoadLibraryWithFlags@plt>"), Some(("call", "PR_LoadLibraryWithFlags")));
        assert_eq!(parse_branch("    113f:\tjmp    1040 <dlopen@GLIBC_2.34>"), Some(("tail-jump", "dlopen")));
        assert_eq!(parse_branch("    113f:\tcall   *%rax"), None);
        assert_eq!(parse_branch("    113f:\tcall   1040 <fauxPR_LoadLibraryWithFlags@plt>"), None);
        assert_eq!(parse_branch("    113f:\tcall   1040 <PR_LoadLibraryWithFlags+0x10>"), None);
        assert_eq!(quote("a\n\"b"), "\"a\\n\\\"b\"");
    }
    #[test]
    fn compiled_positive_negative_elf_fixtures() {
        let d = std::env::temp_dir().join(format!("vulpra-loader-census-{}", std::process::id()));
        fs::create_dir_all(&d).unwrap();
        let p=d.join("fixture.cpp");
        let elf=d.join("libnative-fixture.so");
        fs::write(&p, r#"
extern "C" void* PR_LoadLibraryWithFlags(int, int);
extern "C" void* dlopen(const char*, int);
namespace mozilla {
class FFmpegRuntimeLinker { public: static bool Init(); };
bool FFmpegRuntimeLinker::Init() {
    void* a=PR_LoadLibraryWithFlags(1, 2);
    void* b=dlopen("libdummy.so", 0);
    return a!=nullptr && b!=nullptr;
}
}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared","-fPIC","-O0"])
            .arg(&p).arg("-o").arg(&elf).status().unwrap().success());
        let c=inspect(&elf).unwrap();
        assert_eq!(c.ffmpeg_nspr_init_calls,1);
        assert!(c.branches>=2);
        assert!(c.edges.keys().any(|(_, target, _)| target=="dlopen"));
        fs::write(&p, r#"
namespace mozilla {
class FFmpegRuntimeLinker { public: static bool Init(); };
bool FFmpegRuntimeLinker::Init() { return true; }
}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared","-fPIC","-O0"])
            .arg(&p).arg("-o").arg(&elf).status().unwrap().success());
        assert!(inspect(&elf).is_err());
        fs::remove_dir_all(&d).unwrap();
    }
}