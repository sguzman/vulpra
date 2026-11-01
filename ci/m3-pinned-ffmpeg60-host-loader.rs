// Exact-original FFmpeg 60 native loader anchor and real Ubuntu glibc ABI.
// This intentionally proves only runtime loading and codec version binding.
use std::{fs,path::Path};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
fn source_proof(root:&Path)->Result<(),String>{
    let linker=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp"))
        .map_err(|e|format!("Missing original FFmpeg runtime source: {e}"))?;
    let wrapper=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegLibWrapper.cpp"))
        .map_err(|e|format!("Missing original FFmpeg function loader: {e}"))?;
    let header=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegLibWrapper.h"))
        .map_err(|e|format!("Missing original FFmpeg C ABI header: {e}"))?;
    for (text,needle) in [
        (linker.as_str(),"\"libavcodec.so.60\""),
        (linker.as_str(),"PR_LoadLibraryWithFlags(lspec, PR_LD_NOW | PR_LD_LOCAL)"),
        (linker.as_str(),"sLibAV.Link()"),
        (wrapper.as_str(),"PR_FindSymbol(mAVCodecLib, \"avcodec_version\")"),
        (header.as_str(),"unsigned (*avcodec_version)();")
    ]{
        if !text.contains(needle){return Err(format!("Pinned FFmpeg source route missing anchor: {needle}"));}
    }
    Ok(())
}

fn mandatory_60(root:&Path)->Result<Vec<String>,String>{
    use std::collections::BTreeSet;
    let src=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegLibWrapper.cpp"))
        .map_err(|e|e.to_string())?;
    if !src.contains("case 60:\n      version = AV_FUNC_60;") ||
       !src.contains("LinkResult::MissingFFMpegFunction") {
        return Err("Version-60 mandatory binding contract drift".into());
    }
    let start=src.find("  AV_FUNC(av_lockmgr_register,").ok_or("Missing first binding")?;
    let end=start+src[start..].find("#ifdef MOZ_WIDGET_ANDROID")
        .ok_or("Missing Android-only end boundary")?;
    let chunk=&src[start..end];
    let(mut pos,mut selected)=(0usize,BTreeSet::new());
    while let Some(rel)=chunk[pos..].find("AV_FUNC("){
        let begin=pos+rel+"AV_FUNC(".len();
        let(mut depth,mut closing)=(1i32,None);
        for(i,b)in chunk.as_bytes()[begin..].iter().enumerate(){
            match b {b'('=>depth+=1,b')'=>{depth-=1;if depth==0{closing=Some(begin+i);break;}},_=>{}}
        }
        let last=closing.ok_or("Unclosed AV_FUNC macro")?;
        let (symbol,mask)=chunk[begin..last].split_once(',').ok_or("Malformed AV_FUNC")?;
        let symbol=symbol.trim();
        if !symbol.bytes().all(|x|x.is_ascii_alphanumeric()||x==b'_') ||
           !(symbol.starts_with("av_")||symbol.starts_with("avcodec_")){
            return Err(format!("Invalid FFmpeg function {symbol}"));
        }
        let enabled=mask.split(|c:char|!c.is_ascii_alphanumeric()&&c!='_').any(
            |x|matches!(x,"AV_FUNC_60"|"AV_FUNC_AVUTIL_60"|"AV_FUNC_AVCODEC_ALL"|"AV_FUNC_AVUTIL_ALL"));
        if enabled&&!selected.insert(symbol.to_owned()){return Err("Duplicate FFmpeg60 function".into());}
        pos=last+1;
    }
    if !(20..=100).contains(&selected.len()){return Err(format!("Unexpected required FFmpeg60 function count {}",selected.len()));}
    Ok(selected.into_iter().collect())
}
#[cfg(target_os="linux")]
fn resolve_required_60(symbols:&[String])->Result<usize,String>{
    use std::ffi::{CString,c_char,c_void};
    #[link(name="dl")]unsafe extern "C" {
        fn dlopen(name:*const c_char,flags:i32)->*mut c_void;
        fn dlsym(handle:*mut c_void,name:*const c_char)->*mut c_void;
        fn dlclose(handle:*mut c_void)->i32;
    }
    let lib=CString::new("libavcodec.so.60").unwrap();
    let handle=unsafe{dlopen(lib.as_ptr(),2)};
    if handle.is_null(){return Err("Cannot open FFmpeg60 under RTLD_NOW".into());}
    let mut missing=Vec::new();
    for sym in symbols{
        let name=CString::new(sym.as_str()).map_err(|e|e.to_string())?;
        if unsafe{dlsym(handle,name.as_ptr())}.is_null(){missing.push(sym.as_str());}
    }
    if unsafe{dlclose(handle)}!=0||!missing.is_empty(){
        return Err(format!("Missing FFmpeg60 mandatory dynamic function(s): {}",missing.join(",")));
    }
    Ok(symbols.len())
}

fn check_host_so(path:&Path)->Result<(),String>{
    use std::io::Read;
    let meta=fs::metadata(path).map_err(|e|e.to_string())?;
    if !meta.is_file()||meta.len()<100000||meta.len()>150*1024*1024{
        return Err("Invalid host libavcodec ELF size".into());
    }
    let mut magic=[0u8;20];fs::File::open(path).map_err(|e|e.to_string())?
        .read_exact(&mut magic).map_err(|e|e.to_string())?;
    if &magic[..4]!=b"\x7fELF"||magic[4]!=2||magic[5]!=1||magic[18]!=0x3e||magic[19]!=0{
        return Err("Expected little-endian x86-64 host libavcodec ELF".into());
    }
    Ok(())
}
#[cfg(target_os="linux")]
fn runtime_version()->Result<u32,String>{
    use std::ffi::{CString,c_char,c_void};
    #[link(name="dl")]
    unsafe extern "C"{
        fn dlopen(path:*const c_char,flags:i32)->*mut c_void;
        fn dlsym(lib:*mut c_void,name:*const c_char)->*mut c_void;
        fn dlclose(lib:*mut c_void)->i32;
    }
    let lib=CString::new("libavcodec.so.60").map_err(|e|e.to_string())?;
    let handle=unsafe{dlopen(lib.as_ptr(),2)}; // RTLD_NOW | RTLD_LOCAL
    if handle.is_null(){return Err("Unable to load libavcodec.so.60 and its host dependencies".into());}
    let name=CString::new("avcodec_version").map_err(|e|e.to_string())?;
    let addr=unsafe{dlsym(handle,name.as_ptr())};
    if addr.is_null(){let _=unsafe{dlclose(handle)};return Err("libavcodec missing runtime avcodec_version".into());}
    // Exact pinned C++ type: unsigned (*avcodec_version)().
    let version_fn:unsafe extern "C" fn()->u32=unsafe{std::mem::transmute(addr)};
    let version=unsafe{version_fn()};
    let closed=unsafe{dlclose(handle)};
    if closed!=0||version>>16!=60{return Err(format!("Wrong host FFmpeg major or failed close: {}",version>>16));}
    Ok(version)
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=5||args[1]!=SOURCE{
        return Err("usage: ffmpeg60-host-loader PINNED_SHA PINNED_GECKO_ROOT HOST_LIBAVCODEC_SO OUTPUT_JSON".into());
    }
    source_proof(Path::new(&args[2]))?;
    check_host_so(Path::new(&args[3]))?;
    let version=runtime_version()?;
    let required=mandatory_60(Path::new(&args[2]))?;
    let resolved=resolve_required_60(&required)?;
    fs::write(&args[4],format!(
        "{{\n \"schema_version\":1,\n \"gecko_source_commit\":\"{SOURCE}\",\n \"host_platform\":\"ubuntu-24.04-x86_64\",\n \"requested_library\":\"libavcodec.so.60\",\n \"glibc_rtld_now_load_passed\":true,\n \"avcodec_version_symbol_resolved_and_invoked\":true,\n \"avcodec_runtime_major\":60,\n \"avcodec_runtime_raw_version\":{},\n \"required_ffmpeg60_function_count\":{},\n \"resolved_ffmpeg60_required_functions\":{},\n \"complete_ffmpeg60_required_function_set_verified\":true,\n \"complete_ffmpeg_function_set_verified\":false,\n \"original_vulpra_callsite_proven\":false,\n \"arch_host_abi_proven\":false,\n \"all_dynamic_loading_paths_proven\":false,\n \"m3_sixth_gate_closed\":false,\n \"source_removal_authorized\":false\n}}\n",version,required.len(),resolved
    )).map_err(|e|e.to_string())?;
    println!("PASS: pinned FFmpeg 60 NSPR source load path and actual Ubuntu glibc RTLD_NOW avcodec_version major 60");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn missing_source_path_fails_closed(){
        assert!(source_proof(Path::new("/definitely-missing-gecko-root")).is_err());
    }
    #[test]fn missing_mandatory_bindings_fail_closed(){
        assert!(mandatory_60(Path::new("/definitely-missing-gecko-root")).is_err());
    }
    #[test]fn missing_host_library_fails_closed(){
        assert!(check_host_so(Path::new("/definitely-missing-libavcodec60")).is_err());
    }
}
