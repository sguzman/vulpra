// Read-only isolated CI activation of source-pinned original ONNX Runtime C API.
// No model download, inference, user data, profiler or external networking.
use std::env;
use std::ffi::{c_char,c_int,c_void,CStr,CString};
use std::process::ExitCode;

const RTLD_NOW: c_int=2;
const RTLD_LOCAL: c_int=0;
#[link(name="dl")]
unsafe extern "C" {
    fn dlopen(name:*const c_char, flags:c_int)->*mut c_void;
    fn dlsym(handle:*mut c_void, name:*const c_char)->*mut c_void;
    fn dlclose(handle:*mut c_void)->c_int;
}
#[repr(C)]
struct OrtApiBase {
    get_api: unsafe extern "C" fn(version:u32)->*const c_void,
    get_version_string: unsafe extern "C" fn()->*const c_char,
}

fn run()->Result<(),&'static str>{
    let path=env::args().nth(1).ok_or("Need exactly one original ONNX ELF absolute path")?;
    if env::args().nth(2).is_some() || !path.starts_with('/')
        || !path.ends_with("/libonnxruntime.so") {
        return Err("Not the original packaged ONNX shared library path");
    }
    let name=CString::new(path).map_err(|_|"Unsafe ELF path")?;
    let symname=CString::new("OrtGetApiBase").map_err(|_|"Invalid expected symbol")?;
    let handle=unsafe{dlopen(name.as_ptr(),RTLD_NOW|RTLD_LOCAL)};
    if handle.is_null(){return Err("Original native ONNX library could not be dynamically loaded");}
    let sym=unsafe{dlsym(handle,symname.as_ptr())};
    if sym.is_null(){
        unsafe{dlclose(handle)};
        return Err("Original native ONNX shared library did not export OrtGetApiBase");
    }
    let func:unsafe extern "C" fn()->*const OrtApiBase=unsafe{std::mem::transmute(sym)};
    let api=unsafe{func()};
    if api.is_null(){
        unsafe{dlclose(handle)};
        return Err("Original native ONNX API base was null");
    }
    let version_ptr=unsafe{((*api).get_version_string)()};
    if version_ptr.is_null(){
        unsafe{dlclose(handle)};
        return Err("Original ONNX C API returned null version string");
    }
    let version=unsafe{CStr::from_ptr(version_ptr)}.to_bytes();
    if version.is_empty() || version.len()>128 || !version.is_ascii()
        || version.iter().any(|b| !b.is_ascii_graphic()) {
        unsafe{dlclose(handle)};
        return Err("Original ONNX C API version string was invalid");
    }
    if unsafe{dlclose(handle)} != 0 {return Err("Could not close original native ONNX library");}
    println!("PASS: original packaged ONNX Runtime C API base and nonempty version string invoked");
    Ok(())
}
fn main()->ExitCode{
    match run(){
        Ok(())=>ExitCode::SUCCESS,
        Err(e)=>{eprintln!("FAIL: {e}");ExitCode::FAILURE}
    }
}
