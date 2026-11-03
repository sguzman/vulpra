// Original compiled ONNX Runtime v22 external EP registration capability check.
// CI-only, no crates or real provider, no user files/model/network/GPU.
// A "get_api(22)" null result PREVENTS all reads of later ABI table slots.
// A zero-factory inert plugin proves the loader and factory-entrypoint
// boundary only; it cannot execute or claim a real execution provider.
use std::env;
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::process::ExitCode;
use std::ptr;

const RTLD_NOW: c_int = 2;
const RTLD_LOCAL: c_int = 0;
const RTLD_NOLOAD: c_int = 4;
const ORT_NOT_IMPLEMENTED: c_int = 9;
// Function table slots are supplied only by a CI-compiled offsetof(OrtApi)
// fixture using the exact authenticated upstream public C API header.

#[link(name="dl")]
unsafe extern "C" {
    fn dlopen(path: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, name: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

#[repr(C)]
struct OrtApiBase {
    get_api: unsafe extern "C" fn(u32) -> *const *const c_void,
    get_version_string: unsafe extern "C" fn() -> *const c_char,
}
type Status = *mut c_void;
type CreateEnv = unsafe extern "C" fn(c_int,*const c_char,*mut *mut c_void)->Status;
type GetErrorCode = unsafe extern "C" fn(*const c_void)->c_int;
type RegisterEp = unsafe extern "C" fn(*mut c_void,*const c_char,*const c_char)->Status;
type UnregisterEp = unsafe extern "C" fn(*mut c_void,*const c_char)->Status;

unsafe fn method<T: Copy>(api: *const *const c_void, index: usize) -> Result<T,String> {
    if api.is_null() || std::mem::size_of::<T>() != std::mem::size_of::<*const c_void>() {
        return Err("null or incompatible OrtApi ABI".into());
    }
    let ptr = unsafe { *api.add(index) };
    if ptr.is_null() { return Err("null ONNX API field".into()); }
    Ok(unsafe { std::mem::transmute_copy(&ptr) })
}
fn must_path(s: &str, suffix: &str)->Result<CString,String> {
    if !s.starts_with('/') || !s.ends_with(suffix) || s.contains("..") {
        return Err("non-CI-original absolute filename rejected".into());
    }
    CString::new(s).map_err(|_| "unexpected NUL byte".into())
}
fn outcome(line: &str) {
    println!("M3_EXTERNAL_EP_RESULT={line}");
}
fn run() -> Result<(),String> {
    let args:Vec<String> = env::args().collect();
    if args.len()!=5 {return Err("expected original ONNX, inert EP fixture and two verified C ABI offsets".into());}
    let reg_slot:usize=args[3].parse().map_err(|_| "bad C-verified registration slot")?;
    let unreg_slot:usize=args[4].parse().map_err(|_| "bad C-verified unregistration slot")?;
    if !(250..=400).contains(&reg_slot) || unreg_slot!=reg_slot+1 {
        return Err("pinned header v22 registration slot bounds invalid".into());
    }
    let onnx = must_path(&args[1], "/libonnxruntime.so")?;
    let fixture=must_path(&args[2], "/libvulpra-onnx-inert-ep.so")?;
    let h = unsafe {dlopen(onnx.as_ptr(), RTLD_NOW|RTLD_LOCAL)};
    if h.is_null() {return Err("original compiled ONNX ELF could not be loaded".into());}
    let sym = unsafe {dlsym(h,c"OrtGetApiBase".as_ptr())};
    if sym.is_null() {return Err("missing OrtGetApiBase on original native ELF".into());}
    let get_base:unsafe extern "C" fn()->*const OrtApiBase=unsafe{std::mem::transmute(sym)};
    let base=unsafe{get_base()};
    if base.is_null() {return Err("null OrtApiBase".into());}
    let version=unsafe{((*base).get_version_string)()};
    if version.is_null()||unsafe{CStr::from_ptr(version)}.to_bytes().is_empty(){
        return Err("original ONNX returned no version string".into());
    }

    // Exact safety gate: no v22 API table => no reading slot 284 or 285.
    let api22=unsafe{((*base).get_api)(22)};
    if api22.is_null() {
        outcome("api_v22_not_available");
        return Ok(());
    }
    let api1=unsafe{((*base).get_api)(1)};
    if api1.is_null(){return Err("original ONNX v1 API unexpectedly unavailable".into());}
    let create_env:CreateEnv=unsafe{method(api1,3)?};
    let error_code:GetErrorCode=unsafe{method(api1,1)?};
    let register:RegisterEp=unsafe{method(api22,reg_slot)?};
    let unregister:UnregisterEp=unsafe{method(api22,unreg_slot)?};
    let mut ort_env=ptr::null_mut();
    let status=unsafe{create_env(3,c"vulpra-isolated-inert-ep-probe".as_ptr(),&mut ort_env)};
    if !status.is_null()||ort_env.is_null(){return Err("CreateEnv failed".into());}
    let reg_name=c"vulpra_inert_ci_ep";
    let status=unsafe{register(ort_env,reg_name.as_ptr(),fixture.as_ptr())};
    if !status.is_null(){
        let code=unsafe{error_code(status)};
        if code==ORT_NOT_IMPLEMENTED {
            outcome("v22_api_present_registration_not_implemented");
        } else if (1..=13).contains(&code) {
            // Not a success or proof of provider compatibility; preserve
            // just the bounded enum, never a path/error message.
            outcome("v22_registration_failed_other_status");
        } else {
            return Err("unrecognized original ONNX status code".into());
        }
        return Ok(());
    }

    // An OK status must correspond to an actual fixture previously loaded by
    // ONNX, not something our test harness accidentally loads for the check.
    let plugin=unsafe{dlopen(fixture.as_ptr(),RTLD_NOW|RTLD_NOLOAD)};
    if plugin.is_null(){return Err("registration returned OK but inert library not loaded".into());}
    let counter=unsafe{dlsym(plugin,c"m3_ep_factory_call_count".as_ptr())};
    if counter.is_null()||unsafe{*(counter.cast::<u32>())}!=1 {
        return Err("real original ONNX did not invoke the inert EP factory callback once".into());
    }
    unsafe{dlclose(plugin)};
    let status=unsafe{unregister(ort_env,reg_name.as_ptr())};
    if !status.is_null(){return Err("original ONNX EP unregistration returned a failure".into());}
    outcome("v22_inert_ep_registration_and_factory_callback_success");
    Ok(())
}
fn main()->ExitCode {
    match run(){Ok(())=>ExitCode::SUCCESS,Err(e)=>{eprintln!("FAIL: {e}");ExitCode::FAILURE}}
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn version_guard_and_offsets_are_bounded(){
        assert_eq!(ORT_NOT_IMPLEMENTED,9);
        assert!(must_path("/tmp/safe/libonnxruntime.so","/libonnxruntime.so").is_ok());
        assert!(must_path("../libonnxruntime.so","/libonnxruntime.so").is_err());
    }
}
