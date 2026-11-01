// Isolated Linux WebAuthn libudev host ABI / dlopen fallback witness.
// Sources are pinned to original Firefox b1482404; never executes the
// original browser, touches a USB device, or accesses the network.
use std::{collections::BTreeSet,env,ffi::{c_char,c_void,CString},fs,path::Path};
const SOURCE:&str="b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SO:&str="libudev.so.1";
const SYMBOLS:usize=49;
const RTLD_LAZY:i32=1;
const RTLD_GLOBAL:i32=0x100;
const RTLD_NOLOAD:i32=4;
#[link(name="dl")]
unsafe extern "C" {
    fn dlopen(file:*const c_char, flags:i32)->*mut c_void;
    fn dlsym(handle:*mut c_void,name:*const c_char)->*mut c_void;
    fn dlclose(handle:*mut c_void)->i32;
}
fn parse(text:&str)->Result<Vec<String>,String>{
    let anchors=[
        "use libc::{RTLD_GLOBAL,RTLD_LAZY,RTLD_NOLOAD};",
        "use libc::{dlopen,dlclose,dlsym};",
        "if $a.is_null() { $b } else { $a }",
        "let flags = RTLD_LAZY | RTLD_GLOBAL;",
        "let flags_noload = flags | RTLD_NOLOAD;",
        "ifnull!(dlopen(name, flags_noload), dlopen(name, flags))",
        "Library::open(\"libudev.so.1\")",
        "Symbol::new(LIBRARY.get(stringify!($name)))",
        "pub static ref $name : Symbol<$type>",
        "define!(udev_new, extern \"C\" fn () -> *mut udev);",
    ];
    for a in anchors{if !text.contains(a){return Err("Pinned original libudev loader source changed".into());}}
    let mut symbols=Vec::new();let mut unique=BTreeSet::new();
    for line in text.lines(){
        let l=line.trim();
        if let Some(tail)=l.strip_prefix("define!("){
            let name=tail.split(',').next().ok_or("Invalid original define! macro")?;
            if !name.starts_with("udev_") || name.len()>96 ||
                !name.bytes().all(|c|c.is_ascii_lowercase()||c.is_ascii_digit()||c==b'_'){
                return Err("Unexpected original udev symbol".into());
            }
            if !unique.insert(name.to_string()){return Err("Duplicate original udev symbol".into());}
            symbols.push(name.to_string());
        }
    }
    if symbols.len()!=SYMBOLS || !symbols.iter().any(|s|s=="udev_new") ||
        !symbols.iter().any(|s|s=="udev_enumerate_get_list_entry"){
        return Err(format!("Original source libudev symbol-count mismatch: {}",symbols.len()));
    }
    Ok(symbols)
}
#[derive(Debug)]
struct Observation{
    initial_noload_found:bool,
    initial_path:&'static str,
    returned_noload_after_open:bool,
    resolved_symbols:usize,
    loaded_udev_soname:&'static str,
}
fn probe(names:&[String])->Result<Observation,String>{
    let c=CString::new(SO).unwrap();
    let flags=RTLD_LAZY|RTLD_GLOBAL;
    let flags_noload=flags|RTLD_NOLOAD;
    // Deliberately replicate the ifnull! macro exactly: on a non-null
    // result, the first dlopen expression is evaluated a second time.
    let initial=unsafe{dlopen(c.as_ptr(),flags_noload)};
    let initially_present=!initial.is_null();
    let result=if initial.is_null(){
        unsafe{dlopen(c.as_ptr(),flags)}
    }else{
        unsafe{dlopen(c.as_ptr(),flags_noload)}
    };
    if result.is_null(){
        if initially_present{let _=unsafe{dlclose(initial)};}
        return Err("Could not load libudev.so.1 under the original fallback flags".into());
    }
    let mut matched=0;
    for name in names{
        let n=CString::new(name.as_str()).map_err(|e|e.to_string())?;
        if !unsafe{dlsym(result,n.as_ptr())}.is_null(){matched+=1;}
    }
    // Test the already-loaded path, including its macro's double NOLOAD
    // behavior, without invoking any libudev function or hardware.
    let warm1=unsafe{dlopen(c.as_ptr(),flags_noload)};
    let warm2=unsafe{dlopen(c.as_ptr(),flags_noload)};
    let warm=!warm1.is_null() && !warm2.is_null();
    let mut all_closed=true;
    for handle in [warm2,warm1,result,initial]{
        if !handle.is_null() && unsafe{dlclose(handle)}!=0 {all_closed=false;}
    }
    if !all_closed || !warm {return Err("Warm NOLOAD or reference cleanup failed".into());}
    if matched!=names.len(){
        return Err(format!("Host libudev exports only {matched}/{} original symbols",names.len()));
    }
    Ok(Observation{
        initial_noload_found:initially_present,
        initial_path:if initially_present{"noload_preexisting_then_noload"}else{"noload_miss_then_normal"},
        returned_noload_after_open:warm,
        resolved_symbols:matched,
        loaded_udev_soname:SO,
    })
}
fn quote(s:&str)->String{
    let mut t=String::from("\"");
    for c in s.chars(){
        match c{'"'=>t.push_str("\\\""),'\\'=>t.push_str("\\\\"),
            '\n'=>t.push_str("\\n"),'\r'=>t.push_str("\\r"),
            x if x.is_control()=>t.push_str(&format!("\\u{:04x}",x as u32)),x=>t.push(x)}
    }
    t.push('"');t
}
fn run()->Result<(),String>{
    let a:Vec<_>=env::args().collect();
    if a.len()!=5 || a[1]!=SOURCE ||
        !["ubuntu-24.04","archlinux-container"].contains(&a[3].as_str()){
        return Err("usage: udev-abi PINNED_SHA ORIGINAL_LIBUDEV_SOURCE ubuntu-24.04|archlinux-container REPORT".into());
    }
    let source=fs::read_to_string(Path::new(&a[2])).map_err(|e|e.to_string())?;
    if !(5_000..=40_000).contains(&source.len()){return Err("Pinned source byte bounds invalid".into());}
    let names=parse(&source)?;
    let obs=probe(&names)?;
    let data=format!(concat!(
        "{{\n\"schema_version\":1,\n",
        "\"status\":\"pinned_webauthn_libudev_isolated_host_dynamic_abi\",\n",
        "\"original_source_commit\":{},\n\"isolated_host\":{},\n",
        "\"source_declared_udev_soname\":{},\n",
        "\"source_declared_udev_symbols\":[{}],\n",
        "\"source_declared_udev_symbol_count\":{},\n",
        "\"host_resolved_udev_symbol_count\":{},\n",
        "\"initial_noload_found_preexisting_library\":{},\n",
        "\"original_macro_initial_load_branch\":{},\n",
        "\"warm_noload_double_lookup_succeeded\":{},\n",
        "\"original_source_fallback_flags_reproduced\":true,\n",
        "\"all_udev_handles_closed\":true,\n",
        "\"real_host_dlopen_and_dlsym_executed\":true,\n",
        "\"only_isolated_host_abi_proven\":true,\n",
        "\"original_browser_executed\":false,\n",
        "\"real_webauthn_usb_authenticator_exercised\":false,\n",
        "\"libudev_function_called\":false,\n",
        "\"network_egress_allowed\":false,\n",
        "\"target_endeavouros_hyprland_verified\":false,\n",
        "\"runtime_original_browser_libudev_load_observed\":false,\n",
        "\"all_conditional_loader_routes_proven\":false,\n",
        "\"source_pruning_authorized\":false,\n",
        "\"m3_sixth_gate_closed\":false\n}}\n"
    ),quote(SOURCE),quote(&a[3]),quote(obs.loaded_udev_soname),
      names.iter().map(|x|quote(x)).collect::<Vec<_>>().join(","),
      names.len(),obs.resolved_symbols,obs.initial_noload_found,
      quote(obs.initial_path),obs.returned_noload_after_open);
    fs::write(&a[4],data).map_err(|e|e.to_string())?;
    println!("PASS: isolated {} libudev {} with {}/{} source-derived dlsym bindings, warm NOLOAD; no authenticator execution",
        a[3],obs.initial_path,obs.resolved_symbols,names.len());
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]mod tests{
    use super::*;
    #[test]fn source_contract_sanity(){
        assert!(parse("not Firefox").is_err());
        assert_eq!(SYMBOLS,49);
        assert_eq!(RTLD_LAZY|RTLD_GLOBAL,0x101);
        assert_eq!(RTLD_LAZY|RTLD_GLOBAL|RTLD_NOLOAD,0x105);
    }
    #[test]fn host_probe_rejects_missing_symbol(){
        assert!(probe(&["__vulpra_impossible_udev_20261101".to_string()]).is_err());
    }
}
