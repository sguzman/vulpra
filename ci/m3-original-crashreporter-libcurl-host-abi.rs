// Source-pinned libcurl fallback symbol ABI probe in isolated Linux hosts.
// This does NOT execute original crashreporter or send a network request.
use std::{env,fs,path::Path,ffi::{c_char,c_void,CString}};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const KNOWN:[&str;6]=["libcurl.so","libcurl.so.4","libcurl-gnutls.so",
  "libcurl-gnutls.so.4","libcurl.so.3","libcurl-gnutls.so.3"];
const EXACT_SYMBOL_COUNT:usize=15;
#[link(name="dl")]
unsafe extern "C" {
    fn dlopen(filename:*const c_char,flags:i32)->*mut c_void;
    fn dlsym(handle:*mut c_void,name:*const c_char)->*mut c_void;
    fn dlclose(handle:*mut c_void)->i32;
}
fn parse_source(text:&str)->Result<(Vec<String>,Vec<String>),String>{
    if !text.contains("use libloading::{Library, Symbol};")||
       !text.contains("CURL_LIB_NAMES.iter().find_map(|name|")||
       !text.contains("Library::new(name)")||
       !text.contains("static CURL: Lazy<std::io::Result<Curl>> = Lazy::new(Curl::load);"){
        return Err("Pinned original libcurl fallback source contract drift".into());
    }
    let start=text.find("const CURL_LIB_NAMES: &[&str] = if cfg!(target_os = \"linux\") {")
        .ok_or("Missing Linux libcurl array")?;
    let tail=&text[start..];
    let end=tail.find("} else if cfg!(target_os = \"macos\")").ok_or("Linux array end missing")?;
    let mut names=Vec::new();
    for line in tail[..end].lines(){
        let l=line.trim();
        if let Some(x)=l.strip_prefix('"'){
            let name=x.split('"').next().ok_or("Invalid quote")?;
            if name.len()>80||!name.starts_with("libcurl"){return Err("Unexpected libcurl name".into());}
            names.push(name.to_owned());
        }
    }
    if names!=KNOWN.iter().map(|s|s.to_string()).collect::<Vec<_>>(){
        return Err("Original Linux candidate names/order mismatch".into());
    }
    let block=text.split_once("\nlibrary_binding! {\n").ok_or("Missing libcurl library binding block")?.1;
    let block=block.split_once("\n}\n").ok_or("Unclosed libcurl binding list")?.0;
    let mut symbols=Vec::new();
    for line in block.lines(){
        let l=line.trim();
        if let Some(rest)=l.strip_prefix("fn "){
            let name=rest.split('(').next().ok_or("Invalid symbol line")?;
            if !name.starts_with("curl_")||name.len()>100||!name.bytes().all(|c|c.is_ascii_alphanumeric()||c==b'_'){
                return Err("Unrecognized libcurl binding".into());
            }
            if symbols.iter().any(|s|s==name){return Err("Duplicate libcurl binding".into());}
            symbols.push(name.to_string());
        }
    }
    if symbols.len()!=EXACT_SYMBOL_COUNT{return Err(format!("Libcurl original binding count {} != {}",symbols.len(),EXACT_SYMBOL_COUNT));}
    Ok((names,symbols))
}
fn probe(candidates:&[String],symbols:&[String])->Result<(String,usize,usize),String>{
    // Equivalent system loader entrypoint to libloading's Unix backend; not
    // proof that the original Rust binary executed the fallback branch.
    const RTLD_NOW:i32=2;
    let mut selected=None;
    let mut attempts=0;
    for candidate in candidates{
        attempts+=1;
        let lib=CString::new(candidate.as_str()).map_err(|e|e.to_string())?;
        let handle=unsafe{dlopen(lib.as_ptr(),RTLD_NOW)};
        if !handle.is_null(){selected=Some((candidate.clone(),handle));break;}
    }
    let (chosen,handle)=selected.ok_or("No source-declared libcurl fallback available under isolated host dlopen RTLD_NOW")?;
    let mut matched=0;
    for name in symbols {
        let key=CString::new(name.as_str()).map_err(|e|e.to_string())?;
        if !unsafe{dlsym(handle,key.as_ptr())}.is_null(){matched+=1;}
    }
    let closed=unsafe{dlclose(handle)}==0;
    if !closed||matched!=symbols.len(){
        return Err(format!("Selected host libcurl missing original bindings: {matched}/{} (close={closed})",symbols.len()));
    }
    Ok((chosen,attempts,matched))
}
fn quote(s:&str)->String{
    let mut output=String::from("\"");
    for c in s.chars(){
        match c {'"'=>output.push_str("\\\""),'\\'=>output.push_str("\\\\"),
            '\n'=>output.push_str("\\n"),'\r'=>output.push_str("\\r"),
            x if x.is_control()=>output.push_str(&format!("\\u{:04x}",x as u32)),
            x=>output.push(x)}
    }
    output.push('"');output
}
fn run()->Result<(),String>{
    let a:Vec<_>=env::args().collect();
    if a.len()!=5||a[1]!=SOURCE||!["ubuntu-24.04","archlinux-container"].contains(&a[3].as_str()){
        return Err("usage: original-libcurl-host-abi PINNED_SHA ORIGINAL_LIBCURL_SOURCE ubuntu-24.04|archlinux-container OUT_JSON".into());
    }
    let text=fs::read_to_string(Path::new(&a[2])).map_err(|e|e.to_string())?;
    if !(8_000..=100_000).contains(&text.len()){return Err("Source size outside pinned bounds".into());}
    let (candidates,symbols)=parse_source(&text)?;
    let (chosen,attempts,matched)=probe(&candidates,&symbols)?;
    let candidate_json=candidates.iter().map(|s|quote(s)).collect::<Vec<_>>().join(",");
    let symbol_json=symbols.iter().map(|s|quote(s)).collect::<Vec<_>>().join(",");
    let json=format!(concat!(
       "{{\n\"schema_version\":1,\n\"status\":\"source_pinned_original_crashreporter_libcurl_isolated_host_abi\",\n",
       "\"original_source_commit\":{},\n\"host_profile\":{},\n",
       "\"original_linux_candidates\":[{}],\n\"selected_first_host_loadable_candidate\":{},\n",
       "\"attempted_candidates_until_success\":{},\n",
       "\"original_libcurl_bindings\":[{}],\n\"original_libcurl_binding_count\":{},\n",
       "\"isolated_host_dlsym_resolved_bindings\":{},\n",
       "\"isolated_host_rtld_now_load_success\":true,\n",
       "\"only_isolated_host_abi_proven\":true,\n",
       "\"original_crashreporter_executed\":false,\n",
       "\"original_crashreporter_curl_fallback_branch_executed\":false,\n",
       "\"network_egress_permitted_during_probe\":false,\n",
       "\"actual_original_runtime_selected_soname_proven\":false,\n",
       "\"target_user_workstation_verified\":false,\n",
       "\"all_conditional_dynamic_loader_routes_proven\":false,\n",
       "\"source_pruning_authorized\":false,\n\"m3_sixth_gate_closed\":false\n}}\n"
    ),quote(SOURCE),quote(&a[3]),candidate_json,quote(&chosen),attempts,symbol_json,symbols.len(),matched);
    fs::write(&a[4],json).map_err(|e|e.to_string())?;
    println!("PASS: isolated {} host first source-listed libcurl candidate with {matched}/{} source-declared symbols; no original crashreporter fallback execution",a[3],symbols.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn rejects_missing_or_fake_source(){
        assert!(parse_source("fake").is_err());
        assert_eq!(KNOWN.len(),6);
    }
    #[test]fn can_probe_only_its_test_host(){
        let names=KNOWN.iter().map(|s|s.to_string()).collect::<Vec<_>>();
        let symbols=vec!["curl_easy_init".to_owned(),"curl_easy_cleanup".to_owned()];
        // The Ubuntu test host provides libcurl; no network operation occurs.
        let (selected,tries,matched)=probe(&names,&symbols).unwrap();
        assert!(KNOWN.contains(&selected.as_str()));
        assert!((1..=6).contains(&tries));
        assert_eq!(matched,2);
    }
    #[test]fn rejects_impossible_candidate_and_missing_symbol(){
        assert!(probe(&["libvulpra_impossible_test.so".into()],&[]).is_err());
        assert!(probe(&KNOWN.iter().map(|s|s.to_string()).collect::<Vec<_>>(),
          &["__vulpra_nonexistent_symbol_20261101".into()]).is_err());
    }
}