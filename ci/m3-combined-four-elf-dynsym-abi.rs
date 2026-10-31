// Bounded read-only ABI-surface comparison of two source-matched Vulpra packages.
// Dynamic exported symbols are NOT internal Rust/C++ FFI, dlopen, or linker proof.
// Uses system readelf on checksum-authenticated package members; runs no ELF code.
use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;

type Symbols = BTreeMap<String, usize>;
type Inventory = BTreeMap<String, Symbols>;

fn dynamic_symbols(output: &str, undefined: bool) -> Result<Symbols, String> {
    let mut symbols = Symbols::new();
    for line in output.lines() {
        let fields: Vec<_> = line.split_whitespace().collect();
        if fields.len() < 7 || fields[0].strip_suffix(':').and_then(|v| v.parse::<usize>().ok()).is_none() {
            continue;
        }
        if fields.len() < 8 {
            continue; // the ELF null symbol has no name
        }
        let (kind, binding, visibility, ndx, name) =
            (fields[3], fields[4], fields[5], fields[6], fields[7]);
        if (ndx == "UND") != undefined || binding == "LOCAL" || name.is_empty() {
            continue;
        }
        if !["GLOBAL", "WEAK", "UNIQUE"].contains(&binding) {
            return Err(format!("Unrecognized exported symbol binding: {binding}"));
        }
        // Ndx for defined symbols is a section index: omit it because two
        // valid link layouts may assign different section numbers.
        let record = format!("{kind}|{binding}|{visibility}|{name}");
        *symbols.entry(record).or_default() += 1;
    }
    Ok(symbols)
}

fn exported_symbols(output: &str) -> Result<Symbols, String> {
    dynamic_symbols(output, false)
}

fn imported_symbols(output: &str) -> Result<Symbols, String> {
    dynamic_symbols(output, true)
}

fn paths(root: &Path) -> Result<Vec<PathBuf>, String> {
    let mut stack = vec![(root.to_path_buf(), 0usize)];
    let mut found = Vec::new();
    let mut scanned = 0usize;
    while let Some((dir, depth)) = stack.pop() {
        if depth > 12 { return Err("Unexpectedly deep package".into()); }
        for entry in fs::read_dir(&dir).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            scanned += 1;
            if scanned > 100_000 { return Err("Unexpectedly large package tree".into()); }
            let t = entry.file_type().map_err(|e| e.to_string())?;
            if t.is_symlink() { continue; }
            if t.is_dir() { stack.push((entry.path(), depth + 1)); continue; }
            if !t.is_file() { continue; }
            let mut f = File::open(entry.path()).map_err(|e| e.to_string())?;
            let mut magic = [0u8; 4];
            if f.read_exact(&mut magic).is_ok() && magic == [0x7f, b'E', b'L', b'F'] {
                found.push(entry.path());
            }
        }
    }
    found.sort();
    if found.len() != 28 {
        return Err(format!("Expected 28 authenticated original packaged ELF files, found {}", found.len()));
    }
    Ok(found)
}

fn inventory(root: &Path) -> Result<(Inventory, Inventory), String> {
    let mut data = Inventory::new();
    let mut imports = Inventory::new();
    for file in paths(root)? {
        let rel = file.strip_prefix(root).map_err(|e| e.to_string())?
            .to_str().ok_or("Non-UTF8 ELF path")?.to_string();
        let output = Command::new("readelf").args(["--wide", "--dyn-syms", "--"])
            .arg(&file).output().map_err(|e| e.to_string())?;
        if !output.status.success() {
            return Err(format!("readelf failed on {rel}"));
        }
        let stdout = String::from_utf8(output.stdout).map_err(|e| e.to_string())?;
        let syms = exported_symbols(&stdout)?;
        let undefined = imported_symbols(&stdout)?;
        // Nonempty symbol tables for packaged binaries/libraries are expected.
        // Empty is allowed on an ELF with no exports, but not as a global result.
        imports.insert(rel.clone(), undefined);
        data.insert(rel, syms);
    }
    if data.values().all(|v| v.is_empty()) {
        return Err("No exported dynamic symbols seen in any packaged ELF".into());
    }
    Ok((data, imports))
}

fn json_quote(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            v if v < ' ' => out.push_str(&format!("\\u{:04x}", v as u32)),
            v => out.push(v),
        }
    }
    out.push('"');
    out
}

fn compare(full: &Inventory, lean: &Inventory) -> Result<String, String> {
    let a: BTreeSet<_> = full.keys().collect();
    let b: BTreeSet<_> = lean.keys().collect();
    if a != b { return Err("Full/lean 28-ELF path sets differ".into()); }
    let mut different_records = 0usize;
    let mut full_only = 0usize;
    let mut lean_only = 0usize;
    let mut changed_files = Vec::new();
    let mut samples = Vec::new();
    let mut per_file = Vec::new();
    let mut total_full = 0usize;
    let mut total_lean = 0usize;
    for (file, normal) in full {
        let stripped = lean.get(file).ok_or("Missing lean ELF")?;
        let n: usize = normal.values().sum();
        let m: usize = stripped.values().sum();
        total_full += n;
        total_lean += m;
        let mut changes = 0usize;
        for key in normal.keys().chain(stripped.keys()).collect::<BTreeSet<_>>() {
            let f = normal.get(key).copied().unwrap_or_default();
            let l = stripped.get(key).copied().unwrap_or_default();
            if f != l {
                changes += 1;
                different_records += 1;
                full_only += f.saturating_sub(l);
                lean_only += l.saturating_sub(f);
                if samples.len() < 20 {
                    samples.push(format!("{}: {} full={} lean={}", file, key, f, l));
                }
            }
        }
        if changes != 0 { changed_files.push(file.clone()); }
        per_file.push(format!(
            "{{\"path\":{},\"full_exports\":{},\"lean_exports\":{},\"changed_export_records\":{}}}",
            json_quote(file), n, m, changes
        ));
    }
    let changed = changed_files.iter().map(|x| json_quote(x)).collect::<Vec<_>>().join(",");
    let samples = samples.iter().map(|x| json_quote(x)).collect::<Vec<_>>().join(",");
    Ok(format!(
        "{{\"schema_version\":1,\"status\":\"compiled_full_vs_four_optin_elf_dynamic_exports_compared\",\
        \"original_full_elf_count\":{},\"combined_lean_elf_count\":{},\
        \"full_exported_symbol_occurrences\":{},\"lean_exported_symbol_occurrences\":{},\
        \"changed_export_records\":{},\"full_only_symbol_occurrences\":{},\"lean_only_symbol_occurrences\":{},\
        \"exact_exported_dynamic_abi_parity\":{},\"changed_elf_paths\":[{}],\
        \"bounded_difference_samples\":[{}],\"per_elf\":[{}],\
        \"actual_compiled_elf_dynamics_examined\":true,\"all_rust_cpp_ffi_and_static_symbols_proven\":false,\
        \"runtime_dlopen_closure_proven\":false,\"binary_size_reduction_proven\":false,\
        \"source_removal_authorized\":false,\"m3_sixth_gate_closed\":false}}\n",
        full.len(), lean.len(), total_full, total_lean, different_records, full_only, lean_only,
        if different_records == 0 { "true" } else { "false" }, changed, samples, per_file.join(",")
    ))
}

fn compare_undefined_imports(full: &Inventory, lean: &Inventory)
    -> Result<(usize, usize, usize, Vec<String>), String> {
    if full.keys().collect::<Vec<_>>() != lean.keys().collect::<Vec<_>>() {
        return Err("ELF paths mismatch during undefined import comparison".into());
    }
    let (mut n, mut m, mut different) = (0usize, 0usize, 0usize);
    let mut samples = Vec::new();
    for (path, normal) in full {
        let other = lean.get(path).ok_or("Missing lean ELF import inventory")?;
        n += normal.values().sum::<usize>();
        m += other.values().sum::<usize>();
        for name in normal.keys().chain(other.keys()).collect::<BTreeSet<_>>() {
            let a = normal.get(name).copied().unwrap_or_default();
            let b = other.get(name).copied().unwrap_or_default();
            if a != b {
                different += 1;
                if samples.len() < 20 {
                    samples.push(format!("{path}: {name} full={a} lean={b}"));
                }
            }
        }
    }
    Ok((n, m, different, samples))
}

// Compare actual .text bytes after discarding differing ELF headers/metadata.
// No browser or library is executed.
fn text_overlap_diff(a: &Path, b: &Path) -> Result<(u64, u64, u64), String> {
    let na = fs::metadata(a).map_err(|e| e.to_string())?.len();
    let nb = fs::metadata(b).map_err(|e| e.to_string())?.len();
    let mut fa = File::open(a).map_err(|e| e.to_string())?;
    let mut fb = File::open(b).map_err(|e| e.to_string())?;
    let mut aa = [0u8; 65536];
    let mut bb = [0u8; 65536];
    let mut left = na.min(nb);
    let mut mismatches = 0u64;
    while left > 0 {
        let size = left.min(aa.len() as u64) as usize;
        fa.read_exact(&mut aa[..size]).map_err(|e| e.to_string())?;
        fb.read_exact(&mut bb[..size]).map_err(|e| e.to_string())?;
        mismatches += aa[..size].iter().zip(&bb[..size])
            .filter(|(a,b)| a != b).count() as u64;
        left -= size as u64;
    }
    Ok((na, nb, mismatches))
}

fn compare_text_sections(full_root: &Path, lean_root: &Path, files: &Inventory)
    -> Result<(usize, usize, Vec<String>, Vec<String>), String> {
    let scratch = std::env::temp_dir().join(format!("vulpra-m3-text-{}", std::process::id()));
    fs::create_dir(&scratch).map_err(|e| format!("Temporary section directory: {e}"))?;
    let result = (|| -> Result<(usize, usize, Vec<String>, Vec<String>), String> {
        let (mut equal, mut different) = (0usize, 0usize);
        let mut samples = Vec::new();
        let mut byte_details = Vec::new();
        for (index, name) in files.keys().enumerate() {
            let a = scratch.join(format!("full-{index}.text"));
            let b = scratch.join(format!("lean-{index}.text"));
            for (source, dest) in [(full_root.join(name), &a), (lean_root.join(name), &b)] {
                let output = Command::new("objcopy")
                    .arg(format!("--dump-section=.text={}", dest.display()))
                    .arg(&source)
                    .output().map_err(|e| e.to_string())?;
                if !output.status.success() || !dest.is_file() {
                    return Err(format!("Unable to extract .text from {name}; status {:?}", output.status.code()));
                }
            }
            let status = Command::new("cmp").arg("-s").arg(&a).arg(&b)
                .status().map_err(|e| e.to_string())?;
            match status.code() {
                Some(0) => equal += 1,
                Some(1) => {
                    different += 1;
                    samples.push(name.clone());
                    let (full_bytes, lean_bytes, changed_overlap_bytes) = text_overlap_diff(&a, &b)?;
                    byte_details.push(format!("{name}: full_bytes={full_bytes} lean_bytes={lean_bytes} changed_byte_offsets_in_common_prefix={changed_overlap_bytes}"));
                },
                other => return Err(format!("Cannot compare .text of {name}: {other:?}")),
            }
            fs::remove_file(a).map_err(|e| e.to_string())?;
            fs::remove_file(b).map_err(|e| e.to_string())?;
        }
        Ok((equal, different, samples, byte_details))
    })();
    fs::remove_dir_all(&scratch).map_err(|e| e.to_string())?;
    result
}

fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 4 { return Err("usage: elf-dynsym-abi FULL_EXTRACTED LEAN_EXTRACTED REPORT_JSON".into()); }
    let (full, full_imports) = inventory(Path::new(&args[1]))?;
    let (lean, lean_imports) = inventory(Path::new(&args[2]))?;
    let exported = compare(&full, &lean)?;
    let (normal_undefined, lean_undefined, differing_undefined, samples) =
        compare_undefined_imports(&full_imports, &lean_imports)?;
    if normal_undefined == 0 || lean_undefined == 0 {
        return Err("No undefined dynamic symbol imports observed".into());
    }
    let sample_json = samples.iter().map(|s| json_quote(s))
        .collect::<Vec<_>>().join(",");
    let start = exported.trim().strip_suffix('}')
        .ok_or("Invalid internal exported report")?;
    let result = format!("{start},\"full_undefined_import_symbol_occurrences\":{normal_undefined},\"lean_undefined_import_symbol_occurrences\":{lean_undefined},\"differing_undefined_import_records\":{differing_undefined},\"exact_undefined_dynamic_import_parity\":{},\"bounded_undefined_import_difference_samples\":[{sample_json}]}}\n", differing_undefined == 0);
    let (equal_text, different_text, changed_text_names, changed_text_details) =
        compare_text_sections(Path::new(&args[1]), Path::new(&args[2]), &full)?;
    if equal_text + different_text != 28 { return Err("Incomplete .text comparison".into()); }
    let changed_text_json = changed_text_names.iter().map(|s| json_quote(s))
        .collect::<Vec<_>>().join(",");
    let changed_text_details_json = changed_text_details.iter().map(|s| json_quote(s))
        .collect::<Vec<_>>().join(",");
    let base = result.trim().strip_suffix('}')
        .ok_or("Invalid generated dynamic ABI report")?;
    let result = format!("{base},\"text_sections_compared\":28,\"text_sections_equal\":{equal_text},\"text_sections_different\":{different_text},\"changed_text_elf_paths\":[{changed_text_json}],\"differing_text_section_byte_metrics\":[{changed_text_details_json}],\"only_text_section_bytes_examined\":true}}\n");
    fs::write(&args[3], result).map_err(|e| e.to_string())?;
    println!("PASS: compared exported dynamic symbols for 28 exact-path compiled ELF files");
    Ok(())
}
fn main() { if let Err(e) = run() { eprintln!("FAIL: {e}"); std::process::exit(1); } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn decode_binding_and_versions() {
        let sample = "Num: Value Size Type Bind Vis Ndx Name\n\
            0: 0000000 0 NOTYPE LOCAL DEFAULT UND\n\
            1: 0000001 9 FUNC GLOBAL DEFAULT 15 foo@@LIB_1\n\
            2: 0000002 0 FUNC GLOBAL DEFAULT UND printf@GLIBC_2 (2)\n\
            3: 0000003 4 OBJECT WEAK DEFAULT ABS bar\n\
            4: 0000004 0 FUNC LOCAL DEFAULT 14 internal\n";
        let x = exported_symbols(sample).unwrap();
        assert_eq!(x.len(), 2);
        assert_eq!(x.get("FUNC|GLOBAL|DEFAULT|foo@@LIB_1"), Some(&1));
        assert_eq!(x.get("OBJECT|WEAK|DEFAULT|bar"), Some(&1));
        let imports = imported_symbols(sample).unwrap();
        assert_eq!(imports.get("FUNC|GLOBAL|DEFAULT|printf@GLIBC_2"), Some(&1));
    }
    #[test]
    fn capture_differences_without_suppressing_them() {
        let mut a=Inventory::new();
        let mut b=Inventory::new();
        a.insert("vulpra/libxul.so".into(), BTreeMap::from([("FUNC|GLOBAL|DEFAULT|x".into(),1)]));
        b.insert("vulpra/libxul.so".into(), BTreeMap::from([("FUNC|GLOBAL|DEFAULT|y".into(),1)]));
        let report = compare(&a,&b).unwrap();
        assert!(report.contains("\"changed_export_records\":2"));
        assert!(report.contains("\"exact_exported_dynamic_abi_parity\":false"));
        assert!(compare(&a,&a).unwrap().contains("\"exact_exported_dynamic_abi_parity\":true"));
        b.insert("vulpra/other.so".into(),Symbols::new());
        assert!(compare(&a,&b).is_err());
    }
    #[test]
    fn json_escaping() {
        assert_eq!(json_quote("x\"\\\n"), "\"x\\\"\\\\\\n\"");
    }
}
