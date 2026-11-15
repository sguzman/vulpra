// Parse temporary Firefox160 MOZ_LOG_FILE files for exact, source-grounded
// FFVPX link-failure and platform decoder diagnostic witnesses.
// Report counts only; do not export log lines, paths, PIDs, profiles, or log
// filenames. No browser build or source edits. Rust std-only.
use std::env;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Write};
use std::path::Path;

const MAX_FILES: usize = 128;
const MAX_FILE_BYTES: u64 = 40 * 1024 * 1024;
const MAX_TOTAL_BYTES: u64 = 512 * 1024 * 1024;
const MAX_LINE_BYTES: usize = 128 * 1024;
#[derive(Default)]
struct Tally {
    log_files: usize,
    pdm_any: u64,
    pdm_rdd_order: u64,
    pdm_agnostic_vpx_support: u64,
    ffvpx_link_no_provided_lib: u64,
    ffvpx_link_success: u64,
    ffvpx_unable_to_load_lib: u64,
    ffmpeg_video_lines: u64,
    total_lines: u64,
}
fn classify(line:&str, t:&mut Tally) {
    t.total_lines+=1;
    if line.contains("PlatformDecoderModule") {
        t.pdm_any+=1;
        if line.contains("PDMInitializer, RDD PDM order:") {
            t.pdm_rdd_order+=1;
        }
        if line.contains("Agnostic decoder supports requested type") {
            t.pdm_agnostic_vpx_support+=1;
        }
        if line.contains("FFVPX: Link result: NoProvidedLib") {
            t.ffvpx_link_no_provided_lib+=1;
        }
        if line.contains("FFVPX: Link result: Success") {
            t.ffvpx_link_success+=1;
        }
    }
    if line.contains("FFmpegVideo") {
        t.ffmpeg_video_lines+=1;
        if line.contains("FFVPX: unable to load library ") {
            t.ffvpx_unable_to_load_lib+=1;
        }
    }
}
fn count_logs(root:&Path, prefix:&str)->Result<Tally,String>{
    if prefix!="baseline-moz" && prefix!="denied-moz" {
        return Err("unexpected Firefox160 temporary logging prefix".into());
    }
    if !root.is_dir(){return Err("ephemeral MOZ_LOG directory missing".into());}
    let mut entries=Vec::new();
    let mut bytes=0u64;
    for entry in fs::read_dir(root).map_err(|_|"temporary MOZ_LOG read error")? {
        let entry=entry.map_err(|_|"bad temporary MOZ_LOG entry")?;
        let n=entry.file_name();
        let Some(n)=n.to_str() else {continue};
        if !(n==prefix || n.starts_with(&format!("{prefix}."))) {continue;}
        let meta=fs::symlink_metadata(entry.path()).map_err(|_|"bad MOZ_LOG metadata")?;
        if !meta.file_type().is_file() || meta.len()==0 || meta.len()>MAX_FILE_BYTES {
            return Err("missing, symlinked or oversized MOZ_LOG file".into());
        }
        bytes=bytes.checked_add(meta.len()).ok_or("MOZ_LOG byte overflow")?;
        if bytes>MAX_TOTAL_BYTES {return Err("MOZ_LOG aggregate exceeds cap".into());}
        entries.push(entry.path());
    }
    if entries.is_empty() || entries.len()>MAX_FILES{
        return Err("no captured MOZ_LOG_FILE files or excessive process logs".into());
    }
    entries.sort();
    let mut result=Tally::default();
    result.log_files=entries.len();
    let mut row=Vec::new();
    for path in entries {
        let file=File::open(path).map_err(|_|"cannot open temporary log")?;
        let mut reader=BufReader::new(file);
        loop {
            row.clear();
            let n=reader.read_until(b'\n',&mut row).map_err(|_|"cannot read temporary log")?;
            if n==0 {break;}
            if n>MAX_LINE_BYTES {return Err("MOZ_LOG oversized line".into());}
            if let Ok(line)=std::str::from_utf8(&row) {classify(line,&mut result);}
        }
    }
    Ok(result)
}
fn json(t:&Tally)->String{
    format!(concat!(
        "{{\"schema_version\":1,",
        "\"status\":\"firefox160_private_mozilla_decoder_log_counters\",",
        "\"raw_private_log_files_captured\":{},",
        "\"counted_MOZ_LOG_lines\":{},",
        "\"platform_decoder_module_log_lines\":{},",
        "\"rdd_pdm_order_markers\":{},",
        "\"agnostic_decoder_support_markers\":{},",
        "\"ffvpx_NoProvidedLib_link_result_markers\":{},",
        "\"ffvpx_Success_link_result_markers\":{},",
        "\"ffvpx_unable_to_load_library_markers\":{},",
        "\"ffmpeg_video_log_lines\":{},",
        "\"actual_FFVPX_NoProvidedLib_source_log_observed\":{},",
        "\"specific_video_decoder_selected_from_these_log_markers\":false,",
        "\"direct_compiled_FFVPX_machine_branch_proven\":false,",
        "\"raw_MOZ_LOG_files_or_lines_archived\":false,",
        "\"source_pruning_authorized\":false,",
        "\"m3_sixth_gate_closed\":false}}\n"
    ),t.log_files,t.total_lines,t.pdm_any,t.pdm_rdd_order,
      t.pdm_agnostic_vpx_support,t.ffvpx_link_no_provided_lib,t.ffvpx_link_success,
      t.ffvpx_unable_to_load_lib,t.ffmpeg_video_lines,
      if t.ffvpx_link_no_provided_lib>0 {"true"} else {"false"})
}
fn run()->Result<(),String>{
    let args:Vec<String>=env::args().collect();
    if args.len()!=4 {
        return Err("usage: m3-ffvpx-mozlog-observer EPHEMERAL_DIR baseline-moz|denied-moz REPORT_JSON".into());
    }
    let count=count_logs(Path::new(&args[1]),&args[2])?;
    let out=Path::new(&args[3]);
    File::create(out).and_then(|mut f|f.write_all(json(&count).as_bytes()))
        .map_err(|_|"cannot write sanitized Firefox160 log counters")?;
    println!("PASS: Mozilla decoder logs sanitized, {} files, {} PDM lines, {} FFVPX NoProvidedLib markers; no raw log archived",
        count.log_files,count.pdm_any,count.ffvpx_link_no_provided_lib);
    Ok(())
}
fn main(){if let Err(e)=run(){eprintln!("FAIL: {e}");std::process::exit(1);}}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn exact_source_logging_markers() {
        let mut t=Tally::default();
        for line in [
            "[Parent 123: Main Thread]: D/PlatformDecoderModule FFVPX: Link result: NoProvidedLib",
            "[RDD 321: Media]: D/PlatformDecoderModule PDMInitializer, RDD PDM order:",
            "[RDD 321: Media]: D/PlatformDecoderModule Agnostic decoder supports requested type 'video/vp9'",
            "[RDD 321: Media]: D/FFmpegVideo FFVPX: unable to load library /private/noshow.so",
            "[RDD 321: Media]: D/PlatformDecoderModule FFVPX: Link result: Success"
        ] {classify(line,&mut t);}
        assert_eq!(t.ffvpx_link_no_provided_lib,1);
        assert_eq!(t.ffvpx_link_success,1);
        assert_eq!(t.pdm_rdd_order,1);
        assert_eq!(t.pdm_agnostic_vpx_support,1);
        assert_eq!(t.ffvpx_unable_to_load_lib,1);
        let sanitized=json(&t);
        assert!(sanitized.contains("\"actual_FFVPX_NoProvidedLib_source_log_observed\":true"));
        assert!(!sanitized.contains("/private/"));
    }
    #[test] fn ignore_fake_markers_outside_expected_log_category(){
        let mut t=Tally::default();
        classify("untrusted random log FFVPX: Link result: NoProvidedLib",&mut t);
        classify("untrusted random log FFVPX: unable to load library private",&mut t);
        assert_eq!(t.ffvpx_link_no_provided_lib,0);
        assert_eq!(t.ffvpx_unable_to_load_lib,0);
        assert!(count_logs(Path::new("/tmp"),"unknown").is_err());
    }
}
