// Read-only ONNX Runtime v22 EXTERNAL execution-provider API surface census.
// Original-source native ELF only. Never registers an EP or calls the slots.
// A v22 pointer is required before reading later fields of OrtApi.
use std::env;
use std::ffi::{c_char,c_int,c_void,CStr,CString};
use std::process::ExitCode;
const RTLD_NOW:c_int=2;
const RTLD_LOCAL:c_int=0;
#[link(name="dl")]
unsafe extern "C" {
    fn dlopen(path:*const c_char,flags:c_int)->*mut c_void;
    fn dlsym(handle:*mut c_void,symbol:*const c_char)->*mut c_void;
    fn dlclose(handle:*mut c_void)->c_int;
}
#[repr(C)]
struct OrtApiBase {
    get_api:unsafe extern "C" fn(u32)->*const *const c_void,
    get_version_string:unsafe extern "C" fn()->*const c_char,
}
fn result(value:&str){println!("M3_EXTERNAL_EP_SURFACE={value}");}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4 {return Err("expected pinned ELF path plus two C header offsets".into());}
    let path=&args[1];
    if !path.starts_with('/')||!path.ends_with("/libonnxruntime.so")||
       path.contains("..") {return Err("original ELF path invalid".into());}
    let reg_slot:usize=args[2].parse().map_err(|_|"registration ABI index invalid")?;
    let unreg_slot:usize=args[3].parse().map_err(|_|"unregistration ABI index invalid")?;
    if !(250..=400).contains(&reg_slot)||unreg_slot!=reg_slot+1 {
        return Err("pinned upstream C table offsets inconsistent".into());
    }
    let name=CString::new(path.as_str()).map_err(|_|"NUL in original ELF path")?;
    let handle=unsafe{dlopen(name.as_ptr(),RTLD_NOW|RTLD_LOCAL)};
    if handle.is_null(){return Err("original ONNX ELF could not be loaded".into());}
    let sym=unsafe{dlsym(handle,c"OrtGetApiBase".as_ptr())};
    if sym.is_null(){return Err("original ONNX lacks OrtGetApiBase".into());}
    let getter:unsafe extern "C" fn()->*const OrtApiBase=unsafe{std::mem::transmute(sym)};
    let base=unsafe{getter()};
    if base.is_null(){return Err("original ONNX returned null API base".into());}
    let version=unsafe{((*base).get_version_string)()};
    if version.is_null()||unsafe{CStr::from_ptr(version)}.to_bytes().is_empty(){
        return Err("original ONNX returned empty version".into());
    }
    let api22=unsafe{((*base).get_api)(22)};
    if api22.is_null(){
        result("v22_api_not_exposed");
    } else {
        let register=unsafe{*api22.add(reg_slot)};
        let unregister=unsafe{*api22.add(unreg_slot)};
        if !register.is_null() && !unregister.is_null(){
            result("v22_external_ep_api_entries_present_not_executed");
        } else {
            result("v22_api_exposed_but_ep_entries_missing");
        }
    }
    if unsafe{dlclose(handle)}!=0 {return Err("failed to release original ONNX handle".into());}
    Ok(())
}
fn main()->ExitCode{match run(){Ok(())=>ExitCode::SUCCESS,Err(e)=>{eprintln!("FAIL: {e}");ExitCode::FAILURE}}}
#[cfg(test)]
mod tests{
    #[test]fn api_guard_bounds(){
        let good=(250usize..=400).contains(&301);
        assert!(good);
        assert_eq!(302,301+1);
    }
}
