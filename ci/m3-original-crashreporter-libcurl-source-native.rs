// Original source-pinned crashreporter libcurl dynamic loader candidate-table
// and native dlopen GOT machine instruction witness. No runtime library load.
use std::{collections::BTreeMap,env,fs,path::Path,process::Command};
const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const CANDIDATES: [&str;6] = [
    "libcurl.so","libcurl.so.4","libcurl-gnutls.so",
    "libcurl-gnutls.so.4","libcurl.so.3","libcurl-gnutls.so.3",
];
// Exact fixed compiled layout belongs ONLY to the authenticated original
// source b1482404 packaged binary; it is not an ABI guarantee.
const TABLE: u64 = 0x417aa8;
const DLOPEN_SLOT: u64 = 0x4556f8;
const DLOPEN_CALL: u64 = 0x1bd274;
const TABLE_REFERENCE: u64 = 0x1bd1cc;

fn le(bytes:&[u8], at:usize, n:usize)->Result<u64,String>{
    let s=bytes.get(at..at+n).ok_or("ELF integer outside file")?;
    Ok(s.iter().enumerate().fold(0u64,|a,(i,b)|a|((*b as u64)<<(8*i))))
}
fn map_address(bytes:&[u8],address:u64,size:u64)->Result<usize,String>{
    if bytes.len()<64 || &bytes[..4]!=b"\x7fELF" || bytes[4]!=2 ||
       bytes[5]!=1 || le(bytes,16,2)?!=3 || le(bytes,18,2)?!=62 {
        return Err("Expected little-endian x86-64 ET_DYN ELF".into());
    }
    let phoff=le(bytes,32,8)?;
    let n=le(bytes,56,2)?;
    let entsize=le(bytes,54,2)?;
    if n==0 || n>256 || entsize<56 || entsize>256 {return Err("Invalid bounded ELF program-header table".into());}
    for i in 0..n{
        let off=phoff.checked_add(i.checked_mul(entsize).ok_or("PHDR overflow")?).ok_or("PHDR overflow")? as usize;
        if le(bytes,off,4)?!=1 {continue;}
        let start=le(bytes,off+16,8)?;
        let fileoff=le(bytes,off+8,8)?;
        let filesz=le(bytes,off+32,8)?;
        let within=address.checked_sub(start);
        if let Some(delta)=within {
            if delta.checked_add(size).is_some_and(|end|end<=filesz){
                let pos=fileoff.checked_add(delta).ok_or("ELF file offset overflow")? as usize;
                if pos.checked_add(size as usize).is_some_and(|v|v<=bytes.len()){
                    return Ok(pos);
                }
            }
        }
    }
    Err("ELF address not backed by any file-backed PT_LOAD".into())
}
fn source_names(source:&str)->Result<Vec<String>,String>{
    if !source.contains("use libloading::{Library, Symbol};") ||
       !source.contains("CURL_LIB_NAMES.iter().find_map(|name|") ||
       !source.contains("Library::new(name)") ||
       !source.contains("static CURL: Lazy<std::io::Result<Curl>> = Lazy::new(Curl::load);") {
        return Err("Pinned original Rust libcurl route changed".into());
    }
    let start=source.find("const CURL_LIB_NAMES: &[&str] = if cfg!(target_os = \"linux\") {")
        .ok_or("Original Linux libcurl candidate declaration missing")?;
    let after=&source[start..];
    let linux=after.split("} else if cfg!(target_os = \"macos\")").next()
        .ok_or("Source Linux array end missing")?;
    let mut names=Vec::new();
    for l in linux.lines(){
        let l=l.trim();
        if let Some(stripped)=l.strip_prefix('"'){
            let name=stripped.split('"').next().ok_or("Bad candidate quote")?;
            if !name.starts_with("libcurl") || name.len()>80 {
                return Err("Unexpected libcurl candidate".into());
            }
            names.push(name.to_owned());
        }
    }
    if names != CANDIDATES.iter().map(|s|s.to_string()).collect::<Vec<_>>(){
        return Err("Original Linux libcurl names/order drift".into());
    }
    Ok(names)
}
fn relocations(text:&str)->Result<(BTreeMap<u64,u64>,bool),String>{
    let mut relative=BTreeMap::new();
    let mut found_dlopen=false;
    for line in text.lines(){
        let t:Vec<_>=line.split_whitespace().collect();
        if t.len()<3 || !t[0].bytes().all(|c|c.is_ascii_hexdigit()){continue;}
        let offset=u64::from_str_radix(t[0],16).map_err(|e|e.to_string())?;
        if offset==DLOPEN_SLOT && t[2]=="R_X86_64_GLOB_DAT"{
            if !line.contains("dlopen@GLIBC_2.2.5"){return Err("Original dlopen GOT relocation changed".into());}
            found_dlopen=true;
        }
        if t[2]=="R_X86_64_RELATIVE" && t.len()>=4 {
            if offset>=TABLE && offset<TABLE+6*16 && (offset-TABLE)%16==0 {
                let addend=u64::from_str_radix(t[3],16).map_err(|e|e.to_string())?;
                if relative.insert(offset,addend).is_some(){return Err("Duplicate relocation slot".into());}
            }
        }
    }
    if !found_dlopen || relative.len()!=6{return Err("Missing original dlopen or six table pointer relocations".into());}
    Ok((relative,found_dlopen))
}
fn instruction_address(line:&str)->Option<u64>{
    let p=line.split_once(':')?.0.trim();
    if p.is_empty()||p.len()>16||!p.bytes().all(|b|b.is_ascii_hexdigit()){return None;}
    u64::from_str_radix(p,16).ok()
}
fn machine_witness(disasm:&str)->Result<(),String>{
    let mut call=false;
    let mut reference=false;
    for line in disasm.lines(){
        if let Some(addr)=instruction_address(line){
            if addr==DLOPEN_CALL {
                if !line.contains("call") || !line.contains("*") ||
                   !line.contains("(%rip)") || !line.contains("4556f8"){
                    return Err("Actual compiled dlopen GOT call instruction changed".into());
                }
                call=true;
            }
            if addr==TABLE_REFERENCE {
                if !line.contains("lea") || !line.contains("(%rip)") ||
                   !line.contains("417aa8"){
                    return Err("Compiled libcurl table address reference changed".into());
                }
                reference=true;
            }
        }
    }
    if !call || !reference{return Err("Missing original compiled candidate table / loader call proximity witness".into());}
    Ok(())
}
fn command(name:&str,args:&[&str])->Result<String,String>{
    let result=Command::new(name).args(args).output().map_err(|e|format!("{name} unavailable: {e}"))?;
    if !result.status.success()||result.stdout.len()>40*1024*1024 {
        return Err(format!("{name} failed or exceeded bounded output"));
    }
    String::from_utf8(result.stdout).map_err(|e|e.to_string())
}
fn verify(source:&str,bytes:&[u8],readelf:&str,disasm:&str)->Result<Vec<String>,String>{
    if bytes.len()<100_000 || bytes.len()>32*1024*1024{
        return Err("Original crashreporter ELF outside bounded size".into());
    }
    let candidates=source_names(source)?;
    let (relative,_) = relocations(readelf)?;
    for (i,name) in candidates.iter().enumerate(){
        let slot=TABLE+(i as u64)*16;
        let ptr=map_address(bytes,slot,16)?;
        let length=le(bytes,ptr+8,8)?;
        if length!=name.len() as u64 {return Err(format!("Original candidate {} length mismatch",i));}
        let data_vaddr=*relative.get(&slot).ok_or("Missing candidate relocation")?;
        let off=map_address(bytes,data_vaddr,length)?;
        if bytes.get(off..off+length as usize)!=Some(name.as_bytes()){
            return Err(format!("Original compiled libcurl candidate {} byte mismatch",i));
        }
    }
    machine_witness(disasm)?;
    Ok(candidates)
}
fn quote(s:&str)->String{
    format!("\"{}\"",s.replace('\\',"\\\\").replace('"',"\\\""))
}
fn run()->Result<(),String>{
    let a:Vec<_>=env::args().collect();
    if a.len()!=6||a[1]!=SOURCE||a[2]!=ARCHIVE{
        return Err("usage: pinned-crashreporter-libcurl SOURCE_SHA ARCHIVE_SHA ORIGINAL_LIBCURL_SOURCE ORIGINAL_CRASHREPORTER OUT_JSON".into());
    }
    let source=fs::read_to_string(&a[3]).map_err(|e|e.to_string())?;
    if source.len()<8_000||source.len()>100_000{return Err("Unexpected original libcurl source size".into());}
    let bytes=fs::read(&a[4]).map_err(|e|e.to_string())?;
    let relocs=command("readelf",&["--wide","--relocs",&a[4]])?;
    let disasm=command("objdump",&["-d","--no-show-raw-insn","--start-address=0x1bd1a0","--stop-address=0x1bd2a0",&a[4]])?;
    let names=verify(&source,&bytes,&relocs,&disasm)?;
    let report=format!(
        "{{\n \"schema_version\":1,\n \"status\":\"source_and_compiled_crashreporter_libcurl_loader_candidate_table_verified\",\n \"original_source_commit\":{},\n \"original_archive_sha256\":{},\n \"native_binary\":\"crashreporter\",\n \"original_linux_candidate_count\":{},\n \"original_linux_candidate_names\":[{}],\n \"source_declares_libloading_library_new\":true,\n \"compiled_relative_relocation_backed_candidate_table_verified\":true,\n \"all_compiled_candidate_name_bytes_match_pinned_rust_source\":true,\n \"compiled_table_reference_and_dlopen_got_instruction_verified\":true,\n \"runtime_executed_route_verified\":false,\n \"runtime_selected_soname_verified\":false,\n \"all_possible_loader_paths_verified\":false,\n \"target_endeavouros_hyprland_verified\":false,\n \"source_pruning_authorized\":false,\n \"m3_sixth_gate_closed\":false\n}}\n",
        quote(SOURCE),quote(ARCHIVE),names.len(),names.iter().map(|s|quote(s)).collect::<Vec<_>>().join(","));
    fs::write(&a[5],report).map_err(|e|e.to_string())?;
    println!("PASS: six original source-to-compiled libcurl candidates in original crashreporter loader; no runtime SONAME selection or pruning");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn original_pinned_candidate_source_checks(){
        let source=r#"use libloading::{Library, Symbol};
const CURL_LIB_NAMES: &[&str] = if cfg!(target_os = "linux") {
    &[
        "libcurl.so",
        "libcurl.so.4",
        "libcurl-gnutls.so",
        "libcurl-gnutls.so.4",
        "libcurl.so.3",
        "libcurl-gnutls.so.3",
    ]
} else if cfg!(target_os = "macos") {
    &[]
};
static CURL: Lazy<std::io::Result<Curl>> = Lazy::new(Curl::load);
let lib = CURL_LIB_NAMES.iter().find_map(|name| { Library::new(name) });
"#;
        assert_eq!(source_names(source).unwrap().len(),6);
        assert!(source_names(&source.replace("libcurl.so.4","libcurl.so.9")).is_err());
        assert!(source_names(&source.replace("Library::new(name)","Library::new(\"other\")")).is_err());
    }
    #[test]fn exact_relocation_and_nearest_symbol_disassembly(){
        let mut lines=String::from("00000000004556f8  0000002e00000006 R_X86_64_GLOB_DAT 0000000000000000 dlopen@GLIBC_2.2.5 + 0\n");
        for (i,a) in [0x59400,0x5940a,0x59416,0x59427,0x5943a,0x59446].iter().enumerate(){
            lines.push_str(&format!("{:016x}  0000000000000008 R_X86_64_RELATIVE {:x}\n",TABLE+i as u64*16,a));
        }
        assert_eq!(relocations(&lines).unwrap().0.len(),6);
        assert!(relocations(&lines.replace("dlopen@GLIBC_2.2.5","fake_loader@GLIBC_2.2.5")).is_err());
        let asm="1bd1cc: lea 0x25a8d5(%rip),%rbx # 417aa8 <fake+0x20>\n1bd274: call *0x29847e(%rip) # 4556f8 <unrelated+0x41ee8>";
        machine_witness(asm).unwrap();
        assert!(machine_witness(&asm.replace("4556f8","4556e0")).is_err());
    }
    #[test]fn absent_invalid_elf_fails_closed(){
        assert!(map_address(b"not an ELF",0,10).is_err());
        assert!(verify("missing",&[], "", "").is_err());
    }
}