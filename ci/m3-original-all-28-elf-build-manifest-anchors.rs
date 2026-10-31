// Crosswalk the exact original 28 regular ELF archive basenames to source-pinned
// build declarations. Not an evaluated moz.build/Ninja graph or feature test.
// No arbitrary code execution, source pruning or user profile access.
use std::collections::{BTreeMap,BTreeSet};
use std::env;
use std::fs::{self,File};
use std::io::Read;
use std::path::{Path,PathBuf};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";

struct Origin {elf:&'static str, source:&'static str, anchor:&'static str, guard:&'static str, class:&'static str}
const ORIGINS:&[Origin]=&[
 Origin{elf:"crashhelper",source:"toolkit/crashreporter/crash_helper/moz.build",anchor:"GeckoProgram(\"crashhelper\", linkage=None)",guard:"",class:"guarded_gecko_program"},
 Origin{elf:"crashreporter",source:"toolkit/crashreporter/client/app/moz.build",anchor:"RustProgram(\"crashreporter\")",guard:"",class:"rust_program"},
 Origin{elf:"gfxtest",source:"toolkit/xre/gfxtest/moz.build",anchor:"Program(\"gfxtest\")",guard:"",class:"native_program"},
 Origin{elf:"libclearkey.so",source:"media/gmp-clearkey/0.1/moz.build",anchor:"GeckoSharedLibrary(\"clearkey\")",guard:"",class:"gmp_plugin_library"},
 Origin{elf:"libfreeblpriv3.so",source:"security/nss/lib/freebl/manifest.mn",anchor:"LIBRARY_NAME = freeblpriv",guard:"",class:"nss_make_manifest_conditional"},
 Origin{elf:"libgkcodecs.so",source:"config/external/gkcodecs/moz.build",anchor:"GeckoSharedLibrary(\"gkcodecs\")",guard:"",class:"external_gecko_shared_library"},
 Origin{elf:"liblgpllibs.so",source:"config/external/lgpllibs/moz.build",anchor:"GeckoSharedLibrary(\"lgpllibs\")",guard:"",class:"external_gecko_shared_library"},
 Origin{elf:"libmozavcodec.so",source:"media/ffvpx/libavcodec/moz.build",anchor:"SharedLibrary('mozavcodec')",guard:"",class:"ffvpx_shared_library"},
 Origin{elf:"libmozavutil.so",source:"media/ffvpx/libavutil/moz.build",anchor:"SharedLibrary('mozavutil')",guard:"",class:"ffvpx_shared_library"},
 Origin{elf:"libmozgtk.so",source:"widget/gtk/mozgtk/moz.build",anchor:"SharedLibrary(\"mozgtk\")",guard:"",class:"gtk_shared_library"},
 Origin{elf:"libmozinference.so",source:"config/external/mozinference/moz.build",anchor:"GeckoSharedLibrary(\"mozinference\")",guard:"",class:"external_ml_shared_library"},
 Origin{elf:"libmozsandbox.so",source:"security/sandbox/linux/moz.build",anchor:"SharedLibrary(\"mozsandbox\")",guard:"",class:"security_sandbox_shared_library"},
 Origin{elf:"libmozsqlite3.so",source:"config/external/sqlite/moz.build",anchor:"SHARED_LIBRARY_NAME = \"mozsqlite3\"",guard:"",class:"conditional_sqlite_shared_library"},
 Origin{elf:"libmozwayland.so",source:"widget/gtk/mozwayland/moz.build",anchor:"SharedLibrary(\"mozwayland\")",guard:"",class:"wayland_shared_library"},
 Origin{elf:"libnspr4.so",source:"config/external/nspr/pr/moz.build",anchor:"SharedLibrary(\"nspr4\")",guard:"",class:"conditional_nspr_shared_library"},
 Origin{elf:"libnss3.so",source:"security/nss/lib/nss/manifest.mn",anchor:"LIBRARY_NAME = nss",guard:"",class:"nss_make_manifest"},
 Origin{elf:"libnssutil3.so",source:"security/nss/lib/util/manifest.mn",anchor:"LIBRARY_NAME = nssutil",guard:"",class:"nss_make_manifest"},
 Origin{elf:"libonnxruntime.so",source:"toolkit/components/ml/moz.build",anchor:"FINAL_TARGET_FILES += [\"%\" + CONFIG[\"ONNX_RUNTIME\"]]",guard:"if CONFIG[\"ONNX_RUNTIME\"]:",class:"conditional_external_ml_file"},
 Origin{elf:"libplc4.so",source:"config/external/nspr/libc/moz.build",anchor:"SharedLibrary(\"plc4\")",guard:"",class:"conditional_nspr_shared_library"},
 Origin{elf:"libplds4.so",source:"config/external/nspr/ds/moz.build",anchor:"SharedLibrary(\"plds4\")",guard:"",class:"conditional_nspr_shared_library"},
 Origin{elf:"libsmime3.so",source:"security/nss/lib/smime/manifest.mn",anchor:"LIBRARY_NAME = smime",guard:"",class:"nss_make_manifest"},
 Origin{elf:"libsoftokn3.so",source:"security/nss/lib/softoken/manifest.mn",anchor:"LIBRARY_NAME = softokn",guard:"",class:"nss_make_manifest"},
 Origin{elf:"libssl3.so",source:"security/nss/lib/ssl/manifest.mn",anchor:"LIBRARY_NAME = ssl",guard:"",class:"nss_make_manifest"},
 Origin{elf:"libxul.so",source:"toolkit/library/moz.build",anchor:"SHARED_LIBRARY_NAME = \"xul\"",guard:"",class:"core_gecko_shared_library"},
 Origin{elf:"pingsender",source:"toolkit/components/telemetry/pingsender/moz.build",anchor:"GeckoProgram(\"pingsender\", linkage=None)",guard:"if CONFIG[\"OS_TARGET\"] != \"Android\":",class:"guarded_telemetry_program"},
 Origin{elf:"updater",source:"toolkit/mozapps/update/updater/moz.build",anchor:"Program(\"updater\")",guard:"",class:"guarded_update_program"},
 Origin{elf:"vulpra",source:"browser/app/moz.build",anchor:"GeckoProgram(CONFIG[\"MOZ_APP_NAME\"], linkage=browser_linkage)",guard:"",class:"configured_application_name_program"},
 Origin{elf:"vulpra-bin",source:"browser/app/moz.build",anchor:"GeckoProgram(CONFIG[\"MOZ_APP_NAME\"] + \"-bin\", linkage=browser_linkage)",guard:"",class:"configured_alternate_application_program"}
];

fn valid_name(n:&str)->bool{
 !n.is_empty()&&n.len()<=111&&n.bytes().all(|b|b.is_ascii_alphanumeric()||b"._+-".contains(&b))
}
fn walk(dir:&Path,depth:usize,entries:&mut Vec<PathBuf>)->Result<(),String>{
 if depth>6{return Err("unexpected original package depth".into())}
 for e in fs::read_dir(dir).map_err(|_|"cannot read original package directory")?{
  let p=e.map_err(|_|"malformed original entry")?.path();
  let m=fs::symlink_metadata(&p).map_err(|_|"inaccessible original entry")?;
  if m.file_type().is_dir(){walk(&p,depth+1,entries)?;continue}
  if !m.file_type().is_file()||m.len()<4{continue}
  let mut f=File::open(&p).map_err(|_|"unreadable original ELF candidate")?;
  let mut magic=[0u8;4];f.read_exact(&mut magic).map_err(|_|"bad original candidate")?;
  if magic==[0x7f,b'E',b'L',b'F']{entries.push(p)}
 }
 Ok(())
}
fn analyze(source_root:&Path,package:&Path)->Result<String,String>{
 let mut actual=vec![];walk(package,0,&mut actual)?;
 if actual.len()!=28||ORIGINS.len()!=28{return Err("expected exact 28 original compiled ELF members and 28 source mappings".into())}
 let mut files=BTreeSet::new();
 for p in actual{
  let n=p.file_name().and_then(|s|s.to_str()).ok_or("unrepresentable ELF name")?;
  if !valid_name(n)||!files.insert(n.to_owned()){return Err("duplicate or unsafe packaged ELF basename".into())}
 }
 let mut declared=BTreeSet::new();
 let mut rows=BTreeMap::new();
 for o in ORIGINS{
  if !valid_name(o.elf)||!declared.insert(o.elf)||!files.contains(o.elf){return Err("an ELF source declaration is missing/duplicated".into())}
  let p=source_root.join(o.source);
  let content=fs::read_to_string(&p).map_err(|_|format!("pinned source build manifest missing: {}",o.source))?;
  let matches=content.match_indices(o.anchor).collect::<Vec<_>>();
  if matches.len()!=1{return Err(format!("source origin anchor missing or ambiguous for {}",o.elf))}
  if !o.guard.is_empty()&&!content.contains(o.guard){return Err(format!("source guard missing for {}",o.elf))}
  let line=content[..matches[0].0].bytes().filter(|b|*b==b'\n').count()+1;
  rows.insert(o.elf,format!(
   "    \"{}\":{{\"source_manifest\":\"{}\",\"anchor_line\":{},\"declaration_class\":\"{}\",\"guard_present\":{}}}",
   o.elf,o.source,line,o.class,!o.guard.is_empty()
  ));
 }
 if declared!=files{return Err("pinned original package ELF files differ from origin crosswalk".into())}
 let descriptions=rows.values().cloned().collect::<Vec<_>>().join(",\n");
 Ok(format!(concat!(
  "{{\n \"schema_version\":1,\n \"status\":\"all_original_28_elf_source_manifest_declarations_crosswalked\",\n",
  " \"original_source_commit\":\"{}\",\n \"original_archive_sha256\":\"{}\",\n",
  " \"original_regular_elf_count\":28,\n \"source_manifest_anchor_matches\":28,\n",
  " \"source_manifest_declaration_classes_only\":true,\n",
  " \"nss_subbuilds_separately_anchored\":true,\n",
  " \"config_guards_not_evaluated\":true,\n",
  " \"generated_ninja_or_linker_ownership_not_proven\":true,\n",
  " \"all_feature_bundle_reachability_not_proven\":true,\n",
  " \"no_browser_profile_or_production_mutation\":true,\n",
  " \"source_removal_authorized\":false,\n \"m3_sixth_gate_closed\":false,\n",
  " \"per_original_elf\":{{\n{}\n }}\n}}\n"
 ),SOURCE,ARCHIVE,descriptions))
}
fn main(){
 let args=env::args().collect::<Vec<_>>();
 if args.len()!=4{eprintln!("Expected ORIGINAL_SOURCE_ROOT ORIGINAL_PACKAGE_ROOT SANITIZED_OUTPUT");std::process::exit(2)}
 match analyze(Path::new(&args[1]),Path::new(&args[2])){
  Ok(report)=>{
   if fs::write(&args[3],report).is_err(){eprintln!("FAIL: cannot write sanitized manifest");std::process::exit(1)}
   println!("PASS: all 28 source-pinned original ELF names matched exact build declaration anchors");
  }
  Err(e)=>{eprintln!("FAIL: original ELF source build declaration crosswalk: {e}");std::process::exit(1)}
 }
}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn exact_original_inventory_properties(){
  assert_eq!(ORIGINS.len(),28);
  let names=ORIGINS.iter().map(|x|x.elf).collect::<BTreeSet<_>>();
  assert_eq!(names.len(),28);
  assert!(names.contains("libxul.so")&&names.contains("libsoftokn3.so")&&names.contains("vulpra-bin"));
  assert!(ORIGINS.iter().all(|x|valid_name(x.elf)&&!x.source.is_empty()&&!x.anchor.is_empty()));
 }
}
