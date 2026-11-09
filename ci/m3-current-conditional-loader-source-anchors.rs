// Source-owning side of three actual current libxul.so loader caller witnesses.
// This validates exact Git blob parity and bounded literal loader/failure guards.
// NOT a proof that the dynamic library exists, fallback works, or FFI is closed.
use std::{fs, path::Path, process::Command};

const SOURCE: &str = "bd2499aeadce0368faa8b717b0e8a17e9c9dc317";
struct Rule {
    id: &'static str,
    path: &'static str,
    blob: &'static str,
    function: &'static str,
    next: &'static str,
    names: &'static [&'static str],
    exact_calls: usize,
    expected_false_returns: usize,
    call: &'static str,
    tokens: &'static [&'static str],
}
const RULES: [Rule; 3] = [
    Rule {
        id: "ffmpeg_runtime_init",
        path: "dom/media/platforms/ffmpeg/FFmpegRuntimeLinker.cpp",
        blob: "c854f34aa71f6fd4146e04ab332d3e0f8a60fb11",
        function: "bool FFmpegRuntimeLinker::Init() {",
        next: "bool FFmpegRuntimeLinker::PreferSystemFFmpegForVulkan()",
        names: &["libavcodec.so.62", "libavcodec.so.60", "libavcodec-ffmpeg.so.58"],
        exact_calls: 1,
        expected_false_returns: 1,
        call: "PR_LoadLibraryWithFlags(",
        tokens: &[
            "if (sLinkStatus != LinkStatus_INIT)",
            "sLinkStatus = LinkStatus_NOT_FOUND;",
            "for (auto lib : sLibs)",
            "lspec.value.pathname = lib;",
            "if (sLibAV.mAVCodecLib)",
            "FFmpegLibWrapper::LinkResult res = sLibAV.Link();",
            "sLinkStatus = LinkStatus_SUCCEEDED;",
            "return false;",
        ],
    },
    Rule {
        id: "vaapi_loader",
        path: "dom/media/platforms/ffmpeg/VALibWrapper.cpp",
        blob: "76935cfb49270b0281362d186b65ddbe971f8f97",
        function: "bool VALibWrapper::LinkVAAPILibs() {",
        next: "bool VALibWrapper::AreVAAPIFuncsAvailable()",
        names: &["libva-drm.so.2", "libva.so.2"],
        exact_calls: 2,
        expected_false_returns: 3,
        call: "PR_LoadLibraryWithFlags(",
        tokens: &[
            "if (!gfx::gfxVars::CanUseHardwareVideoDecoding() || !XRE_IsRDDProcess())",
            "lspec.value.pathname = libDrm;",
            "lspec.value.pathname = lib;",
            "if (!mVALibDrm)",
            "if (mVALib && !PR_FindSymbol(mVALib, \"vaExportSurfaceHandle\"))",
            "PR_UnloadLibrary(mVALib);",
            "if (!mVALib)",
            "return false;",
        ],
    },
    Rule {
        id: "gbm_widget",
        path: "widget/gtk/DMABufDevice.cpp",
        blob: "4fd08d1453edac94bc96deb9a5ed0efcb27dad91",
        function: "bool GbmLib::Load() {",
        next: "DMABufDevice* DMABufDeviceLock::EnsureDMABufDevice()",
        names: &["libgbm.so.1", "libdrm.so.2"],
        exact_calls: 2,
        expected_false_returns: 2,
        call: "dlopen(",
        tokens: &[
            "static bool sTriedToLoad = false;",
            "if (sTriedToLoad)",
            "sGbmLibHandle = dlopen(GBMLIB_NAME, RTLD_LAZY | RTLD_LOCAL);",
            "if (!sGbmLibHandle)",
            "sXf86DrmLibHandle = dlopen(DRMLIB_NAME, RTLD_LAZY | RTLD_LOCAL);",
            "if (!sXf86DrmLibHandle)",
            "sCreateDevice = (CreateDeviceFunc)dlsym(sGbmLibHandle, \"gbm_create_device\");",
            "sLoaded = IsLoaded();",
            "return sLoaded;",
        ],
    },
];

fn bounded_func<'a>(source: &'a str, rule: &Rule) -> Result<&'a str, String> {
    let start = source.find(rule.function).ok_or_else(|| format!("{}: missing source function", rule.id))?;
    if source[start + rule.function.len()..].contains(rule.function) {
        return Err(format!("{}: duplicate function declaration", rule.id));
    }
    let rest = &source[start..];
    let end = rest.find(rule.next).ok_or_else(|| format!("{}: missing following function boundary", rule.id))?;
    if end < 50 || end > 45_000 { return Err(format!("{}: unexpected source function bounds", rule.id)); }
    let body = &rest[..end];
    if body.matches(rule.call).count() != rule.exact_calls {
        return Err(format!("{}: loader call count changed", rule.id));
    }
    if body.matches("return false;").count() != rule.expected_false_returns {
        return Err(format!("{}: conditional failure-exit count changed", rule.id));
    }
    // The GBM loader has *two* return sLoaded paths: a repeated load
    // short-circuit and the final availability decision. Losing either one
    // must fail the semantic negative fixture even if the other remains.
    if rule.id == "gbm_widget" && body.matches("return sLoaded;").count() != 2 {
        return Err("GBM duplicate state-return path count changed".into());
    }
    for token in rule.tokens {
        if !body.contains(token) {
            return Err(format!("{}: source guard/library/failure anchor missing: {token}", rule.id));
        }
    }
    Ok(body)
}

fn validate(rule: &Rule, source: &str) -> Result<(), String> {
    if source.len() > 1_000_000 || source.len() < 500 {
        return Err(format!("{}: unexpected source length", rule.id));
    }
    // Names must be in this current source file, not necessarily inside the
    // loader function (FFmpeg candidate array, GBM macros precede it).
    for name in rule.names {
        if !source.contains(&format!("\"{name}\"")) {
            return Err(format!("{}: missing literal source loader-name candidate {name}", rule.id));
        }
    }
    let _ = bounded_func(source, rule)?;
    // Additional source-specific context. Do not claim execution or fallback.
    if rule.id == "ffmpeg_runtime_init" {
        if !source.contains("static const char* sLibs[]") ||
           !source.contains("\"libavcodec.so.\" FFMPEG_MAX_MAJOR_VERSION_STR(FFMPEG_MAX_MAJOR_VERSION)") {
            return Err("FFmpeg candidate array/compile-time max-version name changed".into());
        }
    } else if rule.id == "gbm_widget" &&
      (!source.contains("#define GBMLIB_NAME \"libgbm.so.1\"") ||
       !source.contains("#define DRMLIB_NAME \"libdrm.so.2\"")) {
        return Err("GBM macro names changed".into());
    }
    Ok(())
}

fn git(root: &Path, args: &[&str]) -> Result<String, String> {
    let out = Command::new("git").arg("-C").arg(root).args(args).output()
        .map_err(|e| format!("git unavailable: {e}"))?;
    if !out.status.success() { return Err(format!("git {:?} failed", args)); }
    String::from_utf8(out.stdout).map(|s| s.trim().to_string()).map_err(|e| e.to_string())
}

fn audit(root: &Path, source_commit: &str, output: &Path) -> Result<(), String> {
    if source_commit != SOURCE { return Err("Only exact previously authenticated compiled source supported".into()); }
    let mut rows = Vec::new();
    for rule in &RULES {
        let file = root.join(rule.path);
        let meta = fs::symlink_metadata(&file).map_err(|e| format!("{}: {e}", rule.path))?;
        if !meta.is_file() || meta.len() > 1_000_000 || meta.len() < 500 {
            return Err(format!("{}: source missing, symlinked or outside bounds", rule.path));
        }
        let from_git = git(root, &["rev-parse", &format!("HEAD:{}", rule.path)])?;
        let from_bytes = git(root, &["hash-object", "--", rule.path])?;
        if from_git != rule.blob || from_bytes != rule.blob {
            return Err(format!("{}: checkout/working-tree source blob diverges from compiled SHA", rule.path));
        }
        let src = fs::read_to_string(&file).map_err(|e| e.to_string())?;
        validate(rule, &src)?;
        rows.push(format!(
            "    {{\"id\":\"{}\",\"source_path\":\"{}\",\"exact_compiled_source_git_blob\":\"{}\",\"literal_name_candidates\":{},\"source_guard_and_failure_anchors_observed\":true,\"runtime_requested_library_name_verified\":false,\"missing_library_fallback_exercised\":false}}",
            rule.id, rule.path, rule.blob,
            match rule.id { "ffmpeg_runtime_init" => 3, _ => 2 }
        ));
    }
    let json = format!(concat!(
        "{{\n  \"schema_version\":1,\n",
        "  \"status\":\"three_current_source_owned_conditional_loader_name_and_failure_guards\",\n",
        "  \"native_source_commit\":\"{}\",\n",
        "  \"source_rows\":[\n{}\n  ],\n",
        "  \"source_rows_count\":3,\n",
        "  \"source_literal_library_candidates_checked\":7,\n",
        "  \"compiled_native_branch_reconciliation_performed_by_this_observer\":false,\n",
        "  \"library_names_at_actual_machine_call_arguments_verified\":false,\n",
        "  \"all_indirect_loader_and_symbol_edges_known\":false,\n",
        "  \"source_guards_exercised_at_runtime\":false,\n",
        "  \"safe_feature_fallback_proven\":false,\n",
        "  \"target_endeavouros_hyprland_tested\":false,\n",
        "  \"source_pruning_authorized\":false,\n",
        "  \"m3_sixth_gate_closed\":false,\n",
        "  \"release_ready\":false\n}}\n"
    ), source_commit, rows.join(",\n"));
    fs::write(output, json).map_err(|e| e.to_string())?;
    println!("PASS: three current source-blob owners, seven literal provider candidates and three bounded loader/failure guard functions");
    println!("LIMIT: source literals, not machine argument tracing, runtime fallback, indirect closure, pruning or release");
    Ok(())
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    let result = if args.len() == 5 && args[1] == "--audit" {
        audit(Path::new(&args[2]), &args[3], Path::new(&args[4]))
    } else {
        Err("usage: source-anchors --audit ROOT AUTHENTICATED_NATIVE_SOURCE_SHA OUTPUT_JSON".into())
    };
    if let Err(e) = result { eprintln!("FAIL: {e}"); std::process::exit(1); }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn all_original_source_anchors_are_present() {
        for rule in &RULES {
            let src = fs::read_to_string(rule.path).unwrap();
            validate(rule, &src).unwrap();
        }
    }
    #[test]
    fn deliberate_library_and_guard_mutations_rejected() {
        for rule in &RULES {
            let src = fs::read_to_string(rule.path).unwrap();
            for name in rule.names {
                let altered = src.replacen(&format!("\"{name}\""), "\"libbogus.so.999\"", 1);
                assert!(validate(rule, &altered).is_err(), "{}: altered library {name} passed", rule.id);
            }
            for anchor in rule.tokens {
                let altered = src.replacen(anchor, "REMOVED_GUARD_OR_FALLBACK", 1);
                assert!(validate(rule, &altered).is_err(), "{}: changed source anchor {anchor} passed", rule.id);
            }
            let altered = src.replacen(rule.call, "FAKE_LOADER(", 1);
            assert!(validate(rule, &altered).is_err(), "{}: fake direct loader passed", rule.id);
        }
    }
}
