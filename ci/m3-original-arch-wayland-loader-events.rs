// Retain only safe native provider *basenames* from original browser's
// private Weston LD_DEBUG=libs,files traces. Raw loader logs are discarded
// with the ephemeral container tmpfs, never uploaded, paths/PIDs not exported.
use std::collections::BTreeSet;
use std::env;
use std::fs::{self,File};
use std::io::{BufRead,BufReader,Write};
use std::path::Path;
const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
fn basename(s:&str)->Option<&str>{
 let n=s.trim().rsplit('/').next()?;
 if n.is_empty()||n.len()>111||!n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None}
 Some(n)
}
fn init(line:&str)->Option<&str>{
 let (_,path)=line.split_once("calling init: ")?;
 basename(path.trim())
}
fn requested(line:&str)->Option<(&str,bool)>{
 let (_,part)=line.split_once("file=")?;
 let (path,rest)=part.split_once(" [")?;
 let n=basename(path)?;
 if rest.contains(";  dynamically loaded by "){Some((n,true))}
 else if rest.contains(";  needed by "){Some((n,false))}
 else {None}
}
fn inspect(dir:&Path)->Result<(usize,BTreeSet<String>,BTreeSet<String>,BTreeSet<String>),String>{
 let mut traces=0usize;let mut size_sum=0u64;
 let mut init_names=BTreeSet::new();
 let mut dynamic_names=BTreeSet::new();
 let mut needed_names=BTreeSet::new();
 let mut entries=vec![];
 for e in fs::read_dir(dir).map_err(|_|"cannot read private browser loader trace directory")?{
  let p=e.map_err(|_|"invalid private trace entry")?.path();
  let name=p.file_name().and_then(|x|x.to_str()).unwrap_or("");
  let Some(pid)=name.strip_prefix("m3-browser-loader.")else{continue};
  if pid.is_empty()||!pid.bytes().all(|b|b.is_ascii_digit()){continue}
  let m=fs::symlink_metadata(&p).map_err(|_|"private loader trace metadata inaccessible")?;
  if !m.file_type().is_file()||m.len()==0||m.len()>128*1024*1024{return Err("oversize or nonregular loader trace".into())}
  size_sum=size_sum.checked_add(m.len()).ok_or("loader trace size overflow")?;
  if size_sum>512*1024*1024{return Err("total raw loader traces exceed bound".into())}
  entries.push(p);
 }
 if entries.is_empty()||entries.len()>64{return Err("no bounded native browser PID traces".into())}
 entries.sort();
 for p in entries{
  let reader=BufReader::new(File::open(p).map_err(|_|"unreadable native browser loader log")?);
  let mut local=false;
  for line in reader.split(b'\n'){
   let bytes=line.map_err(|_|"cannot read native loader line")?;
   if bytes.len()>32768{return Err("oversized raw glibc loader line".into())}
   let Ok(line)=std::str::from_utf8(&bytes)else{continue};
   if let Some(n)=init(line){init_names.insert(n.to_owned());local=true;}
   if let Some((n,dyn_load))=requested(line){
    if dyn_load{dynamic_names.insert(n.to_owned());}
    else{needed_names.insert(n.to_owned());}
   }
  }
  if local{traces+=1;}
 }
 for req in ["libmozgtk.so","libmozwayland.so","libxul.so"]{
  if !init_names.contains(req){return Err(format!("real original graphical browser failed to initialize expected native library {req}"));}
 }
 if traces==0{return Err("no original browser native loader initializers seen".into())}
 Ok((traces,init_names,dynamic_names,needed_names))
}
fn array(xs:&BTreeSet<String>)->String{
 xs.iter().map(|s|format!("\"{s}\"")).collect::<Vec<_>>().join(",")
}
fn run()->Result<(),String>{
 let args:Vec<String>=env::args().collect();
 if args.len()!=3{return Err("expected EPHEMERAL_TRACE_DIR SANITIZED_REPORT_JSON".into())}
 let (traces,initialized,dynamic,needed)=inspect(Path::new(&args[1]))?;
 let output=format!(concat!(
  "{{\n \"schema_version\":1,\n \"status\":\"original_arch_wayland_browser_actual_loader_initializers\",\n",
  " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
  " \"native_browser_loader_pid_traces_with_initializers\":{},\n",
  " \"initialized_native_provider_basename_count\":{},\n \"initialized_native_provider_basenames\":[{}],\n",
  " \"runtime_dynamic_loader_requested_basename_count\":{},\n \"runtime_dynamic_loader_requested_basenames\":[{}],\n",
  " \"direct_needed_loader_requested_basename_count\":{},\n \"direct_needed_loader_requested_basenames\":[{}],\n",
  " \"libmozgtk_actual_init_observed\":true,\n \"libmozwayland_actual_init_observed\":true,\n",
  " \"libxul_actual_init_observed\":true,\n",
  " \"init_order_or_full_dynamic_closure_proven\":false,\n",
  " \"private_arch_weston_real_graphical_frame_required_externally\":true,\n",
  " \"raw_loader_logs_symbol_names_paths_or_pids_exported\":false,\n",
  " \"no_user_profile_or_browser_modified\":true,\n",
  " \"full_future_dlopen_or_feature_coverage_proven\":false,\n",
  " \"m3_sixth_gate_closed\":false\n}}\n"
 ),SRC,SHA,traces,initialized.len(),array(&initialized),dynamic.len(),array(&dynamic),needed.len(),array(&needed));
 let mut f=File::create(&args[2]).map_err(|_|"cannot create sanitized loader report")?;
 f.write_all(output.as_bytes()).map_err(|_|"cannot write sanitized loader report")?;
 println!("PASS: original private Arch Wayland browser initialized {} distinct provider basenames including mozgtk, mozwayland and libxul; traces={traces}",initialized.len());
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: original Arch Wayland native loader init audit: {e}");std::process::exit(1)}}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn parser_rejects_unsafe_and_recognizes_real_glibc_lines(){
  assert_eq!(init("123:\tcalling init: /original/libxul.so"),Some("libxul.so"));
  assert_eq!(init("123:\tcalling init: /home/private object.so"),None);
  assert_eq!(requested("123: file=libmozgtk.so [0];  needed by /original/libxul.so [0]"),Some(("libmozgtk.so",false)));
  assert_eq!(requested("123: file=/original/libmozwayland.so [0];  dynamically loaded by /original/libxul.so [0]"),Some(("libmozwayland.so",true)));
  assert_eq!(requested("123: file=../../private [0];  needed by /original/libxul.so [0]"),Some(("private",false)));
 }
}
