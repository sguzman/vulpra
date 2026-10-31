// Read-only, source-matched compiled libxul exported-function body comparison.
// Named dynamic FUNC symbols only: not all internal code, FFI, or relocations.
use std::collections::{BTreeMap, BTreeSet};
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;
use std::process::Command;

const MAX_TEXT_BYTES: u64 = 256 * 1024 * 1024;
const MAX_READELF_OUTPUT: usize = 20 * 1024 * 1024;
type Functions = BTreeMap<String, (usize, usize)>;

fn readelf(elf: &Path, arg: &str) -> Result<String, String> {
    let output = Command::new("readelf").args(["--wide", arg, "--"])
        .arg(elf).output().map_err(|e| e.to_string())?;
    if !output.status.success() || output.stdout.len() > MAX_READELF_OUTPUT {
        return Err(format!("Bounded readelf failed for {arg}"));
    }
    String::from_utf8(output.stdout).map_err(|e| e.to_string())
}

fn text_header(output: &str) -> Result<(u64, u64, u64), String> {
    let mut found = None;
    for line in output.lines() {
        let fields: Vec<_> = line.split_whitespace().collect();
        let Some(i) = fields.iter().position(|x| *x == ".text") else { continue };
        if fields.len() <= i + 4 || fields[i + 1] != "PROGBITS" || found.is_some() {
            return Err("Unexpected or duplicate ELF .text header".into());
        }
        let numbers = [fields[i + 2], fields[i + 3], fields[i + 4]]
            .map(|x| u64::from_str_radix(x, 16).map_err(|e| e.to_string()));
        found = Some((numbers[0].clone()?, numbers[1].clone()?, numbers[2].clone()?));
    }
    let (address, offset, len) = found.ok_or("Missing ELF .text header")?;
    if len == 0 || len > MAX_TEXT_BYTES {
        return Err("Unbounded or empty libxul .text section".into());
    }
    Ok((address, offset, len))
}

fn named_functions(
    output: &str, text_address: u64, text_size: usize
) -> Result<(Functions, usize, usize, usize), String> {
    let mut funcs = Functions::new();
    let mut dupes = BTreeSet::new();
    let mut candidates = 0usize;
    let mut outside = 0usize;
    let mut zero = 0usize;
    for line in output.lines() {
        let cols: Vec<_> = line.split_whitespace().collect();
        if cols.len() < 8 ||
            cols[0].strip_suffix(':').and_then(|v| v.parse::<usize>().ok()).is_none() ||
            cols[3] != "FUNC" || cols[6] == "UND" || cols[4] == "LOCAL" {
            continue;
        }
        candidates += 1;
        if candidates > 50_000 { return Err("Unexpectedly many exported native functions".into()); }
        let value = u64::from_str_radix(cols[1], 16).map_err(|e| e.to_string())?;
        let size = cols[2].parse::<usize>().map_err(|e| e.to_string())?;
        if size == 0 { zero += 1; continue; }
        let Some(pos) = value.checked_sub(text_address) else { outside += 1; continue };
        if pos > text_size as u64 ||
            (pos as usize).checked_add(size).is_none_or(|end| end > text_size) {
            outside += 1;
            continue;
        }
        let name = format!("{}|{}|{}", cols[7], cols[4], cols[5]);
        if name.len() > 1024 { return Err("Unexpectedly large native symbol name".into()); }
        if funcs.insert(name.clone(), (pos as usize, size)).is_some() {
            dupes.insert(name);
        }
    }
    for duplicate in &dupes { funcs.remove(duplicate); }
    Ok((funcs, candidates, outside, zero + dupes.len()))
}

fn binary_text(elf: &Path) -> Result<(u64, Vec<u8>), String> {
    let (addr, offset, len) = text_header(&readelf(elf, "--section-headers")?)?;
    let mut file = File::open(elf).map_err(|e| e.to_string())?;
    let total = file.metadata().map_err(|e| e.to_string())?.len();
    if offset.checked_add(len).is_none_or(|end| end > total) {
        return Err("ELF .text offset exceeds actual packaged file".into());
    }
    file.seek(SeekFrom::Start(offset)).map_err(|e| e.to_string())?;
    let mut data = vec![0u8; len as usize];
    file.read_exact(&mut data).map_err(|e| e.to_string())?;
    Ok((addr, data))
}

fn json_string(s: &str) -> String {
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

fn report(full: &Path, lean: &Path) -> Result<String, String> {
    let (addr_a, code_a) = binary_text(full)?;
    let (addr_b, code_b) = binary_text(lean)?;
    let (fa, ca, oa, za) = named_functions(
        &readelf(full, "--dyn-syms")?, addr_a, code_a.len())?;
    let (fb, cb, ob, zb) = named_functions(
        &readelf(lean, "--dyn-syms")?, addr_b, code_b.len())?;
    if fa.is_empty() || fb.is_empty() {
        return Err("No eligible exported native function bodies in libxul".into());
    }
    let mut identical = 0usize;
    let mut different = 0usize;
    let mut size_changed = 0usize;
    let mut shared = 0usize;
    let mut examples = Vec::new();
    let mut offset_shifts = BTreeMap::<i64, usize>::new();
    for (name, &(start_a, len_a)) in &fa {
        let Some(&(start_b, len_b)) = fb.get(name) else { continue };
        shared += 1;
        *offset_shifts.entry(start_b as i64 - start_a as i64).or_default() += 1;
        if len_a != len_b {
            size_changed += 1;
            if examples.len() < 12 { examples.push(format!("{name}: length {len_a} vs {len_b}")); }
        } else if code_a[start_a..start_a + len_a] == code_b[start_b..start_b + len_b] {
            identical += 1;
        } else {
            different += 1;
            if examples.len() < 12 { examples.push(name.clone()); }
        }
    }
    let mut modes: Vec<_> = offset_shifts.into_iter().collect();
    modes.sort_by_key(|&(shift, count)| (std::cmp::Reverse(count), shift));
    let top_shifts = modes.iter().take(12).map(|(offset, count)| {
        format!("{{\"lean_minus_full_function_offset\":{offset},\"symbol_count\":{count}}}")
    }).collect::<Vec<_>>().join(",");
    let sample_json = examples.iter().map(|x| json_string(x)).collect::<Vec<_>>().join(",");
    Ok(format!(
        "{{\"schema_version\":1,\"status\":\"pinned_original_libxul_named_dynsym_function_code_comparison\",\
        \"full_text_bytes\":{},\"lean_text_bytes\":{},\
        \"full_defined_exported_func_candidates\":{ca},\"lean_defined_exported_func_candidates\":{cb},\
        \"full_outside_text\":{oa},\"lean_outside_text\":{ob},\
        \"full_zero_or_ambiguous_func_candidates\":{za},\"lean_zero_or_ambiguous_func_candidates\":{zb},\
        \"full_mappable_function_records\":{},\"lean_mappable_function_records\":{},\
        \"shared_mappable_named_functions\":{shared},\
        \"byte_identical_named_functions\":{identical},\
        \"byte_different_equal_size_named_functions\":{different},\
        \"changed_size_named_functions\":{size_changed},\
        \"full_only_mappable_function_records\":{},\"lean_only_mappable_function_records\":{},\
        \"top_function_address_shifts\":[{top_shifts}],\
        \"bounded_differing_function_examples\":[{sample_json}],\
        \"scope_is_exported_dynsym_funcs_only\":true,\
        \"all_internal_or_static_ffi_functions_verified\":false,\
        \"runtime_dlopen_graph_verified\":false,\"source_pruning_authorized\":false,\
        \"m3_sixth_gate_closed\":false}}\n",
        code_a.len(), code_b.len(), fa.len(), fb.len(),
        fa.len() - shared, fb.len() - shared
    ))
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    let result = (|| -> Result<(), String> {
        if args.len() != 4 {
            return Err("usage: m3-libxul-funcs FULL_ELF LEAN_ELF REPORT_JSON".into());
        }
        for path in [&args[1], &args[2]] {
            if !Path::new(path).is_file() { return Err("Missing exact packaged libxul file".into()); }
        }
        let output = report(Path::new(&args[1]), Path::new(&args[2]))?;
        fs::write(&args[3], output).map_err(|e| e.to_string())?;
        println!("PASS: compared named exported native function bodies in compiled libxul");
        Ok(())
    })();
    if let Err(e) = result { eprintln!("FAIL: {e}"); std::process::exit(1); }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn parses_section_address_and_size() {
        let line = "[14] .text PROGBITS 0000000000001000 00001000 00000040 00 AX 0 0 16";
        assert_eq!(text_header(line).unwrap(), (4096,4096,64));
        assert!(text_header(line.replace("PROGBITS","NOBITS").as_str()).is_err());
    }
    #[test]
    fn matches_only_bounded_exported_function_bodies() {
        let input = "Num: Value Size Type Bind Vis Ndx Name\n\
          1: 0000000000001004 6 FUNC GLOBAL DEFAULT 14 foo@@VER_1\n\
          2: 000000000000100b 3 FUNC WEAK DEFAULT 14 bar\n\
          3: 0000000000001050 2 FUNC GLOBAL DEFAULT 14 out_of_text\n\
          4: 0000000000001003 0 FUNC GLOBAL DEFAULT 14 no_size\n\
          5: 0000000000000000 0 FUNC GLOBAL DEFAULT UND printf\n";
        let (f,c,o,z)=named_functions(input, 0x1000, 64).unwrap();
        assert_eq!((f.len(),c,o,z), (2,4,1,1));
        assert_eq!(f["foo@@VER_1|GLOBAL|DEFAULT"], (4,6));
    }
    #[test]
    fn duplicate_name_is_not_counted_as_proof() {
        let inp="1: 0000000000001000 3 FUNC GLOBAL DEFAULT 14 same\n\
                 2: 0000000000001004 4 FUNC GLOBAL DEFAULT 14 same\n";
        let (f,c,_,z)=named_functions(inp,0x1000,32).unwrap();
        assert!(f.is_empty());
        assert_eq!((c,z),(2,1));
    }
}
