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
- [ ] 🤖 Establish CI smoke testing for startup, browsing, navigation, extension functionality, security basics and Wayland behavior. **Actual workstation Wayland startup passed 2026-10-26 09:58 local**: packaged Vulpra connected to isolated Weston, attached buffers, committed frames and used private profile. CI https://github.com/sguzman/vulpra/actions/runs/40354284554 validates corrected Wayland surface detection. Browser navigation/JS/profile baseline runner CI https://github.com/sguzman/vulpra/actions/runs/40355994838 passed *synthetic tests only*, pending actual workstation run; real WebExtension and deeper security tests remain pending.

### 📏 Phase 2 — Baseline
- [ ] 📦 Capture source files/bytes, compiled size and build time. Source files/bytes measured in CI 40125494649; source build and package actually succeeded on the workstation. Standalone runner `ci/accept-native-package-local.py` now records real archive, executable and libxul sizes, hash and the successful incremental build duration; workstation metrics JSON remains pending.
- [ ] 📊 Capture startup time, memory and representative page behavior on a declared environment.

## ✂️ M3 — User-specific debloating

### 🧭 Phase 1 — Evidence inventory
- [ ] 🗺️ Map feature bundles, binary dependencies, build dependencies and platform-specific modules.
- [ ] 🔬 Classify candidates as keep, disable, conditionally compile or remove. Include fallback and safety impact.

### 🪚 Phase 2 — Incremental removals
- [ ] 🖥️ Audit and then prune non-Linux platform build/distribution material proven unnecessary.
- [ ] 📣 Audit promotional UI, Pocket, account/Sync and telemetry paths against the user's use case.
- [ ] 🌐 Audit mobile, test fixtures and optional packaged localizations without breaking required desktop functionality.
- [ ] 🧪 Demonstrate each accepted removal with before/after measurements and passing targeted tests.

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
