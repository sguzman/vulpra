// Read-only exact Firefox160 NSS/FFVPX source ownership and guarded-loader
// source-route candidates. Verifies authentic official Firefox release HEAD,
// 10 original Git blobs and unchanged content, never takes caller attribution
// from a glibc requester basename. The independent workflow separately
// authenticates 28-overlay noninterference and native runtime request edges.
// Rust std only; no feature execution, browser build or deletion authority.
use std::{env,fs,path::Path,process::Command};

const RELEASE:&str="2887d9de1f69c0e9776413da80e7ba0d1225dd9b";
const TREE:&str="42dd7439a27dde92f89ac5eed13f88117a4d7ab5";
const ARCHIVE:&str="530b79584801c3632a583d4ebca7e4f5158870133f88dae647d5be7b7def97eb";
struct Owner {
    path:&'static str,
    git_blob:&'static str,
    tokens:&'static [&'static str],
}
const OWNERS:[Owner;10]=[
    Owner{
        path:"security/nss/lib/pk11wrap/pk11load.c",
        git_blob:"3fb57828311d699b14d26eb213d6029dd11d66dd",
        tokens:&[
            "SHLIB_PREFIX \"softokn\" SOFTOKEN_SHLIB_VERSION \".\" SHLIB_SUFFIX",
            "softoken_LoadDSO(void)",
            "PORT_LoadLibraryFromOrigin(my_shlib_name,",
            "softoken_shlib_name);",
            "PR_CallOnce(&loadSoftokenOnce, &softoken_LoadDSO)",
            "PR_FindSymbol(softokenLib, nss_interface)",
            "return SECFailure;",
        ],
    },
    Owner{
        path:"security/nss/lib/softoken/manifest.mn",
        git_blob:"43ebfd8a6113a5141f4d09ecef73070b78b261a1",
        tokens:&["LIBRARY_NAME = softokn","LIBRARY_VERSION = 3"],
    },
    Owner{
        path:"security/nss/lib/freebl/loader.c",
        git_blob:"bb8fe3a7f9cf16a14154f5eb5b5c1ea376c7c093",
        tokens:&[
            "freebl_LoadDSO(void)","const char *name = getLibName();",
            "if (!name)","return PR_FAILURE;",
            "handle = loader_LoadLibrary(name);",
            "PR_FindFunctionSymbol(handle, \"FREEBL_GetVector\")",
        ],
    },
    Owner{
        path:"security/nss/lib/freebl/genload.c",
        git_blob:"e3231e3e527f463b47148b74cb3d7b39ab31456a",
        tokens:&[
            "loader_LoadLibrary(const char* nameToLoad)",
            "PR_LoadLibraryWithFlags(libSpec, PR_LD_NOW | PR_LD_LOCAL)",
        ],
    },
    Owner{
        path:"security/nss/lib/freebl/blname.c",
        git_blob:"4bad74ada087feb407a03f811b8e52d0856bb163",
        tokens:&[
            "#if defined(FREEBL_LOWHASH)",
            "SHLIB_PREFIX \"freeblpriv\" SHLIB_VERSION \".\" SHLIB_SUFFIX",
        ],
    },
    Owner{
        path:"security/nss/lib/freebl/manifest.mn",
        git_blob:"39633d5b46d331f8e7987250c74a29251633461d",
        tokens:&[
            "FREEBL_LOWHASH = 1",
            "LIBRARY_NAME = freeblpriv",
            "LIBRARY_VERSION = 3",
        ],
    },
    Owner{
        path:"dom/media/platforms/ffmpeg/ffvpx/FFVPXRuntimeLinker.cpp",
        git_blob:"4d3eaf7529a534008f9150c2a16a04e5ef211566",
        tokens:&[
            "bool FFVPXRuntimeLinker::Init()",
            "PR_LoadLibraryWithFlags(lspec, PR_LD_NOW | PR_LD_LOCAL)",
            "\"mozavutil\" MOZ_DLL_SUFFIX",
            "\"mozavcodec\" MOZ_DLL_SUFFIX",
            "sFFVPXLib.mAVUtilLib = MozAVLink(libFile);",
            "sFFVPXLib.mAVCodecLib = MozAVLink(libFile);",
            "FFmpegLibWrapper::LinkResult res = sFFVPXLib.Link();",
            "sLinkStatus = LinkStatus_SUCCEEDED;",
            "return false;",
        ],
    },
    Owner{
        path:"dom/media/platforms/PDMFactory.cpp",
        git_blob:"e074da3437155fc64dccc7f4d97a047dc2193a61",
        tokens:&["FFVPXRuntimeLinker::Init();","FFVPXRuntimeLinker::CreateDecoder()"],
    },
    Owner{
        path:"media/ffvpx/libavcodec/moz.build",
        git_blob:"9153f6a16c6f36320e4181a900d2f94f35b34387",
        tokens:&["SharedLibrary('mozavcodec')"],
    },
    Owner{
        path:"media/ffvpx/libavutil/moz.build",
        git_blob:"9893132c47a1b34d71648fd7150671050bd95417",
        tokens:&["SharedLibrary('mozavutil')"],
    },
];

fn git(root:&Path,args:&[&str])->Result<String,String>{
    let output=Command::new("git").arg("-C").arg(root).args(args).output()
        .map_err(|_|"git metadata command unavailable")?;
    if !output.status.success() || output.stdout.len()>2048 {
        return Err("pinned source Git metadata unavailable or oversized".into());
    }
    String::from_utf8(output.stdout).map(|s|s.trim().to_owned())
        .map_err(|_|"malformed Git SHA encoding".into())
}

fn validate_blob(owner:&Owner,source:&str)->Result<(),String>{
    if source.len()<250 || source.len()>120000 || source.contains('\0'){
        return Err(format!("unsafe/changed source bounds: {}",owner.path));
    }
    for token in owner.tokens {
        if !source.contains(token) {
            return Err(format!("Firefox160 conditional loader source anchor changed: {} (anchor {} chars)",
                               owner.path,token.len()));
        }
    }
    Ok(())
}

fn verify(root:&Path)->Result<Vec<(&'static str,&'static str)>,String>{
    if git(root,&["rev-parse","HEAD"])? != RELEASE {
        return Err("refusing a non-Firefox160 official release checkout".into());
    }
    let mut seen=std::collections::BTreeSet::new();
    let mut verified=Vec::new();
    for owner in &OWNERS {
        if !seen.insert(owner.path){return Err("duplicated source owner".into());}
        let file=root.join(owner.path);
        let metadata=fs::symlink_metadata(&file)
            .map_err(|_|format!("missing official Firefox160 source: {}",owner.path))?;
        if !metadata.file_type().is_file() || metadata.len()<250 || metadata.len()>120000 {
            return Err(format!("unsafe source file or path: {}",owner.path));
        }
        let from_commit=git(root,&["rev-parse",&format!("HEAD:{}",owner.path)])?;
        let from_disk=git(root,&["hash-object","--",owner.path])?;
        if from_commit!=owner.git_blob || from_disk!=owner.git_blob {
            return Err(format!("official Firefox160 owner blob changed: {}",owner.path));
        }
        let source=fs::read_to_string(&file).map_err(|_|"source not valid UTF-8")?;
        validate_blob(owner,&source)?;
        verified.push((owner.path,owner.git_blob));
    }
    Ok(verified)
}

fn report(rows:&[(&str,&str)])->String{
    let owner_rows=rows.iter().map(|(path,blob)|format!(
        "{{\"source_path\":\"{path}\",\"verified_original_release_git_blob\":\"{blob}\",\"source_guard_anchors_observed\":true,\"observed_compiled_machine_callsite_proven\":false}}"
    )).collect::<Vec<_>>().join(",\n    ");
    format!(concat!(
        "{{\n \"schema_version\":1,\n",
        " \"status\":\"firefox160_exact_release_nss_ffvpx_conditional_source_owner_candidates\",\n",
        " \"official_upstream_release_commit\":\"{}\",\n",
        " \"assembled_vulpra_candidate_tree_authenticated_separately\":\"{}\",\n",
        " \"original_compiled_native_archive_sha256_authenticated_separately\":\"{}\",\n",
        " \"verified_exact_original_unmodified_source_paths\":10,\n",
        " \"exact_source_owner_rows\":[\n    {}\n  ],\n",
        " \"source_candidate_routes\":[\n",
        "   {{\"id\":\"nss_softoken\",\"candidate_provider\":\"libsoftokn3.so\",\"owner_path\":\"security/nss/lib/pk11wrap/pk11load.c\",\"linked_build_manifest\":\"security/nss/lib/softoken/manifest.mn\",\"source_load_failure_guard_present\":true,\"observed_native_glibc_request_direct_callsite_attributed\":false}},\n",
        "   {{\"id\":\"nss_freebl\",\"candidate_provider\":\"libfreeblpriv3.so\",\"owner_path\":\"security/nss/lib/freebl/loader.c\",\"linked_build_manifest\":\"security/nss/lib/freebl/manifest.mn\",\"source_load_failure_guard_present\":true,\"observed_native_glibc_request_direct_callsite_attributed\":false}},\n",
        "   {{\"id\":\"ffvpx_codec\",\"candidate_provider\":\"libmozavcodec.so\",\"owner_path\":\"dom/media/platforms/ffmpeg/ffvpx/FFVPXRuntimeLinker.cpp\",\"linked_build_manifest\":\"media/ffvpx/libavcodec/moz.build\",\"source_load_failure_guard_present\":true,\"observed_native_glibc_request_direct_callsite_attributed\":false}},\n",
        "   {{\"id\":\"ffvpx_util\",\"candidate_provider\":\"libmozavutil.so\",\"owner_path\":\"dom/media/platforms/ffmpeg/ffvpx/FFVPXRuntimeLinker.cpp\",\"linked_build_manifest\":\"media/ffvpx/libavutil/moz.build\",\"source_load_failure_guard_present\":true,\"observed_native_glibc_request_direct_callsite_attributed\":false}}\n",
        " ],\n",
        " \"source_candidate_routes_count\":4,\n",
        " \"exact_candidate_tree_overlay_noninterference_verified_by_this_tool\":false,\n",
        " \"source_owner_matches_exact_runtime_caller_machine_instructions\":false,\n",
        " \"source_fallback_arms_actually_exercised\":false,\n",
        " \"all_native_ffi_dlopen_dlsym_routes_known\":false,\n",
        " \"target_endeavouros_hyprland_verified\":false,\n",
        " \"source_pruning_authorized\":false,\n",
        " \"security_current\":false,\n \"release_ready\":false,\n \"m3_sixth_gate_closed\":false\n}}\n"
    ),RELEASE,TREE,ARCHIVE,owner_rows)
}

fn run()->Result<(),String>{
    let args:Vec<_>=env::args().collect();
    if args.len()!=4 || args[1]!="--verify" {
        return Err("usage: firefox160-source-owners --verify PINNED_OFFICIAL_SOURCE_DIR REPORT_JSON".into());
    }
    let rows=verify(Path::new(&args[2]))?;
    fs::write(&args[3],report(&rows)).map_err(|_|"could not write bounded source owner report")?;
    println!("PASS: 10 verified official Firefox160 source blobs, 4 guarded NSS/FFVPX candidate source routes; no actual callsite claim");
    Ok(())
}

fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn source_identity_is_exact_and_nonduplicated(){
        assert_eq!(RELEASE.len(),40);
        assert_eq!(ARCHIVE.len(),64);
        assert_eq!(OWNERS.len(),10);
        assert_eq!(OWNERS.iter().map(|owner|owner.path).collect::<std::collections::BTreeSet<_>>().len(),10);
        assert!(OWNERS.iter().all(|owner|owner.git_blob.len()==40));
    }
    #[test]
    fn every_pinned_source_anchor_mutation_rejected(){
        for owner in &OWNERS {
            let mut example=String::from("x").repeat(400);
            for token in owner.tokens {example.push_str(token);example.push('\n');}
            validate_blob(owner,&example).unwrap();
            for token in owner.tokens {
                let changed=example.replacen(token,"FALSIFIED_ANCHOR",1);
                assert!(validate_blob(owner,&changed).is_err(),
                    "mutation of {} anchored token accepted",owner.path);
            }
            assert!(validate_blob(owner,"short").is_err());
        }
    }
    #[test]
    fn source_candidate_report_is_conservative(){
        let rows=OWNERS.iter().map(|r|(r.path,r.git_blob)).collect::<Vec<_>>();
        let json=report(&rows);
        assert!(json.contains("\"source_candidate_routes_count\":4"));
        assert!(json.contains("\"source_fallback_arms_actually_exercised\":false"));
        assert!(json.contains("\"m3_sixth_gate_closed\":false"));
    }
}
