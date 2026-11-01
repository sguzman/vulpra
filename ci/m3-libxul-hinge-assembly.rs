// Read-only checksum-bound compiled libxul hinge assembly audit.
// Source-pinned native artifacts are authenticated by the surrounding workflow.
// This is machine-code structural evidence, not source-function attribution or
// instruction-level semantic equivalence.
use std::fs;
use std::path::Path;
use std::process::Command;

const HINGES: [(usize, usize, usize, usize); 2] = [
    (11_654_896, 454, 11_654_896, 466),
    (11_655_360, 461, 11_655_376, 473),
];
const MAX_STDOUT: usize = 64 * 1024;
const EXPECTED_TEXT_FULL: u64 = 128_073_093;
const EXPECTED_TEXT_LEAN: u64 = 128_073_125;

#[derive(Clone, Debug)]
struct Instruction { mnemonic: String, operands: String }
fn tool_output(mut command: Command) -> Result<String, String> {
    let result = command.output().map_err(|e| e.to_string())?;
    if !result.status.success() || result.stdout.len() > MAX_STDOUT {
        return Err(format!("Bounded native inspector failed with {:?}",result.status.code()));
    }
    String::from_utf8(result.stdout).map_err(|e| e.to_string())
}
fn section(root: &Path) -> Result<(u64,u64), String> {
    let mut cmd=Command::new("readelf");
    cmd.args(["--wide","--section-headers","--"]).arg(root);
    let output=tool_output(cmd)?;
    let mut found=None;
    for line in output.lines(){
        let cols:Vec<_>=line.split_whitespace().collect();
        let Some(pos)=cols.iter().position(|x|*x==".text") else{continue};
        if pos+4>=cols.len() || cols[pos+1]!="PROGBITS" || found.is_some() {
            return Err("Non-unique original native .text".into());
        }
        found=Some((
            u64::from_str_radix(cols[pos+2],16).map_err(|e|e.to_string())?,
            u64::from_str_radix(cols[pos+4],16).map_err(|e|e.to_string())?
        ));
    }
    found.ok_or("No compiled original native text section".into())
}
fn parse_assembly(source: &str) -> Result<Vec<Instruction>, String> {
    let mut rows=Vec::new();
    for line in source.lines(){
        let Some((head,tail))=line.split_once(':') else{continue};
        if head.trim().is_empty() || !head.trim().chars().all(|c|c.is_ascii_hexdigit()){
            continue;
        }
        let mut fields=tail.split_whitespace();
        let Some(mnemonic)=fields.next() else{continue};
        if !mnemonic.chars().all(|c|c.is_ascii_lowercase()||c.is_ascii_digit()||c=='.'){
            return Err("Unexpected native assembly mnemonic".into());
        }
        rows.push(Instruction{mnemonic:mnemonic.to_owned(),operands:fields.collect::<Vec<_>>().join(" ")});
        if rows.len()>200 {return Err("Too many instructions in bounded FDE code range".into());}
    }
    if rows.len()<75 {return Err("Unexpectedly few original native disassembly instructions".into());}
    Ok(rows)
}
fn disassemble(elf:&Path, text:u64, offset:usize, size:usize)
    -> Result<Vec<Instruction>,String>{
    let start=text.checked_add(offset as u64).ok_or("Native code offset overflow")?;
    let stop=start.checked_add(size as u64).ok_or("Native code interval overflow")?;
    let mut cmd=Command::new("objdump");
    cmd.args(["-d","-M","intel","--no-show-raw-insn","-j",".text"])
       .arg(format!("--start-address={start}"))
       .arg(format!("--stop-address={stop}"))
       .arg(elf);
    parse_assembly(&tool_output(cmd)?)
}
fn lcs_changes(a:&[Instruction],b:&[Instruction])
    -> (usize,Vec<String>,Vec<String>) {
    let m=a.len();
    let n=b.len();
    let mut dp=vec![vec![0usize;n+1];m+1];
    for i in (0..m).rev(){
        for j in (0..n).rev(){
            dp[i][j]=if a[i].mnemonic==b[j].mnemonic {
                1+dp[i+1][j+1]
            }else{dp[i+1][j].max(dp[i][j+1])};
        }
    }
    let(mut i,mut j)=(0usize,0usize);
    let mut inserted=Vec::new();
    let mut deleted=Vec::new();
    while i<m || j<n {
        if i<m && j<n && a[i].mnemonic==b[j].mnemonic{
            i+=1;j+=1;
        }else if j<n && (i==m||dp[i][j+1]>=dp[i+1][j]){
            inserted.push(b[j].mnemonic.clone());j+=1;
        }else{
            deleted.push(a[i].mnemonic.clone());i+=1;
        }
    }
    (dp[0][0], inserted, deleted)
}
fn count_contains(rows:&[Instruction],needle:&str)->usize{
    rows.iter().filter(|x|format!("{} {}",x.mnemonic,x.operands).contains(needle)).count()
}
fn as_json_items(items:&[String])->String{
    items.iter().map(|x|format!("\"{}\"",x)).collect::<Vec<_>>().join(",")
}
fn compare(one:&[Instruction],two:&[Instruction],id:usize,normal_bytes:usize,lean_bytes:usize)
    -> Result<String,String>{
    let (lcs,added,deleted)=lcs_changes(one,two);
    let expected=["mov","sub","shr","add","shr"];
    if one.len()!=115 || two.len()!=120 || lcs!=115 ||
       !deleted.is_empty() || added.iter().map(String::as_str).collect::<Vec<_>>()!=expected {
        return Err(format!("Native hinge assembly opcode shape drift in interval {}",id));
    }
    if count_contains(one,"mov ecx,0xc907da4f")!=1 ||
       count_contains(two,"mov ecx,0x92add007")!=1 ||
       count_contains(one,"imul eax,ecx,0x28c")!=1 ||
       count_contains(two,"imul eax,eax,0x28b")!=1 ||
       count_contains(one,"imul r14d,edi,0x1000193")!=1 ||
       count_contains(two,"imul r14d,edi,0x1000193")!=1 {
        return Err(format!("Actual original compiled hash division signature drift in hinge {}",id));
    }
    Ok(format!(
       "{{\"range_id\":{id},\"full_text_range_bytes\":{normal_bytes},\
        \"lean_text_range_bytes\":{lean_bytes},\
        \"full_instructions\":{},\"lean_instructions\":{},\
        \"shared_mnemonic_subsequence_length\":{lcs},\
        \"added_lean_mnemonics\":[{}],\"removed_full_mnemonics\":[],\
        \"full_remainder_divisor\":652,\"lean_remainder_divisor\":651,\
        \"full_remainder_constant\":\"0x28c\",\
        \"lean_remainder_constant\":\"0x28b\",\
        \"full_division_reciprocal\":\"0xc907da4f\",\
        \"lean_division_reciprocal\":\"0x92add007\",\
        \"identical_prime_multiply_immediate\":\"0x1000193\"}}",
        one.len(),two.len(),as_json_items(&added)
    ))
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=4 {return Err("usage: m3-libxul-hinge-assembly FULL_LIBXUL LEAN_LIBXUL JSON".into());}
    let a=Path::new(&args[1]);
    let b=Path::new(&args[2]);
    let (addr_a,len_a)=section(a)?;
    let (addr_b,len_b)=section(b)?;
    if len_a!=EXPECTED_TEXT_FULL || len_b!=EXPECTED_TEXT_LEAN{
        return Err("Original source-pinned compiled libxul .text size drift".into());
    }
    let mut records=Vec::new();
    for (idx,(of,lf,ol,ll)) in HINGES.iter().copied().enumerate(){
        let x=disassemble(a,addr_a,of,lf)?;
        let y=disassemble(b,addr_b,ol,ll)?;
        records.push(compare(&x,&y,idx+1,lf,ll)?);
    }
    let report=format!(
       "{{\"schema_version\":1,\"status\":\"pinned_actual_compiled_libxul_two_hinge_hash_divisors_explained\",\
        \"source_and_runtime_function_identity_proven\":false,\
        \"compiled_hash_bucket_count_change_is_feature_proven\":false,\
        \"all_native_code_or_static_ffi_proven\":false,\
        \"runtime_dlopen_closure_proven\":false,\
        \"source_removal_authorized\":false,\"m3_sixth_gate_closed\":false,\
        \"ranges\":[{}]}}\n",records.join(","));
    fs::write(&args[3],report).map_err(|e|e.to_string())?;
    println!("PASS: two original compiled native FDEs use 652 vs 651 hash divisor with 5 extra lean instructions each");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}

#[cfg(test)]
mod tests{
    use super::*;
    fn instr(m:&str)->Instruction{Instruction{mnemonic:m.into(),operands:String::new()}}
    #[test]
    fn inserted_instructions_are_not_assumed_semantically_equal(){
        let a=["mov","imul","shr","imul","sub"].map(instr);
        let b=["mov","imul","shr","mov","sub","shr","add","shr","imul","sub"].map(instr);
        let(lcs,added,removed)=lcs_changes(&a,&b);
        assert_eq!(lcs,5);
        assert!(removed.is_empty());
        assert_eq!(added,vec!["mov","sub","shr","add","shr"]);
    }
    #[test]
    fn disassembly_parser_fail_closed(){
        let input="0000000000010080 <symbol>:\n 10080:\tmov eax,ecx\n 10083:\tshr eax,1\n";
        // Synthetic parser is intentionally guarded to expect real function-sized range.
        assert!(parse_assembly(input).is_err());
    }
}
