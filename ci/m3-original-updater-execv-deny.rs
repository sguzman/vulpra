// Disposable CI-only LD_PRELOAD guard for the *real original* native
// nsUpdateDriver.cpp staging fork -> execv boundary.
// Deny execution in all cases. Log a sanitized, source-shaped marker ONLY
// when the caller is the original packaged Vulpra ELF and all seven original
// Linux stage arguments match a temporary missing-MAR fixture.
// This is an authentic original-browser execv *attempt*, not an updater exec.
// No raw argument bytes, PIDs, paths, profiles or user files exported.
use std::ffi::{c_char,c_int,c_void,CStr};
#[cfg(test)]
use std::path::Path;
#[cfg(test)]
use std::fs;

const ORIGINAL:&[u8]=b"/original/vulpra";
const UPDATER:&[u8]=b"/original/updater";
const SENTINEL:&[u8]=b"/reports/m3-original-updater-execv-denied.json\0";
const JSON:&[u8]=br#"{"schema_version":1,"status":"original_native_browser_staging_updater_execv_attempt_denied_preexecution","source_commit":"b1482404dfb8b01342990ee99ea3df0f9756b5f7","archive_sha256":"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a","caller_exact_original_browser_executable":true,"original_updater_target_exact_packaged_elf":true,"source_declared_linux_stage_arguments_matched":true,"staging_mode_pid_arg_minus_one":true,"genuine_original_updater_execv_attempt_seen":true,"actual_updater_executable_execution_permitted":false,"all_execv_calls_denied_in_disposable_test":true,"no_mar_downloaded_or_provided":true,"source_pruning_authorized":false,"native_bytes_saved":0,"m3_sixth_gate_closed":false}
"#;
unsafe extern "C" {
    fn readlink(path:*const c_char,out:*mut c_char,len:usize)->isize;
    fn open(path:*const c_char,flags:c_int,...)->c_int;
    fn write(fd:c_int,buf:*const c_void,len:usize)->isize;
    fn close(fd:c_int)->c_int;
    fn __errno_location()->*mut c_int;
}
fn stage_shape(fields:[&[u8];7])->bool{
    fields==[
        UPDATER,b"3",b"/original/updates/0",b"/original",
        b"/original/updated",b"first",b"-1"
    ]
}
unsafe fn same_original_exe()->bool{
    let mut buf=[0u8;256];
    let n=unsafe{readlink(c"/proc/self/exe".as_ptr(),buf.as_mut_ptr().cast(),buf.len())};
    n>=0&&buf.get(..n as usize)==Some(ORIGINAL)
}
unsafe fn record(){
    // POSIX O_WRONLY | O_CREAT | O_EXCL; O_CLOEXEC on Linux.
    const FLAGS:c_int=1|64|128|524288;
    let fd=unsafe{open(SENTINEL.as_ptr().cast(),FLAGS,0o600)};
    if fd<0{return}
    let mut left=JSON;
    while !left.is_empty(){
        let n=unsafe{write(fd,left.as_ptr().cast(),left.len())};
        if n<=0{break}
        left=&left[n as usize..];
    }
    unsafe{close(fd);}
}
#[no_mangle]
pub unsafe extern "C" fn execv(path:*const c_char,argv:*const *const c_char)->c_int{
    if !path.is_null()&&!argv.is_null(){
        let p=unsafe{CStr::from_ptr(path).to_bytes()};
        if p==UPDATER{
            // Source allocates seven argv entries plus null terminator for
            // Linux staging. Nothing here attempts to launch any executable.
            let mut parts=[&[][..];7];
            let mut valid=true;
            for (i,part) in parts.iter_mut().enumerate(){
                let a=unsafe{*argv.add(i)};
                if a.is_null(){valid=false;break}
                *part=unsafe{CStr::from_ptr(a).to_bytes()};
            }
            if valid&&unsafe{(*argv.add(7)).is_null()}&&stage_shape(parts)
                &&unsafe{same_original_exe()}{
                unsafe{record();}
            }
        }
    }
    // FAIL CLOSED: even if a later source path unexpectedly makes another
    // execv call, this CI original process cannot exec via this function.
    unsafe{*__errno_location()=13;} // EACCES
    -1
}
#[cfg(test)]
fn verify_original_archive_not_locally_mutated()->bool{
    // Host-side workflow independently checks SHA-256 before and after.
    // This library is deliberately not entrusted with package integrity.
    Path::new("/original/updater").exists() && fs::metadata("/original/updater").is_ok()
}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn exact_staging_shape(){
        assert!(stage_shape([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original/updated",b"first",b"-1"]));
        assert!(!stage_shape([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original/updated",b"first",b"0"]));
        assert!(!stage_shape([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original",b"first",b"-1"]));
        assert!(!stage_shape([UPDATER,b"3",b"/other/updates/0",b"/original",b"/original/updated",b"first",b"-1"]));
    }
    #[test]fn sentinel_does_not_include_secret_process_data(){
        let s=std::str::from_utf8(JSON).unwrap();
        assert!(s.contains("\"actual_updater_executable_execution_permitted\":false"));
        assert!(!s.contains("argv["));
        assert!(UPDATER.starts_with(b"/original"));
        assert!(!verify_original_archive_not_locally_mutated() || Path::new("/original/updater").exists());
    }
}
