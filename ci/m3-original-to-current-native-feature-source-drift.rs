// Exact historical 28-ELF declaration + protected feature source drift audit.
// This compares bytes from two separately authenticated repository checkouts,
// not an evaluated compiled graph and not a license to prune anything.
use std::{collections::BTreeSet,env,fs,path::Path};
const HISTORICAL:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ORIGINAL_SHA256:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const ORIGIN_PATHS:&[&str]=&[
 "toolkit/crashreporter/crash_helper/moz.build",
 "toolkit/crashreporter/client/app/moz.build",
 "toolkit/xre/gfxtest/moz.build",
 "media/gmp-clearkey/0.1/moz.build",
 "security/nss/lib/freebl/manifest.mn",
 "config/external/gkcodecs/moz.build",
 "config/external/lgpllibs/moz.build",
 "media/ffvpx/libavcodec/moz.build",
 "media/ffvpx/libavutil/moz.build",
 "widget/gtk/mozgtk/moz.build",
 "config/external/mozinference/moz.build",
 "security/sandbox/linux/moz.build",
 "config/external/sqlite/moz.build",
 "widget/gtk/mozwayland/moz.build",
 "config/external/nspr/pr/moz.build",
 "security/nss/lib/nss/manifest.mn",
 "security/nss/lib/util/manifest.mn",
 "toolkit/components/ml/moz.build",
 "config/external/nspr/libc/moz.build",
 "config/external/nspr/ds/moz.build",
 "security/nss/lib/smime/manifest.mn",
 "security/nss/lib/softoken/manifest.mn",
 "security/nss/lib/ssl/manifest.mn",
 "toolkit/library/moz.build",
 "toolkit/components/telemetry/pingsender/moz.build",
 "toolkit/mozapps/update/updater/moz.build",
 "browser/app/moz.build",
];
const FEATURE_PATHS:&[&str]=&[
 "browser/app.mozbuild",
 "browser/moz.configure",
 "toolkit/toolkit.mozbuild",
 "widget/moz.build",
 "toolkit/library/rust/moz.build",
 "toolkit/library/rust/gkrust-features.mozbuild",
 "toolkit/components/moz.build",
 "toolkit/components/telemetry/moz.build",
 "services/moz.build",
 "devtools/moz.build",
 "browser/components/moz.build",
 "browser/components/newtab/moz.build",
 "browser/extensions/newtab/moz.build",
 "browser/components/genai/moz.build",
];
fn list(names:&[String])->String{names.iter().map(|p|format!("\"{p}\"")).collect::<Vec<_>>().join(",")}
fn compare(hist:&Path,current:&Path)->Result<String,String>{
 let mut seen=BTreeSet::new();
 let mut changed_origin=vec![];let mut changed_feature=vec![];let mut missing_current=vec![];
 for (kind,paths) in [("origin",ORIGIN_PATHS),("feature",FEATURE_PATHS)]{
  for path in paths{
   if !seen.insert(*path){return Err("duplicate original source ownership path".into())}
   if path.contains("..")||!path.bytes().all(|b|b.is_ascii_alphanumeric()||b"._/-".contains(&b)){
    return Err("unsafe static audited source path".into())
   }
   let before=fs::read(hist.join(path)).map_err(|_|format!("missing pinned source snapshot: {path}"))?;
   let after=match fs::read(current.join(path)){Ok(v)=>v,Err(_)=>{missing_current.push(path.to_string());continue}};
   if before!=after {
    match kind {
     "origin"=>changed_origin.push(path.to_string()),
     "feature"=>changed_feature.push(path.to_string()),
     _=>unreachable!(),
    }
   }
  }
 }
 if seen.len()!=41{return Err("source boundary inventory drifted".into())}
 let report=format!(concat!(
  "{{\n \"schema_version\":1,\n \"status\":\"source_pinned_original_to_current_native_feature_manifest_drift\",\n",
  " \"original_compiled_source_commit\":\"{}\",\n \"original_compiled_archive_sha256\":\"{}\",\n",
  " \"checked_original_elf_ownership_manifest_paths\":{},\n",
  " \"checked_protected_feature_boundary_paths\":{},\n",
  " \"unique_source_paths_compared\":41,\n",
  " \"modified_original_elf_ownership_manifests\":{},\n",
  " \"modified_feature_boundary_files\":{},\n",
  " \"missing_current_source_paths\":{},\n",
  " \"changed_original_elf_ownership_manifest_paths\":[{}],\n",
  " \"changed_feature_boundary_paths\":[{}],\n",
  " \"current_source_paths_missing\":[{}],\n",
  " \"byte_identical_only_not_a_generated_build_graph\":true,\n",
  " \"original_binary_not_rebuilt_from_current_source\":true,\n",
  " \"current_config_status_or_feature_runtimes_not_proven\":true,\n",
  " \"safe_source_removal_authorized\":false,\n",
  " \"m3_sixth_gate_closed\":false\n}}\n"
 ),HISTORICAL,ORIGINAL_SHA256,ORIGIN_PATHS.len(),FEATURE_PATHS.len(),
 changed_origin.len(),changed_feature.len(),missing_current.len(),
 list(&changed_origin),list(&changed_feature),list(&missing_current));
 Ok(report)
}
fn main(){
 let a:Vec<String>=env::args().collect();
 if a.len()!=4{eprintln!("expected HISTORICAL_SOURCE CURRENT_SOURCE SANITIZED_REPORT");std::process::exit(2)}
 match compare(Path::new(&a[1]),Path::new(&a[2])){
  Ok(s)=>{if fs::write(&a[3],s).is_err(){eprintln!("cannot write sanitized drift report");std::process::exit(1)}
   println!("PASS: exact historical/current 41 source manifest/feature boundary files compared");}
  Err(e)=>{eprintln!("FAIL: bounded original/current source drift verification: {e}");std::process::exit(1)}
 }
}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn independent_path_sets(){
  assert_eq!(ORIGIN_PATHS.len(),27);
  assert_eq!(FEATURE_PATHS.len(),14);
  assert_eq!(ORIGIN_PATHS.iter().chain(FEATURE_PATHS).collect::<BTreeSet<_>>().len(),41);
 }
}
