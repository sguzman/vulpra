// Bounded observer for actual glibc normal-symbol bindings from three original
// protected Vulpra ELF diagnostic routes. Only provider basenames/counts leave CI.
use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;
const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const MEMBERS: [&str; 3] = ["crashhelper", "crashreporter", "updater"];
fn basename(s: &str) -> Option<&str> {
    let n = s.rsplit('/').next()?;
    if n.is_empty() || n.len()>111 || !n.bytes().all(|b|b.is_ascii_alphanumeric() || b"._+-".contains(&b)) { return None; }
    Some(n)
}
fn binding(line: &str, member: &str) -> Option<(String, String)> {
    let (_, tail) = line.split_once("binding file ")?;
    let (src, tail) = tail.split_once(" [")?;
    let (ns, tail) = tail.split_once("] to ")?;
    if ns.is_empty() || !ns.bytes().all(|b|b.is_ascii_digit()) || basename(src)?!=member { return None; }
    let (dst, tail) = tail.split_once(" [")?;
    let (ns, tail) = tail.split_once("]: normal symbol \x60")?;
    if ns.is_empty() || !ns.bytes().all(|b|b.is_ascii_digit()) { return None; }
    let (symbol, _) = tail.split_once('\'')?;
    if symbol.is_empty() || symbol.len()>2048 ||
       !symbol.bytes().all(|b|b.is_ascii_graphic() && b!=b'\'' && b!=b'/' && b!=b'\\') { return None; }
    Some((basename(dst)?.to_owned(),symbol.to_owned()))
}
struct Counts { files:usize,events:usize,distinct:usize,providers:BTreeSet<String> }
fn inspect_one(dir:&Path,member:&str)->Result<Counts,String>{
    let mut paths=vec![];
    for entry in fs::read_dir(dir).map_err(|e|e.to_string())? {
        let p=entry.map_err(|e|e.to_string())?.path();
        let Some(name)=p.file_name().and_then(|x|x.to_str()) else {continue};
        let prefix=format!("{member}-loader.");
        let Some(pid)=name.strip_prefix(&prefix) else {continue};
        if pid.is_empty() || !pid.bytes().all(|b|b.is_ascii_digit()){continue;}
        let m=fs::symlink_metadata(&p).map_err(|e|e.to_string())?;
        if !m.file_type().is_file() || m.len()==0 || m.len()>32_000_000{return Err(format!("{member}: invalid trace size/type"));}
        paths.push(p);
    }
    if paths.is_empty()||paths.len()>8{return Err(format!("{member}: missing/too many PID traces"));}
    let mut events=0usize;let mut files=0usize;
    let mut pairs=HashSet::new();let mut providers=BTreeSet::new();
    for p in paths{
        let mut count=0;
        let mut reader=BufReader::new(File::open(p).map_err(|e|e.to_string())?);
        let mut raw=Vec::new();
        loop{
            raw.clear();
            if reader.read_until(b'\n',&mut raw).map_err(|e|e.to_string())?==0{break;}
            if raw.len()>32768{return Err("oversized glibc log line".into());}
            let Ok(line)=std::str::from_utf8(&raw) else {continue};
            if let Some((provider,symbol))=binding(line,member){
                events+=1;count+=1;
                if events>250000{return Err("too many glibc bindings".into());}
                providers.insert(provider.clone());pairs.insert((provider,symbol));
            }
        }
        if count>0{files+=1;}
    }
    if events==0 || files==0 || providers.is_empty(){return Err(format!("{member}: no actual normal symbol bindings"));}
    Ok(Counts{files,events,distinct:pairs.len(),providers})
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=3{return Err("expected TRACE_DIR OUTPUT_JSON".into());}
    let mut rows=BTreeMap::new();
    for member in MEMBERS {rows.insert(member,inspect_one(Path::new(&args[1]),member)?);}
    let mut providers=BTreeSet::new();
    for r in rows.values(){providers.extend(r.providers.iter().cloned());}
    let members=rows.iter().map(|(n,r)|format!(
        "    \"{n}\": {{\"pid_traces_with_bindings\": {}, \"normal_symbol_binding_events\": {}, \"distinct_symbol_provider_pairs\": {}, \"provider_basename_count\": {}}}",
        r.files,r.events,r.distinct,r.providers.len()
    )).collect::<Vec<_>>().join(",\n");
    let names=providers.iter().map(|n|format!("\"{n}\"")).collect::<Vec<_>>().join(",");
    let sum=|f:fn(&Counts)->usize|rows.values().map(f).sum::<usize>();
    let result=format!(concat!(
      "{{\n \"schema_version\":1,\n \"status\":\"original_protected_auxiliary_normal_symbol_bindings\",\n",
      " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
      " \"original_auxiliary_elf_member_count\":3,\n",
      " \"pid_traces_with_member_bindings\":{},\n \"normal_symbol_binding_events\":{},\n",
      " \"sum_per_member_distinct_symbol_provider_pairs\":{},\n",
      " \"observed_provider_basename_count\":{},\n \"observed_provider_basenames\":[{}],\n",
      " \"per_member\":{{\n{}\n }},\n",
      " \"diagnostic_paths_only\":true,\n \"no_network_egress\":true,\n",
      " \"actual_runtime_bindings_witnessed\":true,\n \"raw_loader_logs_exported\":false,\n",
      " \"symbol_names_exported\":false,\n \"actual_crash_or_update_pipeline_proven\":false,\n",
      " \"complete_transitive_or_lazy_binding_coverage\":false,\n",
      " \"all_28_native_elf_members_covered\":false,\n \"new_source_pruning_authorized\":false\n}}\n"
    ),SOURCE,ARCHIVE,sum(|r|r.files),sum(|r|r.events),sum(|r|r.distinct),providers.len(),names,members);
    let mut out=File::create(&args[2]).map_err(|e|e.to_string())?;
    out.write_all(result.as_bytes()).map_err(|e|e.to_string())?;
    println!("PASS: actual guarded native symbol bindings observed on three diagnostic-only routes; sanitized output");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: guarded auxiliary bindings: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
 use super::*;
 #[test] fn strict_native_binding_parser(){
   let line="123: binding file /tmp/vulpra/updater [0] to /lib/libc.so.6 [0]: normal symbol \x60malloc' [GLIBC_2.2.5]";
   assert_eq!(binding(line,"updater"),Some(("libc.so.6".into(),"malloc".into())));
   assert_eq!(binding(line,"crashreporter"),None);
   assert_eq!(binding(&line.replace("normal symbol","other symbol"),"updater"),None);
   assert_eq!(binding(&line.replace("malloc","../private/path"),"updater"),None);
   assert_eq!(binding(&line.replace(" [0] to "," [a] to "),"updater"),None);
 }
}
