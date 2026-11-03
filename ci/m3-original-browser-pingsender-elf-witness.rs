// CI-only real ORIGINAL browser-controlled pingsender ELF loader witness.
// No real data and no external egress: original browser is --network none,
// synthetic payload is in disposable /tmp, and destination is localhost:9.
// Only actual execution of the immutable packaged /original/pingsender with
// the exact original browser parent and synthetic argv can emit a witness.
// Does not claim delivered telemetry, normal policy, or safe removal.
use std::ffi::{c_char,c_int,c_void};

const SELF_EXE:&[u8]=b"/original/pingsender";
const BROWSER:&[u8]=b"/original/vulpra";
const URL:&[u8]=b"http://localhost:9/vulpra-m3-synthetic-never-submit";
const PAYLOAD:&[u8]=b"/tmp/vulpra-m3-synthetic-only-ping.json";
const REPORT:&[u8]=b"/reports/m3-original-browser-pingsender-elf-witness.json\0";
const DATA:&[u8]=br#"{"schema_version":1,"status":"real_original_browser_started_packaged_pingsender","original_source_commit":"b1482404dfb8b01342990ee99ea3df0f9756b5f7","original_archive_sha256":"7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a","actual_original_packaged_pingsender_executable_loaded":true,"exact_synthetic_localhost_only_argv":true,"original_browser_executable_is_parent":true,"observed_in_original_child_elf_loader":true,"no_external_network_available":true,"real_telemetry_payload_or_user_profile_involved":false,"telemetry_upload_success_proven":false,"normal_policy_or_shutdown_submission_proven":false,"source_pruning_authorized":false,"native_bytes_saved":0,"m3_sixth_gate_closed":false}
"#;
unsafe extern "C" {
    fn getppid()->c_int;
    fn readlink(path:*const c_char,buf:*mut c_char,n:usize)->isize;
    fn snprintf(buf:*mut c_char,n:usize,format:*const c_char,...)->c_int;
    fn open(path:*const c_char,flags:c_int,...)->c_int;
    fn read(fd:c_int,data:*mut c_void,n:usize)->isize;
    fn write(fd:c_int,data:*const c_void,n:usize)->isize;
    fn close(fd:c_int)->c_int;
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
        let _=save_marker();
    }
}
#[used]
#[cfg_attr(target_os="linux",link_section=".init_array")]
static GENUINE_ORIGINAL_PINGSENDER_INIT:extern "C" fn()=witness_elf;

#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn exactly_one_localhost_payload_pair(){
        assert!(expected(vec![SELF_EXE.to_vec(),URL.to_vec(),PAYLOAD.to_vec()].into_iter()));
        assert!(expected(vec![b"pingsender".to_vec(),URL.to_vec(),PAYLOAD.to_vec()].into_iter()));
        assert!(!expected(vec![SELF_EXE.to_vec(),b"https://incoming.telemetry.mozilla.org/submit".to_vec(),PAYLOAD.to_vec()].into_iter()));
        assert!(!expected(vec![SELF_EXE.to_vec(),URL.to_vec(),b"/home/user/private.json".to_vec()].into_iter()));
        assert!(!expected(vec![SELF_EXE.to_vec(),URL.to_vec(),PAYLOAD.to_vec(),b"extra".to_vec()].into_iter()));
    }
    #[test]fn witness_is_precisely_bounded(){
        let doc=std::str::from_utf8(DATA).unwrap();
        assert!(doc.contains("\"telemetry_upload_success_proven\":false"));
        assert!(doc.contains("\"source_pruning_authorized\":false"));
        assert!(doc.contains("\"native_bytes_saved\":0"));
        assert!(!doc.contains("profile_path"));
        assert!(!doc.contains("raw_argv"));
    }
}
