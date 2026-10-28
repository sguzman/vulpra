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

**Status: in progress, 2/6 acceptance gates (33%) complete.** The native M2 browser remains protected. Two independent selective **opt-in** packaged feature removals have now passed native runtime and matched-size acceptance: Normandy recipe runner **27,620 B (0.032%)**, and exactly two ASRouter AI promotion modules **3,184 B (0.00366%)**. Do **not** add those savings together without a combined source-matched build. Bounded source-only platform pruning also passed CI native/browser acceptance: 453 Windows/Cocoa widget and installer files (6,266,676 Git blob B) 14,134 Android-only application files (115,996,869 Git blob B), and 280 further Android/iOS/UIKit-only files (7,704,040 Git blob B): a combined 14,867 files / 129,967,585 original Git blob bytes permanently removed from main. Source blob reduction is not compiled binary saving. The normal build still includes optional modules; four broad M3 gates remain open.

### 🧭 Phase 1 — Evidence inventory
- [ ] 🗺️ Map feature bundles, binary dependencies, build dependencies and platform-specific modules.
- [ ] 🔬 Classify candidates as keep, disable, conditionally compile or remove. Include fallback and safety impact.

### 🪚 Phase 2 — Incremental removals
- [x] 🖥️ Audit and prune an initially bounded set of non-Linux widget/installer sources proven unnecessary for the Linux browser. **453 files (6,266,676 Git blob bytes)** permanently removed in [commit 81d9b335](https://github.com/sguzman/vulpra/commit/81d9b335b747c377b730a0c3a4de9ea1cf522fe5), preserving eight shared generator/Rust dependency files. Actual full native Linux build, Wayland, JS, WebExtension and Nimbus [CI 40519242468 passed](https://github.com/sguzman/vulpra/actions/runs/40519242468). Other non-Linux source trees remain unreviewed. **Source-only reduction, no claimed compiled-package savings.**
- [ ] 📣 Audit promotional UI, Pocket, account/Sync and telemetry paths against the user's use case. **Pocket sub-audit:** [full pinned-source scoped scan 40616102254](https://github.com/sguzman/vulpra/actions/runs/40616102254) passed and classified New Tab feeds, Nimbus/browser policies, bundled resources and incidental matches. Retain built-in New Tab; a narrow opt-in resource change still needs guard/fallback, source-matched package, and native runtime evidence. The larger promotion/Sync/telemetry audit gate remains open. **Next narrowed experiment:** opt-in [New Tab AdsFeed candidate a8547f9](https://github.com/sguzman/vulpra/commit/a8547f9a1cc4e81985cf171c679c1d19a46875b3), full native trial [40617558714](https://github.com/sguzman/vulpra/actions/runs/40617558714) pending; original build unchanged, zero accepted removal or percentage credit.
- [ ] 🌐 Audit mobile, test fixtures and optional packaged localizations without breaking required desktop functionality. **Bounded Android app-only subset accepted:** exactly 14,134 files / 115,996,869 Git blob bytes removed in [commit 546755376](https://github.com/sguzman/vulpra/commit/546755376021d230bb12ab2f904129a7d6f80973) after actual [native Linux compile, Wayland, JS, WebExtension and Nimbus CI 40585240593](https://github.com/sguzman/vulpra/actions/runs/40585240593). Android Gradle/app Taskcluster support knowingly excluded. **Follow-on mobile/iOS/UIKit subset accepted:** 280 more files / 7,704,040 Git blob bytes in exactly eight non-Linux directories, committed as [8331ca6](https://github.com/sguzman/vulpra/commit/8331ca63f97b84779d6b1765955dff6017d060f8) after [full Linux compile, package, Wayland, JS, extensions and Nimbus CI 40600510147](https://github.com/sguzman/vulpra/actions/runs/40600510147). The 110 external literal references include Android/iOS Gradle, build/test staging, taskgraph, mobile documentation and platform-guarded code; `testing/testsuite-targets.mk` `stage-android` still references the removed Android-only fonts and is intentionally unsupported. Shared GeckoView/mobile/widget Android, GTK, common test infrastructure and Linux manifests remain intact. Remaining test/locales/platform audits are open, so this roadmap gate is NOT complete.
- [x] 🧪 Demonstrate every **accepted** removal with relevant before/after measurements and passing targeted tests. **Normandy opt-in binary removal plus bounded source-only platform prune** (453 files / 6,266,676 Git blob bytes; complete native/runtime [40519242468](https://github.com/sguzman/vulpra/actions/runs/40519242468); no claimed binary saving). **Opt-in Normandy runner**, full 86,937,548 B vs lean 86,909,928 B (27,620 B, 0.032%) under source-matched Ubuntu builds. Native runs [lean 40431768974](https://github.com/sguzman/vulpra/actions/runs/40431768974) and [full 40431769117](https://github.com/sguzman/vulpra/actions/runs/40431769117), real runtime [40439671494](https://github.com/sguzman/vulpra/actions/runs/40439671494), matched-size [40439793884](https://github.com/sguzman/vulpra/actions/runs/40439793884). **Opt-in ASRouter AI promo resources:** [native build/runtime 40547968387](https://github.com/sguzman/vulpra/actions/runs/40547968387) verified physical absence of SidebarChatBotPromo and SmartWindowNewTabPromo resources, retention of core ASRouter, Wayland, JS, WebExtensions, Nimbus and safe guarded dispatch. [Full source-matched package comparison 40567473401](https://github.com/sguzman/vulpra/actions/runs/40567473401): 86,930,792 B full vs 86,927,608 B lean, saving **3,184 B (0.00366%)**. Default remains unchanged. This evidence extends the existing per-removal gate, NOT a third newly completed roadmap gate. This gate must be maintained for every future accepted candidate.

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
