// Inspect the 27 non-libxul ELF members of the exact-original native package.
// Bounded direct branches and dynamic symbol imports, not whole dlopen closure.
// Never execute packaged ELF files, reveal absolute paths or use Python/npm.
use std::{collections::{BTreeMap, BTreeSet}, env, fs::{self, File}, io::{BufRead, BufReader, Read}, path::{Path, PathBuf}, process::{Command, Stdio}};
const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const MAX_TOTAL_MEMBERS: usize = 1000;
const MAX_ELF_BYTES: u64 = 5 * 1024 * 1024 * 1024;
const MAX_LINES_PER_ELF: usize = 10_000_000;
const MAX_BRANCHES_PER_ELF: u64 = 100_000;

fn loader(raw: &str) -> Option<&'static str> {
    if raw.contains('+') || raw.contains('-') { return None; }
    let base = raw.split('@').next().unwrap_or(raw);
    match base {
        "PR_LoadLibrary" => Some("PR_LoadLibrary"),
        "PR_LoadLibraryWithFlags" => Some("PR_LoadLibraryWithFlags"),
        "PR_LoadLibraryByPathname" => Some("PR_LoadLibraryByPathname"),
        "dlopen" => Some("dlopen"),
        "dlmopen" => Some("dlmopen"),
        _ => None,
    }
}
fn branch(line: &str) -> Option<(&'static str, &'static str)> {
    let (addr, instruction) = line.split_once(':')?;
    let addr = addr.trim();
    if addr.is_empty() || !addr.chars().all(|c| c.is_ascii_hexdigit()) { return None; }
    let op = instruction.split_whitespace().next()?;
    let kind = match op { "call"|"callq" => "call", "jmp"|"jmpq" => "tail-jump", _ => return None };
    let target = instruction.rsplit_once('<')?.1.strip_suffix('>')?;
    Some((kind, loader(target)?))
}
fn dynamic_import(line: &str) -> Option<&'static str> {
    let tokens: Vec<&str> = line.split_whitespace().collect();
    if tokens.len() < 8 || !tokens[0].ends_with(':') || !tokens[0][..tokens[0].len()-1].bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let und = tokens.iter().position(|s| *s=="UND")?;
    loader(*tokens.get(und+1)?)
}
fn elf(path: &Path) -> Result<bool, String> {
    let meta=fs::metadata(path).map_err(|e| format!("metadata: {e}"))?;
    if !meta.is_file() || meta.len()<20 {return Ok(false);}
    if meta.len()>MAX_ELF_BYTES {return Err("Packaged file exceeds bounded ELF budget".into());}
    let mut head=[0u8;20];
    File::open(path).map_err(|e| e.to_string())?
        .read_exact(&mut head).map_err(|e| e.to_string())?;
    if &head[..4] != b"\x7fELF" {return Ok(false);}
    if head[4]!=2 || head[5]!=1 || !([2,0]==head[16..18] || [3,0]==head[16..18])
       || head[18..20]!=[62,0] {
        return Err("Original packaged ELF must be x86-64 ELF64 little-endian EXEC or DYN".into());
    }
    Ok(true)
}
fn collect(root: &Path) -> Result<Vec<(String,PathBuf)>, String> {
    if !root.is_dir(){return Err("Missing extracted original Vulpra bundle".into());}
    let mut pending=vec![(root.to_path_buf(),0)];
    let mut all=Vec::new();
    let mut visited=0usize;
    while let Some((dir,depth))=pending.pop() {
        if depth>6 {return Err("Unexpected package directory depth".into());}
        for entry in fs::read_dir(&dir).map_err(|e| e.to_string())? {
            let entry=entry.map_err(|e| e.to_string())?;
            visited+=1;
            if visited>MAX_TOTAL_MEMBERS{return Err("Too many original package paths".into());}
            let kind=entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_symlink(){continue;}
            if kind.is_dir(){pending.push((entry.path(),depth+1));continue;}
            if !kind.is_file(){return Err("Unexpected package special file".into());}
            if elf(&entry.path())? {
                let name=entry.file_name().into_string().map_err(|_| "Non-UTF8 ELF basename")?;
                if name.is_empty() || name.len()>128 || !name.bytes().all(|c| c.is_ascii_graphic()) {
                    return Err("Unbounded/unsafe packaged ELF basename".into());
                }
                all.push((name,entry.path()));
            }
        }
    }
    all.sort_by(|a,b|a.0.cmp(&b.0));
    if all.len()!=28 || all.iter().filter(|(s,_)|s=="libxul.so").count()!=1 {
        return Err(format!("Original ELF membership mismatch: expected 28 including exactly one libxul.so, found {}", all.len()));
    }
    if all.windows(2).any(|w|w[0].0==w[1].0) {
        return Err("Duplicate original ELF basenames would misattribute imports".into());
    }
    Ok(all)
}
fn imports(path: &Path) -> Result<BTreeSet<String>,String> {
    let out=Command::new("readelf").args(["--dyn-syms","--wide"]).arg(path)
        .output().map_err(|e|format!("readelf unavailable: {e}"))?;
    if !out.status.success() || out.stdout.len()>32*1024*1024 {
        return Err("readelf dynamic symbol table failed/bounds exceeded".into());
    }
    let mut result=BTreeSet::new();
    for line in String::from_utf8(out.stdout).map_err(|e|e.to_string())?.lines() {
        if let Some(name)=dynamic_import(line){result.insert(name.to_owned());}
    }
    Ok(result)
}
fn calls(path:&Path)->Result<BTreeMap<(String,String),u64>,String>{
    let mut child=Command::new("objdump").args(["-d","--no-show-raw-insn"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e|format!("objdump unavailable: {e}"))?;
    let stdout=child.stdout.take().ok_or("No objdump stdout")?;
    let mut counts=BTreeMap::new();
    let mut branches=0u64;
    for (n,l) in BufReader::new(stdout).lines().enumerate() {
        if n>=MAX_LINES_PER_ELF {
            let _=child.kill();let _=child.wait();
            return Err("Native disassembly exceeded per-ELF line budget".into());
        }
        let l=l.map_err(|e|e.to_string())?;
        if let Some((kind,target))=branch(&l) {
            branches+=1;
            if branches>MAX_BRANCHES_PER_ELF {
                let _=child.kill();let _=child.wait();
                return Err("Native direct loader branches exceeded bound".into());
            }
            *counts.entry((target.into(),kind.into())).or_insert(0)+=1;
        }
    }
    if !child.wait().map_err(|e|e.to_string())?.success() {
        return Err("GNU objdump could not disassemble packaged ELF".into());
    }
    Ok(counts)
}
fn json(s:&str)->String {
    let mut a=String::from("\"");
    for c in s.chars() {
        match c {
            '"' => a.push_str("\\\""),'\\'=>a.push_str("\\\\"),
            '\n'=>a.push_str("\\n"),'\r'=>a.push_str("\\r"),'\t'=>a.push_str("\\t"),
            x if x.is_control()=>a.push_str(&format!("\\u{:04x}",x as u32)),
            x=>a.push(x)
        }
    }
    a.push('"');a
}
fn inspect(root:&Path)->Result<String,String> {
    let members=collect(root)?;
    let mut rows=Vec::new();let mut imported=0usize;let mut branch_total=0u64;let mut branch_files=0usize;let mut import_files=0usize;
    let mut record_count=0usize;
    for (name,path) in &members {
        if name=="libxul.so" {continue;}
        let imported_names=imports(path)?;
        let branch_counts=calls(path)?;
        let count: u64=branch_counts.values().copied().sum();
        if count>0 {branch_files+=1;}
        if !imported_names.is_empty(){import_files+=1;}
        branch_total+=count;imported+=imported_names.len();record_count+=branch_counts.len();
        let names=imported_names.iter().map(|s|json(s)).collect::<Vec<_>>().join(",");
        let records=branch_counts.iter().map(|((api,kind),count)|{
            format!("{{\"loader_api\":{},\"branch_kind\":{},\"native_branches\":{}}}",json(api),json(kind),count)
        }).collect::<Vec<_>>().join(",");
        rows.push(format!("    {{\"elf_basename\":{},\"dynamic_undefined_loader_api_imports\":[{}],\"named_direct_loader_api_branches\":{},\"direct_branches\":[{}]}}",json(name),names,count,records));
    }
    if rows.len()!=27 {return Err("Expected exact 27 non-libxul native ELF members".into());}
    Ok(format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"status\":\"original_27_non_libxul_loader_api_import_and_direct_branch_census\",\n",
        "  \"original_source_commit\":{},\n  \"original_native_archive_sha256\":{},\n",
        "  \"original_packaged_elf_members\":28,\n  \"excluded_previously_audited_libxul_members\":1,\n",
        "  \"non_libxul_elf_members_inspected\":27,\n",
        "  \"non_libxul_elves_with_loader_api_imports\":{},\n",
        "  \"non_libxul_distinct_elf_loader_api_import_records\":{},\n",
        "  \"non_libxul_elves_with_direct_loader_branches\":{},\n",
        "  \"non_libxul_direct_named_loader_api_branches\":{},\n",
        "  \"non_libxul_direct_loader_api_branch_records\":{},\n",
        "  \"per_elf\":[\n{}\n  ],\n",
        "  \"no_executable_entrypoints_run\":true,\n",
        "  \"only_selected_imports_and_named_direct_branches\":true,\n",
        "  \"stripped_function_caller_attribution_proven\":false,\n",
        "  \"indirect_loader_calls_enumerated\":false,\n",
        "  \"runtime_library_argument_values_verified\":false,\n",
        "  \"all_possible_dynamic_library_routes_proven\":false,\n",
        "  \"target_endeavouros_hyprland_verified\":false,\n",
        "  \"source_pruning_authorized\":false,\n",
        "  \"m3_sixth_gate_closed\":false\n}}\n"
    ),json(SOURCE),json(ARCHIVE),import_files,imported,branch_files,branch_total,record_count,rows.join(",\n")))
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=5 || args[1]!=SOURCE || args[2]!=ARCHIVE {
        return Err("usage: original-other-elf-census PINNED_SOURCE_SHA ORIGINAL_ARCHIVE_SHA EXTRACTED_VULPRA_DIR REPORT_JSON".into());
    }
    let report=inspect(Path::new(&args[3]))?;
    fs::write(&args[4],report).map_err(|e|e.to_string())?;
    println!("PASS: original 27 non-libxul ELF direct loader API imports and calls counted; no runtime closure or pruning");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn exact_loader_names_and_parse_variants(){
        assert_eq!(loader("PR_LoadLibrary@plt"),Some("PR_LoadLibrary"));
        assert_eq!(loader("dlopen@GLIBC_2.34"),Some("dlopen"));
        assert_eq!(loader("PR_LoadLibraryWithFlags+0x8"),None);
        assert_eq!(loader("custom_dlopen"),None);
        assert_eq!(branch("   456: call   123 <dlopen@plt>"),Some(("call","dlopen")));
        assert_eq!(branch("   456: jmp    123 <PR_LoadLibraryWithFlags@plt>"),Some(("tail-jump","PR_LoadLibraryWithFlags")));
        assert_eq!(branch("   456: call   *%rax"),None);
        assert_eq!(dynamic_import("    44: 0000000000 0 FUNC GLOBAL DEFAULT UND PR_LoadLibrary@Base (2)"),Some("PR_LoadLibrary"));
        assert_eq!(dynamic_import("    44: 0000000000 0 FUNC GLOBAL DEFAULT UND unsafe_dlopen@Base (2)"),None);
    }
    #[test]fn real_compiled_elf_positive_and_negative_fixture(){
        let d=env::temp_dir().join(format!("vulpra-m3-other-elf-{}",std::process::id()));
        fs::create_dir_all(&d).unwrap();
        let src=d.join("stub.c");let lib=d.join("libtest.so");
        fs::write(&src,r#"extern void *dlopen(const char*,int);
extern void *PR_LoadLibrary(int);
void *example(void){void *a=dlopen("libx.so",0);return a?a:PR_LoadLibrary(1);}"#).unwrap();
        assert!(Command::new("cc").args(["-shared","-fPIC","-O0"]).arg(&src).arg("-o").arg(&lib).status().unwrap().success());
        assert!(elf(&lib).unwrap());
        let x=imports(&lib).unwrap();
        assert!(x.contains("dlopen") && x.contains("PR_LoadLibrary"));
        let c=calls(&lib).unwrap();
        assert!(c.get(&("dlopen".to_owned(),"call".to_owned())).copied().unwrap_or(0)>=1);
        assert!(c.get(&("PR_LoadLibrary".to_owned(),"call".to_owned())).copied().unwrap_or(0)>=1);
        fs::write(&lib,b"not an elf").unwrap();
        assert!(!elf(&lib).unwrap());
        fs::remove_dir_all(&d).unwrap();
    }
    #[test]fn absent_original_package_fails_closed(){
        assert!(inspect(Path::new("/definitely/nonexistent/original-vulpra")).is_err());
        assert_eq!(SOURCE.len(),40); assert_eq!(ARCHIVE.len(),64);
    }
}