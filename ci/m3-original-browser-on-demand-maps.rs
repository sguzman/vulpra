// Original Vulpra WebAudio test: bounded on-demand /proc/maps snapshot.
// Only /original/vulpra and /original/vulpra-bin executable PIDs are included;
// no paths, PIDs, memory contents or raw /proc files are exported. This is one
// sampled phase's residency evidence, NOT general dynamic loader closure.
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::Path;

const SRC: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const SHA: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const PACKAGE: &str = "/original";
const MAX_PROCESSES: usize = 128;
const MAX_MAP_BYTES: usize = 8 * 1024 * 1024;
const MAX_NAMES: usize = 256;

fn safe_name(s: &str) -> bool {
    !s.is_empty() && s.len() <= 111 &&
        s.bytes().all(|c| c.is_ascii_alphanumeric() || b"._+-".contains(&c))
}
fn is_elf_library(s: &str) -> bool {
    s.ends_with(".so") ||
        s.rsplit_once(".so.").is_some_and(|(_,v)| {
            v.as_bytes().first().is_some_and(|b| b.is_ascii_digit())
        })
}
fn is_pulse_library(name: &str) -> bool {
    name=="libpulse.so.0" ||
        name.strip_prefix("libpulse.so.0.").is_some_and(|suffix| {
            !suffix.is_empty() &&
                suffix.bytes().all(|b| b.is_ascii_digit() || b==b'.') &&
                suffix.as_bytes().last().is_some_and(|b|b.is_ascii_digit())
        })
}
fn in_package(p: &str) -> bool {
    p.strip_prefix(PACKAGE).is_some_and(|s| s.starts_with('/'))
}
fn is_original_browser_exe(p: &Path) -> bool {
    p.to_str().is_some_and(|s| {
        in_package(s) && matches!(s.rsplit('/').next(),
                                  Some("vulpra") | Some("vulpra-bin"))
    })
}
fn parse_maps(text: &str, package: &mut BTreeSet<String>,
              host: &mut BTreeSet<String>) -> Result<(), String> {
    for line in text.lines() {
        let Some(path) = line.split_whitespace().nth(5) else {continue};
        if !path.starts_with('/') {continue}
        let basename = path.rsplit('/').next().unwrap_or("");
        if !is_elf_library(basename) {continue}
        if !safe_name(basename) {return Err("unsafe library name".into())}
        if in_package(path) {package.insert(basename.into());}
        else {host.insert(basename.into());}
        if package.len() + host.len() > MAX_NAMES {
            return Err("overlarge bounded library census".into())
        }
    }
    Ok(())
}
fn json_array(xs: &BTreeSet<String>) -> String {
    format!("[{}]",xs.iter().map(|x|format!("\"{x}\""))
        .collect::<Vec<_>>().join(","))
}
fn census() -> Result<(usize,usize,BTreeSet<String>,BTreeSet<String>),String> {
    let mut processes=0usize;
    let mut unreadable=0usize;
    let mut package=BTreeSet::new();
    let mut host=BTreeSet::new();
    for e in fs::read_dir("/proc").map_err(|_|"cannot enumerate private processes")? {
        let e=e.map_err(|_|"invalid private process entry")?;
        let n=e.file_name();
        if n.to_str().and_then(|s|s.parse::<u32>().ok()).is_none(){continue}
        let dir=e.path();
        let Ok(exe)=fs::read_link(dir.join("exe")) else{continue};
        if !is_original_browser_exe(&exe){continue}
        processes+=1;
        if processes>MAX_PROCESSES{return Err("too many private browser processes".into())}
        match fs::read_to_string(dir.join("maps")){
            Ok(data)=>{
                if data.len()>MAX_MAP_BYTES{return Err("oversize browser process map".into())}
                parse_maps(&data,&mut package,&mut host)?;
            }
            Err(_)=>unreadable+=1,
        }
    }
    if processes==0 || processes==unreadable ||
        !package.contains("libxul.so") || !package.contains("libmozgtk.so") {
        return Err("original browser live native mappings not witnessed".into())
    }
    Ok((processes,unreadable,package,host))
}
fn run() -> Result<(),String>{
    let a:Vec<String>=env::args().collect();
    if a.len()!=4 || !matches!(a[1].as_str(),"before"|"during") ||
       a[2]!=PACKAGE || !a[3].starts_with("/reports/") ||
       !a[3].ends_with(".json") || a[3].len()>160 {
        return Err("usage: on-demand-map before|during /original /reports/<name>.json".into());
    }
    let (processes,unreadable,package,host)=census()?;
    // /proc/maps records the fully versioned backing ELF filename,
    // not necessarily the libpulse.so.0 SONAME used by dlopen callers.
    let pulse=host.iter().any(|name|is_pulse_library(name));
    if a[1]=="during" && !pulse {
        return Err("WebAudio stream did not map libpulse.so.0 in original browser".into())
    }
    let report=format!(concat!(
        "{{",
        "\"schema_version\":1,",
        "\"status\":\"original_browser_feature_live_mapped_library_snapshot\",",
        "\"original_source_commit\":\"{}\",",
        "\"original_archive_sha256\":\"{}\",",
        "\"phase\":\"{}\",",
        "\"original_browser_processes_observed\":{},",
        "\"unreadable_original_browser_maps\":{},",
        "\"package_mapped_shared_library_basenames\":{},",
        "\"host_mapped_shared_library_basenames\":{},",
        "\"libpulse_mapped_in_original_browser\":{},",
        "\"original_browser_executables_only\":true,",
        "\"raw_paths_or_process_ids_exported\":false,",
        "\"no_physical_audio_device_used\":true,",
        "\"time_bounded_phase_not_full_dlopen_graph\":true,",
        "\"source_pruning_authorized\":false,",
        "\"m3_sixth_gate_closed\":false",
        "}}\n"
    ),SRC,SHA,a[1],processes,unreadable,
        json_array(&package),json_array(&host),pulse);
    fs::write(&a[3],report).map_err(|_|"cannot write private WebAudio map evidence")?;
    println!("M3_WEBAUDIO_MAP_SNAPSHOT={} process_maps={processes}",a[1]);
    Ok(())
}
fn main(){
    if let Err(e)=run(){eprintln!("M3_WEBAUDIO_MAP_ERROR={e}");std::process::exit(1)}
}
#[cfg(test)]
mod tests{
    use super::*;
    #[test]fn only_original_browser(){
        assert!(is_original_browser_exe(Path::new("/original/vulpra")));
        assert!(!is_original_browser_exe(Path::new("/usr/bin/firefox")));
        assert!(!is_original_browser_exe(Path::new("/original/auxhelper")));
    }
    #[test]fn only_elf_libraries(){
        assert!(is_elf_library("libpulse.so.0"));
        assert!(is_elf_library("libmozgtk.so"));
        assert!(!is_elf_library("ld.so.cache"));
        assert!(!is_elf_library("libpulse.so.debug"));
        assert!(!is_elf_library("audio-device"));
    }
    #[test]fn pulse_soname_vs_mapped_filename(){
        assert!(is_pulse_library("libpulse.so.0"));
        assert!(is_pulse_library("libpulse.so.0.24.3"));
        assert!(!is_pulse_library("libpulse.so.0.debug"));
        assert!(!is_pulse_library("libpulse-trace.so"));
    }
    #[test]fn parser_ignores_unrelated(){
        let input="123-456 r-xp 00000000 00:00 1 /original/libxul.so\n\
                   456-789 r-xp 00000000 00:00 1 /usr/lib/libpulse.so.0\n\
                   789-abc r--p 00000000 00:00 1 /etc/ld.so.cache\n";
        let(mut p,mut h)=(BTreeSet::new(),BTreeSet::new());
        parse_maps(input,&mut p,&mut h).unwrap();
        assert!(p.contains("libxul.so"));
        assert!(h.contains("libpulse.so.0"));
        assert!(!h.contains("ld.so.cache"));
    }
}