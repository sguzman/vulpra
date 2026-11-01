// Verify exact-original XPCOM bootstrap owner and actual packaged
// dependentlibs.list without mislabeling observed glibc edges as all dlopens.
use std::{collections::BTreeSet,env,fs,path::Path};
const PINNED:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const EXPECTED:[&str;14]=[
 "libnspr4.so","libplc4.so","libplds4.so","libmozsandbox.so",
 "libgkcodecs.so","liblgpllibs.so","libnssutil3.so","libnss3.so",
 "libsmime3.so","libmozsqlite3.so","libssl3.so","libmozgtk.so",
 "libmozwayland.so","libxul.so"
];
fn prove(root:&Path,manifest:&Path)->Result<(),String>{
 let source=fs::read_to_string(root.join("xpcom/glue/standalone/nsXPCOMGlue.cpp"))
    .map_err(|e|format!("Missing pinned standalone XPCOM glue: {e}"))?;
 if source.len()<5000||source.len()>50000{
    return Err("Unbounded/missing XPCOM bootstrap source".into());
 }
 for needle in [
   "#define XPCOM_DEPENDENT_LIBS_LIST \"dependentlibs.list\"",
   "LibHandleType libHandle = dlopen(aDependentLib, RTLD_GLOBAL | RTLD_LAZY",
   "ReadDependentCB(aXPCOMFile, aLibLoadingStrategy)",
   "const auto flist = TS_tfopen(xpcomDir, READ_TEXTMODE)",
   "while (fgets(buffer, sizeof(buffer), flist))",
   "ReadDependentCB(xpcomDir, aLibLoadingStrategy)",
 ]{
   if !source.contains(needle){return Err(format!("Pinned XPCOM bootstrap source drift: {needle}"));}
 }
 let bytes=fs::read(manifest).map_err(|e|e.to_string())?;
 if bytes.len()<60||bytes.len()>1024||bytes.contains(&0)||!bytes.ends_with(b"\n"){
    return Err("Invalid original packaged dependentlibs.list bounds".into());
 }
 let list=std::str::from_utf8(&bytes).map_err(|e|e.to_string())?;
 let names:Vec<_>=list.lines().collect();
 if names.len()!=EXPECTED.len()||names!=EXPECTED{
    return Err("Original packaged 14 preload names/order changed".into());
 }
 let unique:BTreeSet<_>=names.iter().copied().collect();
 if unique.len()!=EXPECTED.len(){
    return Err("Duplicate bootstrap manifest library".into());
 }
 Ok(())
}
fn run()->Result<(),String>{
 let args:Vec<_>=env::args().collect();
 if args.len()!=5||args[1]!=PINNED{
    return Err("usage: dependentlibs PINNED_SHA SOURCE_ROOT EXTRACTED_MANIFEST REPORT_JSON".into());
 }
 prove(Path::new(&args[2]),Path::new(&args[3]))?;
 fs::write(&args[4],format!(
 "{{\n \"schema_version\":1,\n \"gecko_source_commit\":\"{PINNED}\",\n \"source_xpcom_manifest_loader_verified\":true,\n \"packaged_dependency_manifest_entries\":14,\n \"manifest_order_and_unique_names_verified\":true,\n \"runtime_edge_set_match_checked_separately\":false,\n \"all_runtime_dlopen_paths_proven\":false,\n \"original_compiled_callstack_proven\":false,\n \"m3_sixth_gate_closed\":false,\n \"source_removal_authorized\":false\n}}\n"
 )).map_err(|e|e.to_string())?;
 println!("PASS: pinned XPCOM bootstrap source and 14 real packaged manifest records; browser runtime edge comparison independent");
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)] mod tests{
 use super::*;
 #[test]fn missing_manifest_or_source_fails_closed(){
   assert!(prove(Path::new("/definitely-unavailable-original-source"),Path::new("/missing-manifest")).is_err());
 }
 #[test]fn no_duplicate_manifest_expected(){
   assert_eq!(EXPECTED.iter().copied().collect::<BTreeSet<_>>().len(),14);
 }
}
