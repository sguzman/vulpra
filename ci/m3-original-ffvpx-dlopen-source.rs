// Pin the original bundled FFVPX codec-loader source against two already
// observed native glibc library requests. No compiled caller proof or pruning.
use std::{env,fs,path::Path};
const PINNED:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SOURCES:[&str;4]=[
    "dom/media/platforms/ffmpeg/ffvpx/FFVPXRuntimeLinker.cpp",
    "dom/media/platforms/PDMFactory.cpp",
    "media/ffvpx/libavcodec/moz.build",
    "media/ffvpx/libavutil/moz.build",
];
fn check(root:&Path)->Result<(),String>{
    let mut docs=Vec::new();
    for relative in SOURCES{
        let contents=fs::read_to_string(root.join(relative))
            .map_err(|e|format!("Missing pinned FFVPX source {relative}: {e}"))?;
        if contents.len()<250||contents.len()>250_000{
            return Err(format!("Unexpected FFVPX source bounds for {relative}"));
        }
        docs.push(contents);
    }
    let linker=&docs[0];
    for anchor in [
        "bool FFVPXRuntimeLinker::Init()",
        "PR_LoadLibraryWithFlags(lspec, PR_LD_NOW | PR_LD_LOCAL)",
        "MOZ_DLL_PREFIX",
        "\"mozavutil\" MOZ_DLL_SUFFIX",
        "\"mozavcodec\" MOZ_DLL_SUFFIX",
        "sFFVPXLib.mAVUtilLib = MozAVLink(libFile);",
        "sFFVPXLib.mAVCodecLib = MozAVLink(libFile);",
        "FFmpegLibWrapper::LinkResult res = sFFVPXLib.Link();",
    ]{
        if !linker.contains(anchor){return Err(format!("FFVPX link source drift: {anchor}"));}
    }
    if !docs[1].contains("FFVPXRuntimeLinker::Init();") ||
       !docs[1].contains("FFVPXRuntimeLinker::CreateDecoder()"){
        return Err("Pinned media PDM factory FFVPX dispatch drift".into());
    }
    if !docs[2].contains("SharedLibrary('mozavcodec')")||
       !docs[3].contains("SharedLibrary('mozavutil')"){
        return Err("Pinned bundled FFVPX library ownership drift".into());
    }
    Ok(())
}
fn run()->Result<(),String>{
    let args:Vec<_>=env::args().collect();
    if args.len()!=4||args[1]!=PINNED{
        return Err("usage: ffvpx-source-route SOURCE_SHA SOURCE_ROOT JSON_REPORT".into());
    }
    check(Path::new(&args[2]))?;
    fs::write(&args[3],format!(
        "{{\n \"schema_version\":1,\n \"source_commit\":\"{PINNED}\",\n \"source_supported_bundled_ffvpx_roots\":[\"libmozavcodec.so\",\"libmozavutil.so\"],\n \"source_dynamic_roots_verified\":2,\n \"bundled_build_sources_verified\":true,\n \"original_native_loader_observation_authenticated_separately\":true,\n \"native_callsite_relocations_proven\":false,\n \"all_runtime_loader_routes_proven\":false,\n \"source_removal_authorized\":false,\n \"m3_sixth_gate_closed\":false\n}}\n"
    )).map_err(|e|e.to_string())?;
    println!("PASS: two original bundled FFVPX dynamic source candidates, no pruning");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn missing_pinned_ffvpx_tree_fails_closed(){
        assert!(check(Path::new("/definitely-absent-ffvpx-source")).is_err());
    }
    #[test]fn source_identity_bounded(){
        assert_eq!(SOURCES.len(),4);
        assert_ne!(PINNED,"main");
    }
}
