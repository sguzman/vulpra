// Exact historical source contract census for Vulpra M3 native hash-table change.
// Read only: no Python execution, source modification, binary execution, or
// assumptions about the meaning of raw compiled module index 452.
use std::collections::BTreeSet;
use std::fs;
use std::path::Path;
fn file(root: &Path, rel: &str) -> Result<String, String> {
    fs::read_to_string(root.join(rel)).map_err(|e|format!("Missing pinned source {rel}: {e}"))
}
fn require(text:&str,needle:&str,context:&str)->Result<(),String>{
    if !text.contains(needle){return Err(format!("Missing exact pinned source anchor in {context}"));}
    Ok(())
}
fn list_entries(src: &str, start: &str, close: &str) -> Result<Vec<String>,String>{
    let body=src.split_once(start).ok_or("Missing Python static list anchor")?.1;
    let content=body.split_once(close).ok_or("Unterminated Python static page list")?.0;
    let mut pages=Vec::new();
    for line in content.lines() {
        let raw=line.trim();
        if raw.is_empty(){continue;}
        if !raw.starts_with('\'') || !raw.ends_with("',") && !raw.ends_with('\''){
            return Err("Unexpected nonliteral Python page list member".into());
        }
        let name=raw.trim_end_matches(',').trim_matches('\'');
        if name.is_empty()||!name.chars().all(|c|c.is_ascii_lowercase()||c.is_ascii_digit()){
            return Err("Unexpected page name in pinned source".into());
        }
        pages.push(name.to_owned());
    }
    if pages.len()!=pages.iter().collect::<BTreeSet<_>>().len(){
        return Err("Duplicate pinned AboutRedirector page".into());
    }
    Ok(pages)
}
fn run()->Result<(),String>{
    let args:Vec<_>=std::env::args().collect();
    if args.len()!=5 {
        return Err("usage: source-contract-census SOURCE_ROOT NORMAL_MOZCONFIG LEAN_MOZCONFIG REPORT".into());
    }
    let original=Path::new(&args[1]);
    let conf=file(original,"browser/components/about/components.conf")?;
    let cxx=file(original,"browser/components/about/AboutRedirector.cpp")?;
    let browser_config=file(original,"browser/moz.configure")?;
    let toolkit_config=file(original,"toolkit/moz.configure")?;
    let generator=file(original,"xpcom/components/gen_static_components.py")?;
    let static_cxx=file(original,"xpcom/components/StaticComponents.cpp.in")?;
    let hash=file(original,"xpcom/ds/PerfectHash.h")?;
    let baseline=fs::read_to_string(&args[2]).map_err(|e|e.to_string())?;
    let lean=fs::read_to_string(&args[3]).map_err(|e|e.to_string())?;

    let base=list_entries(&conf,"pages = [\n","\n]\n")?;
    let profiles=list_entries(&conf,
        "if buildconfig.substs.get('MOZ_SELECTABLE_PROFILES'):\n    pages += [\n",
        "\n    ]")?;
    require(&conf,
        "if buildconfig.substs.get('MOZ_NORMANDY'):\n    pages += ['studies']",
        "about/components.conf")?;
    require(&conf,"'contract_ids': ['@mozilla.org/network/protocol/about;1?what=%s' % page",
        "AboutRedirector XPCOM contracts")?;
    require(&conf,"'legacy_constructor': 'mozilla::browser::AboutRedirector::Create'",
        "AboutRedirector constructor")?;
    require(&cxx,"#ifdef MOZ_NORMANDY\n    {\"studies\"",
        "AboutRedirector C++ guard")?;
    require(&toolkit_config,"set_define(\"MOZ_SELECTABLE_PROFILES\", True)",
        "profile-management configure")?;
    require(&toolkit_config,"set_config(\"MOZ_SELECTABLE_PROFILES\", True)",
        "profile-management substitution")?;
    require(&browser_config,
        "imply_option(\"MOZ_NORMANDY\", True, when=vulpra_include_normandy)",
        "Vulpra Normandy configuration")?;
    require(&lean,"export VULPRA_EXPERIMENT_NO_NORMANDY=1",
        "isolated lean mozconfig")?;
    if baseline.contains("export VULPRA_EXPERIMENT_NO_NORMANDY=1") {
        return Err("Protected normal browser unexpectedly disables Normandy".into());
    }
    require(&generator,"contract_phf = PerfectHash(contracts, key=lambda entry: entry.contract.encode())",
        "XPCOM generated static contract hash")?;
    require(&generator,"{strings.entry_to_cxx(self.contract)}",
        "compiled XPCOM contract key")?;
    require(&generator,"{lower_module_id(self.module)}",
        "compiled XPCOM contract module ID")?;
    require(&static_cxx,"//# @module_contract_id_table@",
        "C++ generated contract table")?;
    require(&static_cxx,"StaticComponents::LookupByContractID",
        "compiled contract lookup")?;
    require(&static_cxx,"StaticComponents::InvalidateContractID",
        "compiled contract invalidation")?;
    require(&hash,"FNV_OFFSET_BASIS = 0x811C9DC5",
        "source FNV basis")?;
    require(&hash,"FNV_PRIME = 16777619",
        "source FNV prime")?;
    require(&hash,"return aEntries[Hash(basis, aKey, aLen) % NEntries];",
        "final perfect-hash entry divisor")?;
    if base.len()!=31 || profiles.len()!=4 ||
       base.iter().any(|v|v=="studies") || profiles.iter().any(|v|v=="studies"){
        return Err("Pinned AboutRedirector contract page count drift".into());
    }
    let normal=base.len()+profiles.len()+1;
    let stripped=base.len()+profiles.len();
    if normal!=36 || stripped!=35 {return Err("Unmatched source contract cardinality".into());}
    fs::write(&args[4],format!(
        "{{\"schema_version\":1,\"status\":\"pinned_original_normandy_aboutstudies_contract_source_guard\",\
        \"unconditional_about_pages\":{},\"selectable_profile_pages\":{},\
        \"full_normandy_only_pages\":1,\"normal_about_contracts\":{normal},\
        \"four_optin_lean_about_contracts\":{stripped},\
        \"about_contract_delta\":{},\
        \"excluded_lean_contract\":\"@mozilla.org/network/protocol/about;1?what=studies\",\
        \"about_redirector_constructor_preserved\":true,\
        \"source_cpp_route_guarded_by_normandy\":true,\
        \"xpcom_perfecthash_contract_entries_verified\":true,\
        \"xpcom_contract_entries_store_module_ids\":true,\
        \"compiled_raw_module_id_452_independently_named\":false,\
        \"actual_compiled_binary_verified_by_this_source_guard\":false,\
        \"unrelated_static_module_dependencies_verified\":false,\
        \"source_removal_authorized\":false,\"m3_sixth_gate_closed\":false}}\n",
        base.len(),profiles.len(),normal-stripped
    )).map_err(|e|e.to_string())?;
    println!("PASS: pinned original source generates 36 about contracts normally, 35 lean; one Normandy-only about:studies XPCOM contract");
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]
    fn parse_declared_python_literal_pages(){
        let rows="pages = [\n    'foo',\n    'bar',\n]\n";
        assert_eq!(list_entries(rows,"pages = [\n","\n]\n").unwrap(),vec!["foo".to_owned(),"bar".to_owned()]);
        assert!(list_entries("pages = [\nfoo,\n]\n","pages = [\n","\n]\n").is_err());
    }
    #[test]
    fn reject_duplicated_page_entries(){
        assert!(list_entries("pages = [\n    'foo',\n    'foo',\n]\n","pages = [\n","\n]\n").is_err());
    }
}
