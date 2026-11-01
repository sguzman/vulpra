// Exact original-source GTK DMA-BUF optional dlopen/dlsym contract
// against an actual Ubuntu x86-64 libgbm.so.1 and libdrm.so.2.
// Source/host ABI evidence only; no compiled Vulpra call stack or Arch claim.
use std::{collections::BTreeSet, fs::{self,File},io::{Read,BufRead,BufReader},path::Path,process::{Command,Stdio}};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
fn symbols(src:&str)->Result<(BTreeSet<String>,BTreeSet<String>),String>{
    if !src.contains("#define GBMLIB_NAME \"libgbm.so.1\"") ||
       !src.contains("#define DRMLIB_NAME \"libdrm.so.2\"") ||
       !src.contains("dlopen(GBMLIB_NAME, RTLD_LAZY | RTLD_LOCAL)") ||
       !src.contains("dlopen(DRMLIB_NAME, RTLD_LAZY | RTLD_LOCAL)"){
        return Err("Wrong pinned DMA-BUF runtime library source anchors".into());
    }
    let mut gbm=BTreeSet::<String>::new();let mut drm=BTreeSet::<String>::new();
    for term in src.split("dlsym(").skip(1){
        let inner=term.split_once(')').ok_or("Malformed dlsym request")?.0;
        let (handle,name)=inner.split_once(',').ok_or("Missing dlsym handle")?;
        let handle=handle.trim();let name=name.trim();
        if !name.starts_with('"')||!name.ends_with('"'){return Err("Nonliteral dlsym name".into());}
        let name=&name[1..name.len()-1];
        if !name.bytes().all(|x|x.is_ascii_alphanumeric()||x==b'_'){return Err("Unsafe dlsym symbol".into());}
        let dest=match handle{"sGbmLibHandle"=>&mut gbm,"sXf86DrmLibHandle"=>&mut drm,_=>return Err("Unexpected dlsym library handle".into())};
        if !dest.insert(name.into()){return Err("Duplicate DMA-BUF dlsym function".into());}
    }
    if gbm.len()!=18||drm.len()!=1||!drm.contains("drmPrimeHandleToFD")||
       gbm.iter().any(|x|!x.starts_with("gbm_")){
        return Err(format!("Unexpected DMA-BUF dlsym shape: gbm={} drm={}",gbm.len(),drm.len()));
    }
    Ok((gbm,drm))
}
fn host(path:&Path)->Result<BTreeSet<String>,String>{
    let len=fs::metadata(path).map_err(|e|e.to_string())?.len();
    if len<10000||len>64*1024*1024{return Err("Host ELF size rejected".into());}
    let mut magic=[0u8;20];File::open(path).map_err(|e|e.to_string())?.read_exact(&mut magic).map_err(|e|e.to_string())?;
    if &magic[..4]!=b"\x7fELF"||magic[4]!=2||magic[5]!=1||magic[18]!=0x3e||magic[19]!=0 {
        return Err("Expected little-endian x86-64 shared ELF".into());
    }
    let mut nm=Command::new("nm").args(["-D","--defined-only","--no-demangle"]).arg(path)
        .stdout(Stdio::piped()).stderr(Stdio::null()).spawn().map_err(|e|e.to_string())?;
    let out=nm.stdout.take().ok_or("No nm output")?;
    let mut symbols=BTreeSet::new();
    for (n,line) in BufReader::new(out).lines().enumerate(){
        if n>500000{let _=nm.kill();let _=nm.wait();return Err("Exceeded bounded exports".into());}
        let line=line.map_err(|e|e.to_string())?;
        let a:Vec<_>=line.split_whitespace().collect();
        if a.len()>=3&&matches!(a[1],"T"|"t"|"W"|"w"){
            symbols.insert(a[2].split('@').next().unwrap_or("").to_string());
        }
    }
    if !nm.wait().map_err(|e|e.to_string())?.success(){return Err("nm failed".into());}
    Ok(symbols)
}
fn subset(label:&str,needed:&BTreeSet<String>,found:&BTreeSet<String>)->Result<(),String>{
    let missing:Vec<_>=needed.difference(found).cloned().collect();
    if !missing.is_empty(){return Err(format!("{label} missing host functions: {}",missing.join(",")));}
    Ok(())
}
fn run()->Result<(),String>{
    let args:Vec<String>=std::env::args().collect();
    if args.len()!=6||args[1]!=SOURCE{return Err("usage: dmabuf-host-abi SOURCE_SHA SOURCE_CPP LIBGBM_SO LIBDRM_SO OUTPUT_JSON".into());}
    let src=fs::read_to_string(&args[2]).map_err(|e|e.to_string())?;
    let (gbm,drm)=symbols(&src)?;
    subset("libgbm.so.1",&gbm,&host(Path::new(&args[3]))?)?;
    subset("libdrm.so.2",&drm,&host(Path::new(&args[4]))?)?;
    fs::write(&args[5],format!(
        "{{\n \"schema_version\":1,\n \"gecko_source_commit\":\"{SOURCE}\",\n \"host_platform\":\"ubuntu-24.04-x86_64\",\n \"requested_gbm_functions\":{},\n \"matched_gbm_exports\":{},\n \"requested_drm_functions\":{},\n \"matched_drm_exports\":{},\n \"missing_requested_functions\":0,\n \"direct_source_to_host_abi_proven\":true,\n \"compiled_browser_callstack_proven\":false,\n \"all_dynamic_loading_paths_proven\":false,\n \"arch_host_abi_proven\":false,\n \"m3_sixth_gate_closed\":false,\n \"source_removal_authorized\":false\n}}\n",gbm.len(),gbm.len(),drm.len(),drm.len()
    )).map_err(|e|e.to_string())?;
    println!("PASS: exact-source 18 GBM + 1 DRM dynamic function names are exported by Ubuntu host ELFs");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn missing_or_incomplete_ffi_fails_closed(){
        assert!(symbols("").is_err());
        assert!(symbols("#define GBMLIB_NAME \"libgbm.so.1\"").is_err());
    }
    #[test]fn rejects_missing_export(){
        let mut a=BTreeSet::new();a.insert("gbm_create_device".to_string());
        assert!(subset("gbm",&a,&BTreeSet::new()).is_err());
        assert!(subset("gbm",&a,&a).is_ok());
    }
}
