// Bounded runtime evidence for the exact original compiled Vulpra ELF inventory.
// Caller verifies checksum/source provenance of the archive and produces a
// 28-name allowlist using readelf on its regular ELF files. Never export actual
// symbol spellings, absolute paths, PIDs, profiles or raw loader traces.
use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;

const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const MAX_FILES: usize = 100;
const MAX_FILE_BYTES: u64 = 256 * 1024 * 1024;
const MAX_TOTAL_BYTES: u64 = 512 * 1024 * 1024;
const MAX_EVENTS: usize = 1_000_000;

fn safe_basename(s: &str) -> Option<&str> {
    let n=s.rsplit('/').next()?;
    if n.is_empty()||n.len()>111||!n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None}
    Some(n)
}
fn allowlist(input: &str) -> Result<BTreeSet<String>, String> {
    let mut names=BTreeSet::new();
    for n in input.lines(){
        if safe_basename(n)!=Some(n)||!names.insert(n.to_string()){
            return Err("invalid or duplicate original ELF name".into());
        }
    }
    if names.len()!=28 || !names.contains("libxul.so"){
        return Err("expected original complete 28-member ELF inventory".into());
    }
    Ok(names)
}
fn binding(line:&str)->Option<(&str,&str,&str)>{
    let (_,rest)=line.split_once("binding file ")?;
    let (src,rest)=rest.split_once(" [")?;
    let (ns,rest)=rest.split_once("] to ")?;
    if ns.is_empty()||!ns.bytes().all(|b|b.is_ascii_digit()){return None}
    let (provider,rest)=rest.split_once(" [")?;
    let (ns,rest)=rest.split_once("]: normal symbol \x60")?;
    if ns.is_empty()||!ns.bytes().all(|b|b.is_ascii_digit()){return None}
    let (symbol,_)=rest.split_once('\'')?;
    if symbol.is_empty()||symbol.len()>8192 ||
        !symbol.bytes().all(|b|b.is_ascii_graphic()&&b!=b'\''&&b!=b'/'&&b!=b'\\'){return None}
    Some((safe_basename(src)?,safe_basename(provider)?,symbol))
}
#[derive(Default)]
struct Observed {
    events:usize,
    pairs:HashSet<(String,String)>,
    providers:BTreeSet<String>,
}
fn inspect(dir:&Path,inventory:&BTreeSet<String>)->Result<(usize,BTreeMap<String,Observed>,BTreeSet<String>),String>{
    let mut traces=vec![];let mut allbytes=0u64;
    for entry in fs::read_dir(dir).map_err(|e|e.to_string())? {
        let p=entry.map_err(|e|e.to_string())?.path();
        let Some(file)=p.file_name().and_then(|n|n.to_str()) else {continue};
        let Some(pid)=file.strip_prefix("m3-package-bindings.") else {continue};
        if pid.is_empty()||!pid.bytes().all(|b|b.is_ascii_digit()){continue}
        let m=fs::symlink_metadata(&p).map_err(|e|e.to_string())?;
        if !m.file_type().is_file()||m.len()==0||m.len()>MAX_FILE_BYTES{return Err("invalid original native trace file".into());}
        allbytes=allbytes.checked_add(m.len()).ok_or("trace size overflow")?;
        if allbytes>MAX_TOTAL_BYTES{return Err("original native trace sum too large".into());}
        traces.push(p);
    }
    if traces.is_empty()||traces.len()>MAX_FILES{return Err("missing or unbounded original native traces".into());}
    traces.sort();
    let mut rows:BTreeMap<String,Observed>=BTreeMap::new();let mut provider_union=BTreeSet::new();
    let mut events=0usize;let mut live_traces=0usize;
    for p in traces{
        let mut seen=0usize;
        let mut reader=BufReader::new(File::open(p).map_err(|e|e.to_string())?);
        let mut raw=Vec::new();
        loop{
            raw.clear();
            if reader.read_until(b'\n',&mut raw).map_err(|e|e.to_string())?==0{break}
            if raw.len()>32768{return Err("oversized glibc line".into());}
            let Ok(line)=std::str::from_utf8(&raw)else{continue};
            let Some((src,provider,symbol))=binding(line)else{continue};
            if !inventory.contains(src){continue}
            seen+=1;events+=1;
            if events>MAX_EVENTS{return Err("original native binding events unbounded".into());}
            let row=rows.entry(src.to_owned()).or_default();
            row.events+=1;
            row.providers.insert(provider.to_owned());
            row.pairs.insert((provider.to_owned(),symbol.to_owned()));
            provider_union.insert(provider.to_owned());
        }
        if seen>0{live_traces+=1}
    }
    if events==0||live_traces==0||!rows.contains_key("libxul.so"){
        return Err("original browser generated no expected ELF requester bindings".into());
    }
    Ok((live_traces,rows,provider_union))
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4{return Err("expected TRACE_DIRECTORY ORIGINAL_ELF_ALLOWLIST OUTPUT_JSON".into());}
    let inventory=allowlist(&fs::read_to_string(&args[2]).map_err(|e|e.to_string())?)?;
    let (traces,rows,providers)=inspect(Path::new(&args[1]),&inventory)?;
    let events:usize=rows.values().map(|r|r.events).sum();
    let pairs:usize=rows.values().map(|r|r.pairs.len()).sum();
    let per=rows.iter().map(|(n,r)|format!(
      "    \"{n}\":{{\"normal_symbol_binding_events\":{},\"distinct_symbol_provider_pairs\":{},\"provider_basename_count\":{}}}",
       r.events,r.pairs.len(),r.providers.len()
    )).collect::<Vec<_>>().join(",\n");
    let names=rows.keys().map(|x|format!("\"{x}\"")).collect::<Vec<_>>().join(",");
    let not_seen=inventory.difference(&rows.keys().cloned().collect()).map(|x|format!("\"{x}\"")).collect::<Vec<_>>().join(",");
    let provider_names=providers.iter().map(|x|format!("\"{x}\"")).collect::<Vec<_>>().join(",");
    let report=format!(concat!(
      "{{\n \"schema_version\":1,\n \"status\":\"original_package_elf_requester_live_binding_inventory\",\n",
      " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
      " \"original_package_elf_count\":28,\n \"original_requester_basenames_observed\":{},\n",
      " \"pid_traces_with_package_requester_bindings\":{},\n",
      " \"normal_symbol_binding_events\":{},\n",
      " \"sum_distinct_requester_symbol_provider_combinations\":{},\n",
      " \"observed_requester_basenames\":[{}],\n",
      " \"unobserved_requester_basenames_on_this_workload\":[{}],\n",
      " \"observed_provider_basename_count\":{},\n \"observed_provider_basenames\":[{}],\n",
      " \"per_original_requester\":{{\n{}\n }},\n",
      " \"raw_loader_logs_exported\":false,\n \"symbol_names_exported\":false,\n",
      " \"private_browser_profile_only\":true,\n",
      " \"complete_lazy_transitive_or_feature_coverage_proven\":false,\n",
      " \"safety_of_source_removal_proven\":false,\n \"m3_sixth_gate_closed\":false\n}}\n"
    ),SOURCE,ARCHIVE,rows.len(),traces,events,pairs,names,not_seen,providers.len(),provider_names,per);
    let mut f=File::create(&args[3]).map_err(|e|e.to_string())?;
    f.write_all(report.as_bytes()).map_err(|e|e.to_string())?;
    println!("PASS: {} original packaged ELF requesters observed over {traces} native PID traces; {events} binding events, {pairs} distinct requester/symbol/provider combinations (symbols redacted)",rows.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: original package ELF runtime binding census: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn reject_forged_and_parse_bounded_original(){
   let line="123: binding file /tmp/pkg/libxul.so [0] to /lib/libc.so.6 [0]: normal symbol \x60malloc' [GLIBC_2.2.5]";
   assert_eq!(binding(line),Some(("libxul.so","libc.so.6","malloc")));
   assert_eq!(binding(&line.replace("normal symbol","bad symbol")),None);
   assert_eq!(binding(&line.replace("malloc","../private/path")),None);
   assert_eq!(allowlist("libxul.so\n"),Err("expected original complete 28-member ELF inventory".into()));
   assert_eq!(safe_basename("/tmp/private name.so"),None);
 }
}
