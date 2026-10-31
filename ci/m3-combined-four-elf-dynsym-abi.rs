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

fn exported_symbols(output: &str) -> Result<Symbols, String> {
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
        if ndx == "UND" || binding == "LOCAL" || name.is_empty() {
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

fn inventory(root: &Path) -> Result<Inventory, String> {
    let mut data = Inventory::new();
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
        // Nonempty symbol tables for packaged binaries/libraries are expected.
        // Empty is allowed on an ELF with no exports, but not as a global result.
        data.insert(rel, syms);
    }
    if data.values().all(|v| v.is_empty()) {
        return Err("No exported dynamic symbols seen in any packaged ELF".into());
    }
    Ok(data)
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

fn run() -> Result<(), String> {
    let args: Vec<_> = std::env::args().collect();
    if args.len() != 4 { return Err("usage: elf-dynsym-abi FULL_EXTRACTED LEAN_EXTRACTED REPORT_JSON".into()); }
    let full = inventory(Path::new(&args[1]))?;
    let lean = inventory(Path::new(&args[2]))?;
    let result = compare(&full, &lean)?;
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
