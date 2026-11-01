// Original Gecko's major-63 NSPR FFmpeg binding contract vs real disposable
// Arch Linux userland. Does NOT prove actual browser decode or user's host.
use std::{collections::BTreeSet,ffi::{CString,c_char,c_void},fs,io::Read,path::Path};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SONAME:&str="libavcodec.so.63";
fn get_bindings(src:&str,macro_name:&str)->Result<BTreeSet<String>,String>{
    let start=src.find("  AV_FUNC(av_lockmgr_register,").ok_or("Original FFmpeg bindings missing")?;
    let end=start+src[start..].find("#ifdef MOZ_WIDGET_ANDROID").ok_or("Android boundary missing")?;
    let chunk=&src[start..end];
    let name=format!("{macro_name}(");
    let(mut at,mut names)=(0usize,BTreeSet::new());
    while let Some(offset)=chunk[at..].find(&name){
        let begin=at+offset+name.len();
        let(mut level,mut endpos)=(1i32,None);
        for(i,b)in chunk.as_bytes()[begin..].iter().enumerate(){
            match b{
                b'('=>level+=1,
                b')'=>{level-=1;if level==0{endpos=Some(begin+i);break;}},
                _=>{}
            }
        }
        let last=endpos.ok_or("Unclosed native FFmpeg binding macro")?;
        let (symbol,mask)=chunk[begin..last].split_once(',').ok_or("Missing native version mask")?;
        let symbol=symbol.trim();
        if !symbol.starts_with("av_")&&!symbol.starts_with("avcodec_")||
            !symbol.bytes().all(|b|b.is_ascii_alphanumeric()||b==b'_'){
            return Err(format!("Unrecognized FFmpeg function {symbol}"));
        }
        let applies=mask.split(|ch:char|!ch.is_ascii_alphanumeric()&&ch!='_')
            .any(|x|matches!(x,"AV_FUNC_63"|"AV_FUNC_AVUTIL_63"|"AV_FUNC_AVCODEC_ALL"|"AV_FUNC_AVUTIL_ALL"));
        if applies&&!names.insert(symbol.into()){return Err(format!("Duplicate FFmpeg63 binding: {symbol}"));}
        at=last+1;
    }
    Ok(names)
}
fn source_contract(root:&Path)->Result<(BTreeSet<String>,BTreeSet<String>),String>{
    let linker=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp"))
        .map_err(|e|e.to_string())?;
    let src=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegLibWrapper.cpp"))
        .map_err(|e|e.to_string())?;
    let header=fs::read_to_string(root.join("dom/media/platforms/ffmpeg/FFmpegLibWrapper.h"))
        .map_err(|e|e.to_string())?;
    for (text,required)in [
        (linker.as_str(),"\"libavcodec.so.63\""),
        (linker.as_str(),"PR_LoadLibraryWithFlags(lspec, PR_LD_NOW | PR_LD_LOCAL)"),
        (linker.as_str(),"sLibAV.Link()"),
        (src.as_str(),"case 63:\n      version = AV_FUNC_63;"),
        (src.as_str(),"LinkResult::MissingFFMpegFunction"),
        (src.as_str(),"PR_FindSymbol(mAVCodecLib, \"avcodec_version\")"),
        (header.as_str(),"unsigned (*avcodec_version)();")
    ]{
        if !text.contains(required){return Err(format!("Missing pinned FFmpeg63 source anchor: {required}"));}
    }
    let mandatory=get_bindings(&src,"AV_FUNC")?;
    let mut optional=get_bindings(&src,"AV_FUNC_OPTION")?;
    optional.extend(get_bindings(&src,"AV_FUNC_OPTION_SILENT")?);
    if mandatory.len()!=42||optional.len()!=28||!mandatory.is_disjoint(&optional){
        return Err(format!("Unexpected FFmpeg63 original source binding census mandatory={} optional={}",mandatory.len(),optional.len()));
    }
    Ok((mandatory,optional))
}
fn check_host(path:&Path)->Result<(),String>{
    let meta=fs::metadata(path).map_err(|e|e.to_string())?;
    if !meta.is_file()||meta.len()<100000||meta.len()>150*1024*1024{
        return Err("Invalid Arch host libavcodec ELF size".into());
    }
    let mut f=fs::File::open(path).map_err(|e|e.to_string())?;
    let mut header=[0u8;20];f.read_exact(&mut header).map_err(|e|e.to_string())?;
    if &header[..4]!=b"\x7fELF"||header[4]!=2||header[5]!=1||header[18]!=0x3e||header[19]!=0{
        return Err("Expected Linux little-endian x86-64 libavcodec ELF".into());
    }
    let os=fs::read_to_string("/etc/os-release").map_err(|e|e.to_string())?;
    if !os.lines().any(|x|x=="ID=arch"){return Err("Not a disposable Arch Linux userland".into());}
    Ok(())
}
#[link(name="dl")]
unsafe extern "C"{
    fn dlopen(name:*const c_char,flags:i32)->*mut c_void;
    fn dlsym(handle:*mut c_void,symbol:*const c_char)->*mut c_void;
    fn dlclose(handle:*mut c_void)->i32;
}
fn verify_runtime(required:&BTreeSet<String>,optional:&BTreeSet<String>)->Result<(u32,usize,usize),String>{
    let soname=CString::new(SONAME).map_err(|e|e.to_string())?;
    let handle=unsafe{dlopen(soname.as_ptr(),2)}; // RTLD_NOW|RTLD_LOCAL
    if handle.is_null(){return Err("Arch glibc could not RTLD_NOW-load FFmpeg63".into());}
    let name=CString::new("avcodec_version").unwrap();
    let ptr=unsafe{dlsym(handle,name.as_ptr())};
    if ptr.is_null(){let _=unsafe{dlclose(handle)};return Err("Missing avcodec_version entry point".into());}
    let fun:unsafe extern "C" fn()->u32=unsafe{std::mem::transmute(ptr)};
    let version=unsafe{fun()};
    let mut missing=Vec::new();let mut optional_found=0usize;
    for sym in required{
        let c=CString::new(sym.as_str()).map_err(|e|e.to_string())?;
        if unsafe{dlsym(handle,c.as_ptr())}.is_null(){missing.push(sym.as_str());}
    }
    for sym in optional{
        let c=CString::new(sym.as_str()).map_err(|e|e.to_string())?;
        if !unsafe{dlsym(handle,c.as_ptr())}.is_null(){optional_found+=1;}
    }
    if unsafe{dlclose(handle)}!=0||version>>16!=63||!missing.is_empty(){
        return Err(format!("Arch FFmpeg63 major={} missing mandatory functions: {}",version>>16,missing.join(",")));
    }
    Ok((version,required.len(),optional_found))
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=5||args[1]!=SOURCE{
        return Err("usage: ffmpeg63-arch PINNED_SHA PINNED_SOURCE_ROOT ARCH_LIBAVCODEC_SO OUTPUT_JSON".into());
    }
    let (required,optional)=source_contract(Path::new(&args[2]))?;
    check_host(Path::new(&args[3]))?;
    let (version,found,optional_found)=verify_runtime(&required,&optional)?;
    fs::write(&args[4],format!(
        "{{\n \"schema_version\":1,\n \"source_commit\":\"{SOURCE}\",\n \"host_platform\":\"archlinux-container-x86_64\",\n \"library\":\"{SONAME}\",\n \"ffmpeg_major\":63,\n \"version_function_invoked\":true,\n \"raw_codec_version\":{version},\n \"declared_mandatory_functions\":{},\n \"resolved_mandatory_functions\":{found},\n \"missing_mandatory_functions\":0,\n \"declared_optional_functions\":{},\n \"resolved_optional_functions\":{optional_found},\n \"missing_optional_functions\":{},\n \"arch_container_loader_verified\":true,\n \"user_arch_host_verified\":false,\n \"compiled_browser_callsite_verified\":false,\n \"real_video_decode_verified\":false,\n \"full_dependency_graph_verified\":false,\n \"m3_sixth_gate_closed\":false,\n \"source_pruning_authorized\":false\n}}\n",required.len(),optional.len(),optional.len()-optional_found
    )).map_err(|e|e.to_string())?;
    println!("PASS: pinned original FFmpeg63 in Arch container mandatory {} / {}, optional {} / {}",found,required.len(),optional_found,optional.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn missing_original_binding_source_fails_closed(){
        assert!(source_contract(Path::new("/missing-gecko-source")).is_err());
    }
    #[test]fn missing_arch_library_fails_closed(){
        assert!(check_host(Path::new("/missing-libavcodec.so.63")).is_err());
    }
    #[test]fn malformed_macro_is_rejected(){
        assert!(get_bindings("  AV_FUNC(av_lockmgr_register, AV_FUNC_63","AV_FUNC").is_err());
    }
}
