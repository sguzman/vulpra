// CI-only original Vulpra glibc LD_DEBUG=bindings observer.
// Does not interpose dlopen or dlsym; glibc debug output changes timing.
// A dlsym provider->provider binding does not identify a Rust caller.
// Never export raw paths, PIDs, or glibc debug logs.
use std::collections::BTreeSet;
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader};
use std::path::Path;

const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const PREFIX:&str="m3-original-browser-usb-glibc-bindings.";
#[derive(Default)]
struct Trace {
    xul:bool, events:usize, symbols:BTreeSet<String>, providers:BTreeSet<String>
}
fn safe_name(p:&str)->Option<&str> {
 let s=p.rsplit('/').next()?;
 if s.is_empty()||s.len()>111||!s.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None}
 Some(s)
}
fn udev_provider(s:&str)->bool {
 s=="libudev.so.1" || s.strip_prefix("libudev.so.1.").is_some_and(|v|
  !v.is_empty() && v.bytes().all(|b|b.is_ascii_digit()||b==b'.') &&
  v.as_bytes().first().is_some_and(|b|b.is_ascii_digit()) &&
  v.as_bytes().last().is_some_and(|b|b.is_ascii_digit()))
}
fn binding(line:&str)->Option<(&str,&str)> {
 let (_,tail)=line.split_once("binding file ")?;
 let (fields,symtail)=tail.split_once(": normal symbol `")?;
 let (sym,_)=symtail.split_once(char::from(39u8))?;
 if !sym.starts_with("udev_") || sym.len()<6 || sym.len()>95 ||
   !sym.bytes().all(|b|b.is_ascii_lowercase()||b.is_ascii_digit()||b==b'_'){return None}
 let (_,target)=fields.split_once(" to ")?;
 let (p,_)=target.split_once(" [")?;
 let provider=safe_name(p)?;
 if !udev_provider(provider){return None}
 Some((sym,provider))
}
fn inspect_line(t:&mut Trace,line:&str){
 if line.contains("/original/libxul.so ["){t.xul=true}
 if let Some((sym,provider))=binding(line){
  t.symbols.insert(sym.into());t.providers.insert(provider.into());t.events+=1;
 }
}
struct ResultSet {
 files:usize,xul_traces:usize,correlated:usize,events:usize,
 symbols:BTreeSet<String>,providers:BTreeSet<String>
}
fn inspect(dir:&Path)->Result<ResultSet,String>{
 let (mut files,mut xul_traces,mut correlated,mut events)=(0,0,0,0);
 let (mut total,mut symbols,mut providers)=(0u64,BTreeSet::new(),BTreeSet::new());
 for e in fs::read_dir(dir).map_err(|_|"private glibc trace directory unreadable")?{
  let e=e.map_err(|_|"bad glibc entry")?;
  let p=e.path();
  let Some(name)=p.file_name().and_then(|n|n.to_str())else{continue};
  let Some(pid)=name.strip_prefix(PREFIX)else{continue};
  if pid.is_empty()||pid.len()>12||!pid.bytes().all(|b|b.is_ascii_digit()){continue}
  let m=fs::symlink_metadata(&p).map_err(|_|"missing trace metadata")?;
  if !m.file_type().is_file()||m.len()==0||m.len()>128*1024*1024{
   return Err("oversized/nonregular private glibc trace".into())
  }
  total+=m.len();
  files+=1;
  if total>512*1024*1024||files>128{return Err("glibc trace aggregate bound exceeded".into())}
  let mut t=Trace::default();
  for line in BufReader::new(File::open(&p).map_err(|_|"unreadable glibc trace")?).split(b'\n'){
   let bytes=line.map_err(|_|"invalid raw loader line")?;
   if bytes.len()>32768{return Err("oversized loader debug line".into())}
   let Ok(line)=std::str::from_utf8(&bytes)else{continue};
   inspect_line(&mut t,line);
   if t.events>20_000{return Err("too many relevant native binding events".into())}
  }
  if t.xul{xul_traces+=1}
  if t.xul&&!t.symbols.is_empty(){
   correlated+=1;events+=t.events;
   symbols.extend(t.symbols);providers.extend(t.providers);
  }
 }
 if files==0||xul_traces==0||correlated==0||events==0||!symbols.contains("udev_new"){
  return Err("no source-relevant udev_new binding within original libxul-loaded browser PID trace".into())
 }
 Ok(ResultSet{files,xul_traces,correlated,events,symbols,providers})
}
fn arr(v:&BTreeSet<String>)->String{
 format!("[{}]",v.iter().map(|s|format!("\"{s}\"")).collect::<Vec<_>>().join(","))
}
fn run()->Result<(),String>{
 let a:Vec<_>=env::args().collect();
 if a.len()!=3||!a[1].starts_with("/tmp/vulpra-m3-webauthn.")||
    a[2]!="/reports/m3-original-udev-glibc-bindings.json"{
  return Err("expected private USB test directory and exact sanitized report".into())
 }
 let v=inspect(Path::new(&a[1]))?;
 let json=format!(concat!(
  "{{",
  "\"schema_version\":1,",
  "\"status\":\"original_browser_glibc_binding_provider_noninterposing_diagnostics\",",
  "\"original_source_commit\":\"{}\",",
  "\"original_archive_sha256\":\"{}\",",
  "\"diagnostic_mode\":\"glibc_LD_DEBUG_bindings\",",
  "\"glibc_trace_file_count\":{},",
  "\"original_libxul_present_trace_count\":{},",
  "\"original_libxul_and_libudev_binding_same_trace_count\":{},",
  "\"original_browser_libudev_binding_event_count\":{},",
  "\"original_browser_unique_udev_symbol_count\":{},",
  "\"original_browser_resolved_udev_symbol_names\":{},",
  "\"original_browser_udev_provider_basenames\":{},",
  "\"ld_preload_and_ld_audit_unset\":true,",
  "\"glibc_debug_mode_changes_timing\":true,",
  "\"binding_requester_not_proven_actual_rust_dlsym_caller\":true,",
  "\"original_browser_udev_provider_binding_observed\":true,",
  "\"actual_rust_ffi_caller_from_binding_log_proven\":false,",
  "\"all_49_symbols_resolved_in_original_browser_proven\":false,",
  "\"raw_glibc_logs_paths_and_pids_exported\":false,",
  "\"physical_usb_device_used\":false,",
  "\"full_binary_feature_ffi_dependency_closure\":false,",
  "\"source_pruning_authorized\":false,",
  "\"native_bytes_saved\":0,",
  "\"m3_sixth_gate_closed\":false",
  "}}\n"),
  SRC,SHA,v.files,v.xul_traces,v.correlated,v.events,
  v.symbols.len(),arr(&v.symbols),arr(&v.providers));
 fs::write(&a[2],json).map_err(|_|"cannot write sanitized original browser bindings report")?;
 println!("M3_GLIBC_BINDINGS=PASS native_udev_binding_events={} correlated_traces={}",v.events,v.correlated);
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("M3_GLIBC_BINDINGS_ERROR={e}");std::process::exit(1)}}
#[cfg(test)]
mod tests {
 use super::*;
 #[test] fn glibc_binding_fixtures(){
  let s=" 123: binding file /lib/libudev.so.1 [0] to /lib/libudev.so.1 [0]: normal symbol `udev_new' [GLIBC_2.2.5]";
  assert_eq!(binding(s),Some(("udev_new","libudev.so.1")));
  assert_eq!(binding(" 123: binding file /original/libxul.so [0] to /usr/lib/libudev.so.1.7.15 [0]: normal symbol `udev_unref'"),Some(("udev_unref","libudev.so.1.7.15")));
 }
 #[test] fn unsafe_and_other_provider_ignored(){
  assert_eq!(binding("1: binding file /lib/libudev.so.1 [0] to /original/libxul.so [0]: normal symbol `udev_new'"),None);
  assert!(!udev_provider("libudev.so.1.debug"));
  assert!(!udev_provider("libudev.so.0"));
  let mut t=Trace::default();
  inspect_line(&mut t,"1: binding file /lib/libudev.so.1 [0] to /lib/libudev.so.1 [0]: normal symbol `udev_new'");
  assert!(!t.xul);assert_eq!(t.events,1);
  inspect_line(&mut t,"1: binding file /original/libxul.so [0] to /lib/libc.so.6 [0]: normal symbol `malloc'");
  assert!(t.xul);
 }
}
