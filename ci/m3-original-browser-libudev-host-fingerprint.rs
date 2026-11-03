// CI-only original-browser host libudev fingerprint, without symbol interposition.
// Do not export raw maps, PIDs, host paths, or security-key data.
use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::process::Command;

const SOURCE: &str = "b1482404dfb8b01342990ee99ea3df0f9756b5f7";
const ARCHIVE: &str = "7aa4f20d1f6058e2ef92d73dec875f3bbfe98ee5a5fe1ea1b11fcb294762069a";
const OUTPUT: &str = "/reports/m3-original-browser-libudev-host-fingerprint.json";

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct Mapping { path: String, device_major: u64, device_minor: u64, inode: u64 }

fn mapped_udev(line: &str) -> Result<Option<Mapping>, String> {
    let mut fields = line.split_whitespace();
    let _range = fields.next();
    let _perms = fields.next();
    let _offset = fields.next();
    let dev = fields.next().ok_or("invalid process mapping device")?;
    let inode = fields.next().ok_or("invalid process mapping inode")?;
    let Some(path) = fields.next() else { return Ok(None) };
    if !path.starts_with("/usr/lib/libudev.so.1") { return Ok(None) }
    let name = path.rsplit('/').next().unwrap_or("");
    if name != "libudev.so.1" && !name.strip_prefix("libudev.so.1.").is_some_and(|s|
        !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit() || b == b'.') &&
        s.as_bytes().last().is_some_and(|b| b.is_ascii_digit())) {
        return Err("unexpected mapped libudev backing filename".into())
    }
    if fields.next().is_some() { return Err("mapped libudev path has unexpected suffix".into()) }
    let (major, minor) = dev.split_once(':').ok_or("invalid process mapping device pair")?;
    let device_major = u64::from_str_radix(major, 16).map_err(|_|"invalid major device")?;
    let device_minor = u64::from_str_radix(minor, 16).map_err(|_|"invalid minor device")?;
    let inode = inode.parse::<u64>().map_err(|_|"invalid process mapping inode number")?;
    if inode == 0 { return Err("mapped libudev has no disk inode".into()) }
    Ok(Some(Mapping { path: path.into(), device_major, device_minor, inode }))
}

// Linux dev_t layout, equivalent to GNU major() / minor().
fn device_numbers(dev: u64) -> (u64, u64) {
    (((dev >> 8) & 0xfff) | ((dev >> 32) & !0xfff),
     (dev & 0xff) | ((dev >> 12) & !0xff))
}

fn witness() -> Result<(String, String, usize), String> {
    let mut mappings = BTreeSet::new();
    let mut browsers = 0usize;
    let mut read_ok = 0usize;
    for entry in fs::read_dir("/proc").map_err(|_|"private process directory unavailable")? {
        let entry = entry.map_err(|_|"invalid private process entry")?;
        if !entry.file_name().to_string_lossy().bytes().all(|b| b.is_ascii_digit()) { continue }
        let root = entry.path();
        let Ok(exe) = fs::read_link(root.join("exe")) else { continue };
        if exe != Path::new("/original/vulpra") && exe != Path::new("/original/vulpra-bin") { continue }
        browsers += 1;
        if browsers > 128 { return Err("too many original browser processes".into()) }
        let Ok(maps) = fs::read_to_string(root.join("maps")) else { continue };
        if maps.len() > 8 * 1024 * 1024 { return Err("oversized private maps".into()) }
        read_ok += 1;
        if !maps.lines().any(|line| line.split_whitespace().nth(5).is_some_and(|p| p == "/original/libxul.so")) { continue }
        for line in maps.lines() {
            if let Some(mapping) = mapped_udev(line)? { mappings.insert(mapping); }
        }
    }
    if browsers == 0 || read_ok == 0 || mappings.is_empty() {
        return Err("no libudev mapping in original libxul-loaded browser process".into())
    }
    let mut fingerprinted = BTreeSet::new();
    for m in &mappings {
        let meta = fs::metadata(&m.path).map_err(|_|"mapped host ELF no longer readable")?;
        if device_numbers(meta.dev()) != (m.device_major, m.device_minor) || meta.ino() != m.inode {
            return Err("mapped ELF inode/device does not match host filesystem".into())
        }
        if !meta.is_file() || meta.len() == 0 || meta.len() > 64 * 1024 * 1024 {
            return Err("mapped host ELF not a bounded regular file".into())
        }
        let result = Command::new("/usr/bin/sha256sum").arg("--").arg(&m.path)
            .output().map_err(|_|"cannot hash mapped host ELF")?;
        if !result.status.success() { return Err("host ELF fingerprint command failed".into()) }
        let output = std::str::from_utf8(&result.stdout).map_err(|_|"non-UTF8 hash output")?;
        let sha = output.split_whitespace().next().ok_or("empty mapped ELF hash")?;
        if sha.len() != 64 || !sha.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()) {
            return Err("invalid mapped ELF SHA-256".into())
        }
        let after = fs::metadata(&m.path).map_err(|_|"host ELF vanished after hashing")?;
        if after.dev() != meta.dev() || after.ino() != meta.ino() || after.len() != meta.len() {
            return Err("host ELF identity changed during hash".into())
        }
        let name = m.path.rsplit('/').next().ok_or("missing host ELF basename")?;
        fingerprinted.insert((name.to_string(), sha.to_string()));
    }
    if fingerprinted.len() != 1 { return Err("multiple distinct host libudev ELF fingerprints".into()) }
    let (name, sha) = fingerprinted.into_iter().next().ok_or("no fingerprint")?;
    Ok((name, sha, browsers))
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 || args[1] != OUTPUT { return Err("unexpected host ELF evidence destination".into()) }
    let (name, sha, browsers) = witness()?;
    fs::write(OUTPUT, format!(concat!(
        "{{\"schema_version\":1,",
        "\"status\":\"original_browser_live_mapped_host_libudev_sha256\",",
        "\"original_source_commit\":\"{}\",",
        "\"original_archive_sha256\":\"{}\",",
        "\"host_mapped_elf_backing_name\":\"{}\",",
        "\"host_mapped_elf_sha256\":\"{}\",",
        "\"original_browser_processes_observed\":{},",
        "\"original_libxul_loaded_browser_mapping_verified\":true,",
        "\"mapped_elf_device_and_inode_verified\":true,",
        "\"no_ld_preload_or_ld_audit_used\":true,",
        "\"raw_process_ids_paths_or_maps_exported\":false,",
        "\"exact_rust_or_c_caller_identified\":false,",
        "\"full_dynamic_dependency_closure_proven\":false,",
        "\"source_pruning_authorized\":false,",
        "\"m3_sixth_gate_closed\":false}}\n"
    ), SOURCE, ARCHIVE, name, sha, browsers))
        .map_err(|_|"cannot save sanitized mapped host ELF fingerprint")?;
    println!("M3_ORIGINAL_BROWSER_MAPPED_LIBUDEV_SHA256=PASS");
    Ok(())
}
fn main() { if let Err(e) = run() { eprintln!("M3_MAPPED_LIBUDEV_HASH_ERROR={e}"); std::process::exit(1) } }

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn parses_realistic_libudev_mapping() {
        let x = mapped_udev("7f010-7f020 r-xp 00000000 00:13 2244 /usr/lib/libudev.so.1.7.15").unwrap().unwrap();
        assert_eq!(x.device_major, 0); assert_eq!(x.device_minor, 0x13); assert_eq!(x.inode,2244);
        assert_eq!(x.path,"/usr/lib/libudev.so.1.7.15");
    }
    #[test] fn malformed_udev_mapping_rejected() {
        assert!(mapped_udev("a-b r--p 0 invalid 12 /usr/lib/libudev.so.1.7.15").is_err());
        assert!(mapped_udev("a-b r--p 0 08:01 0 /usr/lib/libudev.so.1.7.15").is_err());
        assert!(mapped_udev("a-b r--p 0 08:01 12 /usr/lib/libudev.so.1.debug").is_err());
        assert!(mapped_udev("a-b r--p 0 08:01 12 /usr/lib/libudev.so.1.7.15 (deleted)").is_err());
        assert!(mapped_udev("a-b r--p 0 08:01 12 /usr/lib/libc.so.6").unwrap().is_none());
    }
    #[test] fn linux_major_minor_decode() {
        assert_eq!(device_numbers(0x801), (8,1));
        assert_eq!(device_numbers(0x13), (0,19));
    }
}
