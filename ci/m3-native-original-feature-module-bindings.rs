// Actual original C API module bindings from no-egress, disposable-home CI.
// Output includes only bounded counts and provider basenames; never symbol names,
// absolute paths, PIDs, environments or raw glibc trace data.
use std::collections::{BTreeSet,HashSet};
use std::env;
use std::fs::{self,File};
use std::io::{BufRead,BufReader,Write};
use std::path::Path;
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";

fn target(module:&str)->Option<&'static str>{
    match module{
        "libmozinference.so"=>Some("mozinference-loader."),
        "libclearkey.so"=>Some("clearkey-loader."),
        "libonnxruntime.so"=>Some("onnx-loader."),
        "pingsender"=>Some("pingsender-loader."),
        "gfxtest"=>Some("gfxtest-loader."),
        "vulpra-bin"=>Some("vulpra-bin-loader."),
        _=>None
    }
}
fn name(s:&str)->Option<&str>{
    let n=s.rsplit('/').next()?;
    if n.is_empty()||n.len()>111||!n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b)){return None;}
    Some(n)
}
fn normal_binding(line:&str,module:&str)->Option<(String,String)>{
    let (_,rest)=line.split_once("binding file ")?;
    let (src,rest)=rest.split_once(" [")?;
    let (ns,rest)=rest.split_once("] to ")?;
    if ns.is_empty()||!ns.bytes().all(|b|b.is_ascii_digit())||name(src)?!=module{return None;}
    let (dst,rest)=rest.split_once(" [")?;
    let (ns,rest)=rest.split_once("]: normal symbol \x60")?;
    if ns.is_empty()||!ns.bytes().all(|b|b.is_ascii_digit()){return None;}
    let (symbol,_)=rest.split_once('\'')?;
    if symbol.is_empty()||symbol.len()>2048||!symbol.bytes().all(|b|b.is_ascii_graphic()&&b!=b'\''&&b!=b'/'&&b!=b'\\'){return None;}
    Some((name(dst)?.to_owned(),symbol.to_owned()))
}
fn observe(dir:&Path,module:&str)->Result<(usize,usize,usize,BTreeSet<String>),String>{
    let prefix=target(module).ok_or("unauthorized module")?;
    let mut files=vec![];
    for entry in fs::read_dir(dir).map_err(|e|e.to_string())?{
        let p=entry.map_err(|e|e.to_string())?.path();
        let Some(filename)=p.file_name().and_then(|n|n.to_str()) else {continue};
        let Some(pid)=filename.strip_prefix(prefix) else {continue};
        if pid.is_empty()||!pid.bytes().all(|b|b.is_ascii_digit()){continue;}
        let m=fs::symlink_metadata(&p).map_err(|e|e.to_string())?;
        if !m.file_type().is_file()||m.len()==0||m.len()>(if module=="vulpra-bin"{256_000_000}else{48_000_000}){return Err("invalid glibc trace type or size".into());}
        files.push(p);
    }
    let max_files=if module=="vulpra-bin"{64}else{8};
    if files.is_empty()||files.len()>max_files{return Err("missing/too many PID traces".into());}
    let mut events=0;let mut traced=0;
    let mut observed=HashSet::new();let mut providers=BTreeSet::new();
    for p in files{
        let mut per_file=0;
        let mut reader=BufReader::new(File::open(p).map_err(|e|e.to_string())?);
        let mut bytes=Vec::new();
        loop{
            bytes.clear();
            if reader.read_until(b'\n',&mut bytes).map_err(|e|e.to_string())?==0{break;}
            if bytes.len()>32768{return Err("oversized glibc line".into());}
            let Ok(line)=std::str::from_utf8(&bytes)else{continue};
            if let Some((provider,symbol))=normal_binding(line,module){
                per_file+=1;events+=1;
                if events>250_000{return Err("too many native bindings".into());}
                providers.insert(provider.clone());observed.insert((provider,symbol));
            }
        }
        if per_file>0{traced+=1;}
    }
    if events==0||traced==0||providers.is_empty(){return Err("no original module normal-symbol binding".into());}
    Ok((traced,events,observed.len(),providers))
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4{return Err("expected TRACE_DIR OUTPUT_JSON ORIGINAL_MODULE".into());}
    let module=&args[3];
    target(module).ok_or("unsupported original native module")?;
    let (traces,events,pairs,providers)=observe(Path::new(&args[1]),module)?;
    let providers_json=providers.iter().map(|n|format!("\"{n}\"")).collect::<Vec<_>>().join(",");
    let report=format!(concat!(
        "{{\n \"schema_version\":1,\n \"status\":\"original_native_feature_module_actual_symbol_bindings\",\n",
        " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
        " \"original_requester_basename\":\"{}\",\n \"pid_traces_with_original_requester_bindings\":{},\n",
        " \"normal_symbol_binding_events\":{},\n \"distinct_symbol_provider_pairs\":{},\n",
        " \"observed_provider_basename_count\":{},\n \"observed_provider_basenames\":[{}],\n",
        " \"original_c_api_diagnostic_only\":{},\n \"synthetic_loopback_telemetry_only\":{},\n \"private_weston_wayland_gfx_probe_only\":{},\n \"alternate_browser_wayland_frame_only\":{},\n \"no_network_egress\":{},\n",
        " \"actual_normal_symbol_bindings_observed\":true,\n",
        " \"raw_loader_logs_exported\":false,\n \"symbol_names_exported\":false,\n",
        " \"model_inference_or_drm_decryption_proven\":false,\n",
        " \"all_lazy_or_transitive_bindings_proven\":false,\n",
        " \"new_source_pruning_authorized\":false\n}}\n"
    ),SOURCE,ARCHIVE,module,traces,events,pairs,providers.len(),providers_json,!matches!(module.as_str(),"pingsender"|"gfxtest"|"vulpra-bin"),module=="pingsender",module=="gfxtest",module=="vulpra-bin",!matches!(module.as_str(),"gfxtest"|"vulpra-bin"));
    let mut file=File::create(&args[2]).map_err(|e|e.to_string())?;
    file.write_all(report.as_bytes()).map_err(|e|e.to_string())?;
    println!("PASS: actual original native feature-module bindings observed; sanitized module/provider counts");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: bounded original module bindings: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn guarded_native_module_parser(){
        let line="123: binding file /tmp/native/libmozinference.so [0] to /lib/libc.so.6 [0]: normal symbol \x60malloc' [GLIBC_2.2.5]";
        assert_eq!(normal_binding(line,"libmozinference.so"),Some(("libc.so.6".into(),"malloc".into())));
        assert_eq!(normal_binding(line,"libclearkey.so"),None);
        assert_eq!(normal_binding(&line.replace("malloc","../../secret"),"libmozinference.so"),None);
        assert_eq!(normal_binding(&line.replace("normal symbol","not symbol"),"libmozinference.so"),None);
        assert_eq!(target("libonnxruntime.so"),Some("onnx-loader."));
        assert_eq!(target("pingsender"),Some("pingsender-loader."));
        assert_eq!(target("gfxtest"),Some("gfxtest-loader."));
        assert_eq!(target("vulpra-bin"),Some("vulpra-bin-loader."));
        assert_eq!(target("libxul.so"),None);
    }
}
