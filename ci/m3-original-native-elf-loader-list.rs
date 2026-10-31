// Read-only glibc interpreter --list for each original source-pinned regular
// ELF member. Commands run only in a disposable no-egress CI namespace.
// Application main/feature code is not invoked; no absolute paths, process IDs,
// loader stdout/stderr or user profiles are exported.
use std::collections::{BTreeMap,BTreeSet};
use std::env;
use std::fs::{self,File};
use std::io::{Read,Write};
use std::path::{Path,PathBuf};
use std::process::Command;
const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";

fn safe_name(s:&str)->Option<&str>{
 let n=s.rsplit('/').next()?;
 if n.is_empty()||n.len()>111||!n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None;}
 Some(n)
}
fn collect(dir:&Path,depth:usize,entries:&mut Vec<PathBuf>)->Result<(),String>{
 if depth>6{return Err("unexpected original package nesting".into());}
 for e in fs::read_dir(dir).map_err(|_|"cannot read package directory")? {
  let p=e.map_err(|_|"bad original package entry")?.path();
  let m=fs::symlink_metadata(&p).map_err(|_|"bad original member metadata")?;
  if m.file_type().is_dir(){collect(&p,depth+1,entries)?;continue;}
  if !m.file_type().is_file(){continue;}
  if m.len()<4||m.len()>384*1024*1024{continue;}
  let mut f=File::open(&p).map_err(|_|"unreadable original package member")?;
  let mut magic=[0;4];
  f.read_exact(&mut magic).map_err(|_|"truncated original member")?;
  if magic==[0x7f,b'E',b'L',b'F']{entries.push(p);}
 }
 Ok(())
}
fn run_cmd(program:&str,args:&[&str],root:&Path)->Result<String,String>{
 let lib_path=format!("{}:{}",root.display(),root.join("gmp-clearkey/0.1").display());
 let out=Command::new("timeout")
   .args(["--signal=TERM","--kill-after=2s","12s",program])
   .args(args)
   .env("LD_LIBRARY_PATH",lib_path)
   .env_remove("LD_DEBUG")
   .env_remove("LD_DEBUG_OUTPUT")
   .env_remove("HTTP_PROXY").env_remove("HTTPS_PROXY").env_remove("ALL_PROXY")
   .output().map_err(|_|"failed to launch restricted native metadata command")?;
 if !out.status.success()||out.stdout.len()>512*1024||out.stderr.len()>512*1024{
  return Err("restricted original ELF loader or readelf metadata check failed".into());
 }
 String::from_utf8(out.stdout).map_err(|_|"non-UTF8 loader metadata".into())
}
fn needed(text:&str)->Result<BTreeSet<String>,String>{
 let mut names=BTreeSet::new();
 for l in text.lines(){
  let Some((_,rest))=l.split_once("Shared library: [")else{continue};
  let Some((raw,_))=rest.split_once(']')else{return Err("bad ELF DT_NEEDED spelling".into())};
  if safe_name(raw)!=Some(raw){return Err("unsafe original DT_NEEDED basename".into());}
  names.insert(raw.to_owned());
 }
 Ok(names)
}
fn listed(text:&str)->Result<BTreeSet<String>,String>{
 let mut names=BTreeSet::new();
 for l in text.lines(){
  let l=l.trim();if l.is_empty(){continue;}
  if l.contains("not found"){return Err("original ELF linker reported unresolved soname".into());}
  let Some(raw)=l.split_ascii_whitespace().next()else{continue};
  if safe_name(raw).is_none(){return Err("unrecognized native loader output".into());}
  names.insert(safe_name(raw).unwrap().to_owned());
 }
 if names.is_empty(){return Err("empty native glibc linker map".into());}
 Ok(names)
}
fn run()->Result<(),String>{
 let args:Vec<String>=env::args().collect();
 if args.len()!=3{return Err("expected ORIGINAL_PACKAGE_ROOT SANITIZED_OUTPUT_JSON".into());}
 let root=Path::new(&args[1]);
 if !root.is_dir(){return Err("missing authenticated original package root".into());}
 let mut entries=vec![];collect(root,0,&mut entries)?;
 if entries.len()!=28{return Err("expected exactly 28 original regular ELF members".into());}
 entries.sort();
 let mut names=BTreeSet::new();
 let mut per=BTreeMap::new();
 let mut union=BTreeSet::new();
 let mut total_needed=0usize;let mut total_listed=0usize;
 for p in entries{
  let file=p.to_str().ok_or("unrepresentable package member")?;
  let n=safe_name(file).ok_or("invalid packaged ELF requester basename")?;
  if !names.insert(n.to_owned()){return Err("original package has ELF basename collision".into());}
  let direct=needed(&run_cmd("readelf",&["-Wd",file],root)?)?;
  let resolved=listed(&run_cmd("/lib64/ld-linux-x86-64.so.2",&["--list",file],root)?)?;
  for dep in &direct{if !resolved.contains(dep){
    return Err(format!("original member {n} declared a SONAME not listed by the loader"));
  }}
  total_needed+=direct.len();total_listed+=resolved.len();
  union.extend(resolved.iter().cloned());
  per.insert(n.to_owned(),(direct.len(),resolved));
 }
 if total_needed!=268{return Err("original 28-ELF direct-needed graph count drifted".into());}
 if !names.contains("libxul.so")||!names.contains("vulpra-bin"){return Err("key original ELF requester absent".into());}
 let nodes=per.iter().map(|(n,(count,providers))|{
  let list=providers.iter().map(|n|format!("\"{n}\"")).collect::<Vec<_>>().join(",");
  format!("    \"{n}\":{{\"declared_direct_needed_count\":{count},\"loader_listed_provider_count\":{},\"loader_listed_provider_basenames\":[{list}]}}",providers.len())
 }).collect::<Vec<_>>().join(",\n");
 let members=names.iter().map(|n|format!("\"{n}\"")).collect::<Vec<_>>().join(",");
 let providers=union.iter().map(|n|format!("\"{n}\"")).collect::<Vec<_>>().join(",");
 let report=format!(concat!(
  "{{\n \"schema_version\":1,\n \"status\":\"source_pinned_original_all_28_elf_loader_list_resolution\",\n",
  " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
  " \"original_elf_members_listed\":28,\n \"original_elf_basenames\":[{}],\n",
  " \"declared_direct_needed_edges\":{},\n \"direct_needed_sonames_present_in_loader_lists\":{},\n",
  " \"loader_listed_provider_name_occurrences\":{},\n",
  " \"distinct_loader_listed_provider_basenames\":{},\n",
  " \"loader_listed_provider_basenames\":[{}],\n",
  " \"per_original_elf\":{{\n{}\n }},\n",
  " \"glibc_linker_list_metadata_only\":true,\n \"application_main_executed\":false,\n",
  " \"no_network_egress\":true,\n \"actual_genuine_feature_workflows_proven\":false,\n",
  " \"complete_lazy_or_future_dlopen_map_proven\":false,\n",
  " \"arch_hyprland_runtime_tested\":false,\n \"raw_loader_paths_or_pids_exported\":false,\n",
  " \"source_pruning_authorized\":false,\n \"m3_sixth_gate_closed\":false\n}}\n"
 ),SRC,SHA,members,total_needed,total_needed,total_listed,union.len(),providers,nodes);
 let mut f=File::create(&args[2]).map_err(|_|"cannot create sanitized report")?;
 f.write_all(report.as_bytes()).map_err(|_|"cannot write sanitized report")?;
 println!("PASS: loader --list validated {total_needed} direct needed names across 28 original ELF files; {} distinct provider basenames",union.len());
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: original native ELF list-only closure: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn parse_safe_linker_summary(){
  assert_eq!(safe_name("/lib64/libc.so.6"),Some("libc.so.6"));
  assert_eq!(safe_name("/secret/a b.so"),None);
  assert_eq!(needed(" 0x0001 (NEEDED) Shared library: [libc.so.6]").unwrap().len(),1);
  assert!(listed("libc.so.6 => /lib64/libc.so.6 (0xabc)\n/lib64/ld-linux-x86-64.so.2 (0xabc)").unwrap().contains("libc.so.6"));
  assert!(listed("libmissing.so => not found").is_err());
 }
}
