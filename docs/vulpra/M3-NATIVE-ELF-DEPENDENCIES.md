# M3 physical ELF layout and loader dependency census

**Verified native binary:** [GitHub Actions 40927060259](https://github.com/sguzman/vulpra/actions/runs/40927060259) **PASSED** (evidence artifact `m3-historical-native-elf-census`, ID **12920961955**). It verified the existing full normal Vulpra native Linux `tar.xz` archive's SHA-256, streamed exactly one bounded regular `vulpra/libxul.so` member to an isolated temporary file, and read ELF metadata using `readelf -hW/-SW/-dW`. **It never invoked `ldd`, opened a runtime loader, loaded the shared library, ran Vulpra, or recompiled Firefox.** Twelve independent ELF/archive/anti-tamper fixtures passed, including rejection of duplicate libxul members, suspicious symlinks, mismatched sidecars, and incorrectly classified external dependencies.

The archive was built from **source `1683ca67b69389a879717bcd537772c3b40624b6`**; it is *not* an exact whole-source-matched binary from current main. Its compressed archive length is **86,930,792 B** and `libxul.so` is **189,486,920 logical B**.

## ELF section layout in the actual `libxul.so`

| Broad source-independent ELF bucket | File-backed section sizes |
| --- | ---: |
| Executable sections | **128,114,504 B** |
| Read-only and relocated data | **43,537,784 B** |
| Unwind and exception data | **16,488,572 B** |
| Writable/TLS file-backed sections | **1,004,352 B** |
| Relocation sections | **84,264 B** |
| Symbols and names | **144,257 B** |
| Other named sections | **108,769 B** |

These section buckets are approximations by section *names*, and section sizes may overlap. `NOBITS` is tracked as virtual-only and excluded from file-backed bytes. **No section bucket can be assigned to a particular Firefox feature, programming language, dependency, or safe saving.** A linker map and source-matched configured build would be needed for such attribution.

## Direct ELF `DT_NEEDED` dependencies

The actual shared library declares **49 distinct direct dependency names**. Comparing each basename against the same checked archive's regular file and link members gives:

| Resolution scope from archive only | Direct names |
| --- | ---: |
| **Packaged regular libraries** | **13** |
| Archive symlink/hardlink declarations only | **0** |
| **Absent from the Vulpra archive** | **36** |

The bundled 13 include `libmozsandbox.so`, `libnspr4.so`, `libplc4.so`, `libplds4.so`, `libgkcodecs.so`, `liblgpllibs.so`, `libnss3.so`, `libnssutil3.so`, `libsmime3.so`, `libmozsqlite3.so`, `libssl3.so`, `libmozgtk.so` and `libmozwayland.so`.

The 36 nonbundled direct names include system-resolved libraries such as `libgtk-3.so.0`, `libgdk-3.so.0`, `libX11.so.6`, `libXcomposite.so.1`, `libasound.so.2`, `libc.so.6`, `libm.so.6`, `libfreetype.so.6`, `libfontconfig.so.1`, `libdbus-1.so.3`, `libstdc++.so.6` and `libgcc_s.so.1`. **“Absent from archive” does not mean missing at runtime**: this scan does not resolve them on a target machine or follow transitive `DT_NEEDED` and `dlopen` dependencies.

The simultaneous X11 and Wayland declarations do not mean Wayland support is redundant. GTK or fallback paths may rely on both. The [GTK/Wayland runtime evidence](ROADMAP.md) protects the accepted browser.

## Decision and next gate

**Keep** native Gecko, `libxul`, NSS/NSPR, SQLite, security/sandbox, GTK/Wayland/X11 compatibility and WebExtensions. Other candidate modules may still be conditional within the same linked library, but no marginal bytes can be inferred from `DT_NEEDED` or ELF section lengths.

Next useful tests are exact-source generated-config identification; a source-matched linker/section map; a complete transitive dependency census when needed for Linux packaging; and only then isolated native build options with Wayland, JavaScript/navigation, extensions, profile, locale and privacy fallback tests. No compiled feature omission, current-main native build or compressed saving is credited here.

**Accounting: M3 2/6 (33%), overall 44% (Δ 0 pp).**
