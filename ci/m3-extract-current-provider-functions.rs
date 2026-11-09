// Extract the exact bounded C++ function bodies of accepted source-linked
// VA-API and GBM loader owners, for isolated *mock-provider* execution.
// Not a browser binary, not a test of system library presence or actual
// WebDriver fallback. Require fixed source Git blobs and only exact functions.
use std::{fs, path::{Path, PathBuf}, process::Command};

const SOURCE: &str = "bd2499aeadce0368faa8b717b0e8a17e9c9dc317";

struct Target {
    path: &'static str,
    expected_blob: &'static str,
    signature: &'static str,
    output: &'static str,
    anchors: &'static [&'static str],
}

const TARGETS: [Target; 3] = [
    Target {
        path: "dom/media/platforms/ffmpeg/VALibWrapper.cpp",
        expected_blob: "76935cfb49270b0281362d186b65ddbe971f8f97",
        signature: "bool VALibWrapper::LinkVAAPILibs() {",
        output: "real-vaapi-loader.inc",
        anchors: &["libva-drm.so.2", "libva.so.2", "XRE_IsRDDProcess()", "PR_LoadLibraryWithFlags"],
    },
    Target {
        path: "widget/gtk/DMABufDevice.cpp",
        expected_blob: "4fd08d1453edac94bc96deb9a5ed0efcb27dad91",
        signature: "bool GbmLib::IsLoaded() {",
        output: "real-gbm-is-loaded.inc",
        anchors: &["sCreateDevice", "sDrmPrimeHandleToFD", "sDestroySurface"],
    },
    Target {
        path: "widget/gtk/DMABufDevice.cpp",
        expected_blob: "4fd08d1453edac94bc96deb9a5ed0efcb27dad91",
        signature: "bool GbmLib::Load() {",
        output: "real-gbm-load.inc",
        anchors: &["GBMLIB_NAME", "DRMLIB_NAME", "dlopen(", "dlsym(", "return false;"],
    },
];

fn git_blob(root: &Path, path: &str) -> Result<String, String> {
    let out = Command::new("git")
        .arg("-C").arg(root).args(["hash-object", "--", path])
        .output().map_err(|e| format!("Cannot invoke git: {e}"))?;
    if !out.status.success() { return Err(format!("{path}: git hash-object failed")); }
    String::from_utf8(out.stdout).map(|x| x.trim().to_owned()).map_err(|e| e.to_string())
}

fn source_function(s: &str, t: &Target) -> Result<String, String> {
    let start = s.find(t.signature).ok_or_else(|| format!("Missing {}", t.signature))?;
    if s[start + t.signature.len()..].contains(t.signature) {
        return Err(format!("Ambiguous function {}", t.signature));
    }
    let mut depth = 0usize;
    let mut end = None;
    let mut saw_start = false;
    // The exact, blob-authenticated selected functions have no raw-string
    // blocks or braces in unbalanced comments. Reject unbounded inspection.
    for (offset, byte) in s[start..].as_bytes().iter().copied().enumerate() {
        if offset > 16_384 { return Err(format!("Oversized function {}", t.signature)); }
        match byte {
            b'{' => { depth += 1; saw_start = true; }
            b'}' => {
                if depth == 0 { return Err("Invalid brace depth".into()); }
                depth -= 1;
                if saw_start && depth == 0 { end = Some(start + offset + 1); break; }
            }
            _ => {}
        }
    }
    let end = end.ok_or_else(|| format!("Unterminated {}", t.signature))?;
    let body = &s[start..end];
    if body.len() < 150 || body.len() > 15_000 { return Err("Source fragment length outside bounds".into()); }
    for anchor in t.anchors {
        if !body.contains(anchor) {
            return Err(format!("{} missing expected anchor {anchor}", t.signature));
        }
    }
    Ok(format!("// Extracted verbatim from real source, native SHA {SOURCE}\n{body}\n"))
}

fn extract(root: &Path, out: &Path, source: &str) -> Result<(), String> {
    if source != SOURCE { return Err("Native source SHA does not match compiled reference".into()); }
    let meta = fs::symlink_metadata(out).map_err(|e| format!("Output directory inaccessible: {e}"))?;
    if !meta.is_dir() || meta.file_type().is_symlink() { return Err("Unsafe output directory".into()); }
    for t in &TARGETS {
        let file = root.join(t.path);
        let meta = fs::symlink_metadata(&file).map_err(|e| e.to_string())?;
        if !meta.is_file() || meta.file_type().is_symlink() || meta.len() > 1_000_000 {
            return Err(format!("Unsafe source file {}", t.path));
        }
        let blob = git_blob(root, t.path)?;
        if blob != t.expected_blob { return Err(format!("{}: changed original compiled source blob", t.path)); }
        let s = fs::read_to_string(&file).map_err(|e| e.to_string())?;
        let body = source_function(&s, t)?;
        let output = out.join(t.output);
        if output.exists() { return Err(format!("Refuse overwrite {}", output.display())); }
        fs::write(output, body).map_err(|e| e.to_string())?;
    }
    println!("PASS: extracted exactly 3 unchanged source-owned C++ loader function bodies from two compiled Git blobs");
    Ok(())
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let result = if args.len() == 5 && args[1] == "--extract" {
        extract(&PathBuf::from(&args[2]), &PathBuf::from(&args[3]), &args[4])
    } else { Err("usage: tool --extract CHECKOUT_ROOT NEW_OUTPUT_DIR EXACT_NATIVE_SHA".into()) };
    if let Err(e) = result { eprintln!("FAIL: {e}"); std::process::exit(1); }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn check_example() -> Target {
        Target { path:"fixture", expected_blob:"", signature:"bool Box::Load() {",
            output:"x", anchors:&["return false;"] }
    }
    #[test]
    fn balanced_and_duplicate_function_guards() {
        let t=check_example();
        let s=format!("stuff\\nbool Box::Load() {{ if (true) {{ return false; }} /* {} */ return true; }}\\n", "p".repeat(180));
        let body=source_function(&s,&t).unwrap();
        assert!(body.contains("return false;"));
        assert!(!body.contains("stuff\\n"));
        assert!(source_function(&(s.to_owned()+&s),&t).is_err());
        assert!(source_function("bool Box::Load() { return false;", &t).is_err());
        assert!(source_function("bool Box::Load() { return true; }", &t).is_err());
    }
}
