// Bounded byte-level source-provenance witness from independently built,
// SHA256-authenticated original full and combined-four native ELF packages.
// Source filename strings are strong compiled-unit provenance, NOT a
// recovered linker symbol table or proof of specific C++ to Rust call binding.
use std::fs::{self,File};
use std::io::Read;
use std::path::Path;
const MAX_ELF_BYTES:u64=384*1024*1024;
const CHUNK:usize=64*1024;
const ENTRIES:[(&str,&str);4]=[
  ("libxul.so","toolkit/library/rust/shared/lib.rs"),
  ("crashhelper","toolkit/crashreporter/crash_helper_server/src/lib.rs"),
  ("crashhelper","toolkit/crashreporter/crash_helper_server/src/ipc_server.rs"),
  ("crashhelper","toolkit/crashreporter/crash_helper_server/src/breakpad_crash_generator.rs"),
];
fn count_matches(input:&[u8],needle:&[u8],prior_prefix:usize)->usize{
    if needle.is_empty()||input.len()<needle.len(){return 0;}
    input.windows(needle.len()).enumerate()
        .filter(|(pos,span)|*span==needle && *pos+needle.len()>prior_prefix).count()
}
fn count_in_elf(path:&Path,needle:&[u8])->Result<(u64,usize),String>{
    let mut file=File::open(path).map_err(|e|format!("Missing source-matched compiled ELF: {e}"))?;
    let size=file.metadata().map_err(|e|e.to_string())?.len();
    if size<100_000||size>MAX_ELF_BYTES{return Err("Out-of-bounds original compiled ELF".into());}
    let mut head=[0u8;4];
    file.read_exact(&mut head).map_err(|e|e.to_string())?;
    if head!=[0x7f,b'E',b'L',b'F']{return Err("Expected actual original native ELF".into());}
    let mut buf=vec![0u8;CHUNK];
    let(mut seen,mut tail,mut counted)=(4u64,Vec::<u8>::new(),0usize);
    loop{
        let n=file.read(&mut buf).map_err(|e|e.to_string())?;
        if n==0{break;}
        seen+=n as u64;
        if seen>size{return Err("Read past bounded original ELF".into());}
        let mut data=Vec::with_capacity(tail.len()+n);
        data.extend_from_slice(&tail);
        data.extend_from_slice(&buf[..n]);
        counted+=count_matches(&data,needle,tail.len());
        let retain=(needle.len()-1).min(data.len());
        tail=data[data.len()-retain..].to_vec();
        if counted>10_000{return Err("Unexpectedly many source path witnesses".into());}
    }
    if seen!=size{return Err("Short read of compiled ELF".into());}
    Ok((size,counted))
}
fn check(root:&Path)->Result<(Vec<String>,u64),String>{
    let mut records=Vec::new();
    let mut sum=0u64;
    for &(binary,source) in &ENTRIES{
        let (bytes,count)=count_in_elf(&root.join("vulpra").join(binary),source.as_bytes())?;
        if count!=1 {
            return Err(format!("Expected one original compiled Rust source path for {binary}"));
        }
        sum+=count as u64;
        records.push(format!(
            "{{\"binary\":\"{binary}\",\"compiled_elf_bytes\":{bytes},\
             \"rust_source_file\":\"{source}\",\"source_path_occurrences\":{count}}}"
        ));
    }
    Ok((records,sum))
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4{
        return Err("usage: compiled-rust-provenance FULL_EXTRACTED LEAN_EXTRACTED JSON".into());
    }
    let (full,normal)=check(Path::new(&args[1]))?;
    let (lean,omitted)=check(Path::new(&args[2]))?;
    if normal!=4||omitted!=4{return Err("Unexpected native Rust provenance records".into());}
    fs::write(&args[3],format!(
        "{{\"schema_version\":1,\
         \"status\":\"original_compiled_two_native_rust_staticlib_source_path_provenance\",\
         \"source_commit\":\"b1482404dfb8b01342990ee99ea3df0f9756b5f7\",\
         \"normal_source_path_occurrences\":{normal},\
         \"lean_source_path_occurrences\":{omitted},\
         \"full_records\":[{}],\
         \"lean_records\":[{}],\
         \"authenticated_real_compiled_native_elf_bytes_examined\":true,\
         \"source_path_strings_are_not_resolved_ffi_symbols\":true,\
         \"compiled_cpp_to_rust_call_targets_proven\":false,\
         \"all_static_rust_cpp_ffi_edges_identified\":false,\
         \"conditional_dlopen_closure_proven\":false,\
         \"source_removal_authorized\":false,\
         \"m3_sixth_gate_closed\":false}}\n",
         full.join(","),lean.join(",")
    )).map_err(|e|e.to_string())?;
    println!("PASS: original native libxul and crashhelper retain four pinned Rust source-file provenance witnesses in each build");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]
    fn bounded_source_match_does_not_double_count_carried_tail(){
        let needle=b"abc";
        assert_eq!(count_matches(b"abcabc",needle,0),2);
        assert_eq!(count_matches(b"abcabc",needle,3),1);
        assert_eq!(count_matches(b"ab",needle,0),0);
        assert_eq!(count_matches(b"zabca",needle,3),0);
    }
}
