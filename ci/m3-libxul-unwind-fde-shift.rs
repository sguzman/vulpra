// Audit actual compiled libxul unwind FDE code ranges without any browser execution.
// FDEs cover SOME code ranges only, not an exhaustive symbol or call graph.
use std::collections::BTreeSet;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::Path;
use std::process::{Command, Stdio};
type Range = (usize, usize);
const MAX_TEXT: u64 = 256 * 1024 * 1024;
const MAX_FDES: usize = 500_000;
const MAX_LINES: usize = 2_000_000;

fn text_section(file: &Path) -> Result<(u64, Vec<u8>), String> {
    let output = Command::new("readelf").args(["--wide", "--section-headers", "--"])
        .arg(file).output().map_err(|e| e.to_string())?;
    if !output.status.success() || output.stdout.len() > 4_000_000 {
        return Err("Cannot read bounded original ELF section headers".into());
    }
    let stdout = String::from_utf8(output.stdout).map_err(|e| e.to_string())?;
    let mut location = None;
    for line in stdout.lines() {
        let cols: Vec<_> = line.split_whitespace().collect();
        let Some(i) = cols.iter().position(|c| *c == ".text") else { continue };
        if i + 4 >= cols.len() || cols[i + 1] != "PROGBITS" || location.is_some() {
            return Err("Ambiguous compiled libxul .text header".into());
        }
        let parse = |j: usize| u64::from_str_radix(cols[i+j],16).map_err(|e| e.to_string());
        location = Some((parse(2)?,parse(3)?,parse(4)?));
    }
    let (base,offset,size) = location.ok_or("No compiled libxul .text header")?;
    if size == 0 || size > MAX_TEXT { return Err("Out of bounds native text".into()); }
    let mut handle = File::open(file).map_err(|e| e.to_string())?;
    if offset.checked_add(size).is_none_or(|end| end > handle.metadata().map_err(|e| e.to_string())?.len()) {
        return Err("Original ELF .text declared outside packaged file".into());
    }
    handle.seek(SeekFrom::Start(offset)).map_err(|e| e.to_string())?;
    let mut code = vec![0;size as usize];
    handle.read_exact(&mut code).map_err(|e| e.to_string())?;
    Ok((base,code))
}

fn parse_fde_line(line: &str) -> Result<Option<(u64,u64)>, String> {
    if !line.contains(" FDE ") { return Ok(None); }
    let (_, span) = line.split_once(" pc=").ok_or("FDE record missing pc= range")?;
    let range = span.split_whitespace().next().ok_or("Empty FDE PC range")?;
    let (from,to)=range.split_once("..").ok_or("Malformed FDE PC endpoints")?;
    let a=u64::from_str_radix(from,16).map_err(|e| e.to_string())?;
    let b=u64::from_str_radix(to,16).map_err(|e| e.to_string())?;
    if b <= a { return Err("Empty or inverted FDE".into()); }
    Ok(Some((a,b)))
}

fn fde_ranges(elf: &Path, base: u64, length: usize)
    -> Result<(BTreeSet<Range>, usize, usize), String> {
    let mut proc = Command::new("readelf")
        .args(["--wide","--debug-dump=frames","--"]).arg(elf)
        .stdout(Stdio::piped()).stderr(Stdio::null())
        .spawn().map_err(|e| e.to_string())?;
    let reader = BufReader::new(proc.stdout.take().ok_or("No FDE stdout")?);
    let mut frames = BTreeSet::new();
    let (mut total,mut excluded)=(0usize,0usize);
    for (idx,line) in reader.lines().enumerate() {
        if idx >= MAX_LINES { return Err("Unbounded original FDE listing".into()); }
        let line=line.map_err(|e| e.to_string())?;
        let Some((start,end))=parse_fde_line(&line)? else {continue};
        total+=1;
        if total > MAX_FDES { return Err("Unbounded original FDE count".into()); }
        let (Some(begin),Some(finish))=(start.checked_sub(base),end.checked_sub(base)) else {
            excluded+=1;
            continue;
        };
        if finish > length as u64 || begin>=finish {
            excluded+=1;
            continue;
        }
        frames.insert((begin as usize, finish as usize));
    }
    if !proc.wait().map_err(|e| e.to_string())?.success() {
        return Err("Native readelf FDE inspection failed".into());
    }
    if frames.is_empty() { return Err("No compiled .text unwind FDE ranges".into()); }
    Ok((frames,total,excluded))
}

fn compare_ranges(
    normal: &BTreeSet<Range>, lean: &BTreeSet<Range>,
    a: &[u8], b: &[u8], displacement: usize
) -> (usize,usize,usize,u64) {
    let (mut eligible,mut identical,mut different,mut identical_bytes)=(0usize,0usize,0usize,0u64);
    for &(start,end) in normal {
        let Some(shifted_start)=start.checked_add(displacement) else {continue};
        let Some(shifted_end)=end.checked_add(displacement) else {continue};
        if shifted_end > b.len() || !lean.contains(&(shifted_start,shifted_end)) { continue; }
        eligible+=1;
        if a[start..end] == b[shifted_start..shifted_end] {
            identical+=1;
            identical_bytes+=(end-start) as u64;
        } else {
            different+=1;
        }
    }
    (eligible,identical,different,identical_bytes)
}

fn run() -> Result<(), String> {
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4 {return Err("usage: m3-ehframe FULL_LIBXUL LEAN_LIBXUL REPORT".into());}
    let a=Path::new(&args[1]);
    let b=Path::new(&args[2]);
    let (base_a,code_a)=text_section(a)?;
    let (base_b,code_b)=text_section(b)?;
    let (fdes_a,total_a,excluded_a)=fde_ranges(a,base_a,code_a.len())?;
    let (fdes_b,total_b,excluded_b)=fde_ranges(b,base_b,code_b.len())?;
    let same=compare_ranges(&fdes_a,&fdes_b,&code_a,&code_b,0);
    let shifted=compare_ranges(&fdes_a,&fdes_b,&code_a,&code_b,32);
    let json=format!(
       "{{\"schema_version\":1,\"status\":\"original_compiled_libxul_unwind_fde_shift_comparison\",\
        \"full_text_bytes\":{},\"lean_text_bytes\":{},\
        \"full_fde_records\":{total_a},\"lean_fde_records\":{total_b},\
        \"full_outside_text_fde_records\":{excluded_a},\"lean_outside_text_fde_records\":{excluded_b},\
        \"full_unique_in_text_fde_ranges\":{},\"lean_unique_in_text_fde_ranges\":{},\
        \"zero_shift_matching_fde_ranges\":{},\"zero_shift_identical_code_ranges\":{},\
        \"zero_shift_different_code_ranges\":{},\"zero_shift_equal_code_span_bytes\":{},\
        \"plus_32_shift_matching_fde_ranges\":{},\"plus_32_shift_identical_code_ranges\":{},\
        \"plus_32_shift_different_code_ranges\":{},\"plus_32_shift_equal_code_span_bytes\":{},\
        \"sum_of_fde_span_bytes_not_unique_code_coverage\":true,\
        \"only_unwind_described_code_ranges_examined\":true,\
        \"all_compiled_functions_or_rust_ffi_proven\":false,\
        \"runtime_dlopen_closure_proven\":false,\"source_pruning_authorized\":false,\
        \"m3_sixth_gate_closed\":false}}\n",
       code_a.len(),code_b.len(),fdes_a.len(),fdes_b.len(),
       same.0,same.1,same.2,same.3,
       shifted.0,shifted.1,shifted.2,shifted.3);
    fs::write(&args[3],json).map_err(|e| e.to_string())?;
    println!("PASS: compared bounded compiled unwind-described libxul native .text ranges");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fde_address_parser() {
        assert_eq!(parse_fde_line("0001 001c 0000 FDE cie=00000000 pc=00001003..00001008").unwrap(),Some((4099,4104)));
        assert_eq!(parse_fde_line("0001 CIE").unwrap(),None);
        assert!(parse_fde_line("0001 FDE pc=7..3").is_err());
    }
    #[test]
    fn function_range_displacement_does_not_assume_linker_equivalence() {
        let a:BTreeSet<_>=[(1,4),(4,7)].into_iter().collect();
        let b:BTreeSet<_>=[(3,6),(6,9)].into_iter().collect();
        let x=b"Zabcdef";
        let y=b"XXZabcdef";
        assert_eq!(compare_ranges(&a,&b,x,y,0),(0,0,0,0));
        assert_eq!(compare_ranges(&a,&b,x,y,2),(2,2,0,6));
        let changed=b"XXZabXdef";
        assert_eq!(compare_ranges(&a,&b,x,changed,2),(2,1,1,3));
    }
}
