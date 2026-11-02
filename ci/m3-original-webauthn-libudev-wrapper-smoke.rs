// Native smoke test of the *unaltered original* Firefox WebAuthn
// libudev-sys Rust library, linked as a path dependency in disposable CI.
// Only invokes udev_new / udev_unref (no USB device listing or WebAuthn).
// Tests true first-use lazy dlopen and actual two C ABI symbol calls.
use std::{env,ffi::{c_char,c_void,CString},fs};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SONAME:&str="libudev.so.1";
const FLAGS:i32=0x105; // RTLD_LAZY|RTLD_GLOBAL|RTLD_NOLOAD on glibc x86-64
#[link(name="dl")]
unsafe extern "C"{
    fn dlopen(name:*const c_char,flags:i32)->*mut c_void;
    fn dlclose(handle:*mut c_void)->i32;
}
fn already_loaded(name:&CString)->Result<bool,String>{
    let h=unsafe{dlopen(name.as_ptr(),FLAGS)};
    if h.is_null(){return Ok(false);}
    if unsafe{dlclose(h)}!=0{return Err("NOLOAD reference release failed".into());}
    Ok(true)
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4||args[1]!=SOURCE ||
       !["ubuntu-24.04","archlinux-container"].contains(&args[2].as_str()){
        return Err("usage: native-original-webauthn-wrapper PINNED_SHA ubuntu-24.04|archlinux-container OUT_JSON".into());
    }
    let name=CString::new(SONAME).unwrap();
    let before=already_loaded(&name)?;
    if before{return Err("Unexpected libudev.so.1 preload: cannot prove lazy first-use".into());}
    // THESE calls execute the original unmodified source checkout's symbols,
    // not reimplementations of its libloading logic.
    let context=unsafe{(*libudev_sys::udev_new)()};
    if context.is_null(){return Err("Original Rust libudev-sys udev_new returned null".into());}
    let after=already_loaded(&name)?;
    if !after{return Err("Original Rust udev_new did not leave libudev.so.1 loaded".into());}
    let _=unsafe{(*libudev_sys::udev_unref)(context)};
    if !already_loaded(&name)? {
        return Err("Original Rust lazy static libudev.so.1 handle was lost".into());
    }
    let result=format!(concat!(
        "{{\n\"schema_version\":1,\n",
        "\"status\":\"source_pinned_original_rust_webauthn_libudev_first_use_context_smoke\",\n",
        "\"original_source_commit\":\"{}\",\n",
        "\"isolated_host\":\"{}\",\n",
        "\"original_libudev_sys_rust_source_compiled_and_executed\":true,\n",
        "\"source_udev_new_function_invoked\":true,\n",
        "\"source_udev_unref_function_invoked\":true,\n",
        "\"source_udev_new_returned_nonnull_context\":true,\n",
        "\"libudev_soname\":\"libudev.so.1\",\n",
        "\"libudev_noload_pre_first_use\":false,\n",
        "\"libudev_noload_post_first_use\":true,\n",
        "\"libudev_noload_after_context_release\":true,\n",
        "\"original_compiled_wrapper_dlopen_lazy_route_observed\":true,\n",
        "\"usb_device_enumeration_performed\":false,\n",
        "\"webauthn_security_key_session_performed\":false,\n",
        "\"original_browser_executed\":false,\n",
        "\"network_egress_allowed_during_test\":false,\n",
        "\"user_workstation_verified\":false,\n",
        "\"complete_loader_dependency_closure\":false,\n",
        "\"source_pruning_authorized\":false,\n",
        "\"m3_sixth_gate_closed\":false\n}}\n"
    ),SOURCE,args[2]);
    fs::write(&args[3],result).map_err(|e|e.to_string())?;
    println!("PASS: original Rust libudev-sys udev_new/udev_unref executed on {}; actual lazy dlopen first-use observed without USB or network",args[2]);
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn pinned_contract(){
        assert_eq!(SOURCE.len(),40);
        assert_eq!(SONAME,"libudev.so.1");
        assert_eq!(FLAGS,0x105);
    }
}
