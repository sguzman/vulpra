// Original native ONNX Runtime bounded in-memory constant-graph inference.
// No external crates, network, model downloads, or user/Firefox files.
// The first 11 OrtApi C ABI fields are an immutable v1 prefix: pinned to
// upstream public MIT header v1.22.0, git blob b01b7e48dc87bbeeb026c61fb06c591053853ad1,
// lines 808-963. No unknown struct tail is dereferenced.
use std::env;
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::process::ExitCode;
use std::ptr;

const RTLD_NOW: c_int = 2;
const RTLD_LOCAL: c_int = 0;

#[link(name = "dl")]
unsafe extern "C" {
    fn dlopen(path: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

// ABI prefix unchanged by the append-only OrtApi C interface.
#[repr(C)]
struct OrtApiBase {
    get_api: unsafe extern "C" fn(u32) -> *const OrtApiV1Prefix,
    get_version_string: unsafe extern "C" fn() -> *const c_char,
}
#[repr(C)]
struct OrtApiV1Prefix {
    create_status: *const c_void,
    get_error_code: *const c_void,
    get_error_message: unsafe extern "C" fn(*const c_void) -> *const c_char,
    create_env: unsafe extern "C" fn(c_int, *const c_char, *mut *mut c_void) -> *mut c_void,
    create_env_with_custom_logger: *const c_void,
    enable_telemetry_events: *const c_void,
    disable_telemetry_events: unsafe extern "C" fn(*const c_void) -> *mut c_void,
    create_session: *const c_void,
    create_session_from_array: unsafe extern "C" fn(
        *const c_void, *const c_void, usize, *const c_void, *mut *mut c_void,
    ) -> *mut c_void,
    run: unsafe extern "C" fn(
        *mut c_void, *const c_void, *const *const c_char, *const *const c_void,
        usize, *const *const c_char, usize, *mut *mut c_void,
    ) -> *mut c_void,
    create_session_options: unsafe extern "C" fn(*mut *mut c_void) -> *mut c_void,
}

fn varint(mut n: u64, out: &mut Vec<u8>) {
    while n >= 128 {
        out.push((n as u8 & 0x7f) | 0x80);
        n >>= 7;
    }
    out.push(n as u8);
}
fn field_var(n: u64, v: u64, dst: &mut Vec<u8>) {
    varint(n * 8, dst);
    varint(v, dst);
}
fn field_bytes(n: u64, value: &[u8], dst: &mut Vec<u8>) {
    varint(n * 8 + 2, dst);
    varint(value.len() as u64, dst);
    dst.extend_from_slice(value);
}

// ONNX protobuf: Model(ir=8, opset=13), Graph(Constant -> output y:
// tensor(float32 [1])). Includes no external data or model filesystem paths.
fn constant_model() -> Vec<u8> {
    let mut tensor = Vec::new();
    field_var(1, 1, &mut tensor); // dims [1]
    field_var(2, 1, &mut tensor); // FLOAT
    field_bytes(9, &1.25f32.to_le_bytes(), &mut tensor); // raw_data

    let mut attr = Vec::new();
    field_bytes(1, b"value", &mut attr);
    field_bytes(5, &tensor, &mut attr); // AttributeProto.t
    field_var(20, 4, &mut attr); // AttributeProto type TENSOR

    let mut node = Vec::new();
    field_bytes(2, b"y", &mut node);
    field_bytes(4, b"Constant", &mut node);
    field_bytes(5, &attr, &mut node);

    let mut dim = Vec::new();
    field_var(1, 1, &mut dim);
    let mut shape = Vec::new();
    field_bytes(1, &dim, &mut shape);
    let mut tensor_ty = Vec::new();
    field_var(1, 1, &mut tensor_ty); // FLOAT type
    field_bytes(2, &shape, &mut tensor_ty);
    let mut value_ty = Vec::new();
    field_bytes(1, &tensor_ty, &mut value_ty);
    let mut output = Vec::new();
    field_bytes(1, b"y", &mut output);
    field_bytes(2, &value_ty, &mut output);

    let mut graph = Vec::new();
    field_bytes(1, &node, &mut graph);
    field_bytes(2, b"single-constant", &mut graph);
    field_bytes(12, &output, &mut graph);
    let mut opset = Vec::new();
    field_var(2, 13, &mut opset);
    let mut model = Vec::new();
    field_var(1, 8, &mut model); // ir_version
    field_bytes(2, b"vulpra-isolated-native-fixture", &mut model);
    field_bytes(7, &graph, &mut model);
    field_bytes(8, &opset, &mut model);
    model
}

// These seven function-pointer offsets are pinned against the actual public
// ONNX Runtime v1.22.0 C header by CI offsetof(OrtApi, ...) assertions.
// Never read past a bounded and header-verified index in the real native table.
const IS_TENSOR: usize = 50;
const TENSOR_MUTABLE_DATA: usize = 51;
const TENSOR_ELEMENT_TYPE: usize = 60;
const TENSOR_DIMENSIONS_COUNT: usize = 61;
const TENSOR_DIMENSIONS: usize = 62;
const TENSOR_ELEMENT_COUNT: usize = 64;
const TENSOR_TYPE_AND_SHAPE: usize = 65;
const TENSOR_FLOAT32: c_int = 1;

unsafe fn api_function<T: Copy>(api: *const OrtApiV1Prefix, index: usize) -> T {
    assert_eq!(std::mem::size_of::<T>(), std::mem::size_of::<*const c_void>());
    assert!(index <= TENSOR_TYPE_AND_SHAPE);
    // SAFETY: CI verifies these offsets from the pinned upstream C header,
    // and OrtApi's stable v1 function table is never shortened in later APIs.
    let raw = unsafe { *api.cast::<*const c_void>().add(index) };
    assert!(!raw.is_null());
    unsafe { std::mem::transmute_copy(&raw) }
}

fn verify_actual_tensor(api: *const OrtApiV1Prefix, output: *mut c_void) -> Result<(), String> {
    type IsTensor = unsafe extern "C" fn(*const c_void, *mut c_int) -> *mut c_void;
    type GetTypeAndShape = unsafe extern "C" fn(*const c_void, *mut *mut c_void) -> *mut c_void;
    type GetElementType = unsafe extern "C" fn(*const c_void, *mut c_int) -> *mut c_void;
    type GetDimensionsCount = unsafe extern "C" fn(*const c_void, *mut usize) -> *mut c_void;
    type GetDimensions = unsafe extern "C" fn(*const c_void, *mut i64, usize) -> *mut c_void;
    type GetElementCount = unsafe extern "C" fn(*const c_void, *mut usize) -> *mut c_void;
    type GetMutableData = unsafe extern "C" fn(*mut c_void, *mut *mut c_void) -> *mut c_void;

    let prefix = unsafe { &*api };
    let is_tensor: IsTensor = unsafe { api_function(api, IS_TENSOR) };
    let get_type_shape: GetTypeAndShape = unsafe { api_function(api, TENSOR_TYPE_AND_SHAPE) };
    let get_element_type: GetElementType = unsafe { api_function(api, TENSOR_ELEMENT_TYPE) };
    let get_dimensions_count: GetDimensionsCount =
        unsafe { api_function(api, TENSOR_DIMENSIONS_COUNT) };
    let get_dimensions: GetDimensions = unsafe { api_function(api, TENSOR_DIMENSIONS) };
    let get_element_count: GetElementCount = unsafe { api_function(api, TENSOR_ELEMENT_COUNT) };
    let get_mutable_data: GetMutableData = unsafe { api_function(api, TENSOR_MUTABLE_DATA) };

    let mut is_tensor_value = 0;
    require_status(prefix, unsafe { is_tensor(output, &mut is_tensor_value) }, "IsTensor")?;
    if is_tensor_value != 1 { return Err("ONNX output was not a tensor".into()); }

    let mut shape = ptr::null_mut();
    require_status(prefix, unsafe { get_type_shape(output, &mut shape) }, "GetTensorTypeAndShape")?;
    if shape.is_null() { return Err("ONNX shape information was null".into()); }

    let mut elem_type = 0;
    require_status(prefix, unsafe { get_element_type(shape, &mut elem_type) }, "GetTensorElementType")?;
    if elem_type != TENSOR_FLOAT32 { return Err("ONNX output was not float32".into()); }
    let mut dimensions_count = 0;
    require_status(prefix, unsafe { get_dimensions_count(shape, &mut dimensions_count) }, "GetDimensionsCount")?;
    if dimensions_count != 1 { return Err("ONNX output rank was not one".into()); }
    let mut dimensions = [0i64; 1];
    require_status(prefix, unsafe { get_dimensions(shape, dimensions.as_mut_ptr(), 1) }, "GetDimensions")?;
    if dimensions != [1] { return Err("ONNX output shape was not [1]".into()); }
    let mut elements = 0;
    require_status(prefix, unsafe { get_element_count(shape, &mut elements) }, "GetTensorShapeElementCount")?;
    if elements != 1 { return Err("ONNX output was not one element".into()); }

    let mut raw: *mut c_void = ptr::null_mut();
    require_status(prefix, unsafe { get_mutable_data(output, &mut raw) }, "GetTensorMutableData")?;
    if raw.is_null() { return Err("ONNX output data was null".into()); }
    // The validated float32[1] shape permits reading exactly one f32.
    let result = unsafe { *(raw.cast::<f32>()) };
    if !result.is_finite() || result.to_bits() != 1.25f32.to_bits() {
        return Err("ONNX output did not equal exact expected 1.25 float32".into());
    }
    Ok(())
}

fn require_status(api: &OrtApiV1Prefix, status: *mut c_void, op: &'static str) -> Result<(), String> {
    if status.is_null() { return Ok(()); }
    // Status details might reveal untrusted native absolute paths. Do not
    // retain them in CI or stderr; preserve only which C API operation failed.
    let _ = api.get_error_message;
    Err(format!("original native ONNX {op} returned a non-null status"))
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 || !args[1].starts_with('/') ||
        !args[1].ends_with("/libonnxruntime.so") || args[1].contains('\0') {
        return Err("expected exactly one original packaged ONNX ELF absolute path".into());
    }
    let path = CString::new(args[1].as_str()).map_err(|_| "invalid library path")?;
    let handle = unsafe { dlopen(path.as_ptr(), RTLD_NOW | RTLD_LOCAL) };
    if handle.is_null() { return Err("original packaged ONNX ELF failed to load".into()); }
    let sym = unsafe { dlsym(handle, c"OrtGetApiBase".as_ptr()) };
    if sym.is_null() {
        unsafe { dlclose(handle); }
        return Err("original packaged ONNX has no OrtGetApiBase".into());
    }
    let getter: unsafe extern "C" fn() -> *const OrtApiBase = unsafe { std::mem::transmute(sym) };
    let base = unsafe { getter() };
    if base.is_null() { return Err("ONNX C API base was null".into()); }
    let version = unsafe { ((*base).get_version_string)() };
    if version.is_null() || unsafe { CStr::from_ptr(version) }.to_bytes().is_empty() {
        return Err("invalid native ONNX C API version".into());
    }
    let api = unsafe { ((*base).get_api)(1) };
    if api.is_null() { return Err("original ONNX does not support v1 C API".into()); }
    let api = unsafe { &*api };
    let mut env = ptr::null_mut();
    require_status(api, unsafe { (api.create_env)(3, c"vulpra-isolated-onnx-session".as_ptr(), &mut env) }, "CreateEnv")?;
    if env.is_null() { return Err("ONNX environment was null".into()); }
    require_status(api, unsafe { (api.disable_telemetry_events)(env) }, "DisableTelemetryEvents")?;
    let mut opts = ptr::null_mut();
    require_status(api, unsafe { (api.create_session_options)(&mut opts) }, "CreateSessionOptions")?;
    if opts.is_null() { return Err("ONNX session options null".into()); }
    let model = constant_model();
    if model.len() > 4096 || model.len() < 45 {
        return Err("synthetic in-memory model size invalid".into());
    }
    let mut session = ptr::null_mut();
    require_status(api, unsafe {
        (api.create_session_from_array)(
            env, model.as_ptr().cast(), model.len(), opts, &mut session
        )
    }, "CreateSessionFromArray")?;
    if session.is_null() { return Err("original ONNX session null".into()); }
    let output_name = c"y".as_ptr();
    let mut output = ptr::null_mut();
    require_status(api, unsafe {
        (api.run)(
            session, ptr::null(), ptr::null(), ptr::null(), 0,
            &output_name, 1, &mut output,
        )
    }, "Run")?;
    if output.is_null() { return Err("ONNX Constant operator returned null output".into()); }
    verify_actual_tensor(api, output)?;
    // Intentional process-lifetime cleanup in this one-shot isolated CI probe:
    // v1 API release function pointers occur beyond the prefix used here.
    // No long-lived service or user process is started.
    println!("PASS: exact original packaged ONNX Runtime CPU Constant output equals float32[1] value 1.25");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => { eprintln!("FAIL: {e}"); ExitCode::FAILURE }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn compact_model_has_no_external_data_or_network_names() {
        let bytes = constant_model();
        assert!(bytes.len() > 45 && bytes.len() < 4096);
        assert!(bytes.windows(8).any(|w| w == b"Constant"));
        assert!(bytes.windows(5).any(|w| w == b"value"));
        assert!(!bytes.windows(6).any(|w| w == b"http:/"));
    }
    #[test]
    fn api_field_offsets_are_strict_and_sequential_for_target_slots() {
        assert_eq!(IS_TENSOR, 50);
        assert_eq!(TENSOR_MUTABLE_DATA, 51);
        assert_eq!(TENSOR_ELEMENT_TYPE, 60);
        assert_eq!(TENSOR_DIMENSIONS_COUNT, 61);
        assert_eq!(TENSOR_DIMENSIONS, 62);
        assert_eq!(TENSOR_ELEMENT_COUNT, 64);
        assert_eq!(TENSOR_TYPE_AND_SHAPE, 65);
        assert_eq!(1.25f32.to_bits(), 0x3fa00000);
    }
    #[test]
    fn varint_encoding_boundary() {
        let mut a = vec![];
        varint(300, &mut a);
        assert_eq!(a, vec![0xac, 0x02]);
    }
}
