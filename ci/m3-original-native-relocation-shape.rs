// Read-only compiled ELF dynamic relocation SHAPE comparison.
// Authenticated exact-source native packages are supplied by the workflow.
// This is not a full linker map, runtime symbol binding, static Rust/C++ FFI,
// semantic equivalence, nor proof of all possible dlopen/dependency edges.
use std::collections::{BTreeMap,BTreeSet};
use std::fs::{self,File};
use std::io::{BufRead,BufReader,Read};
use std::path::{Path,PathBuf};
use std::process::{Command,Stdio};

type Counts=BTreeMap<String,u64>;
type Audit=BTreeMap<String,(Counts,Counts,u64)>;
const MAX_ROWS:usize=2_000_000;
const MAX_TEXT_BYTES:usize=256*1024*1024;

fn is_hex(s:&str)->bool{
    !s.is_empty()&&s.chars().all(|c|c.is_ascii_hexdigit())
}
fn scan_reloc_line(line:&str,section:&mut String,types:&mut Counts,names:&mut Counts)
 -> Result<bool,String>{
    if line.starts_with("Relocation section '"){
        let name=line.split('\'').nth(1).ok_or("Missing relocation section name")?;
        if !(name.starts_with(".rela.")||name.starts_with(".rel.")){
            return Err("Unexpected relocation section name".into());
        }
        *section=name.to_owned();
        return Ok(false);
    }
    let c:Vec<_>=line.split_whitespace().collect();
    if c.len()<3||!is_hex(c[0])||!is_hex(c[1])||!c[2].starts_with("R_"){
        return Ok(false);
    }
    if section.is_empty(){return Err("Relocation record without section header".into());}
    let reloc=c[2];
    if !reloc.starts_with("R_X86_64_"){
        return Err("Unexpected native relocation architecture".into());
    }
    *types.entry(format!("{section}|{reloc}")).or_default()+=1;
    // Some relocations have no symbol (RELATIVE/IRELATIVE); all other
    // relocation types are enumerated but symbol names are retained only
    // for an unambiguous readelf Name + Addend column.
    if reloc!="R_X86_64_RELATIVE"&&reloc!="R_X86_64_IRELATIVE" {
        if c.len()>=5&&is_hex(c[3])&&c[4]!="+"&&c[4]!="-"{
            let name=c[4];
            if name.len()>512||!name.is_ascii()||name.contains('/') {
                return Err("Unsafe/unbounded relocation reference name".into());
            }
            *names.entry(format!("{section}|{reloc}|{name}")).or_default()+=1;
        }
    }
    Ok(true)
}
fn inspect(elf:&Path)->Result<(Counts,Counts,u64),String>{
    let mut child=Command::new("readelf")
      .args(["--wide","--relocs","--"]).arg(elf)
      .stdout(Stdio::piped()).stderr(Stdio::null())
      .spawn().map_err(|e|e.to_string())?;
    let out=child.stdout.take().ok_or("readelf stdout missing")?;
    let reader=BufReader::new(out);
    let(mut types,mut names)=(Counts::new(),Counts::new());
    let(mut section,mut total,mut bytes)=(String::new(),0u64,0usize);
    for (n,line) in reader.lines().enumerate(){
        if n>=MAX_ROWS {return Err("Native relocation rows exceed bounded inspection".into());}
        let line=line.map_err(|e|e.to_string())?;
        bytes=bytes.saturating_add(line.len());
        if bytes>MAX_TEXT_BYTES{return Err("Native relocation text exceeds bounded size".into());}
        if scan_reloc_line(&line,&mut section,&mut types,&mut names)?{
            total+=1;
        }
    }
    if !child.wait().map_err(|e|e.to_string())?.success(){
        return Err("readelf native relocation inspection failed".into());
    }
    Ok((types,names,total))
}
fn elf_paths(root:&Path)->Result<Vec<PathBuf>,String>{
    let(mut queue,mut found,mut visited)=(vec![(root.to_owned(),0usize)],Vec::new(),0usize);
    while let Some((dir,depth))=queue.pop(){
        if depth>12{return Err("Package tree too deep".into());}
        for item in fs::read_dir(&dir).map_err(|e|e.to_string())?{
            let item=item.map_err(|e|e.to_string())?;
            visited+=1;
            if visited>100_000{return Err("Unbounded ELF package entries".into());}
            let t=item.file_type().map_err(|e|e.to_string())?;
            if t.is_symlink(){continue;}
            if t.is_dir(){queue.push((item.path(),depth+1));continue;}
            if !t.is_file(){continue;}
            let mut f=File::open(item.path()).map_err(|e|e.to_string())?;
            let mut header=[0u8;4];
            if f.read_exact(&mut header).is_ok()&&header==[0x7f,b'E',b'L',b'F']{
                found.push(item.path());
            }
        }
    }
    found.sort();
    if found.len()!=28{return Err(format!("Wrong real native ELF member count {}",found.len()));}
    Ok(found)
}
fn collect(root:&Path)->Result<Audit,String>{
    let mut found=Audit::new();
    for path in elf_paths(root)?{
        let name=path.strip_prefix(root).map_err(|e|e.to_string())?
            .to_str().ok_or("NonUTF8 ELF member")?.to_owned();
        let record=inspect(&path)?;
        if found.insert(name,record).is_some(){return Err("Duplicate ELF member".into());}
    }
    Ok(found)
}
fn changed_counts(a:&Counts,b:&Counts,sample:usize)->(usize,Vec<String>){
    let mut different=0;
    let mut examples=Vec::new();
    for k in a.keys().chain(b.keys()).collect::<BTreeSet<_>>(){
        let x=a.get(*k).copied().unwrap_or(0);
        let y=b.get(*k).copied().unwrap_or(0);
        if x!=y{
            different+=1;
            if examples.len()<sample{examples.push(format!("{k}:{x}->{y}"));}
        }
    }
    (different,examples)
}
fn quote(s:&str)->String{
    let mut out=String::from("\"");
    for ch in s.chars(){
        match ch{
            '"'=>out.push_str("\\\""),
            '\\'=>out.push_str("\\\\"),
            '\n'=>out.push_str("\\n"),
            '\r'=>out.push_str("\\r"),
            '\t'=>out.push_str("\\t"),
            c if c<' '=>out.push_str(&format!("\\u{:04x}",c as u32)),
            c=>out.push(c)
        }
    }
    out.push('"');
    out
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4{return Err("usage: native-reloc-types FULL_EXTRACTED LEAN_EXTRACTED REPORT_JSON".into());}
    let full=collect(Path::new(&args[1]))?;
    let lean=collect(Path::new(&args[2]))?;
    if full.keys().collect::<Vec<_>>()!=lean.keys().collect::<Vec<_>>(){
        return Err("Real compiled full and lean ELF file paths differ".into());
    }
    let (mut full_reloc,mut lean_reloc,mut full_names,mut lean_names)=(0u64,0u64,0u64,0u64);
    let (mut type_diff,mut name_diff,mut paths_changed)=(0usize,0usize,0usize);
    let mut details=Vec::new();
    let mut examples=Vec::new();
    for (path,(types,names,total)) in &full{
        let (types_b,names_b,total_b)=lean.get(path).ok_or("Absent ELF member")?;
        full_reloc+=total;
        lean_reloc+=total_b;
        full_names+=names.values().sum::<u64>();
        lean_names+=names_b.values().sum::<u64>();
        let(dt,te)=changed_counts(types,types_b,5);
        let(dn,ne)=changed_counts(names,names_b,5);
        type_diff+=dt;
        name_diff+=dn;
        if dt+dn>0{
            paths_changed+=1;
            for example in te.into_iter().chain(ne).take(8){
                if examples.len()<40{examples.push(format!("{path}: {example}"));}
            }
        }
        details.push(format!(
           "{{\"path\":{},\"full_relocations\":{},\"lean_relocations\":{},\
            \"changed_relocation_type_records\":{dt},\
            \"changed_named_relocation_reference_records\":{dn}}}",
            quote(path),total,total_b
        ));
    }
    if full_reloc==0||lean_reloc==0||full_names==0||lean_names==0{
        return Err("No actual compiled native relocation records or symbols".into());
    }
    let samples=examples.iter().map(|x|quote(x)).collect::<Vec<_>>().join(",");
    let output=format!(
      "{{\"schema_version\":1,\"status\":\"source_matched_28_compiled_elf_dynamic_relocation_shape_compared\",\
        \"elf_files_compared\":28,\"full_relocation_records\":{full_reloc},\
        \"lean_relocation_records\":{lean_reloc},\
        \"full_named_relocation_occurrences\":{full_names},\
        \"lean_named_relocation_occurrences\":{lean_names},\
        \"changed_per_elf_relocation_type_records\":{type_diff},\
        \"changed_per_elf_named_relocation_reference_records\":{name_diff},\
        \"elf_paths_with_relocation_record_differences\":{paths_changed},\
        \"per_elf\":[{}],\
        \"bounded_difference_samples\":[{samples}],\
        \"actual_compiled_elf_relocation_sections_inspected\":true,\
        \"relocation_offsets_and_addends_not_equated\":true,\
        \"relocations_do_not_prove_static_ffi_or_runtime_bindings\":true,\
        \"complete_dlopen_closure_proven\":false,\
        \"source_removal_authorized\":false,\
        \"m3_sixth_gate_closed\":false}}\n",details.join(","));
    fs::write(&args[3],output).map_err(|e|e.to_string())?;
    println!("PASS: examined actual source-matched native relocation records from 28 ELFs");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}

#[cfg(test)]
mod tests{
    use super::*;
    #[test]
    fn separate_type_counts_from_symbol_target_counts(){
        let (mut ty,mut sy)=(Counts::new(),Counts::new());
        let mut section=String::new();
        assert!(!scan_reloc_line("Relocation section '.rela.dyn' at offset 0x12 contains 2 entries: ",&mut section,&mut ty,&mut sy).unwrap());
        assert!(scan_reloc_line("00001234 00000000 R_X86_64_RELATIVE 12345678",&mut section,&mut ty,&mut sy).unwrap());
        assert!(scan_reloc_line("00005678 00000002 R_X86_64_GLOB_DAT 0000000000000000 memcpy@GLIBC_2.14 + 0",&mut section,&mut ty,&mut sy).unwrap());
        assert_eq!(ty[".rela.dyn|R_X86_64_RELATIVE"],1);
        assert_eq!(sy[".rela.dyn|R_X86_64_GLOB_DAT|memcpy@GLIBC_2.14"],1);
        assert_eq!(sy.len(),1);
    }
    #[test]
    fn relocation_drift_is_not_silently_ignored(){
        let a=Counts::from([("a".into(),1),("b".into(),3)]);
        let b=Counts::from([("a".into(),1),("b".into(),2),("c".into(),1)]);
        let (n,d)=changed_counts(&a,&b,4);
        assert_eq!(n,2);
        assert_eq!(d,["b:3->2","c:0->1"]);
    }
    #[test]
    fn reject_unknown_native_relocation_architecture(){
        let mut s=String::new();
        let(mut a,mut b)=(Counts::new(),Counts::new());
        assert!(scan_reloc_line("0000 0001 R_AARCH64_ABS64 0",&mut s,&mut a,&mut b).is_err());
    }
}
