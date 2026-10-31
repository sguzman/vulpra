// Exact pinned original browser's generated dependentlibs.list in packaged
// archive. Verify source-declared GTK/Wayland/Gecko preloading order without
// executing native code or loading a production profile. This is a subset of
// source/build feature ownership, not complete generated Ninja/dlopen closure.
use std::{collections::BTreeSet,env,fs,path::Path};
const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
fn valid(s:&str)->bool{
 !s.is_empty()&&s.len()<112&&s.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b))
}
fn parse(content:&str)->Result<Vec<String>,String>{
 let mut libs=vec![];let mut seen=BTreeSet::new();
 for line in content.lines(){
  let s=line.trim();
  if !valid(s)||!seen.insert(s.to_owned()){return Err("unsafe, empty or duplicated generated native library name".into());}
  libs.push(s.to_owned());
 }
 if libs.len()<5||libs.len()>40{return Err("missing or unbounded original native preload list".into());}
 let ix=|name:&str|libs.iter().position(|x|x==name).ok_or(format!("generated native preload library missing: {name}"));
 if !(ix("libmozgtk.so")?<ix("libmozwayland.so")?&&ix("libmozwayland.so")?<ix("libxul.so")?){
  return Err("original Gtk before Wayland before Gecko load order broken".into());
 }
 Ok(libs)
}
fn run()->Result<String,String>{
 let args:Vec<String>=env::args().collect();
 if args.len()!=5{return Err("expected PACKAGE_ROOT ORIGINAL_LIBRARY_MOZ_BUILD ORIGINAL_LIBRARY_BUILD_MOZ_BUILD OUTPUT_JSON".into());}
 let root=Path::new(&args[1]);
 let source=fs::read_to_string(&args[2]).map_err(|_|"cannot read historical toolkit/library/moz.build")?;
 let generator=fs::read_to_string(&args[3]).map_err(|_|"cannot read historical toolkit/library/build/moz.build")?;
 for required in [
   "mozgtk appears in dependentlibs.list, preceding mozwayland",
   "        \"mozgtk\",","        \"mozwayland\",",
 ]{
  if !source.contains(required){return Err(format!("missing pinned source Wayland load ordering declaration {required}"));}
 }
 if !generator.contains("\"dependentlibs.list\"")||!generator.contains("script=\"dependentlibs.py\""){
  return Err("historical build dependency-list generator declaration missing".into());
 }
 let libs=parse(&fs::read_to_string(root.join("dependentlibs.list"))
  .map_err(|_|"original compiled browser dependentlibs.list missing")?)?;
 for lib in &libs{
  let p=root.join(lib);
  let m=fs::symlink_metadata(&p).map_err(|_|format!("original generated preload member not packaged: {lib}"))?;
  if !m.file_type().is_file(){return Err("preload dependency is not a regular original native library".into());}
 }
 let gtk=libs.iter().position(|v|v=="libmozgtk.so").unwrap();
 let wayland=libs.iter().position(|v|v=="libmozwayland.so").unwrap();
 let xul=libs.iter().position(|v|v=="libxul.so").unwrap();
 let list=libs.iter().map(|x|format!("\"{x}\"")).collect::<Vec<_>>().join(",");
 Ok(format!(concat!(
   "{{\n \"schema_version\":1,\n \"status\":\"original_compiled_generated_native_dependentlibs_order_verified\",\n",
   " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
   " \"original_dependentlibs_count\":{},\n \"ordered_package_member_basenames\":[{}],\n",
   " \"mozgtk_position_zero_indexed\":{},\n \"mozwayland_position_zero_indexed\":{},\n",
   " \"libxul_position_zero_indexed\":{},\n",
   " \"source_declares_gtk_before_wayland_before_gecko\":true,\n",
   " \"source_declares_generated_dependentlibs\":true,\n",
   " \"all_listed_native_files_exist_in_original_archive\":true,\n",
   " \"runtime_dlopen_success_for_every_item_proven\":false,\n",
   " \"complete_feature_bundle_link_graph_proven\":false,\n",
   " \"generated_ninja_ownership_proven\":false,\n",
   " \"safe_source_or_library_removal_authorized\":false,\n",
   " \"m3_sixth_gate_closed\":false\n}}\n"
 ),SRC,ARCHIVE,libs.len(),list,gtk,wayland,xul))
}
fn main(){
 match run(){
  Ok(report)=>{
   let arg=env::args().nth(4).expect("checked argument count");
   if fs::write(arg,report).is_err(){eprintln!("FAIL: cannot write sanitized browser preload report");std::process::exit(1)}
   println!("PASS: exact original compiled browser dependentlibs generated load order and all packaged file paths");
  }
  Err(e)=>{eprintln!("FAIL: original generated browser native preload list: {e}");std::process::exit(1)}
 }
}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn ordered_and_adversarial_preloads(){
   let good="libnspr4.so\nlibmozgtk.so\nlibmozwayland.so\nlibxul.so\nlibmozsqlite3.so";
   assert_eq!(parse(good).unwrap().len(),5);
   assert!(parse("libnspr4.so\nlibmozwayland.so\nlibmozgtk.so\nlibxul.so\nlibnss3.so").is_err());
   assert!(parse(&good.replace("libxul.so","../../secret")).is_err());
   assert!(parse(&format!("{good}\nlibxul.so")).is_err());
 }
}
