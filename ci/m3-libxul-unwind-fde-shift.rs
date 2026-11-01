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
// readelf emits many CFA instruction rows per FDE; stream with a hard cap.
const MAX_LINES: usize = 16_000_000;

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
    let file_len = handle.metadata().map_err(|e| e.to_string())?.len();
    if offset.checked_add(size).is_none_or(|end| end > file_len) {
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


fn alignment_union(full: &BTreeSet<Range>, lean: &BTreeSet<Range>,
                   a: &[u8], b: &[u8], delta: usize)
    -> (usize,usize,usize,usize,usize,[[usize;5];8]) {
    let (mut both,mut zero_only,mut shifted_only,mut neither,mut identical_any)=
        (0usize,0usize,0usize,0usize,0usize);
    // Eighth bins: original FDEs, zero matches, shifted matches,
    // no matches, byte identity under either possible placement.
    let mut bins=[[0usize;5];8];
    for &(start,end) in full {
        let bucket=(start.saturating_mul(8)/a.len()).min(7);
        bins[bucket][0]+=1;
        let z=end<=b.len() && lean.contains(&(start,end));
        let t=match(start.checked_add(delta),end.checked_add(delta)){
            (Some(p),Some(q)) if q<=b.len()=>lean.contains(&(p,q)),
            _=>false,
        };
        if z {bins[bucket][1]+=1;}
        if t {bins[bucket][2]+=1;}
        match (z,t) {
            (true,true)=>both+=1,
            (true,false)=>zero_only+=1,
            (false,true)=>shifted_only+=1,
            (false,false)=>{neither+=1;bins[bucket][3]+=1;},
        }
        let identical=z && a[start..end]==b[start..end] ||
            t && a[start..end]==b[start+delta..end+delta];
        if identical {identical_any+=1;bins[bucket][4]+=1;}
    }
    (both,zero_only,shifted_only,neither,identical_any,bins)
}

// Bounded numeric code offsets only: do not export raw unwind instructions.
fn boundary_transition(full: &BTreeSet<Range>, lean: &BTreeSet<Range>,
                       full_len: usize, lean_len: usize, delta: usize)
    -> Result<String,String> {
    let (mut last_zero,mut first_shift)=(None::<usize>,None::<usize>);
    let mut no_alignment=Vec::new();
    let mut records=Vec::new();
    let mut buckets=[[0usize;4];16];
    for &(start,end) in full {
        let z=end<=lean_len && lean.contains(&(start,end));
        let t=match(start.checked_add(delta),end.checked_add(delta)){
            (Some(p),Some(q)) if q<=lean_len=>lean.contains(&(p,q)),
            _=>false,
        };
        if z && !t {last_zero=Some(last_zero.map_or(start,|p|p.max(start)));}
        if t && !z {first_shift=Some(first_shift.map_or(start,|p|p.min(start)));}
        if !z && !t {
            no_alignment.push((start,end));
            if no_alignment.len()>10 {return Err("Too many unmatched FDE ranges for bounded hinge report".into());}
        }
        records.push((start,z,t));
        let region=(start as u128 * 128 / full_len as u128) as usize;
        if region<16 {
            buckets[region][0]+=1;
            if z {buckets[region][1]+=1;}
            if t {buckets[region][2]+=1;}
            if !z && !t {buckets[region][3]+=1;}
        }
    }
    let last_zero=last_zero.ok_or("No original-only FDE hinge anchors")?;
    let first_shift=first_shift.ok_or("No shifted-only FDE hinge anchors")?;
    let late_zero=records.iter().filter(|(s,z,t)|*z && !*t && *s>=first_shift).count();
    let early_shift=records.iter().filter(|(s,z,t)|*t && !*z && *s<=last_zero).count();
    let missing=no_alignment.iter().map(|(a,b)|format!(
        "{{\"original_text_offset_start\":{a},\"original_text_offset_end\":{b}}}"
    )).collect::<Vec<_>>().join(",");
    let bins=buckets.iter().enumerate().map(|(idx,c)|format!(
        "{{\"first_eighth_sixteenth\":{idx},\"original_fde_ranges\":{},\"zero_offset\":{},\"plus_32_offset\":{},\"neither\":{}}}",
        c[0],c[1],c[2],c[3]
    )).collect::<Vec<_>>().join(",");
    Ok(format!(
        "{{\"last_zero_only_original_start_offset\":{last_zero},\
        \"first_plus_32_only_original_start_offset\":{first_shift},\
        \"zero_only_not_strictly_before_first_shift_count\":{late_zero},\
        \"shift_only_not_strictly_after_last_zero_count\":{early_shift},\
        \"unmatched_original_fde_offsets\":[{missing}],\
        \"first_eighth_local_sixteenth_bins\":[{bins}],\
        \"code_offset_not_source_line_or_function_identity\":true}}"
    ))
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
    let union=alignment_union(&fdes_a,&fdes_b,&code_a,&code_b,32);
    let transition=boundary_transition(&fdes_a,&fdes_b,code_a.len(),code_b.len(),32)?;

    if union.0+union.1+union.2+union.3 != fdes_a.len() {
        return Err("Incomplete exclusive FDE layout classification".into());
    }
    let buckets = union.5.iter().enumerate().map(|(i,c)| {
        format!("{{\"eighth\":{i},\"full_fde_ranges\":{},\"zero_offset\":{},\"plus_32_offset\":{},\"neither\":{},\"identical_under_either\":{}}}",c[0],c[1],c[2],c[3],c[4])
    }).collect::<Vec<_>>().join(",");

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
        \"unwind_fde_both_alignments\":{},\
        \"unwind_fde_zero_only\":{},\
        \"unwind_fde_plus_32_only\":{},\
        \"unwind_fde_neither_alignment\":{},\
        \"unwind_fde_identical_under_either\":{},\
        \"unwind_fde_eighth_bins\":[{buckets}],\
        \"unwind_fde_layout_transition\":{transition},\
        \"sum_of_fde_span_bytes_not_unique_code_coverage\":true,\
        \"only_unwind_described_code_ranges_examined\":true,\
        \"all_compiled_functions_or_rust_ffi_proven\":false,\
        \"runtime_dlopen_closure_proven\":false,\"source_pruning_authorized\":false,\
        \"m3_sixth_gate_closed\":false}}\n",
       code_a.len(),code_b.len(),fdes_a.len(),fdes_b.len(),
       same.0,same.1,same.2,same.3,
       shifted.0,shifted.1,shifted.2,shifted.3,
       union.0,union.1,union.2,union.3,union.4);
    fs::write(&args[3],json).map_err(|e| e.to_string())?;
    println!("PASS: compared bounded compiled unwind-described libxul native .text ranges");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn hinge_and_unmatched_ranges_are_bounded() {
        let a:BTreeSet<_>=[(1,4),(4,7),(7,9)].into_iter().collect();
        let b:BTreeSet<_>=[(1,4),(6,9)].into_iter().collect();
        let d=boundary_transition(&a,&b,9,11,2).unwrap();
        assert!(d.contains("\"last_zero_only_original_start_offset\":1"));
        assert!(d.contains("\"first_plus_32_only_original_start_offset\":4"));
        assert!(d.contains("\"unmatched_original_fde_offsets\":[{\"original_text_offset_start\":7,\"original_text_offset_end\":9}]"));
    }
    #[test]
    fn exclusive_alignment_fixture() {
        let a:BTreeSet<_>=[(1,4),(4,7),(7,9)].into_iter().collect();
        let b:BTreeSet<_>=[(1,4),(6,9)].into_iter().collect();
        let x=alignment_union(&a,&b,b"Zabcdefgh",b"ZZZabcdefgh",2);
        assert_eq!((x.0,x.1,x.2,x.3),(0,1,1,1));
        assert_eq!(x.5.iter().map(|v|v[0]).sum::<usize>(),3);
    }
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
