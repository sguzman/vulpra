// Isolated source-pinned, original packaged CDM ABI negative-path probe.
// No EME session, decryption keys, media payload, browser data or DRM bypass.
use std::env;
use std::ffi::{c_char, c_int, c_void, CString};
use std::process::ExitCode;

#[link(name = "dl")]
unsafe extern "C" {
    fn dlopen(path: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

fn run() -> Result<(), &'static str> {
    let mut args = env::args();
    let _binary = args.next();
    let path = args.next().ok_or("Expected one original ClearKey library path")?;
    if args.next().is_some() || !path.starts_with('/')
        || !path.ends_with("/gmp-clearkey/0.1/libclearkey.so") {
        return Err("Only an absolute packaged original ClearKey path is allowed");
    }
    let c_path = CString::new(path).map_err(|_| "Unsafe original plugin path")?;
    let lib = unsafe { dlopen(c_path.as_ptr(), 2) }; // RTLD_NOW, RTLD_LOCAL
    if lib.is_null() {
        return Err("Original packaged ClearKey native CDM could not load");
    }
    let checked = (|| {
        let symbol = CString::new("CreateCdmInstance").map_err(|_| "Unsafe C export")?;
        let entry = unsafe { dlsym(lib, symbol.as_ptr()) };
        if entry.is_null() {
            return Err("Actual compiled ClearKey CDM entry point was not exported");
        }
        // Source-pinned gmp-clearkey.cpp rejects interface version zero before
        // dereferencing the key system or host callback. This validates only
        // the expected negative C ABI branch, not any working media session.
        let create: unsafe extern "C" fn(
            i32, *const c_char, u32, *mut c_void, *mut c_void
        ) -> *mut c_void = unsafe { std::mem::transmute(entry) };
        let key = CString::new("org.w3.clearkey").map_err(|_| "Invalid test-only key-system label")?;
        let result = unsafe {
            create(0, key.as_ptr(), key.as_bytes().len() as u32,
                   std::ptr::null_mut(), std::ptr::null_mut())
        };
        if !result.is_null() {
            return Err("Invalid interface version unexpectedly returned a CDM instance");
        }
        Ok(())
    })();
    if unsafe { dlclose(lib) } != 0 {
        return Err("Original native ClearKey CDM close failed");
    }
    checked?;
    println!("PASS: original packaged ClearKey CDM C API rejected invalid interface version");
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
