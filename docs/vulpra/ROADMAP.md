# Vulpra roadmap

The milestones are ordered by engineering dependencies, not by arbitrary source-deletion targets. Completion requires the explicit gates below; no task becomes 100% on documentation alone.

## 🦊 M1 — Reproducible source foundation

### 🌱 Phase 1 — Provenance
- [x] 🔎 Confirm exact upstream tag and source archive SHA-256; extracted critical paths verified. Evidence: import run 40119418469, provenance ledger. Full tree equivalence is a separate remaining gate.
- [x] 📥 Import source to `upstream-base` and verify all source file contents, paths and symlinks. Evidence: passed CI 40120947358, with verified Git CRLF normalization and empty directory exceptions.
- [x] 🌿 Merge the baseline ancestry into `main`, preserve project rules and verify essential Firefox build paths. Evidence: commit 58802537 and GitHub file checks.

### 🛠️ Phase 2 — Execution
- [x] 🔧 Execute importer under GitHub Actions and resolve permission failures. Evidence: successful run 40119418469.
- [ ] 🔐 Review licensing, notices and branding plan. Evidence: source audit and documented result.

## 🐧 M2 — Working Linux browser

### ⚙️ Phase 1 — Build
- [ ] 🧱 Configure reproducible release-like Linux x86-64 build with a documented toolchain.
- [ ] 🛡️ Ship separately named binary with a dedicated profile; no changes to installed Firefox Developer Edition.
- [ ] 🤖 Establish CI smoke testing for startup, browsing, navigation, extension functionality, security basics and Wayland behavior.

### 📏 Phase 2 — Baseline
- [ ] 📦 Capture source files/bytes, compiled size and build time.
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
