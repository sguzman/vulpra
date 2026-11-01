// Bounded real host-ELF dynamic export check for exact pinned cubeb pulse ffi.
// Distinct from proving a Vulpra callsite, real dlopen execution or Arch ABI.
use std::collections::BTreeSet;
use std::fs::{self,File};
use std::io::{Read, BufRead, BufReader};
use std::path::Path;
use std::process::{Command,Stdio};
const REV: &str = "88194f91c8778fa608a19af7b91306094525595d";
const EXPECTED: usize = 82;

fn requested(text:&str)->Result<BTreeSet<String>,String>{
    let prefix="let fp = dlsym(h, cstr!(\"";
    let mut out=BTreeSet::new();
    for line in text.lines(){
        if let Some(offset)=line.find(prefix){
            let tail=&line[offset+prefix.len()..];
            let end=tail.find("\"));").ok_or("Unterminated dynamic PulseAudio lookup")?;
            let name=&tail[..end];
            if !name.starts_with("pa_") || !name.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'_'){
                return Err("Unexpected dynamic PulseAudio symbol".into());
            }
            if !out.insert(name.to_string()){return Err("Duplicate dynamic PulseAudio lookup".into());}
        }
    }
    if out.len()!=EXPECTED {return Err(format!("Expected {EXPECTED} literal dlsym requests, got {}",out.len()));}
    Ok(out)
}
fn host_exports(path:&Path)->Result<BTreeSet<String>,String>{
    let md=fs::metadata(path).map_err(|e|format!("Missing host library: {e}"))?;
    if !md.is_file()||md.len()<10000||md.len()>64*1024*1024 {return Err("Out-of-bounds host libpulse ELF".into());}
    let mut f=File::open(path).map_err(|e|e.to_string())?;
    let mut head=[0u8;20];f.read_exact(&mut head).map_err(|e|e.to_string())?;
    if &head[..4]!=b"\x7fELF"||head[4]!=2||head[5]!=1||head[18]!=0x3e||head[19]!=0 {
        return Err("Expected little-endian x86-64 host ELF".into());
    }
    let mut child=Command::new("nm").args(["-D","--defined-only","--no-demangle"])
        .arg(path).stdout(Stdio::piped()).stderr(Stdio::null()).spawn()
        .map_err(|e|format!("Unable to run GNU nm: {e}"))?;
    let stdout=child.stdout.take().ok_or("Missing nm output pipe")?;
    let mut names=BTreeSet::new();
    let mut count=0usize;
    for line in BufReader::new(stdout).lines(){
        let line=line.map_err(|e|e.to_string())?;
        count+=1;
        if count>500000 {let _=child.kill();let _=child.wait();return Err("Host export stream exceeded bound".into());}
        let tokens:Vec<_>=line.split_whitespace().collect();
        if tokens.len()>=3 && matches!(tokens[1],"T"|"W"|"t"|"w"){
            let name=tokens[2].split('@').next().unwrap_or("");
            if name.starts_with("pa_"){names.insert(name.to_string());}
        }
    }
    if !child.wait().map_err(|e|e.to_string())?.success(){return Err("GNU nm failed on host ELF".into());}
    Ok(names)
}
// Load the same SONAME that the pinned Rust source requests and actually ask
// glibc to resolve each name. nm export-table parity is checked separately.
#[cfg(target_os="linux")]
fn loader_resolves(needed:&BTreeSet<String>)->Result<usize,String>{
    use std::ffi::{CString,c_char,c_void};
    #[link(name="dl")]
    unsafe extern "C"{
        fn dlopen(name:*const c_char,flags:i32)->*mut c_void;
        fn dlsym(handle:*mut c_void,name:*const c_char)->*mut c_void;
        fn dlclose(handle:*mut c_void)->i32;
    }
    let lib=CString::new("libpulse.so.0").map_err(|e|e.to_string())?;
    let handle=unsafe{dlopen(lib.as_ptr(),1)}; // RTLD_LAZY, matching source
    if handle.is_null(){return Err("glibc could not dlopen libpulse.so.0".into());}
    let mut count=0;
    let mut missing=Vec::new();
    for s in needed{
        let s_c=CString::new(s.as_str()).map_err(|e|e.to_string())?;
        if unsafe{dlsym(handle,s_c.as_ptr())}.is_null(){missing.push(s.as_str());}
        else{count+=1;}
    }
    let closed=unsafe{dlclose(handle)};
    if closed!=0||!missing.is_empty(){
        return Err(format!("glibc libpulse dlsym failures: {}",missing.join(",")));
    }
    Ok(count)
}
// This CI userland is not the user's Arch/Hyprland installation.
fn detect_userland()->Result<&'static str,String>{
    if !cfg!(all(target_os="linux",target_arch="x86_64")){
        return Err("Only Linux x86-64 native ABI supported".into());
    }
    let os=fs::read_to_string("/etc/os-release").map_err(|e|e.to_string())?;
    let id=os.lines().find_map(|l|l.strip_prefix("ID="))
        .ok_or("Missing os-release ID")?.trim_matches('"');
    let version=os.lines().find_map(|l|l.strip_prefix("VERSION_ID="))
        .unwrap_or("").trim_matches('"');
    match (id,version){
        ("ubuntu","24.04")=>Ok("ubuntu-24.04-x86_64"),
        ("arch",_)=>Ok("archlinux-container-x86_64"),
        _=>Err(format!("Unverified ABI userland: {id} {version}"))
    }
}

fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=5||args[1]!=REV{return Err("usage: pulse-host-abi PINNED_CUBEB_SHA PINNED_FFI_SOURCE HOST_LIBPULSE_SO OUTPUT_JSON".into());}
    let source=fs::read_to_string(&args[2]).map_err(|e|e.to_string())?;
    if !source.contains("let h = dlopen(cstr!(\"libpulse.so.0\"), RTLD_LAZY);"){
        return Err("Pinned external FFI no longer requests libpulse.so.0".into());
    }
    let requested=requested(&source)?;
    let exports=host_exports(Path::new(&args[3]))?;
    let missing:Vec<_>=requested.difference(&exports).cloned().collect();
    if !missing.is_empty(){return Err(format!("Host libpulse lacks {} requested dynamic functions: {}",missing.len(),missing.join(",")));}
    let dynamically_resolved=loader_resolves(&requested)?;
    if dynamically_resolved!=requested.len(){return Err("Incomplete real glibc symbol resolution".into());}
    let platform=detect_userland()?;
    fs::write(&args[4],format!(
        "{{\n  \"schema_version\": 1,\n  \"external_cubeb_source_commit\": \"{REV}\",\n  \"host_platform\": \"{platform}\",\n  \"requested_dlsym_function_count\": {},\n  \"host_exported_requested_functions\": {},\n  \"missing_requested_host_functions\": 0,\n  \"single_host_library_abi_compatible\": true,\n  \"glibc_dlopen_and_dlsym_resolved_all_requested\": true,\n  \"browser_compiled_feature_flag_verified\": false,\n  \"browser_native_callsite_verified\": false,\n  \"arch_container_abi_verified\":{},\n  \"arch_host_abi_verified\": false,\n  \"all_dlopen_dependencies_closed\": false,\n  \"m3_sixth_gate_closed\": false,\n  \"source_removal_authorized\": false\n}}\n",requested.len(),requested.len(),platform=="archlinux-container-x86_64"
    )).map_err(|e|e.to_string())?;
    println!("PASS: all {} pinned cubeb PulseAudio functions resolve on {platform} native host loader",requested.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1)}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn empty_or_forged_requests_fail_closed(){
        assert!(requested("").is_err());
        assert!(requested("let fp = dlsym(h, cstr!(\"pa_fake\"));").is_err());
        assert!(requested("let fp = dlsym(h, cstr!(\"bad_sym\"));").is_err());
    }
    #[test]fn malformed_elf_rejected(){
        let p=std::env::temp_dir().join(format!("vulpra-pulse-elf-fixture-{}",std::process::id()));
        fs::write(&p,b"not elf data").unwrap();
        assert!(host_exports(&p).is_err());
        let _=fs::remove_file(p);
    }
}
