// Bounded native evidence for one named original FFmpeg -> NSPR loader seam.
// A direct machine branch does not prove which SONAME was chosen at runtime.
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read};
use std::path::Path;
use std::process::{Command, Stdio};

const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const CALLER: &str = "mozilla::FFmpegRuntimeLinker::Init(";
const TARGET: &str = "PR_LoadLibraryWithFlags";
const MAX_ELF: u64 = 16 * 1024 * 1024 * 1024;
const MAX_NM_LINES: usize = 12_000_000;
const MAX_ASM_LINES: usize = 400_000;

fn check_elf(path: &Path) -> Result<(), String> {
    let m = fs::metadata(path).map_err(|e| format!("ELF input unavailable: {e}"))?;
    if !m.is_file() || m.len() < 64 || m.len() > MAX_ELF {
        return Err("Linked ELF has invalid size or kind".into());
    }
    let mut header = [0u8; 20];
    File::open(path).map_err(|e| e.to_string())?
        .read_exact(&mut header).map_err(|e| e.to_string())?;
    if &header[0..4] != b"\x7fELF" || header[4] != 2 || header[5] != 1 ||
        header[16..18] != [3, 0] || header[18..20] != [62, 0] {
        return Err("Expected a little-endian x86-64 shared ELF".into());
    }
    Ok(())
}

fn demangle(raw: &str) -> Result<String, String> {
    let r = Command::new("c++filt").arg("-n").arg(raw).output()
        .map_err(|e| format!("Cannot invoke c++filt: {e}"))?;
    if !r.status.success() { return Err("c++filt failed".into()); }
    String::from_utf8(r.stdout).map(|s| s.trim().to_owned()).map_err(|e| e.to_string())
}

fn native_caller(path: &Path) -> Result<String, String> {
    check_elf(path)?;
    let mut child = Command::new("nm")
        .args(["--defined-only", "--no-demangle", "--format=posix"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("Cannot invoke GNU nm: {e}"))?;
    let stdout = child.stdout.take().ok_or("nm stdout unavailable")?;
    let mut found = None;
    let mut n = 0;
    let mut possible = 0;
    for line in BufReader::new(stdout).lines() {
        let line = line.map_err(|e| e.to_string())?;
        n += 1;
        if n > MAX_NM_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Unbounded native symbol stream".into());
        }
        let mut fields = line.split_whitespace();
        let Some(raw) = fields.next() else { continue };
        let Some(kind) = fields.next() else { continue };
        if !matches!(kind, "T" | "t" | "W" | "w") || !raw.contains("FFmpegRuntimeLinker") { continue; }
        possible += 1;
        if possible > 96 {
            let _ = child.kill(); let _ = child.wait();
            return Err("Too many native FFmpeg caller candidates".into());
        }
        if demangle(raw)?.starts_with(CALLER) {
            if found.replace(raw.to_string()).is_some() {
                let _ = child.kill(); let _ = child.wait();
                return Err("Ambiguous compiled FFmpegRuntimeLinker::Init symbol".into());
            }
        }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() { return Err("GNU nm failed".into()); }
    found.ok_or_else(|| "Missing native FFmpegRuntimeLinker::Init text symbol (possibly inlined/stripped)".into())
}

fn target_label(label: &str) -> bool {
    label == TARGET || label == format!("{TARGET}@plt")
}

fn direct_branches(path: &Path, raw: &str) -> Result<usize, String> {
    let mut child = Command::new("objdump").arg("-d").arg("--no-show-raw-insn")
        .arg(format!("--disassemble={raw}"))
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e| format!("Cannot invoke GNU objdump: {e}"))?;
    let stdout = child.stdout.take().ok_or("objdump stdout unavailable")?;
    let mut count = 0;
    let mut instructions = 0;
    for (n, line) in BufReader::new(stdout).lines().enumerate() {
        if n >= MAX_ASM_LINES {
            let _ = child.kill(); let _ = child.wait();
            return Err("Unbounded native disassembly".into());
        }
        let line = line.map_err(|e| e.to_string())?;
        let Some((address, body)) = line.split_once(':') else { continue };
        if address.trim().is_empty() || !address.trim().chars().all(|c| c.is_ascii_hexdigit()) { continue; }
        instructions += 1;
        let op = body.split_whitespace().next().unwrap_or("");
        if !matches!(op, "call" | "callq" | "jmp" | "jmpq") { continue; }
        let Some(label) = body.rsplit_once('<').and_then(|(_, s)| s.strip_suffix('>')) else { continue; };
        if target_label(label) { count += 1; }
    }
    if !child.wait().map_err(|e| e.to_string())?.success() { return Err("GNU objdump failed".into()); }
    if instructions == 0 { return Err("Empty compiled FFmpeg caller disassembly".into()); }
    Ok(count)
}

fn verify(path: &Path) -> Result<usize, String> {
    let raw = native_caller(path)?;
    let count = direct_branches(path, &raw)?;
    if count == 0 { return Err("No linked direct FFmpeg Init -> PR_LoadLibraryWithFlags branch found".into()); }
    Ok(count)
}

fn run() -> Result<(), String> {
    let a: Vec<String> = std::env::args().collect();
    if a.len() != 4 || a[1] != SOURCE {
        return Err("usage: ffmpeg-loader-call PINNED_SHA UNSTRIPPED_LIBXUL REPORT_JSON".into());
    }
    let branches = verify(Path::new(&a[2]))?;
    let report = format!(concat!(
        "{{\n  \"schema_version\": 1,\n  \"source_commit\": \"{}\",\n",
        "  \"status\": \"compiled_ffmpeg_loader_direct_nspr_branch_verified\",\n",
        "  \"compiled_ffmpeg_init_direct_pr_loadlibrarywithflags_branches\": {},\n",
        "  \"selected_compiled_callsite_verified\": true,\n",
        "  \"actual_soname_argument_proven\": false,\n",
        "  \"all_dlopen_routes_verified\": false,\n",
        "  \"arch_workstation_verified\": false,\n",
        "  \"source_pruning_authorized\": false,\n",
        "  \"m3_sixth_gate_closed\": false\n}}\n"), SOURCE, branches);
    fs::write(&a[3], report).map_err(|e| e.to_string())?;
    println!("PASS: compiled original FFmpeg Init -> NSPR library-loader direct branch(es): {branches}; broad dependency closure still unverified");
    Ok(())
}
fn main() { if let Err(e) = run() { eprintln!("FAIL: {e}"); std::process::exit(1); } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_target_only() {
        assert!(target_label("PR_LoadLibraryWithFlags"));
        assert!(target_label("PR_LoadLibraryWithFlags@plt"));
        assert!(!target_label("PR_LoadLibrary"));
        assert!(!target_label("other_PR_LoadLibraryWithFlags@plt"));
    }
    #[test]
    fn real_compiled_positive_and_negative_native_fixtures() {
        let d = std::env::temp_dir().join(format!("vulpra-ffmpeg-native-{}", std::process::id()));
        fs::create_dir_all(&d).unwrap();
        let source = d.join("test.cpp");
        let elf = d.join("libsample.so");
        fs::write(&source, r#"
extern "C" void* PR_LoadLibraryWithFlags(int, int);
namespace mozilla {
class FFmpegRuntimeLinker { public: static bool Init(); };
bool FFmpegRuntimeLinker::Init() { return PR_LoadLibraryWithFlags(1, 2) != nullptr; }
}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared", "-fPIC", "-O0"])
            .arg(&source).arg("-o").arg(&elf).status().unwrap().success());
        assert_eq!(verify(&elf).unwrap(), 1);
        fs::write(&source, r#"
namespace mozilla {
class FFmpegRuntimeLinker { public: static bool Init(); };
bool FFmpegRuntimeLinker::Init() { return true; }
}
"#).unwrap();
        assert!(Command::new("c++").args(["-shared", "-fPIC", "-O0"])
            .arg(&source).arg("-o").arg(&elf).status().unwrap().success());
        assert!(verify(&elf).is_err());
        fs::write(&source, "int unrelated() { return 42; }").unwrap();
        assert!(Command::new("c++").args(["-shared", "-fPIC", "-O0"])
            .arg(&source).arg("-o").arg(&elf).status().unwrap().success());
        assert!(verify(&elf).is_err());
        fs::remove_dir_all(&d).unwrap();
    }
}