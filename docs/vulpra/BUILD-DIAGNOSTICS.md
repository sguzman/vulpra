# Native build failure and remediation (2026-10-24)

## Observed failure

[GitHub Actions run 40126828007](https://github.com/sguzman/vulpra/actions/runs/40126828007) ended **failure** after starting at 19:46:40 UTC and ending at 20:47:22 UTC. The full job log was retrieved and showed Rust and native code compilation progressing to `dom/clients/api` without a reported compiler error before the tail:

- `The runner has received a shutdown signal.`
- `Process completed with exit code 143.`

This was **not** evidence that Vulpra compiles successfully; no binary was packaged or exercised. The workflow used `timeout --signal=INT --kill-after=120s 55m ./mach build`, which coincides with the compilation time at which the job was terminated. It is possible other runner termination factors contributed, but **the self-imposed cutoff must be removed first**.

## Corrective change

- Removed the 55-minute per-command timeout. The GitHub-hosted job remains bounded to 330 minutes to allow build, packaging and smoke testing under the documented six-hour platform limit.
- Added Mozilla's supported `--with-ccache=sccache` option, `mozilla-actions/sccache-action@v0.0.11` (sccache v0.16.0) and the GitHub Actions backend. The native-configure workflow uses the same cache configuration.
- Preserved `tee` capture and the bounded failure-tail artifact for actionable errors. These steps run if the build process exits normally with an error; a force-stopped runner might not execute cleanup or upload.
- Kept `--disable-tests`, Vulpra app basename and the full-native (non-artifact) engine build.

The first cache-enabled build may be slower due to its cold cache. No speedup or successful retry should be claimed until actual CI evidence exists. Do not change the percentage for the working-browser milestone on the basis of this remediation alone.

## 2026-10-24: second SIGTERM without an explicit timeout

[Native build 40131775964](https://github.com/sguzman/vulpra/actions/runs/40131775964) also ended with **runner shutdown / process exit 143** at 21:31:56 UTC, although the 55-minute process timeout was already removed. It was compiling `dom/cache` at 30:29 build-elapsed and did not report a compiler error. This disconfirms the previous assumption that the original 55-minute command timeout fully explained the shutdown. The run configured **four parallel jobs** based on the hosted runner's four cores / ~15.6 GiB RAM. Memory pressure is a **hypothesis**, not yet an observed OOM event; no kernel or cgroup OOM evidence was captured.

A new experiment caps `MOZ_PARALLEL_BUILD=2` (upstream-supported mozconfig knob) to reduce peak simultaneous compiler usage. The native-build step now prints UTC resource heartbeats every 45 seconds: `free`, `df`, cgroup `memory.current` / `memory.events`, and top process command names and RSS. The monitor ends with the build step; it avoids process argument lists to reduce accidental disclosure. If another runner stops unexpectedly, examine these heartbeats before changing build options or citing any root cause. Do not mark the build gate passed until an actual native package runs.
