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
        // Exact signatures are pinned to the original Firefox 159 beta llama.h.
        let init: unsafe extern "C" fn() =
            unsafe { std::mem::transmute(symbol(handle, "llama_backend_init")?) };
        let time_us: unsafe extern "C" fn() -> i64 =
            unsafe { std::mem::transmute(symbol(handle, "llama_time_us")?) };
        let supports_mmap: unsafe extern "C" fn() -> bool =
            unsafe { std::mem::transmute(symbol(handle, "llama_supports_mmap")?) };
        let free: unsafe extern "C" fn() =
            unsafe { std::mem::transmute(symbol(handle, "llama_backend_free")?) };
        unsafe { init(); }
        let clock = unsafe { time_us() };
        let _mmap_supported = unsafe { supports_mmap() };
        unsafe { free(); }
        if clock <= 0 {
            return Err("Original llama C API clock was not initialized");
        }
        Ok(())
    })();
    if unsafe { dlclose(handle) } != 0 {
        return Err("Could not close the original inference shared library");
    }
    result?;
    println!("PASS: original packaged mozinference llama backend initialized and C API invoked");
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
