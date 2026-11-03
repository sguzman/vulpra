// CI-only observation, not an updater invocation. The exact original browser
// is running in a disposable no-egress Arch namespace with its original package
// mount read-only. Watch for any /original/updater executable while the browser
// independently queries only source-vetted read-only XPCOM state getters.
// Per-sample nonobservation is NOT proof of complete update dependency closure.
use std::env;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::thread;
use std::time::{Duration, Instant};

const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const BROWSER:&str="/original/vulpra";
const UPDATER:&str="/original/updater";
const FINISH:&str="/tmp/vulpra-m3-updater-readonly-query-complete";
const OUTPUT:&str="/reports/m3-original-browser-updater-no-exec-samples.json";

fn numeric_pid(raw:&[u8])->Option<u32>{
    if raw.is_empty()||raw.len()>12||!raw.iter().all(|b|b.is_ascii_digit()){return None}
    let n=std::str::from_utf8(raw).ok()?.parse::<u32>().ok()?;
    (n>1).then_some(n)
}
fn scan(uid:u32)->Result<(usize,usize),String>{
    let mut browsers=0usize;
    let mut updaters=0usize;
    let mut inspected=0usize;
    for entry in fs::read_dir("/proc").map_err(|_|"cannot scan private proc")?{
        let entry=entry.map_err(|_|"private proc listing failed")?;
        let name=entry.file_name();
        let Some(name)=name.to_str()else{continue};
        if numeric_pid(name.as_bytes()).is_none(){continue}
        inspected+=1;
        if inspected>2048{return Err("private process bound exceeded".into())}
        let base=entry.path();
        let Ok(exe)=fs::read_link(base.join("exe"))else{continue};
        if fs::metadata(&base).ok().map(|m|m.uid())!=Some(uid){continue}
        if exe==Path::new(BROWSER){browsers+=1;}
        if exe==Path::new(UPDATER){updaters+=1;}
    }
    if browsers>128||updaters>32{return Err("unexpected original process count".into())}
    Ok((browsers,updaters))
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=3||args[1]!=FINISH||args[2]!=OUTPUT{
        return Err("invalid disposable test completion marker or output path".into())
    }
    if Path::new(FINISH).exists()||Path::new(OUTPUT).exists(){
        return Err("refusing stale observer marker or output file".into())
    }
    let uid=fs::metadata("/proc/self").map_err(|_|"no private proc")?.uid();
    let start=Instant::now();
    let mut samples=0usize;
    let mut browser_samples=0usize;
    let mut original_updater_samples=0usize;
    let mut max_browser=0usize;
    let mut query_completed=false;
    while start.elapsed()<Duration::from_secs(40){
        let (b,u)=scan(uid)?;
        samples+=1;
        if b>0{browser_samples+=1;}
        if u>0{original_updater_samples+=1;}
        max_browser=max_browser.max(b);
        if Path::new(FINISH).exists(){
            query_completed=true;
            // The status marker must not turn off /proc monitoring before
            // the witnessed actual browser has remained live long enough.
            if browser_samples>=8&&samples>=12{break}
        }
        thread::sleep(Duration::from_millis(100));
    }
    if !query_completed||browser_samples<8||max_browser<1||original_updater_samples!=0{
        return Err(format!("insufficient original browser read-only samples: marker={} browser_sampled={} updater_observed={}",
            query_completed,browser_samples>=8,original_updater_samples>0))
    }
    let output=format!(concat!(
      "{{\"schema_version\":1,",
      "\"status\":\"original_browser_update_service_readonly_updater_process_sampling\",",
      "\"source_commit\":\"{}\",",
      "\"archive_sha256\":\"{}\",",
      "\"total_private_process_samples\":{},",
      "\"live_original_browser_samples\":{},",
      "\"max_simultaneously_live_original_browser_executables\":{},",
      "\"actually_observed_original_updater_executable_samples\":{},",
      "\"original_browser_read_only_query_completed\":true,",
      "\"original_updater_execution_observed_in_bounded_samples\":false,",
      "\"not_seen_in_samples_does_not_prove_unused\":true,",
      "\"no_install_download_stage_or_update_check_method_invoked\":true,",
      "\"private_network_disabled\":true,",
      "\"original_browser_package_mounted_read_only\":true,",
      "\"no_user_profiles_touched\":true,",
      "\"raw_pids_paths_or_private_profile_exported\":false,",
      "\"complete_updater_dependency_closure_proven\":false,",
      "\"source_pruning_authorized\":false,",
      "\"native_bytes_saved\":0,",
      "\"m3_sixth_gate_closed\":false}}\n"),
      SOURCE,ARCHIVE,samples,browser_samples,max_browser,original_updater_samples);
    fs::write(OUTPUT,output).map_err(|_|"cannot save original updater observer summary")?;
    println!("M3_ORIGINAL_BROWSER_UPDATER_PASSIVE=PASS browser_samples={browser_samples} updater_samples=0");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("M3_ORIGINAL_UPDATER_READONLY_OBSERVER_ERROR={e}");std::process::exit(1)}}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]fn strict_pid_shape(){
        assert_eq!(numeric_pid(b"10"),Some(10));
        assert_eq!(numeric_pid(b"1"),None);
        assert_eq!(numeric_pid(b"not-a-pid"),None);
        assert_eq!(numeric_pid(b"123456789012345"),None);
    }
    #[test]fn original_paths_are_not_host_updater_paths(){
        assert_ne!(BROWSER,UPDATER);
        assert_ne!(Path::new(UPDATER),Path::new("/usr/bin/updater"));
        assert_ne!(Path::new(BROWSER),Path::new("/usr/bin/firefox"));
    }
}
