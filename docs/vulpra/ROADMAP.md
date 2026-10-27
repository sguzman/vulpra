# Vulpra roadmap

The milestones are ordered by engineering dependencies, not by arbitrary source-deletion targets. Completion requires the explicit gates below; no task becomes 100% on documentation alone.

## 🦊 M1 — Reproducible source foundation

### 🌱 Phase 1 — Provenance
- [x] 🔎 Confirm exact upstream tag and source archive SHA-256; extracted critical paths verified. Evidence: import run 40119418469, provenance ledger. Full tree equivalence is a separate remaining gate.
- [x] 📥 Import source to `upstream-base` and verify all source file contents, paths and symlinks. Evidence: passed CI 40120947358, with verified Git CRLF normalization and empty directory exceptions.
- [x] 🌿 Merge the baseline ancestry into `main`, preserve project rules and verify essential Firefox build paths. Evidence: commit 58802537 and GitHub file checks.

### 🛠️ Phase 2 — Execution
- [x] 🔧 Execute importer under GitHub Actions and resolve permission failures. Evidence: successful run 40119418469.
- [x] 🔐 Review licensing, notices and branding plan. Evidence: passed audit CI 40122675149 and docs/vulpra/LICENSING-BRANDING.md. Independent Vulpra branding remains an M2 release gate.

## 🐧 M2 — Working Linux browser

### ⚙️ Phase 1 — Build
- [x] 🧪 Implement private-profile launch contract and mocked executable regression tests. Evidence: passing CI 40124539256.
- [x] 📦 Stage a separate Vulpra launcher in a tarball and verify mock package/checksum/profile behavior. Evidence: passing CI 40125061263. Real native packaging remains unverified.
- [x] 🏷️ Configure independent Vulpra display strings and an upstream-supported app basename, retaining Gecko extension compatibility ID. Evidence: passing audit CI 40124841263. Actual compiled identity and icons remain unverified.
- [x] 🧱 Configure full native Linux x86-64 build with the pinned source and documented GitHub Actions toolchain. Evidence: configure-only runs 40126134453 and 40126662777 (--disable-tests); no compiled binary yet.
- [x] 🛡️ Produce independently branded packaged browser with dedicated profile; no changes to installed Firefox Developer Edition. Actual workstation evidence (2026-10-26): `./mach package` produced `vulpra-159.0.en-US.linux-x86_64.tar.xz`, staged `vulpra-local-20261026-094040-827316872.tar.xz` passed SHA-256, and launched headlessly using a temporary Vulpra-only profile, writing a PNG. Graphical Wayland, navigation and extensions remain separate gates.
- [x] 🤖 Verify packaged browser startup, Wayland, navigation/JavaScript and targeted WebExtension/profile security behavior. **Actual workstation passes on 2026-10-26:** native and packaged headless screenshot, Wayland graphics buffers/commits (09:58), localhost JS-initiated navigation and HTTP 302, PNG and profile isolation (10:20), plus `geckodriver` temporary unsigned XPI install/content scripts/background messaging/`storage.local`/uninstall/preserved Firefox profile (11:04). WebExtension report `.git/vulpra-native-build/webextension-smoke-20261026-110444.json`. M2 working-browser acceptance 5/5 (100%). This is not a complete release, security audit or updater.

### 📏 Phase 2 — Baseline
- [x] 📦 Record reproducible source, compiled package, binary sizes and build time. Source inventory measured in CI 40125494649; native build completed on workstation with reported 1052s successful incremental invocation, package verified by SHA-256, and acceptance baseline `acceptance-20261026-102011.json` generated in .git/vulpra-native-build (sizes and RSS recorded but actual numeric values in that JSON not yet separately reviewed).
- [x] 📊 Capture an initial target-workstation end-to-end timing and limited memory baseline. Real Vulpra packaged localhost JS navigation → 302 redirect → rendered screenshot took 0.895s; the generated baseline JSON also records sampled parent RSS. This is neither pure cold startup nor total multiprocess memory and is not a broad performance characterization.

## ✂️ M3 — User-specific debloating

**Status: in progress, 2/6 acceptance gates (33%) complete.** The native M2 browser remains protected. The opt-in Normandy runner has a measured compressed binary reduction; the bounded Windows/Cocoa source-only pruning now has complete CI native/browser acceptance and an exact 453-file deletion committed to main. These are distinct accomplishments: source blob reduction is not binary saving. Four M3 gates remain open and other platform trees still require selective audits.

### 🧭 Phase 1 — Evidence inventory
- [ ] 🗺️ Map feature bundles, binary dependencies, build dependencies and platform-specific modules.
- [ ] 🔬 Classify candidates as keep, disable, conditionally compile or remove. Include fallback and safety impact.

### 🪚 Phase 2 — Incremental removals
- [x] 🖥️ Audit and prune an initially bounded set of non-Linux widget/installer sources proven unnecessary for the Linux browser. **453 files (6,266,676 Git blob bytes)** permanently removed in [commit 81d9b335](https://github.com/sguzman/vulpra/commit/81d9b335b747c377b730a0c3a4de9ea1cf522fe5), preserving eight shared generator/Rust dependency files. Actual full native Linux build, Wayland, JS, WebExtension and Nimbus [CI 40519242468 passed](https://github.com/sguzman/vulpra/actions/runs/40519242468). Other non-Linux source trees remain unreviewed. **Source-only reduction, no claimed compiled-package savings.**
- [ ] 📣 Audit promotional UI, Pocket, account/Sync and telemetry paths against the user's use case.
- [ ] 🌐 Audit mobile, test fixtures and optional packaged localizations without breaking required desktop functionality.
- [x] 🧪 Demonstrate every **accepted** removal with relevant before/after measurements and passing targeted tests. **Normandy opt-in binary removal plus bounded source-only platform prune** (453 files / 6,266,676 Git blob bytes; complete native/runtime [40519242468](https://github.com/sguzman/vulpra/actions/runs/40519242468); no claimed binary saving). **Opt-in Normandy runner**, full 86,937,548 B vs lean 86,909,928 B (27,620 B, 0.032%) under source-matched Ubuntu builds. Native runs [lean 40431768974](https://github.com/sguzman/vulpra/actions/runs/40431768974) and [full 40431769117](https://github.com/sguzman/vulpra/actions/runs/40431769117), real runtime [40439671494](https://github.com/sguzman/vulpra/actions/runs/40439671494), matched-size [40439793884](https://github.com/sguzman/vulpra/actions/runs/40439793884). This gate must be maintained for every future accepted candidate.

## 🐞 M4 — Actual defect fixes and personalization

### 🧰 Phase 1 — User-visible reliability
- [ ] 📝 Capture reproducible bugs experienced on Vulpra's target environment, with observed/expected behavior.
- [ ] 🔍 Triage against current upstream fixes and create minimal reproduction tests.
- [ ] ✅ Author, test and ship fixes, each with regression evidence.

### 🦀 Phase 2 — Long-horizon Rust ownership
- [ ] 🧩 Inventory retained C/C++ and Python modules with dependency boundaries.
- [ ] 🦀 Migrate coherent subsystems incrementally into Rust while preserving browser behavior.
- [ ] 🧪 Verify final Rust/web-technology target only after all retained non-Rust components are addressed and integrated.

## Continuous acceptance gates

- 🛡️ Security update workflow and advisory response are perpetual requirements, not a one-time checkbox.
- 🧪 Never label a browser, removal, or rewrite “working” without actual build and behavior evidence.
- 📚 Record links to commit hashes, CI runs, build artifacts, reproducible measurements and bug cases in the progress ledger.
