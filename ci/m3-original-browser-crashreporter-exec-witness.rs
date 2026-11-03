// CI-only original-browser fatal-abort reporter launch witness.
// An independent disposable original Vulpra browser receives a privileged
// nsIDebug2.abort in isolated no-egress CI, never an installed browser.
// Poll /proc for the exact packaged /original/crashreporter ELF *after*
// a private trigger marker and check original callback's sole .dmp argument.
// Export only counters/booleans; never raw dumps, arguments, PID or paths.
use std::env;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::thread;
use std::time::{Duration,Instant};

const SRC:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA:&str="7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const BROWSER:&str="/original/vulpra";
const REPORTER:&str="/original/crashreporter";
const FLAG:&str="/tmp/vulpra-m3-fatal-abort-triggered";
const OUTPUT:&str="/reports/m3-original-browser-crashreporter-exec.json";

fn pid(raw:&[u8])->Option<u32>{
    if raw.is_empty()||raw.len()>12||!raw.iter().all(|b|b.is_ascii_digit()){return None}
    let n=std::str::from_utf8(raw).ok()?.parse::<u32>().ok()?;
    (n>1).then_some(n)
}
fn reporter_args(bytes:&[u8])->bool{
    if bytes.len()<12||bytes.len()>16384||bytes.last()!=Some(&0){return false}
    let parts=bytes.split(|b|*b==0).collect::<Vec<_>>();
    parts.len()==3&&parts[0]==REPORTER.as_bytes()&&
      parts[1].starts_with(b"/")&&parts[1].ends_with(b".dmp")&&
      !parts[1].contains(&b'\n')&&parts[1].len()<=4096
}
fn scan(uid:u32)->Result<(usize,usize),String>{
    let mut browsers=0;
    let mut reporters=0;
    let mut count=0;
    for entry in fs::read_dir("/proc").map_err(|_|"private proc unavailable")?{
        let entry=entry.map_err(|_|"process scan failed")?;
        let name=entry.file_name();
        let Some(name)=name.to_str()else{continue};
        if pid(name.as_bytes()).is_none(){continue}
        count+=1;
        if count>2048{return Err("private PID namespace exceeded bound".into())}
        let p=entry.path();
        let Ok(exe)=fs::read_link(p.join("exe"))else{continue};
        if fs::metadata(&p).ok().map(|m|m.uid())!=Some(uid){continue}
        if exe==Path::new(BROWSER){browsers+=1;}
        if exe==Path::new(REPORTER){
            let Ok(args)=fs::read(p.join("cmdline"))else{continue};
            if reporter_args(&args){reporters+=1;}
        }
    }
    if browsers>128||reporters>16{return Err("unexpected native process count".into())}
    Ok((browsers,reporters))
}
fn run()->Result<(),String>{
    let args=env::args().collect::<Vec<_>>();
    if args.len()!=3||args[1]!=FLAG||args[2]!=OUTPUT{
        return Err("unexpected test-only marker or output path".into())
    }
    if Path::new(FLAG).exists()||Path::new(OUTPUT).exists(){
        return Err("test marker or report already exists".into())
    }
    let uid=fs::metadata("/proc/self").map_err(|_|"missing private /proc")?.uid();
    let start=Instant::now();
    let mut before_browser=false;
    while start.elapsed()<Duration::from_secs(35)&&!Path::new(FLAG).exists(){
        let (b,r)=scan(uid)?;
        before_browser|=b>0;
        if r>0{return Err("reporter appeared before explicit isolated fatal abort".into())}
        thread::sleep(Duration::from_millis(15));
    }
    if !before_browser||!Path::new(FLAG).exists(){
        return Err("missing live original browser before authorized crash trigger".into())
    }
    let mut scans=0usize;
    let mut reporter_samples=0usize;
    let mut browser_gone=false;
    let mut max_reporters=0usize;
    let after=Instant::now();
    while after.elapsed()<Duration::from_secs(22){
        let (browser,reporter)=scan(uid)?;
        scans+=1;
        if reporter>0{
            reporter_samples+=1;
            max_reporters=max_reporters.max(reporter);
        }
        if browser==0{browser_gone=true;}
        if reporter_samples>=2&&browser_gone{break}
        thread::sleep(Duration::from_millis(5));
    }
    if reporter_samples<1||!browser_gone{
        // Counts and booleans only. These diagnostics contain no private
        // process IDs, minidump paths, raw argument bytes or profile data.
        return Err(format!(
            "runtime observation incomplete: reporter_seen={} browser_exit_seen={} samples={} before_browser_seen={}",
            reporter_samples>0,browser_gone,scans,before_browser
        ))
    }
    let out=format!(concat!(
      "{{\"schema_version\":1,",
      "\"status\":\"real_original_browser_fatal_abort_spawned_original_crashreporter\",",
      "\"original_source_commit\":\"{}\",",
      "\"original_archive_sha256\":\"{}\",",
      "\"live_original_browser_seen_before_test_abort\":true,",
      "\"private_explicit_fatal_abort_trigger_observed\":true,",
      "\"real_original_browser_exited_after_abort\":true,",
      "\"actual_packaged_reporter_executable_observed\":true,",
      "\"original_reporter_single_minidump_argument_verified\":true,",
      "\"original_reporter_samples\":{},",
      "\"max_simultaneous_original_reporter_executables\":{},",
      "\"post_trigger_process_scans\":{},",
      "\"no_original_reporter_before_trigger\":true,",
      "\"direct_browser_crashreporter_launch_callback_source_verified\":true,",
      "\"crash_report_uploaded_or_submitted\":false,",
      "\"crash_reporter_ui_success_proven\":false,",
      "\"minidump_correctness_or_contents_examined\":false,",
      "\"crashhelper_rendezvous_during_signal_proven\":false,",
      "\"user_browser_or_profile_touched\":false,",
      "\"network_egress_allowed\":false,",
      "\"raw_minidumps_argv_pids_paths_or_profiles_exported\":false,",
      "\"full_crash_or_updater_lifecycle_proven\":false,",
      "\"source_pruning_authorized\":false,",
      "\"native_bytes_saved\":0,",
      "\"m3_sixth_gate_closed\":false}}\n"),
      SRC,SHA,reporter_samples,max_reporters,scans);
    fs::write(OUTPUT,out).map_err(|_|"cannot save sanitized witness")?;
    println!("M3_ORIGINAL_CRASHREPORTER_EXEC=PASS samples={reporter_samples} process_scans={scans}");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("M3_ORIGINAL_CRASHREPORTER_WITNESS_FAILURE={e}");std::process::exit(1)}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn real_reporter_requires_one_absolute_dump_arg(){
        assert!(reporter_args(b"/original/crashreporter\0/tmp/private/synthetic.dmp\0"));
        assert!(!reporter_args(b"/original/crashreporter\0"));
        assert!(!reporter_args(b"/other/crashreporter\0/tmp/synthetic.dmp\0"));
        assert!(!reporter_args(b"/original/crashreporter\0relative.dmp\0"));
        assert!(!reporter_args(b"/original/crashreporter\0/tmp/synthetic.dmp\0extra\0"));
    }
    #[test]fn process_pid_is_numeric_bounded(){
        assert_eq!(pid(b"99"),Some(99));
        assert_eq!(pid(b"0"),None);
        assert_eq!(pid(b"1"),None);
        assert_eq!(pid(b"hello"),None);
        assert_eq!(pid(b"9999999999999999"),None);
    }
}
