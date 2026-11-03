// CI-only evidence: genuine original Vulpra creates its own original packaged
// crashhelper via the Linux crash_helper_client::spawn_crash_helper path.
// The original helper double-forks, so its PPid is not the browser PID.
// Its argv[1] is the launching browser PID, as in the immutable original
// Rust source. Validate that numeric PID against a *live original browser
// executable* in the same isolated container PID namespace.
// Never export the numeric PIDs, argument bytes, paths or raw /proc data.
use std::env;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::thread;
use std::time::{Duration,Instant};

const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const HELPER:&str="/original/crashhelper";
const OUT:&str="/reports/m3-original-browser-crashhelper-activation.json";
const MAX_PROCESS_ENTRIES:usize=2048;

fn original_browser(path:&Path)->bool {
    matches!(path.to_str(),Some("/original/vulpra")|Some("/original/vulpra-bin"))
}
fn numeric_pid(raw:&[u8])->Option<u32>{
    if raw.is_empty()||raw.len()>12||!raw.iter().all(u8::is_ascii_digit){return None;}
    let pid=std::str::from_utf8(raw).ok()?.parse::<u32>().ok()?;
    (pid>1).then_some(pid)
}
fn helper_launcher_pid(bytes:&[u8])->Option<u32>{
    if bytes.is_empty()||bytes.len()>16384||*bytes.last()?!=0{return None}
    let v:Vec<&[u8]>=bytes.split(|c|*c==0).collect();
    // Original Linux posix_spawn: executable, parent pid, breakpad data,
    // minidump path, IPC endpoint, build id. Their contents are never logged.
    if v.len()!=7||v[0]!=HELPER.as_bytes() ||
      v[2..6].iter().any(|s|s.is_empty()){return None}
    numeric_pid(v[1])
}
fn is_packaged_process(proc:&Path,expected:&str)->bool{
    fs::read_link(proc.join("exe")).ok().as_deref()==Some(Path::new(expected))
}
fn matching_live_helper(proc:&Path,original_uid:u32)->bool{
    if !is_packaged_process(proc,HELPER){return false}
    if fs::metadata(proc).ok().map(|m|m.uid())!=Some(original_uid){return false}
    let Ok(args)=fs::read(proc.join("cmdline"))else{return false};
    let Some(parent_id)=helper_launcher_pid(&args)else{return false};
    let browser=Path::new("/proc").join(parent_id.to_string());
    let Ok(exe)=fs::read_link(browser.join("exe"))else{return false};
    if !original_browser(&exe){return false}
    fs::metadata(browser).ok().map(|m|m.uid())==Some(original_uid)
}
fn observe_sample(uid:u32)->Result<(usize,usize),String>{
    let mut browser=0usize;
    let mut helper=0usize;
    let mut visited=0usize;
    for entry in fs::read_dir("/proc").map_err(|_|"cannot read private proc")?{
        let entry=entry.map_err(|_|"cannot enumerate process")?;
        let name=entry.file_name();
        let Some(raw)=name.to_str()else{continue};
        if numeric_pid(raw.as_bytes()).is_none(){continue}
        visited+=1;
        if visited>MAX_PROCESS_ENTRIES{return Err("isolated process bound exceeded".into())}
        let process=entry.path();
        let Ok(exe)=fs::read_link(process.join("exe"))else{continue};
        if original_browser(&exe)&&
          fs::metadata(&process).ok().map(|m|m.uid())==Some(uid){
            browser+=1;
        }
        if exe==Path::new(HELPER)&&matching_live_helper(&process,uid){
            helper+=1;
        }
    }
    if browser>128||helper>32{
        return Err("unexpected number of original browser or helper processes".into())
    }
    Ok((browser,helper))
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=3||args[1]!="/original"||args[2]!=OUT{
        return Err("expected /original and strict sanitized report path".into())
    }
    let expected_uid=fs::metadata("/proc/self").map_err(|_|"private proc unavailable")?.uid();
    let start=Instant::now();
    let mut samples=0usize;
    let mut concurrent=0usize;
    let mut confirmed=0usize;
    let mut max_browser=0usize;
    let mut max_helper=0usize;
    while start.elapsed()<Duration::from_secs(18){
        let (b,h)=observe_sample(expected_uid)?;
        if b>0{samples+=1;}
        if b>0&&h>0{
            concurrent+=1;
            confirmed+=h;
        }
        max_browser=max_browser.max(b);
        max_helper=max_helper.max(h);
        if concurrent>=3{break}
        thread::sleep(Duration::from_millis(200));
    }
    if samples==0||concurrent<3||max_browser<1||max_helper<1{
        return Err("no repeated original-browser-owned live crashhelper executable observed".into())
    }
    let output=format!(concat!(
      "{{\"schema_version\":1,",
      "\"status\":\"source_pinned_original_browser_spawned_original_crashhelper_live\",",
      "\"original_source_commit\":\"{}\",",
      "\"original_archive_sha256\":\"{}\",",
      "\"original_browser_observed_sample_count\":{},",
      "\"browser_and_matched_crashhelper_concurrent_samples\":{},",
      "\"max_live_original_browser_executables\":{},",
      "\"max_original_helper_executables_with_live_browser_pid_arg\":{},",
      "\"matching_original_helper_observations\":{},",
      "\"helper_executable_path_exact_original_package\":true,",
      "\"helper_argv_parent_pid_matches_live_original_browser\":true,",
      "\"original_linux_posix_spawn_source_has_double_fork\":true,",
      "\"helper_immediate_kernel_ppid_required\":false,",
      "\"original_browser_crash_handler_enabled_for_test\":true,",
      "\"deliberate_browser_crash_performed\":false,",
      "\"real_crash_report_or_submission_proven\":false,",
      "\"original_updater_execution_proven\":false,",
      "\"raw_pids_paths_argv_or_private_profiles_exported\":false,",
      "\"network_egress_allowed\":false,",
      "\"test_uses_private_weston_and_temporary_profile\":true,",
      "\"full_normal_feature_launch_or_loader_closure_proven\":false,",
      "\"source_pruning_authorized\":false,",
      "\"native_bytes_saved\":0,",
      "\"m3_sixth_gate_closed\":false}}\n"),
      SOURCE,ARCHIVE,samples,concurrent,max_browser,max_helper,confirmed);
    fs::write(OUT,output).map_err(|_|"cannot write sanitized browser helper evidence")?;
    println!("M3_ORIGINAL_BROWSER_CRASHHELPER_LIVE=PASS concurrent_samples={concurrent} helper_observations={confirmed}");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("M3_CRASHHELPER_WITNESS_ERROR={e}");std::process::exit(1)}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn exact_launch_argument_shape(){
        let valid=b"/original/crashhelper\0567\0metadata\0/tmp/private\0socket\0buildid\0";
        assert_eq!(helper_launcher_pid(valid),Some(567));
        assert_eq!(helper_launcher_pid(b"/original/crashhelper\0x\0m\0p\0i\0b\0"),None);
        assert_eq!(helper_launcher_pid(b"/other/crashhelper\0567\0m\0p\0i\0b\0"),None);
        assert_eq!(helper_launcher_pid(b"/original/crashhelper\0567\0m\0p\0i\0b"),None);
    }
    #[test]fn strict_original_executable(){
        assert!(original_browser(Path::new("/original/vulpra")));
        assert!(original_browser(Path::new("/original/vulpra-bin")));
        assert!(!original_browser(Path::new("/usr/bin/firefox")));
        assert!(!original_browser(Path::new("/original/crashhelper")));
    }
    #[test]fn pid_bounds(){
        assert_eq!(numeric_pid(b"12"),Some(12));
        assert_eq!(numeric_pid(b"1"),None);
        assert_eq!(numeric_pid(b"0"),None);
        assert_eq!(numeric_pid(b"12345678901234"),None);
    }
}
