# M3 packaged AI Window offline prompt dependency acceptance

**Actual browser runtime evidence:** [GitHub Actions 40937489359](https://github.com/sguzman/vulpra/actions/runs/40937489359) **PASSED**, with bounded artifact `m3-aiwindow-archived-offline-runtime` (ID **12925766713**). The run extracted the previously SHA-256-verified **normal** Vulpra Linux package compiled at `1683ca67b69389a879717bcd537772c3b40624b6`, launched its real native binary through stock geckodriver and Marionette chrome context in a disposable HOME/profile, blocked nonlocal connections, and never called an AI model or remote model API. Its original Firefox-profile sentinel remained unchanged.

Before running, CI checked that four relevant source blobs were **byte-for-byte identical** between the archived compiled source and the current repo: `browser/components/aiwindow/models/Utils.sys.mjs`, `PromptLoader.sys.mjs`, `ChatUtils.sys.mjs`, and `services/settings/dumps/main/moz.build`. That guarantees continuity of these specific prompt-loader and packaging declarations, **not source equivalence of the whole browser**.

## Observed real browser behavior

| Runtime phase | Result |
| --- | --- |
| Synthetic Remote Settings collection with **zero** records | Explicit `clientReason: "promptLoadFailure"` rejection |
| Synthetic collection with params and response-rules but **missing identity module** | Explicit `promptLoadFailure` rejection |
| Synthetic collection with core modules but **missing params manifest** | Explicit `promptLoadFailure` rejection |
| Synthetic **complete** chat params + identity + response-rules records | Successfully assembled prompt, version `10.0`, both synthetic sections present |
| **Actual packaged offline seed**, no fake client | **214 real Remote Settings records readable** in a fresh isolated profile |
| Of those seed records: chat params | **21** |
| Seed identity-module records | **1** |
| Seed response-rules-module records | **5** |

The report retains **only booleans, record counts, synthetic fixture lengths and failure categories**. It contains no real prompt contents, model conversations, user identifiers, network payloads or real model output. Eight negative evidence-validation fixtures were rejected by the synthetic test, with four exact-source Git blob continuity checks.

## Decision

This is stronger than a static reference audit: the installed offline seed is actually readable by the native browser, while an empty collection causes the current prompt assembler to fail closed. **Keep the built-in default `ai-window-prompts.json` seed** and the relevant Remote Settings client initialization. Removing the file without an independent offline bootstrap / fixed core manifest replacement would jeopardize first-run or network-outage AI Window behavior. The exact packaged resource consumes **1,577,264 uncompressed `omni.ja` ZIP-entry bytes** in the older normal archive, **not** 1,577,264 proven recoverable compressed `tar.xz` bytes.

The fake-client empty-record phase is **not** a literal built archive with the seed removed. The actual diagnostic exercised the **unmodified** packaged seed. We have not proved what a source-matched seed-omitted browser would do in all profiles, whether syncing can repair it, or how many bytes a guarded omission would save. This is sufficient to **protect** the default behavior, not permission to delete source or claim a runtime-safe omission.

Future optimization would require a separately designed offline fallback bundled in some other form, no-loss-of-required-identity/rules acceptance and exact-source native full-versus-guarded archive tests. Until then, classify this concrete seed **keep**, not reviewable deletion.

**Progress:** a native consumer/fallback subcase verified, not the complete feature dependency or candidate acceptance gate. **M3 2/6 (33%), overall 44%, Δ 0 pp.**
