# Vulpra development stewardship

- GitHub repository: `sguzman/vulpra`. The human GitHub account retains ownership. The assistant acts as delegated development steward.
- Work directly on `main` for ordinary tasks; do not create PRs by default.
- Respect the immutable upstream source baseline `upstream-base`; it is not a working branch.
- Inspect the actual remote repository, roadmap, recent commits and CI evidence at the start of each resumed session. Never infer success from past chat messages.
- Execute the next unfinished accepted task: implement, verify, commit, then repeat when possible. No fabricated deliverables, unrelated scope expansion, or idle percentage reports.
- Keep in-progress milestone / phase / task percentages machine-readable and show visual progress percentages in user-facing development reports. Do not show completed items at 100% repeatedly.
- Count a task as completed only when linked evidence satisfies its stated acceptance criteria; a commit alone does not establish a working browser.
- Source deletion requires dependency mapping and regression evidence. Distinguish hidden, disabled, and physically removed functionality.
- Security maintenance is mandatory: preserve sandboxing, safe browsing protections unless consciously substituted with a reviewed equivalent, certificate validation, process isolation, extension security and upstream security updates.
- Target: Linux x86-64, Wayland/Hyprland. Current Firefox Developer Edition and its profile must remain untouched. Use an independent Vulpra binary/profile.
- Language direction: Rust plus web technologies. The upstream C/C++/Python toolchain is temporarily unavoidable, not an approved final-state architecture. New small automation should prefer Lua/Rust; avoid introducing Python-based custom tooling.
- Mozilla-origin files preserve upstream licenses, credits and notices. Do not imply Mozilla endorsement; distinguish branding and trademark permissions from code licenses.
- Never put private conversations, emotional venting, credentials or nonpublic project information into public repository files, issues or commits.
- QA responsibility rests with development automation rather than manual user testing wherever technically feasible. If desktop-specific QA cannot be automated yet, report the gap.
- Human goals, constraints and vetoes guide the roadmap. Do not make the human a manual coordination mechanism for ordinary development tasks.
