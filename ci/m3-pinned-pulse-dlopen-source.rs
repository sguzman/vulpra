// Exact two-revision source proof for Mozilla's optional PulseAudio dlopen path.
// A source/call-route witness, NOT proof of exercised native call stacks or full loader closure.
use std::{fs, path::Path};
const GECKO: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const CUBEB: &str = "88194f91c8778fa608a19af7b91306094525595d";
fn read(root: &Path, file: &str) -> Result<String, String> {
    fs::read_to_string(root.join(file)).map_err(|e| format!("Missing pinned source {file}: {e}"))
}
fn anchor(source: &str, fragment: &str, label: &str) -> Result<(), String> {
    if !source.contains(fragment) { return Err(format!("Missing pinned PulseAudio route: {label}")); }
    Ok(())
}
fn verify(gecko: &Path, external: &Path) -> Result<(), String> {
    let config = read(gecko, "toolkit/library/rust/shared/Cargo.toml")?;
    anchor(&config, "git = \"https://github.com/mozilla/cubeb-pulse-rs\", rev=\"88194f91c8778fa608a19af7b91306094525595d\"", "exact external Git dependency")?;
    anchor(&config, "features=[\"pulse-dlopen\"]", "requested Rust feature")?;
    let features = read(gecko, "toolkit/library/rust/gkrust-features.mozbuild")?;
    anchor(&features, "cubeb_pulse_rust", "Gecko cargo feature selector")?;
    let moz = read(gecko, "media/libcubeb/src/moz.build")?;
    anchor(&moz, "CONFIG['MOZ_PULSEAUDIO']", "generated PulseAudio config guard")?;
    anchor(&moz, "DEFINES['USE_PULSE_RUST'] = True", "C API Rust backend guard")?;
    let c = read(gecko, "media/libcubeb/src/cubeb.c")?;
    anchor(&c, "pulse_rust_init", "C backend registered Rust entrypoint")?;
    let cargo = read(external, "Cargo.toml")?;
    anchor(&cargo, "pulse-dlopen = [\"pulse-ffi/dlopen\"]", "feature forwarding to pulse-ffi")?;
    let ffi_cargo = read(external, "pulse-ffi/Cargo.toml")?;
    anchor(&ffi_cargo, "dlopen = []", "pulse-ffi dynamic feature")?;
    let api = read(external, "src/capi.rs")?;
    anchor(&api, "#[no_mangle]\npub unsafe extern \"C\" fn pulse_rust_init(", "unmangled Rust C ABI entrypoint")?;
    anchor(&api, "capi::capi_init::<PulseContext>(c, context_name)", "C ABI to backend dispatch")?;
    let context = read(external, "src/backend/context.rs")?;
    anchor(&context, "#[cfg(feature = \"pulse-dlopen\")]\n    fn _new(", "feature-conditional backend constructor")?;
    anchor(&context, "let libpulse = match unsafe { open() }", "PulseContext opens optional library")?;
    anchor(&context, "None => {", "backend handles absent library")?;
    let ffi = read(external, "pulse-ffi/src/lib.rs")?;
    anchor(&ffi, "#[cfg(feature = \"dlopen\")]\npub unsafe fn open()", "feature-gated loader wrapper")?;
    anchor(&ffi, "LibLoader::open()", "wrapper calls native loader")?;
    let dynamic = read(external, "pulse-ffi/src/ffi_funcs.rs")?;
    anchor(&dynamic, "#[cfg(feature = \"dlopen\")]\nmod dynamic_fns", "dynamic library feature module")?;
    anchor(&dynamic, "let h = dlopen(cstr!(\"libpulse.so.0\"), RTLD_LAZY);", "exact libpulse.so.0 runtime dlopen")?;
    anchor(&dynamic, "let fp = dlsym(h, cstr!(\"pa_get_library_version\"));", "dynamic function resolution")?;
    Ok(())
}
fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 6 || args[1] != GECKO || args[2] != CUBEB {
        return Err("usage: pulse-dlopen-source GECKO_SHA CUBEB_SHA GECKO_ROOT CUBEB_ROOT OUTPUT_JSON".into());
    }
    verify(Path::new(&args[3]), Path::new(&args[4]))?;
    let evidence = format!(
       "{{\n  \"schema_version\": 1,\n  \"gecko_source_commit\": \"{GECKO}\",\n  \"external_cubeb_source_commit\": \"{CUBEB}\",\n  \"conditional_pulse_dlopen_source_route_verified\": true,\n  \"requested_library\": \"libpulse.so.0\",\n  \"runtime_loader_invocation_observed_at_source\": true,\n  \"native_callstack_attribution_proven\": false,\n  \"all_conditional_dynamic_loads_mapped\": false,\n  \"m3_sixth_gate_closed\": false,\n  \"source_removal_authorized\": false\n}}\n"
    );
    fs::write(&args[5], evidence).map_err(|e| e.to_string())?;
    println!("PASS: pinned Gecko→cubeb-pulse-rs→pulse-ffi libpulse.so.0 dlopen source route");
    Ok(())
}
fn main() {
    if let Err(e) = run() { eprintln!("FAIL: {e}"); std::process::exit(1); }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn missing_anchor_fails_closed() {
        assert!(anchor("dlopen(other)", "libpulse.so.0", "lib").is_err());
        assert!(anchor("libpulse.so.0", "libpulse.so.0", "lib").is_ok());
    }
    #[test] fn missing_source_tree_fails_closed() {
        assert!(verify(Path::new("/definitely-missing-gecko"),
                       Path::new("/definitely-missing-cubeb")).is_err());
    }
}
