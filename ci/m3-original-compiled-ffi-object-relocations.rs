// Audits relocatable *compiled C++* object references to three source-pinned
// Rust FFI symbols. Does not assert resolved final ELF callsites or full FFI closure.
use std::fs::{self,File};
use std::io::{BufRead,BufReader,Read};
use std::path::{Path,PathBuf};
use std::process::{Command,Stdio};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const MAX_OBJECTS:usize=1000;
const MAX_BYTES:u64=1_500_000_000;
const MAX_LINES:usize=1_000_000;
const NAMES:[&str;3]=["GkRust_Init","GkRust_Shutdown","crash_generator_logic_desktop"];
fn collect(root:&Path,depth:usize,paths:&mut Vec<PathBuf>)->Result<(),String>{
    if depth>6{return Err("Relocatable object directory nesting exceeded".into());}
    let entries=fs::read_dir(root).map_err(|e|format!("Missing compiled C++ object directory: {e}"))?;
    for ent in entries{
        let ent=ent.map_err(|e|e.to_string())?;
        let kind=ent.file_type().map_err(|e|e.to_string())?;
        if kind.is_symlink(){return Err("Symlink inside compiled C++ object directory".into());}
        if kind.is_dir(){collect(&ent.path(),depth+1,paths)?;}
        else if kind.is_file()&&ent.path().extension().is_some_and(|e|e=="o"){
            paths.push(ent.path());
            if paths.len()>MAX_OBJECTS{return Err("Too many original C++ object inputs".into());}
        }
    }
    Ok(())
}
fn is_elf_reloc(path:&Path)->Result<(),String>{
    let meta=fs::metadata(path).map_err(|e|e.to_string())?;
    if meta.len()<64||meta.len()>MAX_BYTES{return Err("Unexpected C++ relocatable object size".into());}
    let mut f=File::open(path).map_err(|e|e.to_string())?;
    let mut h=[0u8;20];f.read_exact(&mut h).map_err(|e|e.to_string())?;
    if &h[..4]!=b"\x7fELF"||h[4]!=2||h[5]!=1||h[16]!=1||h[17]!=0||h[18]!=62||h[19]!=0{
        return Err("Expected little-endian x86_64 ELF ET_REL native object".into());
    }
    Ok(())
}
fn text_section(header:&str)->bool{
    let Some(name)=header.strip_prefix("Relocation section '")
        .and_then(|s|s.split('\'').next())else{return false;};
    name==".rela.text"||name.starts_with(".rela.text.")
       ||name==".rel.text"||name.starts_with(".rel.text.")
}
fn target(line:&str,active:bool)->Option<usize>{
    if !active{return None;}
    let tokens:Vec<_>=line.split_whitespace().collect();
    if tokens.len()<5||!tokens[2].starts_with("R_X86_64_"){return None;}
    if !matches!(tokens[2],"R_X86_64_PLT32"|"R_X86_64_PC32"|"R_X86_64_GOTPCREL"|"R_X86_64_GOTPCRELX"|"R_X86_64_REX_GOTPCRELX"){return None;}
    NAMES.iter().position(|&name|tokens[4]==name)
}
fn inspect(path:&Path)->Result<[usize;3],String>{
    is_elf_reloc(path)?;
    let mut cmd=Command::new("readelf")
        .args(["-Wr"]).arg(path)
        .stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e|format!("Cannot run GNU readelf: {e}"))?;
    let stdout=cmd.stdout.take().ok_or("Missing readelf output")?;
    let mut count=[0;3];let mut lines=0;let mut active=false;
    for line in BufReader::new(stdout).lines(){
        let line=line.map_err(|e|e.to_string())?;
        lines+=1;
        if lines>MAX_LINES{
            let _=cmd.kill();let _=cmd.wait();
            return Err("Unbounded native relocation stream".into());
        }
        if line.starts_with("Relocation section '"){active=text_section(&line);}
        else if let Some(i)=target(&line,active){count[i]+=1;}
    }
    if !cmd.wait().map_err(|e|e.to_string())?.success(){
        return Err("GNU readelf failed on original native object".into());
    }
    Ok(count)
}
fn group(dir:&Path,kind:usize)->Result<([usize;3],usize),String>{
    let mut paths=Vec::new();collect(dir,0,&mut paths)?;
    if paths.is_empty(){return Err("No compiled native C++ objects in expected source directory".into());}
    let mut total=[0;3];
    for path in &paths {
        let found=inspect(path)?;
        for (i,count) in found.iter().enumerate(){
            if (kind==0&&i==2)||(kind==1&&i!=2){
                if *count>0{return Err("Rust FFI relocation found in unexpected C++ consumer".into());}
            }
            total[i]+=count;
        }
    }
    Ok((total,paths.len()))
}
fn proof(root:&Path)->Result<(usize,usize,usize,usize,usize),String>{
    let (xp,xp_n)=group(&root.join("xpcom/build"),0)?;
    let (cr,cr_n)=group(&root.join("toolkit/crashreporter/crash_helper"),1)?;
    if xp[0]==0||xp[1]==0||cr[2]==0{
        return Err(format!("Missing required original C++ text relocations: init={} shutdown={} crash={}",xp[0],xp[1],cr[2]));
    }
    Ok((xp[0],xp[1],cr[2],xp_n,cr_n))
}
fn run()->Result<(),String>{
    let args:Vec<String>=std::env::args().collect();
    if args.len()!=4||args[1]!=SOURCE{
        return Err("usage: ffi-object-relocations PINNED_SOURCE_SHA OBJECT_DIRECTORY REPORT_JSON".into());
    }
    let (init,shutdown,crash,xp_n,cr_n)=proof(Path::new(&args[2]))?;
    let report=format!(
        "{{\n  \"schema_version\":1,\n  \"source_commit\":\"{SOURCE}\",\n  \"status\":\"compiled_cxx_text_relocation_imports_observed\",\n  \"original_xpcom_compiled_objects_inspected\":{xp_n},\n  \"original_crashhelper_compiled_objects_inspected\":{cr_n},\n  \"gkrust_init_text_relocations\":{init},\n  \"gkrust_shutdown_text_relocations\":{shutdown},\n  \"crash_generator_logic_desktop_text_relocations\":{crash},\n  \"all_three_expected_cxx_imports_observed\":true,\n  \"exact_cpp_source_callsite_count_proven\":false,\n  \"resolved_final_elf_callsite_machine_targets_proven\":false,\n  \"all_rust_cpp_ffi_seams_proven\":false,\n  \"conditional_dlopen_closure_proven\":false,\n  \"source_pruning_authorized\":false,\n  \"m3_sixth_gate_closed\":false\n}}\n"
    );
    fs::write(&args[3],report).map_err(|e|e.to_string())?;
    println!("PASS: 3 original native C++ text relocation imports observed; final ELF callsites not proven");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn parse_text_only_and_not_data(){
        assert!(text_section("Relocation section '.rela.text.startup' at offset 0x40 contains 1 entry:"));
        assert!(!text_section("Relocation section '.rela.data.rel.ro' at offset 0x40 contains 1 entry:"));
        assert_eq!(target("000000000004  0000000900000004 R_X86_64_PLT32 0000000000000000 GkRust_Init - 4",true),Some(0));
        assert_eq!(target("000000000004  0000000900000004 R_X86_64_PLT32 0000000000000000 GkRust_Init - 4",false),None);
    }
    #[test]fn actual_c_objects_have_expected_text_relocations(){
        let dir=std::env::temp_dir().join(format!("ffi-object-relocations-{}",std::process::id()));
        let xp=dir.join("xpcom/build");let crash=dir.join("toolkit/crashreporter/crash_helper");
        fs::create_dir_all(&xp).unwrap();fs::create_dir_all(&crash).unwrap();
        let src1=xp.join("caller.c");let src2=crash.join("caller.c");
        fs::write(&src1,"extern void GkRust_Init(void);extern void GkRust_Shutdown(void);void call_rust(void){GkRust_Init();GkRust_Shutdown();}\n").unwrap();
        fs::write(&src2,"extern int crash_generator_logic_desktop(void);int call_crash(void){return crash_generator_logic_desktop();}\n").unwrap();
        for (source,obj) in [(&src1,xp.join("caller.o")),(&src2,crash.join("caller.o"))]{
            assert!(Command::new("cc").arg("-c").arg("-fPIC").arg(source).arg("-o").arg(obj).status().unwrap().success());
        }
        let (a,b,c,_,_)=proof(&dir).unwrap();
        assert_eq!((a,b,c),(1,1,1));
        fs::remove_dir_all(dir).unwrap();
    }
    #[test]fn missing_compiled_build_fails_closed(){
        assert!(proof(Path::new("/definitely-missing-original-build")).is_err());
    }
}
