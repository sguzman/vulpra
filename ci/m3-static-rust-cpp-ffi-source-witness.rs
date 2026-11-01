// Bounded, source-pinned Rust-to-C++ static FFI witness for the two exact
// emitted original Mozilla Rust staticlib -> native consumers.
// Structural source/call graph only; NOT a full final native symbol map.
use std::fs;
use std::path::Path;
fn read(root:&Path,path:&str)->Result<String,String>{
    fs::read_to_string(root.join(path)).map_err(|e|format!("Missing pinned source {path}: {e}"))
}
fn must(text:&str,needle:&str,reason:&str)->Result<(),String>{
    if !text.contains(needle){return Err(format!("Missing original FFI anchor: {reason}"));}
    Ok(())
}
fn times(text:&str,needle:&str)->usize{text.match_indices(needle).count()}
fn scope_no_mangle(text:&str,signature:&str)->Result<(),String>{
    let offset=text.find(signature).ok_or("Missing pinned Rust FFI symbol")?;
    let before=&text[..offset];
    let last=before.lines().rev().take(5).collect::<Vec<_>>();
    if !last.iter().any(|s|s.trim()=="#[no_mangle]"){
        return Err(format!("No immediately preceding unmangled Rust export: {signature}"));
    }
    Ok(())
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=3{return Err("usage: ffi-source-witness PINNED_SOURCE_ROOT JSON".into());}
    let root=Path::new(&args[1]);
    let cxx=read(root,"xpcom/build/XPCOMInit.cpp")?;
    let shared=read(root,"toolkit/library/rust/shared/lib.rs")?;
    let rust_root=read(root,"toolkit/library/rust/lib.rs")?;
    let rust_cargo=read(root,"toolkit/library/rust/Cargo.toml")?;
    let rust_moz=read(root,"toolkit/library/rust/moz.build")?;
    let build_moz=read(root,"toolkit/library/build/moz.build")?;
    let crash_cpp=read(root,"toolkit/crashreporter/crash_helper/crashhelper.cpp")?;
    let crash_rust=read(root,"toolkit/crashreporter/crash_helper_server/src/lib.rs")?;
    let crash_cargo=read(root,"toolkit/crashreporter/crash_helper_server/Cargo.toml")?;
    let crash_src_moz=read(root,"toolkit/crashreporter/crash_helper_server/moz.build")?;
    let crash_bin_moz=read(root,"toolkit/crashreporter/crash_helper/moz.build")?;

    must(&cxx,"extern \"C\" void GkRust_Init();","C++ gkrust startup declaration")?;
    must(&cxx,"extern \"C\" void GkRust_Shutdown();","C++ gkrust shutdown declaration")?;
    if times(&cxx,"GkRust_Init();")!=3||times(&cxx,"GkRust_Shutdown();")!=2{
        // First match each is declaration; the rest are actual direct call sites.
        return Err("Original C++ gkrust initialization/shutdown callsite count drift".into());
    }
    for symbol in ["GkRust_Init","GkRust_Shutdown"]{
        let signature=format!("pub extern \"C\" fn {symbol}(");
        must(&shared,&signature,"unmangled Rust gkrust source")?;
        scope_no_mangle(&shared,&signature)?;
    }
    must(&rust_root,"extern crate gkrust_shared;","gkrust Rust root includes shared module")?;
    must(&rust_cargo,"crate-type = [\"staticlib\"]","native gkrust archive")?;
    must(&rust_cargo,"gkrust-shared = { path = \"shared\" }","gkrust shared Rust dependency")?;
    must(&rust_moz,"RustLibrary(\"gkrust\", gkrust_features, is_gkrust=True)",
        "Mozilla gkrust native build declaration")?;
    must(&build_moz,"USE_LIBS += [\"gkrust\"]","native libxul gkrust static archive dependency")?;

    must(&crash_cpp,"#include \"mozilla/crash_helper_ffi_generated.h\"",
        "native crash helper generated header")?;
    must(&crash_cpp,"int res = crash_generator_logic_desktop(client_pid, client_handle,",
        "actual C++ native -> Rust desktop crash handling call")?;
    if times(&crash_cpp,"crash_generator_logic_desktop(")!=1{
        return Err("Unexpected crashhelper desktop FFI callsite count".into());
    }
    let crash_sig="pub unsafe extern \"C\" fn crash_generator_logic_desktop(";
    must(&crash_rust,crash_sig,"Rust crash helper desktop export")?;
    scope_no_mangle(&crash_rust,crash_sig)?;
    must(&crash_rust,"#[cfg(not(target_os = \"android\"))]",
        "Rust desktop crash helper gate")?;
    must(&crash_cargo,"crate-type = [\"staticlib\"]",
        "Rust crash helper native static archive")?;
    must(&crash_src_moz,"RustLibrary(\"crash_helper_server\")",
        "Mozilla crash helper RustLibrary")?;
    must(&crash_src_moz,"CbindgenHeader(","generated FFI header generator")?;
    must(&crash_src_moz,"\"crash_helper_ffi_generated.h\",",
        "generated named FFI header")?;
    must(&crash_src_moz,"\"!crash_helper_ffi_generated.h\",",
        "generated FFI header dist export")?;
    must(&crash_bin_moz,"\"crash_helper_server\",",
        "Mozilla crashhelper staticlib link declaration")?;
    must(&crash_bin_moz,"\"crashhelper.cpp\",",
        "Mozilla crashhelper C++ build input")?;
    must(&crash_bin_moz,"GeckoProgram(\"crashhelper\", linkage=None)",
        "native crash helper executable")?;

    let result=format!(
      "{{\"schema_version\":1,\
       \"status\":\"pinned_original_two_rust_staticlib_cpp_source_ffi_seams_verified\",\
       \"source_commit\":\"b1482404dfb8b01342990ee99ea3df0f9756b5f7\",\
       \"native_staticlib_roots\":2,\
       \"native_consumer_targets\":2,\
       \"cpp_callsite_functions\":3,\
       \"gkrust_init_cpp_calls\":2,\
       \"gkrust_shutdown_cpp_calls\":1,\
       \"crash_generator_logic_desktop_cpp_calls\":1,\
       \"ffi_edges\":[\
         {{\"rust_staticlib\":\"libgkrust.a\",\
           \"cpp_consumer\":\"libxul.so\",\
           \"source_export\":\"GkRust_Init\",\
           \"source_header\":\"xpcom/build/XPCOMInit.cpp\"}},\
         {{\"rust_staticlib\":\"libgkrust.a\",\
           \"cpp_consumer\":\"libxul.so\",\
           \"source_export\":\"GkRust_Shutdown\",\
           \"source_header\":\"xpcom/build/XPCOMInit.cpp\"}},\
         {{\"rust_staticlib\":\"libcrash_helper_server.a\",\
           \"cpp_consumer\":\"crashhelper\",\
           \"source_export\":\"crash_generator_logic_desktop\",\
           \"source_header\":\"toolkit/crashreporter/crash_helper/crashhelper.cpp\"}}],\
       \"rust_no_mangle_and_extern_c_source_confirmed\":true,\
       \"cpp_declarations_or_generated_cbindgen_bridge_confirmed\":true,\
       \"original_native_link_declarations_confirmed\":true,\
       \"actual_compiled_ffi_symbols_or_relocations_verified\":false,\
       \"all_static_rust_cpp_ffi_edges_identified\":false,\
       \"conditional_dlopen_closure_proven\":false,\
       \"source_removal_authorized\":false,\"m3_sixth_gate_closed\":false}}\n"
    );
    fs::write(&args[2],result).map_err(|e|e.to_string())?;
    println!("PASS: three pinned original C++ to Rust source FFI callsite functions, two staticlib roots");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]
    fn requires_unmangled_export_near_function(){
        let source="#[no_mangle]\npub extern \"C\" fn A() {}\n";
        assert!(scope_no_mangle(source,"pub extern \"C\" fn A(").is_ok());
        let wrong="#[no_mangle]\nfn unrelated() {}\nfn extra() {}\nfn other() {}\nfn x() {}\nfn z() {}\npub extern \"C\" fn B() {}\n";
        assert!(scope_no_mangle(wrong,"pub extern \"C\" fn B(").is_err());
    }
    #[test]
    fn fixed_callsite_count_includes_declaration(){
        let source="extern \"C\" void GkRust_Init();\n  GkRust_Init();\n  GkRust_Init();";
        assert_eq!(times(source,"GkRust_Init();"),3);
    }
}
