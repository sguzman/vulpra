// Read-only exact native ELF DT_NEEDED graph comparison for a pinned
// source-matched full browser and its four-opt-in lean compiled candidate.
// Do NOT execute ELF files, infer future dlopen closure or alter profiles.
use std::{collections::{BTreeMap,BTreeSet},env,fs::{self,File},io::Read,path::{Path,PathBuf},process::Command};
fn needed(stdout:&str)->Result<Vec<String>,String>{
 let mut names=Vec::new();
 for line in stdout.lines(){
  if !line.contains("(NEEDED)") {continue}
  let name=line.split("Shared library: [").nth(1).and_then(|s|s.split(']').next())
   .ok_or("malformed NEEDED entry")?;
  if name.is_empty()||name.contains('/')||name.contains('\0'){return Err("invalid NEEDED basename".into())}
  names.push(name.to_string())
 }
 Ok(names)
}
fn visit(root:&Path,dir:&Path,out:&mut BTreeMap<String,Vec<String>>)->Result<(),String>{
 for entry in fs::read_dir(dir).map_err(|e|e.to_string())?{
  let entry=entry.map_err(|e|e.to_string())?;
  let ty=entry.file_type().map_err(|e|e.to_string())?;
  let p=entry.path();
  if ty.is_symlink(){continue}
  if ty.is_dir(){visit(root,&p,out)?;continue}
  if !ty.is_file(){return Err("unexpected package entry type".into())}
  let mut f=File::open(&p).map_err(|e|e.to_string())?;
  let mut magic=[0u8;4];
  if f.read_exact(&mut magic).is_err()||magic!=[0x7f,b'E',b'L',b'F']{continue}
  let rel=p.strip_prefix(root).map_err(|e|e.to_string())?.to_string_lossy().replace('\\',"/");
  let result=Command::new("readelf").args(["-dW"]).arg(&p).output().map_err(|e|e.to_string())?;
  if !result.status.success(){return Err(format!("readelf failed for packaged ELF {rel}"))}
  let imports=needed(&String::from_utf8(result.stdout).map_err(|e|e.to_string())?)?;
  if out.insert(rel,imports).is_some(){return Err("duplicate ELF path".into())}
 }
 Ok(())
}
fn inventory(root:&Path)->Result<BTreeMap<String,Vec<String>>,String>{
 let canonical=root.canonicalize().map_err(|e|e.to_string())?;
 let mut out=BTreeMap::new();
 visit(&canonical,&canonical,&mut out)?;
 if out.is_empty(){return Err("no actual packaged ELF files".into())}
 Ok(out)
}
fn counts(m:&BTreeMap<String,Vec<String>>)->(usize,usize,usize){
 let all=m.values().flat_map(|v|v.iter()).collect::<BTreeSet<_>>();
 (m.len(),m.values().map(Vec::len).sum(),all.len())
}
fn run()->Result<(),String>{
 let a=env::args().collect::<Vec<_>>();
 if a.len()!=4{return Err("usage: COMPILED_FULL_DIR COMPILED_FOUR_LEAN_DIR OUTPUT_JSON".into())}
 let full=inventory(&PathBuf::from(&a[1]))?;
 let lean=inventory(&PathBuf::from(&a[2]))?;
 let orig=counts(&full);let candidate=counts(&lean);
 if orig!=(28,268,50){return Err(format!("original source full compiled ELF graph mismatch: {orig:?}"))}
 if candidate!=(28,268,50){return Err(format!("candidate compiled ELF graph count drift: {candidate:?}"))}
 if full!=lean{
  let left=full.keys().collect::<BTreeSet<_>>();
  let right=lean.keys().collect::<BTreeSet<_>>();
  let added=right.difference(&left).count();
  let removed=left.difference(&right).count();
  let modified=full.iter().filter(|(name,needed)|lean.get(*name)!=Some(*needed)).count();
  return Err(format!("combined compiled native imports changed: added_paths={added} removed_paths={removed} different_imports={modified}"))
 }
 let report=format!(concat!(
 "{{\n",
 " \"schema_version\":1,\n",
 " \"status\":\"compiled_source_matched_combined_four_native_elf_imports_unchanged\",\n",
 " \"original_full_elf_count\":{},\n",
 " \"combined_lean_elf_count\":{},\n",
 " \"original_full_direct_needed_edges\":{},\n",
 " \"combined_lean_direct_needed_edges\":{},\n",
 " \"original_full_unique_needed_names\":{},\n",
 " \"combined_lean_unique_needed_names\":{},\n",
 " \"per_file_exact_needed_order_identical\":true,\n",
 " \"all_twenty_eight_elf_paths_unchanged\":true,\n",
 " \"real_native_elf_metadata_inspected_without_execution\":true,\n",
 " \"per_file_binary_sha256_identical\":false,\n",
 " \"runtime_dynamic_or_transitive_dependency_closure_proven\":false,\n",
 " \"default_browser_modified\":false,\n",
 " \"source_removal_authorized\":false,\n",
 " \"m3_sixth_gate_closed\":false\n",
 "}}\n"
 ),orig.0,candidate.0,orig.1,candidate.1,orig.2,candidate.2);
 fs::write(&a[3],report).map_err(|e|e.to_string())?;
 println!("PASS: 28 native ELF files, 268 direct needed edges, 50 unique names, exact per-ELF imports preserved");
 Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: source-matched four-optin native ELF direct graph: {e}");std::process::exit(1)}}
#[cfg(test)]mod tests{
 use super::*;
 #[test]fn reject_malformed_and_accept_real_needed(){
  let x=" 0x0000000000000001 (NEEDED)             Shared library: [libxul.so]\n";
  assert_eq!(needed(x).unwrap(),vec!["libxul.so"]);
  assert!(needed(" (NEEDED) no library bracket").is_err());
  assert!(needed(" (NEEDED) Shared library: [/evil.so]").is_err());
 }
 #[test]fn count_exact_edge_and_name_members(){
  let mut map=BTreeMap::new();
  map.insert("app".to_string(),vec!["a.so".into(),"b.so".into()]);
  map.insert("lib.so".to_string(),vec!["a.so".into()]);
  assert_eq!(counts(&map),(2,3,2));
 }
}
