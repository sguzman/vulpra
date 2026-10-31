// Bounded standalone activation of the original packaged mozinference llama C API.
// Never loads a model, runs an inference, or accesses a user's browser profile.
use std::env;
use std::ffi::{c_char, c_int, c_void, CString};
use std::process::ExitCode;

const RTLD_NOW: c_int = 2;
const RTLD_LOCAL: c_int = 0;
#[link(name = "dl")]
unsafe extern "C" {
    fn dlopen(path: *const c_char, mode: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

fn symbol(handle: *mut c_void, name: &'static str) -> Result<*mut c_void, &'static str> {
    let c_name = CString::new(name).map_err(|_| "Invalid pinned symbol")?;
    let address = unsafe { dlsym(handle, c_name.as_ptr()) };
    if address.is_null() {
        return Err("Pinned original llama C API export missing");
    }
    Ok(address)
}

fn run() -> Result<(), &'static str> {
    let mut args = env::args();
    let _binary = args.next();
    let path = args.next().ok_or("Expected one original library path")?;
    if args.next().is_some() || !path.starts_with('/')
        || !path.ends_with("/libmozinference.so") {
        return Err("Only a packaged absolute libmozinference.so path is accepted");
    }
    let c_path = CString::new(path).map_err(|_| "Unsafe library path")?;
    let handle = unsafe { dlopen(c_path.as_ptr(), RTLD_NOW | RTLD_LOCAL) };
    if handle.is_null() {
        return Err("Original native mozinference library failed to load");
    }
    let result = (|| {
        // Source-pinned production LlamaRuntimeLinker.h binds both exports.
        // llama_model_default_params returns a large struct by value, so do not
        // invoke it from a handwritten foreign ABI; its export is checked only.
        let _default_params = symbol(handle, "llama_model_default_params")?;
        let set_log: unsafe extern "C" fn(
            extern "C" fn(c_int, *const c_char, *mut c_void),
            *mut c_void,
        ) = unsafe { std::mem::transmute(symbol(handle, "llama_log_set")?) };
        extern "C" fn discard_log(_level: c_int, _message: *const c_char, _data: *mut c_void) {}
        unsafe { set_log(discard_log, std::ptr::null_mut()); }
        Ok(())
    })();
    if unsafe { dlclose(handle) } != 0 {
        return Err("Could not close the original inference shared library");
    }
    result?;
    println!("PASS: original packaged mozinference production-linked llama C API invoked");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("FAIL: {message}");
            ExitCode::FAILURE
        }
    }
}
