// M3 disposable CI-only original-browser -> real-updater provenance guard.
//
// This is an LD_PRELOAD *interposer*, not an original binary modification.
// It allows exactly one kind of execv: the original compiled Vulpra browser
// attempting source-declared staging of the original packaged updater using
// a deliberately absent-MAR, temporary update fixture. Every other intercepted
// execv fails EACCES. The validated execv is forwarded to real libc execve.
// The same library is inherited into the executed updater. Its ELF loader
// initializer authenticates /proc/self/exe, exact kernel argv and the original
// browser parent executable, recording a second sanitized witness.
// Neither witness contains PIDs, private paths, command lines or dump data.
// Real updater can only write to isolated update/status and empty staging
// mounts; original installed binary tree is mounted read-only; no egress.
use std::ffi::{c_char,c_int,c_void,CStr};

const BROWSER:&[u8]=b"/original/vulpra";
const UPDATER:&[u8]=b"/original/updater";
const PRE:&[u8]=b"/reports/m3-real-browser-updater-pre-exec.json\0";
const POST:&[u8]=b"/reports/m3-real-browser-updater-loader.json\0";
const MAR:&[u8]=b"/original/updates/0/update.mar\0";
const PRE_JSON:&[u8]=br#"{"schema":1,"status":"authentic_original_browser_staging_execv_forwarded","caller_original_browser":true,"exact_original_updater_path":true,"source_declared_seven_argument_stage_shape":true,"staging_pid_arg_negative_one":true,"test_only_missing_mar_confirmed":true,"forward_to_libc_execve_attempted":true,"updater_load_confirmed_by_this_marker":false,"no_other_execv_allowed":true,"native_package_modified":false,"source_pruning_authorized":false,"native_bytes_saved":0}
"#;
const POST_JSON:&[u8]=br#"{"schema":1,"status":"real_original_updater_elf_loaded_from_original_browser_parent","actual_proc_exe_is_original_packaged_updater":true,"kernel_arg_vector_matches_original_source":true,"parent_proc_exe_is_original_browser":true,"browser_execv_intent_marker_preexists":true,"updater_loader_initialized_after_actual_exec":true,"updater_install_success_or_mar_validity_proven":false,"original_install_writable":false,"source_pruning_authorized":false,"native_bytes_saved":0}
"#;
unsafe extern "C" {
    fn readlink(path:*const c_char,out:*mut c_char,len:usize)->isize;
    fn open(path:*const c_char,flags:c_int,...)->c_int;
    fn read(fd:c_int,buf:*mut c_void,len:usize)->isize;
    fn write(fd:c_int,buf:*const c_void,len:usize)->isize;
    fn close(fd:c_int)->c_int;
    fn access(path:*const c_char,mode:c_int)->c_int;
    fn getppid()->c_int;
    fn snprintf(buf:*mut c_char,len:usize,fmt:*const c_char,...)->c_int;
    fn execve(file:*const c_char,argv:*const *const c_char,envp:*const *const c_char)->c_int;
    static mut environ:*mut *mut c_char;
    fn __errno_location()->*mut c_int;
}
fn expected(fields:[&[u8];7])->bool{
    fields==[UPDATER,b"3",b"/original/updates/0",b"/original",
             b"/original/updated",b"first",b"-1"]
}
unsafe fn same_executable(want:&[u8])->bool{
    let mut b=[0u8;256];
    let n=unsafe{readlink(c"/proc/self/exe".as_ptr(),b.as_mut_ptr().cast(),b.len())};
    n>0&&b.get(..n as usize)==Some(want)
}
unsafe fn source_argv(argv:*const *const c_char)->bool{
    if argv.is_null(){return false}
    let mut p=[&[][..];7];
    for (idx,item) in p.iter_mut().enumerate(){
        let ptr=unsafe{*argv.add(idx)};
        if ptr.is_null(){return false}
        let val=unsafe{CStr::from_ptr(ptr).to_bytes()};
        if val.len()>128{return false}
        *item=val;
    }
    (unsafe{(*argv.add(7)).is_null()})&&expected(p)
}
unsafe fn own_kernel_argv()->bool{
    // Read directly from /proc, not a mutable user-space argv pointer.
    const RD:c_int=0|524288; // O_RDONLY | O_CLOEXEC
    let fd=unsafe{open(c"/proc/self/cmdline".as_ptr(),RD)};
    if fd<0{return false}
    let mut b=[0u8;512];
    let n=unsafe{read(fd,b.as_mut_ptr().cast(),b.len())};
    unsafe{close(fd);}
    if n<=0||n as usize>=b.len(){return false}
    let bytes=&b[..n as usize];
    if bytes.last()!=Some(&0){return false}
    let mut items=bytes.split(|v|*v==0);
    let mut fields=[&[][..];7];
    for s in &mut fields{
        let Some(a)=items.next()else{return false};
        if a.is_empty()||a.len()>128{return false}
        *s=a;
    }
    expected(fields)&&items.next()==Some(&[][..])&&items.next().is_none()
}
unsafe fn exact_parent_browser()->bool{
    let ppid=unsafe{getppid()};
    if ppid<=1{return false}
    let mut path=[0i8;80];
    let n=unsafe{snprintf(path.as_mut_ptr(),path.len(),c"/proc/%d/exe".as_ptr(),ppid)};
    if n<=0||n as usize>=path.len(){return false}
    let mut buf=[0u8;256];
    let length=unsafe{readlink(path.as_ptr(),buf.as_mut_ptr().cast(),buf.len())};
    length>0&&buf.get(..length as usize)==Some(BROWSER)
}
unsafe fn write_exclusive(path:&[u8],data:&[u8])->bool{
    const CREATE_EXCLUSIVE:c_int=1|64|128|524288; // WRONLY, CREAT, EXCL, CLOEXEC
    let fd=unsafe{open(path.as_ptr().cast(),CREATE_EXCLUSIVE,0o600)};
    if fd<0{return false}
    let mut rest=data;
    while !rest.is_empty(){
        let n=unsafe{write(fd,rest.as_ptr().cast(),rest.len())};
        if n<=0{unsafe{close(fd)};return false}
        rest=&rest[n as usize..];
    }
    unsafe{close(fd);}
    true
}
extern "C" fn on_elf_load(){
    // Constructor runs for every preloaded executable; only an actual
    // successfully execve-loaded ORIGINAL updater (not a copied/shimmed
    // executable) with original browser parent can produce this witness.
    unsafe{
        if !same_executable(UPDATER){return}
        if !own_kernel_argv()||!exact_parent_browser(){return}
        if access(PRE.as_ptr().cast(),0)!=0{return}
        if access(MAR.as_ptr().cast(),0)==0{return}
        let _=write_exclusive(POST,POST_JSON);
    }
}
#[used]
#[cfg_attr(target_os="linux",link_section=".init_array")]
static OBSERVE_REAL_ELF_LOADER:extern "C" fn()=on_elf_load;

#[no_mangle]
pub unsafe extern "C" fn execv(path:*const c_char,argv:*const *const c_char)->c_int{
    unsafe{
        // Abort all unexpected execv. Only this exact source-owned staging
        // command is authorized, and only if the MAR is absent.
        if path.is_null()||CStr::from_ptr(path).to_bytes()!=UPDATER ||
           !same_executable(BROWSER)||!source_argv(argv)||
           access(MAR.as_ptr().cast(),0)==0 ||
           !write_exclusive(PRE,PRE_JSON){
            *__errno_location()=13; // EACCES
            return -1
        }
        // Forward to the REAL kernel exec from the ORIGINAL browser's fork.
        // The updater loader will independently witness successful exec
        // and the exact ORIGINAL browser parent before the updater runs.
        execve(path,argv,environ.cast())
    }
}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn strict_native_stage_shape(){
        assert!(expected([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original/updated",b"first",b"-1"]));
        assert!(!expected([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original/updated",b"first",b"0"]));
        assert!(!expected([UPDATER,b"3",b"/original/updates/0",b"/original",b"/original",b"first",b"-1"]));
        assert!(!expected([UPDATER,b"3",b"/other/updates/0",b"/original",b"/original/updated",b"first",b"-1"]));
    }
    #[test]fn witness_does_not_claim_install_or_source_removal(){
        for doc in [PRE_JSON,POST_JSON]{
            let s=std::str::from_utf8(doc).unwrap();
            assert!(s.contains("\"source_pruning_authorized\":false"));
            assert!(s.contains("\"native_bytes_saved\":0"));
            assert!(!s.contains("\"installed\":true"));
        }
        assert!(std::str::from_utf8(POST_JSON).unwrap().contains("\"updater_loader_initialized_after_actual_exec\":true"));
    }
}
