// Source-pinned original WebAuthn libudev dynamic-loader implementation:
// exact rust lazy loader + 12-byte SONAME compiled construction, GOT entry,
// and branch-conditional two real dlopen machine calls. Read-only.
use std::{collections::BTreeMap,env,fs,path::Path,process::Command};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const ELF_SHA:&str="d6d1af9d377cab1f31bda6cfe05c52b945b21f0c37295636d0aca99fef4272cf";
const ELF_SIZE:u64=189486696;
const GOT:u64=0xb3c33c8;
fn bounded_command(cmd:&str,args:&[&str],bound:usize)->Result<String,String>{
    let out=Command::new(cmd).args(args).output().map_err(|e|format!("{cmd}: {e}"))?;
    if !out.status.success()||out.stdout.len()>bound{
        return Err(format!("{cmd} unsuccessful or exceeded bounded output"));
    }
    String::from_utf8(out.stdout).map_err(|e|e.to_string())
}
fn source_witness(text:&str)->Result<(),String>{
    let tokens=[
        "use libc::{RTLD_GLOBAL,RTLD_LAZY,RTLD_NOLOAD};",
        "use libc::{dlopen,dlclose,dlsym};",
        "($a:expr, $b:expr)",
        "if $a.is_null() { $b } else { $a }",
        "let flags = RTLD_LAZY | RTLD_GLOBAL;",
        "let flags_noload = flags | RTLD_NOLOAD;",
        "let name = CString::new(name).unwrap();",
        "ifnull!(dlopen(name, flags_noload), dlopen(name, flags))",
        "Library::open(\"libudev.so.1\")",
        "Symbol::new(LIBRARY.get(stringify!($name)))",
        "define!(udev_new, extern \"C\" fn () -> *mut udev);",
        "pub static ref $name : Symbol<$type>",
    ];
    for needle in tokens{
        if !text.contains(needle){return Err(format!("Original WebAuthn libudev source missing {}",needle.replace('"',"'")));}
    }
    let start=text.find("fn open(name: &'static str) -> Library {")
        .ok_or("Missing exact original libudev Library::open")?;
    let end=text[start..].find("\n  fn get(").ok_or("Missing original Libudev open end")?;
    let region=&text[start..start+end];
    for needle in ["let flags = RTLD_LAZY | RTLD_GLOBAL;",
        "let flags_noload = flags | RTLD_NOLOAD;",
        "ifnull!(dlopen(name, flags_noload), dlopen(name, flags))"]{
        if !region.contains(needle){return Err("Loader fallback implementation changed".into());}
    }
    let open=text.find("Library::open(\"libudev.so.1\")").ok_or("Missing actual lazy library")?;
    if !text[..open].contains("lazy_static!"){return Err("Original lazy static library path changed".into());}
    Ok(())
}
fn relocation_witness(text:&str)->Result<(),String>{
    let mut found=0;
    for line in text.lines(){
        let t:Vec<_>=line.split_whitespace().collect();
        if t.len()<5||t[0].len()>16||!t[0].bytes().all(|c|c.is_ascii_hexdigit()){continue;}
        if u64::from_str_radix(t[0],16).map_err(|e|e.to_string())?!=GOT{continue;}
        if t[2]!="R_X86_64_GLOB_DAT" || !t[4].starts_with("dlopen@GLIBC_2.2.5"){
            return Err("Wrong original WebAuthn libudev native dlopen relocation".into());
        }
        found+=1;
    }
    if found!=1 {return Err("Original libudev dlopen slot missing/ambiguous".into());}
    Ok(())
}
fn parse_window(text:&str)->Result<BTreeMap<u64,(String,String)>,String>{
    let mut found=BTreeMap::new();
    for line in text.lines(){
        let Some((a,raw))=line.split_once(':') else {continue};
        let a=a.trim();
        if a.is_empty()||a.len()>16||!a.bytes().all(|b|b.is_ascii_hexdigit()){continue;}
        let addr=u64::from_str_radix(a,16).map_err(|e|e.to_string())?;
        let instruction=raw.trim().to_owned();
        let op=instruction.split_whitespace().next().unwrap_or("").to_owned();
        if op.is_empty(){continue;}
        if found.insert(addr,(op,instruction)).is_some(){
            return Err("Duplicate native WebAuthn instruction address".into());
        }
    }
    Ok(found)
}
fn check(map:&BTreeMap<u64,(String,String)>,addr:u64,op:&str,parts:&[&str])->Result<(),String>{
    let (actual,insn)=map.get(&addr).ok_or_else(||format!("Missing original native instruction {addr:x}"))?;
    if actual!=op||parts.iter().any(|p|!insn.contains(p)){
        return Err(format!("Original native libudev instruction mismatch at {addr:x}"));
    }
    Ok(())
}
fn machine_witness(disasm:&str)->Result<(),String>{
    let m=parse_window(disasm)?;
    let expected=[
        (0x99365f4,"mov",&["$0xd,%edi"][..]),
        (0x9936608,"movabs",&["$0x2e7665647562696c","%rcx"][..]),
        (0x9936612,"mov",&["%rcx,(%rax)"][..]),
        (0x9936615,"movl",&["$0x312e6f73","0x8(%rax)"][..]),
        (0x993661c,"movq",&["$0xd,(%rsp)"][..]),
        (0x9936624,"mov",&["%rax,0x8(%rsp)"][..]),
        (0x9936629,"movq",&["$0xc,0x10(%rsp)"][..]),
        (0x9936632,"mov",&["%rsp,%rdi"][..]),
        (0x993663a,"mov",&["%rax,%rbx"][..]),
        (0x9936640,"mov",&["(%rip)","%r14","b3c33c8"][..]),
        (0x9936647,"mov",&["%rax,%rdi"][..]),
        (0x993664a,"mov",&["$0x105,%esi"][..]),
        (0x993664f,"call",&["*%r14"][..]),
        (0x9936652,"xor",&["%ecx,%ecx"][..]),
        (0x9936654,"test",&["%rax,%rax"][..]),
        (0x9936657,"setne",&["%cl"][..]),
        (0x993665a,"lea",&["0x101(,%rcx,4),%esi"][..]),
        (0x9936661,"mov",&["%rbx,%rdi"][..]),
        (0x9936664,"call",&["*%r14"][..]),
    ];
    for (addr,op,parts) in expected{check(&m,addr,op,parts)?;}
    // Verify exactly the original 64-bit and 32-bit immediates spell
    // libudev.so.1 (not relying on unrelated objdump nearest symbols).
    let mut string=0x2e7665647562696cu64.to_le_bytes().to_vec();
    string.extend_from_slice(&0x312e6f73u32.to_le_bytes());
    if string.as_slice()!=b"libudev.so.1"{
        return Err("libudev native constructed SONAME is not the source constant".into());
    }
    if !m.contains_key(&0x9936635)||!m.contains_key(&0x993663d){
        return Err("Missing intermediate native source-to-call construction".into());
    }
    Ok(())
}
fn verify(source:&str,elf:&Path)->Result<(),String>{
    source_witness(source)?;
    let meta=fs::metadata(elf).map_err(|e|e.to_string())?;
    if !meta.is_file()||meta.len()!=ELF_SIZE{
        return Err("Original packaged libxul file size differs".into());
    }
    let file=elf.to_str().ok_or("Non-UTF8 native file path")?;
    let hash=bounded_command("sha256sum",&[file],2048)?;
    if hash.split_whitespace().next()!=Some(ELF_SHA){
        return Err("Original libxul SHA-256 mismatch".into());
    }
    let relocs=bounded_command("readelf",&["-Wr",file],48*1024*1024)?;
    relocation_witness(&relocs)?;
    let text=bounded_command("objdump",&[
        "-d","--no-show-raw-insn",
        "--start-address=0x99365f0","--stop-address=0x9936667",file
    ],32*1024)?;
    machine_witness(&text)?;
    Ok(())
}
fn quote(s:&str)->String{format!("\"{}\"",s)}
fn run()->Result<(),String>{
    let a:Vec<_>=env::args().collect();
    if a.len()!=6||a[1]!=SOURCE||a[2]!=ARCHIVE{
        return Err("usage: original-libudev SOURCE_SHA ARCHIVE_SHA ORIGINAL_LIBUDEV_SOURCE ORIGINAL_LIBXUL OUTPUT_JSON".into());
    }
    let source=fs::read_to_string(&a[3]).map_err(|e|e.to_string())?;
    if !(5_000..=40_000).contains(&source.len()){
        return Err("Unexpected original libudev Rust source byte bounds".into());
    }
    verify(&source,Path::new(&a[4]))?;
    let out=format!(concat!(
        "{{\n \"schema_version\":1,\n",
        " \"status\":\"original_webauthn_libudev_source_to_native_register_dlopen_candidate_verified\",\n",
        " \"original_source_commit\":{},\n \"original_archive_sha256\":{},\n",
        " \"native_libxul_sha256\":{},\n \"native_libxul_bytes\":{},\n",
        " \"original_source_path\":\"dom/webauthn/libudev-sys/src/lib.rs\",\n",
        " \"native_constructed_soname\":\"libudev.so.1\",\n",
        " \"source_conditional_lazy_library\":true,\n",
        " \"source_libudev_udev_new_null_fallback\":true,\n",
        " \"native_dlopen_got_glibc_2_2_5_relocation_verified\":true,\n",
        " \"native_first_call_register_r14_address\":{},\n",
        " \"native_second_call_register_r14_address\":{},\n",
        " \"native_first_rtld_flags_hex\":\"0x105\",\n",
        " \"native_second_rtld_flags_conditional_hex\":[\"0x101\",\"0x105\"],\n",
        " \"source_ifnull_macro_evaluates_first_argument_twice_on_success\":true,\n",
        " \"native_compiled_candidate_argument_verified\":true,\n",
        " \"actual_webauthn_key_flow_executed\":false,\n",
        " \"actual_runtime_libudev_soname_loaded\":false,\n",
        " \"complete_dynamic_library_dependency_graph_verified\":false,\n",
        " \"target_endeavouros_hyprland_verified\":false,\n",
        " \"source_pruning_authorized\":false,\n",
        " \"m3_sixth_gate_closed\":false\n}}\n"
    ),quote(SOURCE),quote(ARCHIVE),quote(ELF_SHA),ELF_SIZE,0x993664fu64,0x9936664u64);
    fs::write(&a[5],out).map_err(|e|e.to_string())?;
    println!("PASS: pinned WebAuthn libudev.so.1 lazy source / original native two register dlopen callsites; no runtime or prune");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn source_fails_without_lazy_or_no_load_guard(){
        assert!(source_witness("not the original source").is_err());
        let source=std::fs::read_to_string(std::env::var("M3_ORIGINAL_UDEV_SOURCE_FILE").unwrap()).unwrap();
        source_witness(&source).unwrap();
        assert!(source_witness(&source.replace("RTLD_NOLOAD","RTLD_MISSING")).is_err());
        assert!(source_witness(&source.replace("Library::open(\"libudev.so.1\")","Library::open(\"fake.so\")")).is_err());
    }
    #[test]fn relocation_rejects_wrong_function_or_version(){
        let line="000000000b3c33c8  0000021400000006 R_X86_64_GLOB_DAT 0000000000000000 dlopen@GLIBC_2.2.5 + 0";
        relocation_witness(line).unwrap();
        assert!(relocation_witness(&line.replace("dlopen","dlmopen")).is_err());
        assert!(relocation_witness(&line.replace("GLIBC_2.2.5","GLIBC_2.100")).is_err());
        assert!(relocation_witness(&(line.to_owned()+"\n"+line)).is_err());
    }
    #[test]fn valid_compiled_libudev_window_detects_specific_mutations(){
        // Literal machine-text fixture from the SHA-pinned original ELF.
        // Do not substitute this for the separate real-binary CI proof.
        let valid=r#"Disassembly of section .text:
 99365f4: mov $0xd,%edi
 9936608: movabs $0x2e7665647562696c,%rcx
 9936612: mov %rcx,(%rax)
 9936615: movl $0x312e6f73,0x8(%rax)
 993661c: movq $0xd,(%rsp)
 9936624: mov %rax,0x8(%rsp)
 9936629: movq $0xc,0x10(%rsp)
 9936632: mov %rsp,%rdi
 9936635: call 8a4c820 <XRE_GetBootstrap@@libxul.so+0xd09e30>
 993663a: mov %rax,%rbx
 993663d: mov %rdx,%r15
 9936640: mov 0x1a8cd81(%rip),%r14 # b3c33c8 <unrelated-label>
 9936647: mov %rax,%rdi
 993664a: mov $0x105,%esi
 993664f: call *%r14
 9936652: xor %ecx,%ecx
 9936654: test %rax,%rax
 9936657: setne %cl
 993665a: lea 0x101(,%rcx,4),%esi
 9936661: mov %rbx,%rdi
 9936664: call *%r14"#;
        machine_witness(valid).unwrap();
        for (old,new) in [
            ("0x2e7665647562696c","0x2e7665647562696d"),
            ("0x312e6f73","0x312e6f72"),
            ("0x105,%esi","0x104,%esi"),
            ("0x101(,%rcx,4)","0x103(,%rcx,4)"),
            ("b3c33c8","b3c33d8"),
            ("9936664: call *%r14","9936664: call *%r13"),
            ("993664f: call *%r14","993664f: call *%r13"),
        ]{
            let mutated=valid.replace(old,new);
            assert_ne!(mutated,valid);
            assert!(machine_witness(&mutated).is_err(),
                "Unexpectedly accepted mutation from {old} to {new}");
        }
    }
    #[test]fn wrong_machine_register_flow_fails_closed(){
        let mut fake=String::from("Disassembly of section .text:\n");
        for (addr,op,s) in [
            (0x9936608,"movabs","$0x2e7665647562696c,%rcx"),
            (0x9936615,"movl","$0x312e6f73,0x8(%rax)"),
            (0x9936640,"mov","0x1a8cd81(%rip),%r14 # b3c33c8"),
            (0x993664f,"call","*%r14"),
            (0x9936664,"call","*%r13")] {
            fake.push_str(&format!(" {addr:x}: {op} {s}\n"));
        }
        assert!(machine_witness(&fake).is_err());
    }
}