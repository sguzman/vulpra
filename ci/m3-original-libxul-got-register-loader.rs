// Bounded source-pinned ORIGINAL STRIPPED libxul.so loader GOT evidence.
// Direct RIP-relative calls, PLT-forwarding jumps, and one exact local
// GOT-load -> register-indirect call sequence. NOT a global indirect-call
// enumeration, runtime SONAME or safe pruning proof. No browser execution.
use std::{collections::BTreeMap,env,fs,path::Path,process::Command};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const ELF_SHA:&str="d6d1af9d377cab1f31bda6cfe05c52b945b21f0c37295636d0aca99fef4272cf";
const ELF_BYTES:u64=189486696;
const SLOTS:[(u64,&str,&str);5]=[
    (0xb3c33c8,"dlopen","R_X86_64_GLOB_DAT"),
    (0xb3c3428,"PR_LoadLibrary","R_X86_64_GLOB_DAT"),
    (0xb3c61a8,"dlopen","R_X86_64_JUMP_SLOT"),
    (0xb3c6258,"PR_LoadLibrary","R_X86_64_JUMP_SLOT"),
    (0xb3c6400,"PR_LoadLibraryWithFlags","R_X86_64_JUMP_SLOT"),
];
const CALLS:[(u64,u64,&str);4]=[
    (0x8cd53d1,0xb3c33c8,"call"),
    (0x9cf277e,0xb3c3428,"call"),
    (0x9cf2790,0xb3c3428,"call"),
    (0xa983e4a,0xb3c33c8,"call"),
];
const PLT:[(u64,u64,&str);3]=[
    (0xae4af70,0xb3c61a8,"jmp"),
    (0xae4b0d0,0xb3c6258,"jmp"),
    (0xae4b420,0xb3c6400,"jmp"),
];
const REGISTER_FLOW:[(u64,&str,&str);10]=[
    (0x9936640,"mov","0xb3c33c8"),
    (0x9936647,"mov","%rax,%rdi"),
    (0x993664a,"mov","$0x105,%esi"),
    (0x993664f,"call","*%r14"),
    (0x9936652,"xor","%ecx,%ecx"),
    (0x9936654,"test","%rax,%rax"),
    (0x9936657,"setne","%cl"),
    (0x993665a,"lea","%esi"),
    (0x9936661,"mov","%rbx,%rdi"),
    (0x9936664,"call","*%r14"),
];
fn run_command(name:&str,args:&[&str],max:usize)->Result<String,String>{
    let o=Command::new(name).args(args).output()
        .map_err(|e|format!("{name} tool unavailable: {e}"))?;
    if !o.status.success()||o.stdout.len()>max{return Err(format!("{name} failed/oversized"));}
    String::from_utf8(o.stdout).map_err(|e|e.to_string())
}
fn parse_relocs(text:&str)->Result<BTreeMap<u64,(String,String)>,String>{
    let mut found=BTreeMap::new();
    for line in text.lines(){
        let t:Vec<_>=line.split_whitespace().collect();
        if t.len()<5||t[0].len()>16||!t[0].bytes().all(|b|b.is_ascii_hexdigit()){continue;}
        let off=u64::from_str_radix(t[0],16).map_err(|e|e.to_string())?;
        if !SLOTS.iter().any(|(slot,_,_)|*slot==off){continue;}
        let symbol=t[4].split('@').next().unwrap_or(t[4]);
        if found.insert(off,(symbol.into(),t[2].into())).is_some(){
            return Err("Duplicate native loader GOT relocation address".into());
        }
    }
    for (off,api,kind) in SLOTS{
        let Some((observed_api,observed_kind))=found.get(&off) else{
            return Err(format!("Missing original relocation {off:x}"));
        };
        if observed_api!=api||observed_kind!=kind{
            return Err(format!("Native original loader relocation mismatch at {off:x}"));
        }
    }
    Ok(found)
}
fn insns(text:&str)->Result<BTreeMap<u64,(String,String,String)>,String>{
    let mut records=BTreeMap::new();
    let mut section=String::new();
    for l in text.lines(){
        if let Some(t)=l.strip_prefix("Disassembly of section "){
            section=t.trim_end_matches(':').to_string();continue;
        }
        let Some((addr,rest))=l.split_once(':') else{continue};
        let addr=addr.trim();
        if addr.is_empty()||addr.len()>16||!addr.bytes().all(|b|b.is_ascii_hexdigit()){continue;}
        let address=u64::from_str_radix(addr,16).map_err(|e|e.to_string())?;
        let op=rest.trim().split_whitespace().next().unwrap_or("");
        if op.is_empty(){continue;}
        if records.insert(address,(op.to_owned(),rest.to_owned(),section.clone())).is_some(){
            return Err("Duplicate native instruction address".into());
        }
    }
    Ok(records)
}
fn got_slot(record:&(String,String,String))->Option<u64>{
    let (_,text,_)=record;
    let (left,comment)=text.split_once('#')?;
    if !left.contains("(%rip)")||!left.contains('*'){return None;}
    let hex=comment.trim().split_whitespace().next()?;
    if hex.is_empty()||hex.len()>16||!hex.bytes().all(|b|b.is_ascii_hexdigit()){return None;}
    u64::from_str_radix(hex,16).ok()
}
fn verify_insn(text:&str,addr:u64,slot:u64,op:&str,section:&str)->Result<(),String>{
    let map=insns(text)?;
    let record=map.get(&addr).ok_or_else(||format!("Missing native instruction {addr:x}"))?;
    if record.0!=op||record.2!=section||got_slot(record)!=Some(slot){
        return Err(format!("Wrong original native GOT instruction {addr:x}"));
    }
    Ok(())
}
fn verify_register_flow(text:&str)->Result<(),String>{
    let map=insns(text)?;
    let keys:Vec<u64>=map.keys().copied().collect();
    let expected:Vec<u64>=REGISTER_FLOW.iter().map(|r|r.0).collect();
    if keys!=expected {
        return Err("Original register-indirect block has extra/missing instructions".into());
    }
    for (addr,op,operand) in REGISTER_FLOW{
        let record=map.get(&addr).ok_or("Missing register-flow instruction")?;
        if record.0!=op||record.2!=".text"{
            return Err(format!("Changed native register-flow opcode at {addr:x}"));
        }
        if addr==0x9936640{
            if got_slot_load(record)!=Some(0xb3c33c8)||!record.1.contains(",%r14"){
                return Err("Original dlopen GOT pointer does not load into r14".into());
            }
        }else if !record.1.contains(operand){
            return Err(format!("Unexpected register-flow operand at {addr:x}"));
        }
    }
    Ok(())
}
fn got_slot_load(record:&(String,String,String))->Option<u64>{
    let (_,text,_)=record;
    let (left,comment)=text.split_once('#')?;
    if !left.contains("(%rip)")||left.contains('*'){return None;}
    let hex=comment.trim().split_whitespace().next()?;
    if hex.is_empty()||hex.len()>16||!hex.bytes().all(|b|b.is_ascii_hexdigit()){return None;}
    u64::from_str_radix(hex,16).ok()
}
fn native_window(elf:&str,start:u64,end:u64)->Result<String,String>{
    run_command("objdump",&[
        "-d","--no-show-raw-insn",
        &format!("--start-address=0x{start:x}"),
        &format!("--stop-address=0x{end:x}"),elf],128*1024)
}
fn inspect(elf:&Path)->Result<(),String>{
    let meta=fs::metadata(elf).map_err(|e|e.to_string())?;
    if !meta.is_file()||meta.len()!=ELF_BYTES{return Err("Original packaged libxul byte-size mismatch".into());}
    let file=elf.to_str().ok_or("Non-UTF8 ELF path")?;
    let header=run_command("readelf",&["-h",file],32*1024)?;
    if !header.contains("ELF64")||!header.contains("X86-64")||
       !header.contains("DYN (Position-Independent Executable file)") && !header.contains("DYN (Shared object file)") {
        return Err("Expected original native x86-64 ELF shared object".into());
    }
    let hash=run_command("sha256sum",&[file],2048)?;
    if hash.split_whitespace().next()!=Some(ELF_SHA){
        return Err("Original source-pinned packaged libxul SHA256 mismatch".into());
    }
    parse_relocs(&run_command("readelf",&["-Wr",file],48*1024*1024)?)?;
    for (addr,slot,op) in CALLS{
        verify_insn(&native_window(file,addr,addr+6)?,addr,slot,op,".text")?;
    }
    for (addr,slot,op) in PLT{
        verify_insn(&native_window(file,addr,addr+6)?,addr,slot,op,".plt")?;
    }
    verify_register_flow(&native_window(file,0x9936640,0x9936667)?)?;
    Ok(())
}
fn json(s:&str)->String{format!("\"{}\"",s)}
fn run()->Result<(),String>{
    let a:Vec<_>=env::args().collect();
    if a.len()!=5||a[1]!=SOURCE||a[2]!=ARCHIVE{
        return Err("usage: original-libxul-got SOURCE_SHA ARCHIVE_SHA ORIGINAL_LIBXUL_ELF OUTPUT_JSON".into());
    }
    inspect(Path::new(&a[3]))?;
    let report=format!(concat!(
        "{{\n \"schema_version\":1,\n",
        " \"status\":\"original_stripped_libxul_compiled_loader_got_and_register_indirect_sequence_verified\",\n",
        " \"original_source_commit\":{},\n \"original_archive_sha256\":{},\n",
        " \"original_stripped_libxul_sha256\":{},\n \"original_stripped_libxul_bytes\":{},\n",
        " \"selected_exact_native_loader_dynamic_relocations\":5,\n",
        " \"selected_got_indirect_nonplt_calls\":4,\n",
        " \"selected_plt_loader_jumps\":3,\n",
        " \"selected_register_indirect_dlopen_calls\":2,\n",
        " \"selected_register_got_loads\":1,\n",
        " \"selected_compiled_nonplt_loader_calls\":6,\n",
        " \"all_verified_instruction_addresses_in_source_pinned_original_stripped_binary\":true,\n",
        " \"no_browser_code_executed\":true,\n",
        " \"actual_runtime_dlopen_soname_arguments_proven\":false,\n",
        " \"all_register_indirect_loader_routes_enumerated\":false,\n",
        " \"complete_native_loader_dependency_graph_proven\":false,\n",
        " \"target_user_workstation_verified\":false,\n",
        " \"source_pruning_authorized\":false,\n",
        " \"m3_sixth_gate_closed\":false\n}}\n"
    ),json(SOURCE),json(ARCHIVE),json(ELF_SHA),ELF_BYTES);
    fs::write(&a[4],report).map_err(|e|e.to_string())?;
    println!("PASS: 5 loader relocations; 4 non-PLT GOT calls; 2 GOT-to-register dlopen calls; 3 PLT forwards; not complete closure");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn numeric_got_parser_disregards_unrelated_nearest_symbol(){
        let raw="Disassembly of section .text:\n 9936640: mov 0x1a8cd81(%rip),%r14 # b3c33c8 <__fxstatat64@plt+0x5702b8>\n 993664f: call *%r14";
        let m=insns(raw).unwrap();
        assert_eq!(got_slot_load(m.get(&0x9936640).unwrap()),Some(0xb3c33c8));
        assert_eq!(got_slot(m.get(&0x993664f).unwrap()),None);
        let call="Disassembly of section .text:\n 8cd53d1: call *0x26edff1(%rip) # b3c33c8 <__fxstatat64@plt+0x5702b8>";
        verify_insn(call,0x8cd53d1,0xb3c33c8,"call",".text").unwrap();
        assert!(verify_insn(call,0x8cd53d1,0xb3c3428,"call",".text").is_err());
    }
    #[test]fn relocation_mismatch_and_duplicate_fail_closed(){
        let s="000000000b3c33c8  0000021400000006 R_X86_64_GLOB_DAT 0000000000000000 dlopen@GLIBC_2.2.5 + 0\n";
        assert!(parse_relocs(s).is_err());
        let bad=s.replace("dlopen","dlfake");
        assert!(parse_relocs(&bad).is_err());
        assert!(insns("Disassembly of section .text:\n 1: call x\n 1: call y").is_err());
    }
    #[test]fn register_indirect_sequence_mutation_rejected(){
        let mut s=String::from("Disassembly of section .text:\n");
        for (addr,op,operand) in REGISTER_FLOW{
            let text=if addr==0x9936640{
                format!("{addr:x}: mov 0x1a8cd81(%rip),%r14 # b3c33c8 <unrelated+123>")
            }else if addr==0x993665a{
                format!("{addr:x}: lea 0x101(,%rcx,4),%esi")
            }else {
                format!("{addr:x}: {op} {operand}")
            };
            s.push_str(&text);s.push('\n');
        }
        verify_register_flow(&s).unwrap();
        assert!(verify_register_flow(&s.replace("9936664: call *%r14","9936664: call *%r13")).is_err());
        assert!(verify_register_flow(&s.replace("9936640: mov","9936640: xor")).is_err());
    }
}