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
