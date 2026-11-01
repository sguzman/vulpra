// Bounded source-pinned Arch FFmpeg63 ELF dependency tracer: actual DT_NEEDED
// vs glibc ldd resolution on ONE disposable host library, not browser graph.
use std::{collections::BTreeSet,fs,path::Path,process::Command};
const PINNED:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ROOT:&str="libavcodec.so.63";
fn safe_name(n:&str)->bool{
    !n.is_empty()&&n.len()<=128&&n.bytes().all(|b|
        b.is_ascii_alphanumeric()||matches!(b,b'.'|b'_'|b'-'|b'+'))
}
fn parse_needed(out:&str)->Result<BTreeSet<String>,String>{
    let mut names=BTreeSet::new();
    for line in out.lines(){
        if !line.contains("(NEEDED)"){continue;}
        let start=line.find("Shared library: [").ok_or("Malformed ELF NEEDED record")?
            +"Shared library: [".len();
        let name=line[start..].split_once(']').ok_or("Unclosed ELF NEEDED name")?.0;
        if !safe_name(name){return Err("Unsafe ELF dependency name".into());}
        if !names.insert(name.into()){return Err("Duplicate DT_NEEDED entry".into());}
    }
    if names.len()<3||names.len()>150{return Err(format!("Unexpected direct NEEDED count {}",names.len()));}
    Ok(names)
}
fn parse_ldd(out:&str)->Result<BTreeSet<String>,String>{
    let mut found=BTreeSet::new();
    for line in out.lines(){
        let line=line.trim();
        if line.contains("not found"){return Err("Host ldd has unresolved dependencies".into());}
        if let Some((name,target))=line.split_once(" => "){
            let path=target.split_whitespace().next().ok_or("No ldd target path")?;
            if !safe_name(name)||!path.starts_with('/')||!Path::new(path).exists(){
                return Err(format!("Invalid ldd binding for {name}"));
            }
            if !found.insert(name.into()){return Err("Duplicate glibc ldd name".into());}
        }
    }
    if found.len()<5||found.len()>500{return Err(format!("Unexpected resolved transitive DSO count {}",found.len()));}
    Ok(found)
}
fn capture(program:&str,args:&[&str])->Result<String,String>{
    let out=Command::new(program).args(args).output().map_err(|e|e.to_string())?;
    if !out.status.success()||out.stdout.len()>1024*1024||out.stdout.is_empty(){
        return Err(format!("Failed or out-of-bounds {program} response"));
    }
    String::from_utf8(out.stdout).map_err(|e|e.to_string())
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4||args[1]!=PINNED{
        return Err("usage: arch-ffmpeg63-elf-closure SOURCE_SHA ROOT_LIBAVCODEC_SO JSON".into());
    }
    let file=Path::new(&args[2]);
    if file.file_name().and_then(|s|s.to_str())!=Some(ROOT) || !file.is_file(){
        return Err("Input must be real libavcodec.so.63".into());
    }
    let os=fs::read_to_string("/etc/os-release").map_err(|e|e.to_string())?;
    if !os.lines().any(|s|s=="ID=arch"){return Err("Not the verified Arch container".into());}
    let name=file.to_str().ok_or("Non UTF-8 library path")?;
    let needed=parse_needed(&capture("readelf",&["-d",name])?)?;
    let resolved=parse_ldd(&capture("ldd",&[name])?)?;
    let missing:Vec<_>=needed.difference(&resolved).cloned().collect();
    if !missing.is_empty(){return Err(format!("Missing dynamic loader bindings: {}",missing.join(",")));}
    let quoted=|names:&BTreeSet<String>|names.iter().map(|s|format!("\"{s}\""))
        .collect::<Vec<_>>().join(",");
    let report=format!(
        "{{\n \"schema_version\":1,\n \"gecko_source_commit\":\"{PINNED}\",\n \"userland\":\"archlinux-container-x86_64\",\n \"root\":\"{ROOT}\",\n \"direct_elf_needed_count\":{},\n \"resolved_glibc_ldd_name_count\":{},\n \"missing_direct_needed_count\":0,\n \"direct_needed_names\":[{}],\n \"resolved_transitive_names\":[{}],\n \"all_observed_ldd_bindings_resolved\":true,\n \"complete_conditional_dlopen_graph_proven\":false,\n \"original_browser_compiled_root_proven\":false,\n \"target_workstation_verified\":false,\n \"m3_sixth_gate_closed\":false,\n \"source_pruning_authorized\":false\n}}\n",
        needed.len(),resolved.len(),quoted(&needed),quoted(&resolved)
    );
    fs::write(&args[3],report).map_err(|e|e.to_string())?;
    println!("PASS: Arch FFmpeg63 direct ELF DT_NEEDED {}/{} glibc-resolved, with {} total ldd names",needed.len(),needed.len(),resolved.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn real_style_needed_parser(){
        let x="0x00000001 (NEEDED) Shared library: [libavutil.so.61]\n0x00000001 (NEEDED) Shared library: [libc.so.6]\n0x00000001 (NEEDED) Shared library: [libm.so.6]";
        assert_eq!(parse_needed(x).unwrap().len(),3);
        assert!(parse_needed("NO NEEDED").is_err());
    }
    #[test]fn ldd_missing_symbol_and_truncated_report_fail_closed(){
        assert!(parse_ldd("liba.so => not found").is_err());
        assert!(parse_ldd("libc.so.6 => /nonexistent/library (0xabc)").is_err());
    }
}
