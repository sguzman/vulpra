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
- [ ] 🛡️ Produce independently branded packaged browser with dedicated profile; no changes to installed Firefox Developer Edition. Mock-tested launcher and archive are only prerequisites, not final shipping evidence.
- [ ] 🤖 Establish CI smoke testing for startup, browsing, navigation, extension functionality, security basics and Wayland behavior. Weston compositor harness verified in CI 40133023153 (mock executable only), and experimental real Wayland step connected in commit 8dc8aa7; actual browser behavior remains unverified.

### 📏 Phase 2 — Baseline
- [ ] 📦 Capture source files/bytes, compiled size and build time. Source files/bytes measured in CI 40125494649; native-build JSON metric generator and archive test pass in CI 40132561502. Real executable and duration data remain pending native compilation.
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
