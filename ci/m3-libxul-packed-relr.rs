// Read-only original compiled x86_64 ELF SHT_RELR structural crosswalk.
// Authenticated exact-source full and four-opt-in native packages supplied by CI.
// RELR stores relocation TARGET offsets, not resolution of source-level symbols.
// Equal count does NOT prove same relocation sites, values, runtime bindings,
// semantic equivalence, source-FFI completeness, or conditional dlopen closure.
use std::collections::BTreeMap;
use std::fs::{self,File};
use std::io::{Read,Seek,SeekFrom};
use std::path::Path;
use std::process::Command;
const MAX_RELR_SECTION:usize=32*1024*1024;
const MAX_TARGETS:usize=2_000_000;
type Hist=BTreeMap<i64,u64>;

fn section(elf:&Path)->Result<(u64,u64,usize),String>{
    let o=Command::new("readelf").args(["--wide","--section-headers","--"])
        .arg(elf).output().map_err(|e|e.to_string())?;
    if !o.status.success() || o.stdout.len()>2_000_000{
        return Err("Invalid or unbounded compiled ELF section headers".into());
    }
    let text=String::from_utf8(o.stdout).map_err(|e|e.to_string())?;
    let mut found=None;
    for line in text.lines(){
        let c:Vec<_>=line.split_whitespace().collect();
        let Some(i)=c.iter().position(|x|*x==".relr.dyn") else{continue};
        if i+4>=c.len()||c[i+1]!="PROGBITS"||found.is_some(){
            return Err("Ambiguous non-PROGBITS original .relr.dyn section".into());
        }
        let number=|j:usize|u64::from_str_radix(c[i+j],16).map_err(|e|e.to_string());
        let (addr,file_offset,length)=(number(2)?,number(3)?,number(4)?);
        if length==0||length>MAX_RELR_SECTION as u64||length%8!=0{
            return Err("Out-of-bounds x86_64 RELR section length".into());
        }
        found=Some((addr,file_offset,length as usize));
    }
    found.ok_or("No original packed RELR section".into())
}
fn words(elf:&Path)->Result<(u64,Vec<u64>),String>{
    let (addr,file_offset,size)=section(elf)?;
    let mut handle=File::open(elf).map_err(|e|e.to_string())?;
    let total=handle.metadata().map_err(|e|e.to_string())?.len();
    if file_offset.checked_add(size as u64).is_none_or(|v|v>total){
        return Err("Packed RELR outside original binary".into());
    }
    handle.seek(SeekFrom::Start(file_offset)).map_err(|e|e.to_string())?;
    let mut buf=vec![0u8;size];
    handle.read_exact(&mut buf).map_err(|e|e.to_string())?;
    let values=buf.chunks_exact(8).map(|c|u64::from_le_bytes(c.try_into().unwrap()))
        .collect::<Vec<_>>();
    Ok((addr,values))
}
fn expanded(words:&[u64])->Result<(Vec<u64>,usize),String>{
    let(mut cursor,mut direct,mut positions)=(0u64,0usize,Vec::new());
    for &value in words{
        if value&1==0{
            if value==0||value%8!=0{
                return Err("Invalid ELF64 RELR base entry".into());
            }
            direct+=1;
            positions.push(value);
            cursor=value.checked_add(8).ok_or("RELR direct offset overflow")?;
        }else{
            if cursor==0{return Err("RELR bitmap before direct base".into());}
            let mut mask=value>>1;
            while mask!=0{
                let bit=mask.trailing_zeros() as u64;
                let offset=cursor.checked_add(bit*8).ok_or("RELR bitmap offset overflow")?;
                positions.push(offset);
                mask&=mask-1;
            }
            cursor=cursor.checked_add(63*8).ok_or("RELR bitmap window overflow")?;
        }
        if positions.len()>MAX_TARGETS{
            return Err("Too many expanded native RELR addresses".into());
        }
    }
    if positions.is_empty()||positions.windows(2).any(|pair|pair[0]>=pair[1]){
        return Err("Missing, duplicated, or unsorted native RELR addresses".into());
    }
    Ok((positions,direct))
}
fn histogram(a:&[u64],b:&[u64])->Result<Hist,String>{
    if a.len()!=b.len(){return Err("Original compiled RELR relocation counts differ".into());}
    let mut h=Hist::new();
    for (&first,&second) in a.iter().zip(b){
        let shift=second as i128-first as i128;
        if shift <i64::MIN as i128||shift>i64::MAX as i128{
            return Err("Unbounded native RELR address delta".into());
        }
        *h.entry(shift as i64).or_default()+=1;
    }
    Ok(h)
}
fn report(a:&Path,b:&Path)->Result<String,String>{
    let (vma_a,wa)=words(a)?;
    let (vma_b,wb)=words(b)?;
    let (ra,direct_a)=expanded(&wa)?;
    let (rb,direct_b)=expanded(&wb)?;
    let h=histogram(&ra,&rb)?;
    let mut top=h.iter().collect::<Vec<_>>();
    top.sort_by_key(|(delta,count)|(std::cmp::Reverse(**count),**delta));
    let top_json=top.iter().take(12).map(|(delta,count)|
        format!("{{\"lean_minus_full_offset\":{delta},\"relocations\":{count}}}")
    ).collect::<Vec<_>>().join(",");
    let same_words=wa.iter().zip(&wb).filter(|(a,b)|a==b).count();
    let same_offset=ra.iter().zip(&rb).filter(|(a,b)|a==b).count();
    let mut crosswalk=BTreeMap::<u64,usize>::new();
    for &offset in &rb{*crosswalk.entry(offset).or_default()+=1;}
    let same_set=ra.iter().filter(|v|crosswalk.contains_key(v)).count();
    Ok(format!(
        "{{\"schema_version\":1,\"status\":\"source_matched_original_native_libxul_packed_relr_decoded\",\
        \"normal_relr_vma\":{vma_a},\"lean_relr_vma\":{vma_b},\
        \"normal_encoded_word_count\":{},\"lean_encoded_word_count\":{},\
        \"normal_direct_base_words\":{direct_a},\"lean_direct_base_words\":{direct_b},\
        \"normal_decoded_target_addresses\":{},\"lean_decoded_target_addresses\":{},\
        \"same_encoded_word_values\":{same_words},\
        \"identical_position_target_addresses\":{same_offset},\
        \"set_intersection_of_relocation_target_addresses\":{same_set},\
        \"unique_position_shift_values\":{},\
        \"top_relative_address_shift_counts\":[{top_json}],\
        \"all_decoded_target_offsets_sorted_unique\":true,\
        \"same_relocation_targets_or_addends_proven\":false,\
        \"actual_runtime_relocation_resolution_verified\":false,\
        \"complete_static_rust_cpp_ffi_verified\":false,\
        \"conditional_dlopen_closure_verified\":false,\
        \"source_removal_authorized\":false,\"m3_sixth_gate_closed\":false}}\n",
        wa.len(),wb.len(),ra.len(),rb.len(),h.len()
    ))
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4{
        return Err("usage: m3-native-relr FULL_LIBXUL LEAN_LIBXUL REPORT_JSON".into());
    }
    fs::write(&args[3],report(Path::new(&args[1]),Path::new(&args[2]))?)
        .map_err(|e|e.to_string())?;
    println!("PASS: original compiled full versus lean packed RELR relocation offsets decoded");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]
    fn relr_binary_base_and_bitmap_follow_elf64_rules(){
        // 0x1000 explicit, bitmap then two slots after the base.
        let (a,base)=expanded(&[0x1000,0b1011]).unwrap();
        assert_eq!(a,[0x1000,0x1008,0x1018]);
        assert_eq!(base,1);
        assert!(expanded(&[3]).is_err());
        assert!(expanded(&[0]).is_err());
    }
    #[test]
    fn relr_rejects_duplicate_and_overflowed_offsets(){
        assert!(expanded(&[0x1000,0x1000]).is_err());
        assert!(expanded(&[u64::MAX-7]).is_err());
    }
    #[test]
    fn relocation_offsets_are_not_treated_as_symbol_identity(){
        let a=[4096,4104,4120];
        let b=[4128,4136,4152];
        let h=histogram(&a,&b).unwrap();
        assert_eq!(h.get(&32),Some(&3));
        assert!(histogram(&a,&b[..2]).is_err());
    }
}
