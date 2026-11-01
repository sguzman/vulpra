// Proof of three specific original native C++ callers issuing direct machine
// branches to named Rust FFI definitions in their final linked ELF consumers.
// Does not establish the universe of FFI seams, dynamic routes, or runtime use.
use std::{collections::BTreeMap,fs::{self,File},io::{BufRead,BufReader,Read},path::Path,process::{Command,Stdio}};
const PINNED:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const MAX_ELF_BYTES:u64=16*1024*1024*1024;
const MAX_NM_LINES:usize=12_000_000;
const MAX_DISASSEMBLY_LINES:usize=400_000;
const MAX_CANDIDATES:usize=64;
const CALLERS:[(&str,&str);4]=[
 ("NS_InitXPCOM","GkRust_Init"),
 ("NS_InitMinimalXPCOM","GkRust_Init"),
 ("mozilla::ShutdownXPCOM","GkRust_Shutdown"),
 ("main","crash_generator_logic_desktop"),
];
fn check_elf(path:&Path)->Result<(),String>{
 let meta=fs::metadata(path).map_err(|e|format!("Missing original linked ELF: {e}"))?;
 if !meta.is_file()||meta.len()<64||meta.len()>MAX_ELF_BYTES{return Err("Unexpected linked ELF bounds".into());}
 let mut file=File::open(path).map_err(|e|e.to_string())?;
 let mut h=[0u8;20];file.read_exact(&mut h).map_err(|e|e.to_string())?;
 if &h[..4]!=b"\x7fELF"||h[4]!=2||h[5]!=1||h[18]!=62||h[19]!=0||
   !matches!((h[16],h[17]),(2,0)|(3,0)){
   return Err("Expected x86-64 little-endian linked ELF executable/DSO".into());
 }
 Ok(())
}
fn demangle(raw:&str)->Result<String,String>{
 let out=Command::new("c++filt").arg("-n").arg(raw).output()
   .map_err(|e|format!("GNU c++filt missing: {e}"))?;
 if !out.status.success(){return Err("GNU c++filt failed".into());}
 String::from_utf8(out.stdout).map(|x|x.trim().to_owned()).map_err(|e|e.to_string())
}
fn classify(display:&str)->Option<usize>{
 if display=="NS_InitXPCOM"||display.starts_with("NS_InitXPCOM("){Some(0)}
 else if display=="NS_InitMinimalXPCOM"||display.starts_with("NS_InitMinimalXPCOM("){Some(1)}
 else if display.starts_with("mozilla::ShutdownXPCOM("){Some(2)}
 else if display=="main"{Some(3)}
 else{None}
}
fn candidates(path:&Path,crash:bool)->Result<BTreeMap<usize,String>,String>{
 check_elf(path)?;
 let mut child=Command::new("nm")
   .args(["--defined-only","--no-demangle","--format=posix"])
   .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
   .map_err(|e|format!("GNU nm not available: {e}"))?;
 let stdout=child.stdout.take().ok_or("Missing nm output")?;
 let mut found=BTreeMap::new();let mut lines=0;let mut possible=0;
 let mut candidate_hints=Vec::new();
 for line in BufReader::new(stdout).lines(){
   let line=line.map_err(|e|e.to_string())?;
   lines+=1;
   if lines>MAX_NM_LINES{
     let _=child.kill();let _=child.wait();
     return Err("Unbounded native ELF symbol stream".into());
   }
   let mut columns=line.split_whitespace();
   let Some(raw)=columns.next()else{continue};
   let Some(kind)=columns.next()else{continue};
   if !matches!(kind,"T"|"t"|"W"|"w"){continue;}
   if !(raw.contains("NS_InitXPCOM")||raw.contains("NS_InitMinimalXPCOM")||
        raw.contains("ShutdownXPCOM")||raw=="main"){continue;}
   possible+=1;
   if possible>MAX_CANDIDATES{
     let _=child.kill();let _=child.wait();
     return Err("Too many original native caller symbol candidates".into());
   }
   let display=demangle(raw)?;
   if candidate_hints.len()<12{candidate_hints.push(format!("{raw} [{kind}] -> {display}"));}
   if let Some(i)=classify(&display){
     if (crash&&i!=3)||(!crash&&i==3){continue;}
     if found.insert(i,raw.to_owned()).is_some(){
       let _=child.kill();let _=child.wait();
       return Err(format!("Ambiguous native caller symbol for {}",CALLERS[i].0));
     }
   }
 }
 if !child.wait().map_err(|e|e.to_string())?.success(){return Err("GNU nm failed on linked native ELF".into());}
 for idx in if crash{3..4}else{0..3}{
   if !found.contains_key(&idx){return Err(format!("Missing real native caller symbol {}; scanned {} text symbols, {} name candidates, examples: {}",CALLERS[idx].0,lines,possible,candidate_hints.join(" | ")));}
 }
 Ok(found)
}
fn disassemble(path:&Path,raw:&str,expected:&str)->Result<usize,String>{
 let mut child=Command::new("objdump")
   .arg("-d").arg("--no-show-raw-insn")
   .arg(format!("--disassemble={raw}"))
   .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
   .map_err(|e|format!("GNU objdump not available: {e}"))?;
 let stdout=child.stdout.take().ok_or("No objdump stdout")?;
 let mut count=0usize;let mut lines=0usize;let mut instructions=0usize;
 for line in BufReader::new(stdout).lines(){
   let line=line.map_err(|e|e.to_string())?;lines+=1;
   if lines>MAX_DISASSEMBLY_LINES{
     let _=child.kill();let _=child.wait();
     return Err("Unbounded caller machine disassembly".into());
   }
   let Some((pc,body))=line.split_once(':')else{continue};
   let pc=pc.trim();
   if pc.is_empty()||!pc.chars().all(|c|c.is_ascii_hexdigit()){continue;}
   let body=body.trim_start();instructions+=1;
   let first=body.split_whitespace().next().unwrap_or("");
   if !matches!(first,"call"|"callq"|"jmp"|"jmpq"){continue;}
   let Some(target)=body.rsplit_once('<').and_then(|(_,tail)|tail.strip_suffix('>'))else{continue;};
   if target==expected{count+=1;}
 }
 if !child.wait().map_err(|e|e.to_string())?.success(){return Err("GNU objdump failed on native caller".into());}
 if instructions==0{return Err("Empty disassembly for expected native caller".into());}
 Ok(count)
}
fn verify(libxul:&Path,crash:&Path)->Result<([usize;4],usize),String>{
 let x=candidates(libxul,false)?;let c=candidates(crash,true)?;
 let mut counts=[0usize;4];
 for (i,name) in x.iter().chain(c.iter()){
   counts[*i]=disassemble(if *i==3{crash}else{libxul},name,CALLERS[*i].1)?;
   if counts[*i]!=1{return Err(format!("Final native caller {} has {} direct branches to {}",CALLERS[*i].0,counts[*i],CALLERS[*i].1));}
 }
 Ok((counts,x.len()+c.len()))
}
fn run()->Result<(),String>{
 let args:Vec<_>=std::env::args().collect();
 if args.len()!=5||args[1]!=PINNED{
   return Err("usage: linked-ffi-calls PINNED_SHA ORIGINAL_UNSTRIPPED_LIBXUL ORIGINAL_UNSTRIPPED_CRASHHELPER REPORT_JSON".into());
 }
 let (counts,callers)=verify(Path::new(&args[2]),Path::new(&args[3]))?;
 let json=format!(
  "{{\n  \"schema_version\":1,\n  \"source_commit\":\"{PINNED}\",\n  \"status\":\"four_native_direct_caller_branches_to_linked_rust_ffi_definitions\",\n  \"caller_functions_verified\":{callers},\n  \"ns_init_xpcom_to_gkrust_init_branches\":{},\n  \"ns_init_minimal_xpcom_to_gkrust_init_branches\":{},\n  \"mozilla_shutdown_xpcom_to_gkrust_shutdown_branches\":{},\n  \"crashhelper_main_to_crash_generator_logic_desktop_branches\":{},\n  \"all_four_specific_native_branch_targets_verified\":true,\n  \"all_cpp_ffi_callers_enumerated\":false,\n  \"all_static_ffi_boundaries_verified\":false,\n  \"conditional_dlopen_closure_proven\":false,\n  \"source_pruning_authorized\":false,\n  \"m3_sixth_gate_closed\":false\n}}\n",
  counts[0],counts[1],counts[2],counts[3]);
 fs::write(&args[4],json).map_err(|e|e.to_string())?;
 println!("PASS: four direct machine-code branches from four exact C++ caller functions to three original linked Rust FFI definitions");
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
 use super::*;
 #[test]fn rejects_missing_and_unrelated_symbols(){
   assert_eq!(classify("NS_InitXPCOM(nsIServiceManager**)"),Some(0));
   assert_eq!(classify("NS_InitMinimalXPCOM()"),Some(1));
   assert_eq!(classify("mozilla::ShutdownXPCOM(nsIServiceManager*)"),Some(2));
   assert_eq!(classify("main"),Some(3));
   assert_eq!(classify("mozilla::NS_InitXPCOMHelper()"),None);
   assert!(verify(Path::new("/missing/libxul.so"),Path::new("/missing/crashhelper")).is_err());
 }
 #[test]fn real_compiled_cpp_linked_elf_machine_calls(){
   let dir=std::env::temp_dir().join(format!("vulpra-linked-ffi-{}",std::process::id()));
   fs::create_dir_all(&dir).unwrap();
   let a=dir.join("ffi.cpp");let b=dir.join("crash.cpp");
   fs::write(&a,r#"extern "C" __attribute__((noinline)) void GkRust_Init(){}
extern "C" __attribute__((noinline)) void GkRust_Shutdown(){}
static __attribute__((used,noinline)) void NS_InitXPCOM(){GkRust_Init();}
static __attribute__((used,noinline)) void NS_InitMinimalXPCOM(){GkRust_Init();}
namespace mozilla {static __attribute__((used,noinline)) void ShutdownXPCOM(void*){GkRust_Shutdown();}}
"#).unwrap();
   fs::write(&b,r#"extern "C" __attribute__((noinline)) int crash_generator_logic_desktop(){return 7;}
int main(){return crash_generator_logic_desktop();}
"#).unwrap();
   let lib=dir.join("libxul.so");let crash=dir.join("crashhelper");
   assert!(Command::new("c++").args(["-shared","-fPIC","-O0","-Wl,-Bsymbolic"])
     .arg(&a).arg("-o").arg(&lib).status().unwrap().success());
   assert!(Command::new("c++").args(["-O0","-no-pie"])
     .arg(&b).arg("-o").arg(&crash).status().unwrap().success());
   let (counts,n)=verify(&lib,&crash).unwrap();
   assert_eq!(counts,[1,1,1,1]);assert_eq!(n,4);
   fs::remove_dir_all(&dir).unwrap();
 }
}
