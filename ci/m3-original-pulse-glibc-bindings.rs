// CI-only: observe real original Vulpra browser libpulse symbol bindings
// via glibc LD_DEBUG=bindings. No interposer, raw PID, private path or log export.
use std::collections::BTreeSet;
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader};
use std::path::Path;
const SRC: &str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA: &str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const PREFIX: &str="m3-original-browser-pulse-glibc.";
const OUT: &str="/reports/m3-original-pulse-glibc-bindings.json";
fn safe_name(s:&str)->Option<&str> {
    let n=s.rsplit('/').next()?;
    if n.is_empty()||n.len()>111||
      !n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None}
    Some(n)
}
fn pulse_provider(n:&str)->bool{
    n=="libpulse.so.0"||n.strip_prefix("libpulse.so.0.").is_some_and(|v|
      !v.is_empty()&&v.bytes().all(|b|b.is_ascii_digit()||b==b'.')&&
      v.as_bytes().last().is_some_and(|b|b.is_ascii_digit()))
}
fn binding(s:&str)->Option<(&str,&str,&str)>{
    let (_,tail)=s.split_once("binding file ")?;
    let (files,syms)=tail.split_once(": normal symbol `")?;
    let (sym,_)=syms.split_once(char::from(39u8))?;
    if !sym.starts_with("pa_")||sym.len()<4||sym.len()>95||
      !sym.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'_'){return None}
    let (req,prov)=files.split_once(" to ")?;
    let (req,_)=req.split_once(" [")?;
    let (prov,_)=prov.split_once(" [")?;
    let req=safe_name(req)?;
    let prov=safe_name(prov)?;
    if !pulse_provider(prov){return None}
    Some((sym,req,prov))
}
#[derive(Default)]
struct Trace{
    xul:bool, events:usize, names:BTreeSet<String>,
    requesters:BTreeSet<String>, providers:BTreeSet<String>
}
fn observe(t:&mut Trace,s:&str){
    if s.contains("/original/libxul.so [")||s.contains("calling init: /original/libxul.so"){
        t.xul=true
    }
    if let Some((name,req,prov))=binding(s){
        t.events+=1;
        t.names.insert(name.into());
        t.requesters.insert(req.into());
        t.providers.insert(prov.into());
    }
}
#[derive(Default)]
struct Summary{
    files:usize, xul:usize, correlated:usize, events:usize,
    names:BTreeSet<String>, requesters:BTreeSet<String>, providers:BTreeSet<String>
}
fn inspect(dir:&Path)->Result<Summary,String>{
    let mut out=Summary::default();
    let mut bytes=0u64;
    for item in fs::read_dir(dir).map_err(|_|"private trace directory unavailable")?{
        let item=item.map_err(|_|"private trace entry error")?;
        let p=item.path();
        let Some(name)=p.file_name().and_then(|n|n.to_str())else{continue};
        let Some(pid)=name.strip_prefix(PREFIX)else{continue};
        if pid.is_empty()||pid.len()>12||!pid.bytes().all(|b|b.is_ascii_digit()){continue}
        let m=fs::symlink_metadata(&p).map_err(|_|"invalid trace metadata")?;
        if !m.file_type().is_file()||m.len()==0||m.len()>128*1024*1024{
            return Err("oversized or nonregular glibc trace".into())
        }
        out.files+=1;
        bytes+=m.len();
        if out.files>128||bytes>512*1024*1024{
            return Err("private glibc aggregate bound exceeded".into())
        }
        let mut t=Trace::default();
        for line in BufReader::new(File::open(&p).map_err(|_|"unreadable trace")?).split(b'\n'){
            let line=line.map_err(|_|"invalid private glibc line")?;
            if line.len()>32768{return Err("oversized native binding line".into())}
            let Ok(s)=std::str::from_utf8(&line)else{continue};
            observe(&mut t,s);
            if t.events>20000{return Err("excessive libpulse bindings".into())}
        }
        if t.xul{out.xul+=1}
        if t.xul&&t.events>0{
            out.correlated+=1;
            out.events+=t.events;
            out.names.extend(t.names);
            out.requesters.extend(t.requesters);
            out.providers.extend(t.providers);
        }
    }
    if out.files==0||out.xul==0||out.correlated==0||out.events==0||
       out.names.is_empty()||out.providers.is_empty(){
        return Err("no actual libpulse binding in original libxul-loaded browser trace".into())
    }
    if out.names.len()>512||out.requesters.len()>64||out.providers.len()>8{
        return Err("oversized bounded PulseAudio summary".into())
    }
    Ok(out)
}
fn array(v:&BTreeSet<String>)->String{
    format!("[{}]",v.iter().map(|s|format!("\"{s}\"")).collect::<Vec<_>>().join(","))
}
fn run()->Result<(),String>{
    let a:Vec<String>=env::args().collect();
    if a.len()!=3||!a[1].starts_with("/tmp/vulpra-pulse.")||a[2]!=OUT{
        return Err("expected private Pulse directory and bounded output".into())
    }
    let v=inspect(Path::new(&a[1]))?;
    let json=format!(concat!(
      "{{\"schema_version\":1,",
      "\"status\":\"original_browser_noninterposing_glibc_libpulse_binding_observed\",",
      "\"original_source_commit\":\"{}\",",
      "\"original_archive_sha256\":\"{}\",",
      "\"diagnostic_mode\":\"glibc_LD_DEBUG_bindings\",",
      "\"private_glibc_trace_count\":{},",
      "\"original_libxul_loaded_trace_count\":{},",
      "\"original_libxul_and_libpulse_binding_same_trace_count\":{},",
      "\"original_browser_libpulse_binding_event_count\":{},",
      "\"original_browser_distinct_libpulse_symbol_count\":{},",
      "\"original_browser_resolved_libpulse_symbol_names\":{},",
      "\"glibc_requester_basenames\":{},",
      "\"libpulse_provider_basenames\":{},",
      "\"no_ld_preload_or_ld_audit_used\":true,",
      "\"glibc_diagnostic_changes_timing\":true,",
      "\"binding_requester_does_not_prove_rust_or_c_caller\":true,",
      "\"actual_browser_rust_ffi_caller_stack_proven\":false,",
      "\"raw_process_ids_paths_or_logs_exported\":false,",
      "\"physical_audio_device_or_microphone_used\":false,",
      "\"full_native_dependency_closure_proven\":false,",
      "\"source_pruning_authorized\":false,",
      "\"native_bytes_saved\":0,",
      "\"m3_sixth_gate_closed\":false}}\n"),
      SRC,SHA,v.files,v.xul,v.correlated,v.events,v.names.len(),
      array(&v.names),array(&v.requesters),array(&v.providers));
    fs::write(OUT,json).map_err(|_|"cannot write sanitized libpulse binding report")?;
    println!("M3_ORIGINAL_BROWSER_PULSE_GLIBC_BINDINGS=PASS events={} names={}",v.events,v.names.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("M3_PULSE_GLIBC_ERROR={e}");std::process::exit(1)}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn binding_accepts_libpulse_and_original_libxul(){
        let s=" 123: binding file /original/libxul.so [0] to /usr/lib/libpulse.so.0.25.0 [0]: normal symbol `pa_context_new' [0]";
        assert_eq!(binding(s),Some(("pa_context_new","libxul.so","libpulse.so.0.25.0")));
        let mut t=Trace::default();observe(&mut t,s);
        assert!(t.xul);assert_eq!(t.events,1)
    }
    #[test]fn separate_requester_and_provider(){
        let s=" 124: binding file /usr/lib/libpulse.so.0 [0] to /usr/lib/libpulse.so.0 [0]: normal symbol `pa_context_connect' [0]";
        let mut t=Trace::default();observe(&mut t,s);
        assert!(!t.xul);assert_eq!(t.events,1);
        assert!(t.requesters.contains("libpulse.so.0"));
        assert!(t.providers.contains("libpulse.so.0"))
    }
    #[test]fn reject_foreign_provider(){
        assert!(binding(" 125: binding file /original/libxul.so [0] to /usr/lib/libc.so.6 [0]: normal symbol `pa_context_new' [0]").is_none());
        assert!(binding(" 125: binding file /original/libxul.so [0] to /usr/lib/libpulse.so.0.debug [0]: normal symbol `pa_context_new' [0]").is_none());
        assert!(binding(" 125: binding file /original/libxul.so [0] to /usr/lib/libpulse.so.0 [0]: normal symbol `bad_name' [0]").is_none());
    }
}
