// CI-only real ORIGINAL browser-controlled pingsender ELF loader witness.
// No real data and no external egress: original browser is --network none,
// synthetic payload is in disposable /tmp, and destination is localhost:9.
// Only actual execution of the immutable packaged /original/pingsender with
// the exact original browser parent and synthetic argv can emit a witness.
// Does not claim delivered telemetry, normal policy, or safe removal.
use std::ffi::{c_char,c_int,c_void,CStr};
use std::sync::atomic::{AtomicBool,AtomicU32,AtomicUsize,Ordering};

const SELF_EXE:&[u8]=b"/original/pingsender";
const BROWSER:&[u8]=b"/original/vulpra";
const URL:&[u8]=b"http://localhost:9/vulpra-m3-synthetic-never-submit";
const PAYLOAD:&[u8]=b"/tmp/vulpra-m3-synthetic-only-ping.json";
const REPORT:&[u8]=b"/reports/m3-original-browser-pingsender-libcurl-dlsym.json\0";
const EXPECTED_LIBRARIES:[&[u8];6]=[
    b"libcurl.so",b"libcurl.so.4",b"libcurl-gnutls.so",
    b"libcurl-gnutls.so.4",b"libcurl.so.3",b"libcurl-gnutls.so.3"
];
const CURL_API:[&[u8];14]=[
    b"curl_easy_init",b"curl_easy_setopt",b"curl_easy_perform",
    b"curl_easy_getinfo",b"curl_slist_append",b"curl_slist_free_all",
    b"curl_easy_strerror",b"curl_easy_cleanup",b"curl_global_cleanup",
    b"curl_url",b"curl_url_set",b"curl_url_get",b"curl_free",b"curl_url_cleanup"
];
const ALL: u32 = (1 << 14)-1;
static AUTHENTIC:AtomicBool=AtomicBool::new(false);
static CURL_HANDLE:AtomicUsize=AtomicUsize::new(0);
static SEEN:AtomicU32=AtomicU32::new(0);
static WRITTEN:AtomicBool=AtomicBool::new(false);
const DATA:&[u8]=br#"{"schema_version":1,"status":"original_browser_owned_pingsender_loaded_libcurl_and_resolved_all_14_source_symbols","source_commit":"b1482404dfb8b01342990ee99ea3df0f9756b5f7","archive_sha256":"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a","real_original_packaged_pingsender_elf_loaded":true,"parent_executable_original_browser":true,"kernel_argv_localhost_synthetic_only":true,"real_pingsender_called_dlopen_for_original_curl_soname":true,"real_dlopen_returned_nonnull_libcurl_handle":true,"actual_dlsym_invocations_on_same_libcurl_handle":14,"all_9_required_source_symbols_returned_nonnull":true,"all_5_optional_url_symbols_returned_nonnull":true,"no_remote_network_or_real_telemetry":true,"telemetry_post_success_proven":false,"actual_curl_easy_perform_executed_proven":false,"full_conditional_loader_or_ffi_graph_closed":false,"source_pruning_authorized":false,"native_bytes_saved":0,"m3_sixth_gate_closed":false}
"#;
unsafe extern "C" {
    fn getppid()->c_int;
    fn readlink(path:*const c_char,buf:*mut c_char,n:usize)->isize;
    fn snprintf(buf:*mut c_char,n:usize,format:*const c_char,...)->c_int;
    fn open(path:*const c_char,flags:c_int,...)->c_int;
    fn read(fd:c_int,data:*mut c_void,n:usize)->isize;
    fn write(fd:c_int,data:*const c_void,n:usize)->isize;
    fn close(fd:c_int)->c_int;
    fn dlvsym(handle:*mut c_void,symbol:*const c_char,version:*const c_char)->*mut c_void;
}
fn expected(mut args:impl Iterator<Item=Vec<u8>>)->bool{
    let first=args.next();let url=args.next();let path=args.next();
    (first.as_deref()==Some(SELF_EXE)||
      first.as_deref()==Some(b"pingsender".as_slice()))&&
    url.as_deref()==Some(URL)&&path.as_deref()==Some(PAYLOAD)&&args.next().is_none()
}
unsafe fn proc_executable(path:*const c_char,want:&[u8])->bool{
    let mut buf=[0u8;256];
    let n=unsafe{readlink(path,buf.as_mut_ptr().cast(),buf.len())};
    n>0&&buf.get(..n as usize)==Some(want)
}
unsafe fn kernel_argv()->bool{
    const RD:c_int=524288; // O_RDONLY | O_CLOEXEC
    let fd=unsafe{open(c"/proc/self/cmdline".as_ptr(),RD)};
    if fd<0{return false}
    let mut buf=[0u8;512];
    let n=unsafe{read(fd,buf.as_mut_ptr().cast(),buf.len())};
    unsafe{close(fd);}
    if n<1||n as usize>=buf.len(){return false}
    let bytes=&buf[..n as usize];
    if bytes.last()!=Some(&0){return false}
    expected(bytes[..bytes.len()-1].split(|b|*b==0).map(|b|b.to_vec()))
}
unsafe fn is_parent_original_browser()->bool{
    let parent=unsafe{getppid()};
    if parent<=1{return false}
    let mut name=[0i8;64];
    let n=unsafe{snprintf(name.as_mut_ptr(),name.len(),c"/proc/%d/exe".as_ptr(),parent)};
    n>0&&(n as usize)<name.len()&&unsafe{proc_executable(name.as_ptr(),BROWSER)}
}
unsafe fn save_marker()->bool{
    const FLAGS:c_int=1|64|128|524288; // O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC
    let fd=unsafe{open(REPORT.as_ptr().cast(),FLAGS,0o600)};
    if fd<0{return false}
    let mut data=DATA;
    while !data.is_empty(){
        let n=unsafe{write(fd,data.as_ptr().cast(),data.len())};
        if n<=0{unsafe{close(fd)};return false}
        data=&data[n as usize..];
    }
    unsafe{close(fd);}
    true
}
extern "C" fn witness_elf(){
    unsafe{
        if !proc_executable(c"/proc/self/exe".as_ptr(),SELF_EXE){return}
        if !kernel_argv()||!is_parent_original_browser(){return}
        AUTHENTIC.store(true,Ordering::Release);
    }
}
#[used]
#[cfg_attr(target_os="linux",link_section=".init_array")]
static GENUINE_ORIGINAL_PINGSENDER_INIT:extern "C" fn()=witness_elf;

// Only actual original packaged child qualifies. The hooks forward to
// glibc through dlvsym, avoiding recursion in our own dlsym wrapper.
fn curl_candidate(name:&[u8])->bool{EXPECTED_LIBRARIES.contains(&name)}
fn curl_symbol(name:&[u8])->Option<usize>{CURL_API.iter().position(|s|*s==name)}
unsafe fn real_dlopen_fn()->Option<unsafe extern "C" fn(*const c_char,c_int)->*mut c_void>{
    let fnptr=unsafe{dlvsym((-1isize) as *mut c_void,
        c"dlopen".as_ptr(),c"GLIBC_2.34".as_ptr())};
    if fnptr.is_null(){return None}
    Some(unsafe{std::mem::transmute(fnptr)})
}
unsafe fn real_dlsym_fn()->Option<unsafe extern "C" fn(*mut c_void,*const c_char)->*mut c_void>{
    let fnptr=unsafe{dlvsym((-1isize) as *mut c_void,
        c"dlsym".as_ptr(),c"GLIBC_2.34".as_ptr())};
    if fnptr.is_null(){return None}
    Some(unsafe{std::mem::transmute(fnptr)})
}
#[no_mangle]
pub unsafe extern "C" fn dlopen(name:*const c_char,flags:c_int)->*mut c_void{
    let Some(real)= (unsafe{real_dlopen_fn()}) else {return std::ptr::null_mut()};
    let result=unsafe{real(name,flags)};
    // Original CurlWrapper::Init explicitly uses RTLD_NOW.
    if !result.is_null()&&!name.is_null()&&flags&2==2&&AUTHENTIC.load(Ordering::Acquire){
        let n=unsafe{CStr::from_ptr(name).to_bytes()};
        if curl_candidate(n){CURL_HANDLE.store(result as usize,Ordering::Release);}
    }
    result
}
#[no_mangle]
pub unsafe extern "C" fn dlsym(handle:*mut c_void,symbol:*const c_char)->*mut c_void{
    let Some(real)= (unsafe{real_dlsym_fn()}) else {return std::ptr::null_mut()};
    let result=unsafe{real(handle,symbol)};
    if result.is_null()||symbol.is_null()||!AUTHENTIC.load(Ordering::Acquire){
        return result
    }
    let selected=CURL_HANDLE.load(Ordering::Acquire);
    if selected==0||selected!=handle as usize{return result}
    let s=unsafe{CStr::from_ptr(symbol).to_bytes()};
    if let Some(i)=curl_symbol(s){
        let mask=SEEN.fetch_or(1u32<<i,Ordering::AcqRel)|(1u32<<i);
        if mask==ALL&&!WRITTEN.swap(true,Ordering::AcqRel){
            // This witness proves genuine source-defined dlsym resolution,
            // NOT whether libcurl later sent a request or was usable in every
            // host ABI configuration. Never export symbol values or PIDs.
            unsafe{let _=save_marker();}
        }
    }
    result
}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn exact_local_only_pingsender_args(){
        assert!(expected(vec![SELF_EXE.to_vec(),URL.to_vec(),PAYLOAD.to_vec()].into_iter()));
        assert!(!expected(vec![SELF_EXE.to_vec(),b"https://incoming.telemetry.mozilla.org/submit".to_vec(),PAYLOAD.to_vec()].into_iter()));
    }
    #[test]fn exact_original_library_candidates(){
        assert_eq!(EXPECTED_LIBRARIES.len(),6);
        assert!(curl_candidate(b"libcurl.so.4"));
        assert!(!curl_candidate(b"libcurl.so.4.evil"));
        assert!(!curl_candidate(b"/tmp/fake/libcurl.so"));
    }
    #[test]fn source_declared_symbols_unique_and_required(){
        assert_eq!(CURL_API.len(),14);
        for (i,s) in CURL_API.iter().enumerate(){
            assert_eq!(curl_symbol(s),Some(i));
        }
        assert_eq!(curl_symbol(b"curl_made_up"),None);
        assert_eq!(ALL.count_ones(),14);
    }
    #[test]fn witness_claims_bounded(){
        let s=std::str::from_utf8(DATA).unwrap();
        assert!(s.contains("\"all_9_required_source_symbols_returned_nonnull\":true"));
        assert!(s.contains("\"all_5_optional_url_symbols_returned_nonnull\":true"));
        assert!(s.contains("\"actual_curl_easy_perform_executed_proven\":false"));
        assert!(s.contains("\"source_pruning_authorized\":false"));
        assert!(s.contains("\"m3_sixth_gate_closed\":false"));
        assert!(!s.contains("raw_argv"));
    }
}
