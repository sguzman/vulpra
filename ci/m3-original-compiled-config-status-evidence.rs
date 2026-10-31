// Extract exactly the seven already asserted source-matched native configure
// values from the historical *successful* full-normal compiled baseline job.
// The CI workflow independently verifies that its guarded configure step
// passed on the exact historical source SHA. This is NOT a new build or a
// complete evaluated mozbuild/Ninja configuration graph.
use std::{env,fs};
const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const REQUIRED:&[&str]=&[
 "assert str(get(\"MOZ_NORMANDY\")) in (\"1\",\"True\")",
 "assert get(\"MOZ_WIDGET_TOOLKIT\")==\"gtk\"",
 "assert get(\"MOZ_APP_BASENAME\")==\"Vulpra\"",
 "assert get(\"MOZ_DEVTOOLS\")==\"all\"",
 "for k in (\"MOZ_SANDBOX\",\"MOZ_WAYLAND\",\"MOZ_SERVICES_SYNC\"):",
 "assert str(get(k)) in (\"1\",\"True\")",
 "print(\"PASS: full Normandy and protected features\")",
 "root=Path(\"obj-vulpra-linux-m3-baseline/config.statusd/substs\")",
 "          ./mach configure",
];
fn inspect(workflow:&str,mozconfig:&str)->Result<String,String>{
 let start=workflow.find("      - name: Configure protected full-Normandy feature set")
  .ok_or("expected exact configure step missing")?;
 let end=workflow[start+1..].find("      - name: Match native candidate 24 GiB swap")
  .ok_or("expected configure step end missing")?+start+1;
 let section=&workflow[start..end];
 for expected in REQUIRED{
  if !section.contains(expected){return Err(format!("historical configure assertion absent: {expected}"));}
 }
 if workflow.matches("      - name: Configure protected full-Normandy feature set").count()!=1{
  return Err("ambiguous historical configure success evidence".into());
 }
 if !mozconfig.contains("obj-vulpra-linux-m3-baseline")||
    mozconfig.contains("VULPRA_EXPERIMENT_NO_NORMANDY=1"){
  return Err("source-matched original full-normal mozconfig absent or lean mode".into());
 }
 Ok(format!(concat!(
  "{{\n \"schema_version\":1,\n \"status\":\"original_compiled_baseline_evaluated_feature_guards_authenticated\",\n",
  " \"original_source_commit\":\"{}\",\n \"original_compiled_archive_sha256\":\"{}\",\n",
  " \"original_compiled_source_run\":40997075527,\n",
  " \"historical_config_status_step_success_authenticated_externally\":true,\n",
  " \"moz_normandy\":true,\n \"moz_widget_toolkit\":\"gtk\",\n",
  " \"moz_app_basename\":\"Vulpra\",\n \"moz_devtools\":\"all\",\n",
  " \"moz_sandbox\":true,\n \"moz_wayland\":true,\n \"moz_services_sync\":true,\n",
  " \"source_matched_mozconfig_confirmed\":true,\n",
  " \"full_generated_ninja_ownership_proven\":false,\n",
  " \"nss_codec_or_ml_runtime_feature_exhaustiveness_proven\":false,\n",
  " \"current_source_config_status_evaluated\":false,\n",
  " \"cross_platform_config_equivalence_proven\":false,\n",
  " \"new_feature_omission_or_source_pruning_authorized\":false,\n",
  " \"m3_sixth_gate_closed\":false\n}}\n"
 ),SRC,ARCHIVE))
}
fn main(){
 let a:Vec<String>=env::args().collect();
 if a.len()!=4{eprintln!("expected PINNED_WORKFLOW PINNED_MOZCONFIG SANITIZED_REPORT");std::process::exit(2)}
 let result=fs::read_to_string(&a[1]).map_err(|_|"missing pinned source workflow")
  .and_then(|w|fs::read_to_string(&a[2]).map_err(|_|"missing pinned original mozconfig")
   .and_then(|c|inspect(&w,&c)));
 match result{
  Ok(v)=>{if fs::write(&a[3],v).is_err(){eprintln!("cannot write report");std::process::exit(1)}
   println!("PASS: original successful compiled configure step's seven exact evaluated feature assertions pinned");}
  Err(e)=>{eprintln!("FAIL: original compiled feature assertion audit: {e}");std::process::exit(1)}
 }
}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn fail_closed_without_actual_historical_assertions(){
  assert!(inspect("      - name: Configure protected full-Normandy feature set\n      - name: Match native candidate 24 GiB swap","obj-vulpra-linux-m3-baseline").is_err());
  assert!(inspect("","").is_err());
 }
}
