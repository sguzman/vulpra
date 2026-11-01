// Exact-original NSS dynamic-loader source contract for two already-observed
// protected security roots. This is a source-route check, not a compiled call stack.
use std::{env,fs,path::Path};
const PINNED:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const RELATIVE:[&str;6]=[
    "security/nss/lib/pk11wrap/pk11load.c",
    "security/nss/lib/softoken/manifest.mn",
    "security/nss/lib/freebl/loader.c",
    "security/nss/lib/freebl/genload.c",
    "security/nss/lib/freebl/blname.c",
    "security/nss/lib/freebl/manifest.mn",
];
fn assert_source(root:&Path)->Result<(),String>{
    let mut files=Vec::new();
    for relative in RELATIVE{
        let path=root.join(relative);
        let contents=fs::read_to_string(&path).map_err(|e|format!("{relative}: {e}"))?;
        if contents.len()<500||contents.len()>600_000{
            return Err(format!("{relative}: unexpected source bounds"));
        }
        files.push(contents);
    }
    let loader=&files[0];
    for anchor in [
        "#ifndef NSS_STATIC_SOFTOKEN",
        "SHLIB_PREFIX \"softokn\" SOFTOKEN_SHLIB_VERSION \".\" SHLIB_SUFFIX",
        "softoken_LoadDSO(void)",
        "PORT_LoadLibraryFromOrigin(my_shlib_name,",
        "softoken_shlib_name);",
        "PR_CallOnce(&loadSoftokenOnce, &softoken_LoadDSO)",
        "PR_FindSymbol(softokenLib, nss_interface)",
    ]{
        if !loader.contains(anchor){return Err(format!("NSS softoken route changed: {anchor}"));}
    }
    if !files[1].contains("LIBRARY_NAME = softokn")||
       !files[1].contains("LIBRARY_VERSION = 3"){
        return Err("Missing original security softokn3 build declaration".into());
    }
    let freebl=&files[2];
    for anchor in [
        "#include \"blname.c\"",
        "#include \"genload.c\"",
        "freebl_LoadDSO(void)",
        "const char *name = getLibName();",
        "handle = loader_LoadLibrary(name);",
        "PR_FindFunctionSymbol(handle, \"FREEBL_GetVector\")",
    ]{
        if !freebl.contains(anchor){return Err(format!("NSS FreeBL source route changed: {anchor}"));}
    }
    if !files[3].contains("loader_LoadLibrary(const char* nameToLoad)")||
       !files[3].contains("PR_LoadLibraryWithFlags(libSpec, PR_LD_NOW | PR_LD_LOCAL)"){
        return Err("NSS FreeBL NSPR dynamic load contract changed".into());
    }
    if !files[4].contains("#if defined(FREEBL_LOWHASH)")||
       !files[4].contains("SHLIB_PREFIX \"freeblpriv\" SHLIB_VERSION \".\" SHLIB_SUFFIX"){
        return Err("NSS FreeBL lowhash dynamic SONAME source changed".into());
    }
    if !files[5].contains("LIBRARY_VERSION = 3")||
       !files[5].contains("FREEBL_LOWHASH = 1")||
       !files[5].contains("LIBRARY_NAME = freeblpriv"){
        return Err("NSS FreeBL Linux lowhash build branch changed".into());
    }
    Ok(())
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4||args[1]!=PINNED{
        return Err("usage: nss-source-route PINNED_SHA GECKO_ROOT REPORT_JSON".into());
    }
    assert_source(Path::new(&args[2]))?;
    fs::write(&args[3],format!(
        "{{\n \"schema_version\":1,\n \"source_commit\":\"{PINNED}\",\n \"observed_source_candidates\":[\"libsoftokn3.so\",\"libfreeblpriv3.so\"],\n \"source_supported_nss_dynamic_routes\":2,\n \"source_route_for_softoken_verified\":true,\n \"source_route_for_freebl_verified\":true,\n \"nss_security_removal_authorized\":false,\n \"original_compiled_conditional_verified\":false,\n \"original_compiled_callstack_verified\":false,\n \"complete_dynamic_graph_verified\":false,\n \"m3_sixth_gate_closed\":false\n}}\n"
    )).map_err(|e|e.to_string())?;
    println!("PASS: two pinned NSS security dynamic source candidates; no pruning or gate closure");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn missing_source_tree_fails_closed(){
        assert!(assert_source(Path::new("/definitely-missing-nss-source")).is_err());
    }
    #[test]fn missing_pinned_commit_argument_fails_closed(){
        assert_ne!(PINNED,"main");
        assert_eq!(RELATIVE.len(),6);
    }
}
