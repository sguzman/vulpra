// Bounded source guard for a combined 4-opt-in *experiment*, not the default.
// Compares exact build options and Linux feature switches without evaluating
// arbitrary moz.build source, writing profiles, or authorizing removals.
use std::{collections::BTreeSet,env,fs};
const FLAGS:[(&str,&str);4]=[
 ("VULPRA_EXPERIMENT_NO_NORMANDY","MOZ_NORMANDY"),
 ("VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS","VULPRA_NO_ASROUTER_PROMOS"),
 ("VULPRA_EXPERIMENT_NO_NEWTAB_ADSFEED","VULPRA_NO_NEWTAB_ADSFEED"),
 ("VULPRA_EXPERIMENT_NO_NEWTAB_PROMOCARD","VULPRA_NO_NEWTAB_PROMOCARD"),
];
fn normalized(s:&str)->Vec<String>{
 s.lines().map(str::trim).filter(|x|!x.is_empty()&&!x.starts_with('#')&&!x.starts_with("mk_add_options MOZ_OBJDIR=")&&!x.starts_with("export VULPRA_EXPERIMENT_NO_")).map(str::to_owned).collect()
}
fn validate(base:&str,lean:&str,source:&str)->Result<(),String>{
 if base.contains("export VULPRA_EXPERIMENT_NO_"){
  return Err("normal build toggles experiments".into())
 }
 if !base.contains("obj-vulpra-linux-m3-baseline")||!lean.contains("obj-vulpra-linux-m3-combined-lean"){
  return Err("native build output isolation contract absent".into())
 }
 if normalized(base)!=normalized(lean){
  return Err("combined lean changes ordinary Linux build options".into())
 }
 let mut chosen=BTreeSet::new();
 for line in lean.lines(){
  let v=line.trim();
  if v.starts_with("export "){
   let Some((key,value))=v.strip_prefix("export ").and_then(|v|v.split_once('='))else{
    return Err("invalid exported opt-in flag".into())
   };
   if !FLAGS.iter().any(|x|x.0==key)||value!="1"||!chosen.insert(key){
    return Err("unsupported or duplicate combined experiment switch".into())
   }
  }
 }
 if chosen.len()!=4{return Err("missing one of four combined experiment switches".into())}
 for (flag,config) in FLAGS{
  let needle=format!("env=\"{flag}\"");
  if source.matches(&needle).count()!=1{return Err(format!("missing/ambiguous source switch {flag}"))}
  if flag!="VULPRA_EXPERIMENT_NO_NORMANDY"{
   let needle=format!("set_config(\"{config}\",");
   if source.matches(&needle).count()!=1{return Err(format!("missing original config guard {config}"))}
  }
 }
 if !source.contains("imply_option(\"MOZ_SERVICES_SYNC\", True)")||
  !source.contains("imply_option(\"MOZ_DEVTOOLS\", \"all\")")||
  !source.contains("imply_option(\"MOZ_PROFILE_MIGRATOR\", True)")||
  !source.contains("imply_option(\"MOZ_NORMANDY\", True, when=vulpra_include_normandy)"){
  return Err("protected normal browser integration guard absent".into())
 }
 Ok(())
}
fn run()->Result<(),String>{
 let args=env::args().collect::<Vec<_>>();
 if args.len()!=5{return Err("expected BASELINE_MOZCONFIG LEAN_MOZCONFIG PINNED_BROWSER_MOZ_CONFIG SANITIZED_JSON".into())}
 let base=fs::read_to_string(&args[1]).map_err(|_|"baseline mozconfig not readable")?;
 let lean=fs::read_to_string(&args[2]).map_err(|_|"combined lean mozconfig not readable")?;
 let source=fs::read_to_string(&args[3]).map_err(|_|"pinned source browser/moz.configure missing")?;
 validate(&base,&lean,&source)?;
 fs::write(&args[4],concat!(
 "{\n \"schema_version\":1,\n",
 " \"status\":\"combined_four_opt_in_source_configuration_guarded\",\n",
 " \"normal_base_unchanged\":true,\n",
 " \"combined_isolated_objdir\":true,\n",
 " \"explicit_experiment_flags\":4,\n",
 " \"original_browser_config_guards_present\":true,\n",
 " \"protected_sync_devtools_migrator_unchanged\":true,\n",
 " \"native_compilation_or_runtime_tested\":false,\n",
 " \"combined_size_saving_verified\":false,\n",
 " \"default_browser_changed\":false,\n",
 " \"source_removal_authorized\":false,\n",
 " \"m3_sixth_gate_closed\":false\n}\n"
 )).map_err(|_|"cannot write safe combined source report")?;
 println!("PASS: combined 4-opt-in build options source-verified, normal baseline unchanged");
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: bounded combined lean source guard: {e}");std::process::exit(1)}}
#[cfg(test)]
mod tests{
 use super::*;
 fn base()->&'static str{"mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux-m3-baseline\nac_add_options --disable-tests\n"}
 fn lean()->String{
  format!("mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux-m3-combined-lean\nac_add_options --disable-tests\n{}",FLAGS.iter().map(|(v,_)|format!("export {v}=1\n")).collect::<String>())
 }
 fn src()->String{
  format!("{}imply_option(\"MOZ_SERVICES_SYNC\", True)\nimply_option(\"MOZ_DEVTOOLS\", \"all\")\nimply_option(\"MOZ_PROFILE_MIGRATOR\", True)\nimply_option(\"MOZ_NORMANDY\", True, when=vulpra_include_normandy)\n{}",
   FLAGS.iter().map(|(v,_)|format!("env=\"{v}\"\n")).collect::<String>(),
   FLAGS.iter().skip(1).map(|(_,c)|format!("set_config(\"{c}\", xyz)\n")).collect::<String>())
 }
 #[test]fn accepts_only_matching_four_guarded_flags(){
  assert!(validate(base(),&lean(),&src()).is_ok());
  assert!(validate(base(),&lean().replace("export VULPRA_EXPERIMENT_NO_NORMANDY=1\n",""),&src()).is_err());
  assert!(validate(base(),&format!("{}export UNSAFE=1\n",lean()),&src()).is_err());
  assert!(validate(base(),&lean().replace("=1\n","=0\n"),&src()).is_err());
  assert!(validate(base(),&lean().replace("ac_add_options --disable-tests","ac_add_options --disable-sandbox"),&src()).is_err());
  assert!(validate(base(),&lean(),&src().replace("imply_option(\"MOZ_DEVTOOLS\", \"all\")","")).is_err());
 }
}
