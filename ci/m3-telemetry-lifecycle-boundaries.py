#!/usr/bin/env python3
"""Pinned desktop Telemetry submission/policy dependency contract.

Read-only graph of actual source registration and guarded submission callers.
Does NOT test actual network behavior, disable telemetry, build Firefox,
measure a package, or authorize deletion. Local Glean/crash are distinct.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "controller": "toolkit/components/telemetry/app/TelemetryControllerParent.sys.mjs",
    "sender": "toolkit/components/telemetry/app/TelemetrySend.sys.mjs",
    "policy": "toolkit/components/telemetry/app/TelemetryReportingPolicy.sys.mjs",
    "telemetry_build": "toolkit/components/telemetry/moz.build",
    "glean_build": "toolkit/components/glean/moz.build",
    "crash_build": "toolkit/crashreporter/moz.build",
    "browser_prefs": "browser/app/profile/firefox.js",
    "privacy": "browser/components/preferences/privacy.js",
}

ANCHORS = {
    "controller": (
        'TelemetrySend: "resource://gre/modules/TelemetrySend.sys.mjs"',
        '"resource://gre/modules/TelemetryReportingPolicy.sys.mjs"',
        "lazy.TelemetryReportingPolicy.setup();",
        "lazy.TelemetrySend.earlyInit();",
        "await lazy.TelemetrySend.setup(this._testMode);",
        "lazy.TelemetryReportingPolicy.shutdown();",
        "await lazy.TelemetrySend.shutdown();",
        "lazy.TelemetrySend.flushPingSenderBatch();",
        "await Services.telemetry.shutdown();",
    ),
    "sender": (
        '"resource://gre/modules/TelemetryReportingPolicy.sys.mjs"',
        "if (!this.sendingEnabled(ping)) {",
        "if (ping && isDeletionRequestPing(ping)) {",
        "TelemetryUtils.Preferences.FhrUploadEnabled,",
        "lazy.TelemetryReportingPolicy.canUpload() &&",
        "if (!lazy.TelemetryReportingPolicy.canUpload()) {",
        'AppConstants.platform === "win" ? "pingsender.exe" : "pingsender";',
        "SendScheduler.triggerSendingPings(true);",
    ),
    "policy": (
        "canUpload() {",
        "if (!this.dataSubmissionEnabled) {",
        "if (this._notificationInProgress) {",
        "return !this._shouldNotifyDataReportingPolicy() && !this._shouldShowTOU();",
        "lazy.TelemetrySend.notifyCanUpload();",
    ),
    "telemetry_build": (
        'FINAL_LIBRARY = "xul"',
        '"pingsender",',
        '"app/TelemetryControllerParent.sys.mjs",',
        '"app/TelemetryReportingPolicy.sys.mjs",',
        '"app/TelemetrySend.sys.mjs",',
        '"core/Telemetry.cpp",',
    ),
    "glean_build": (
        '"bindings/Glean.cpp",',
        '"bindings/GleanPings.cpp",',
    ),
    "crash_build": ('if CONFIG["MOZ_CRASHREPORTER"]:',),
    "browser_prefs": (
        'pref("toolkit.telemetry.archive.enabled", true);',
        'pref("toolkit.telemetry.shutdownPingSender.enabled", true);',
        'pref("toolkit.telemetry.firstShutdownPing.enabled", true);',
    ),
    "privacy": ('!AppConstants.MOZ_DATA_REPORTING &&',),
}

def source(name: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "HEAD:" + FILES[name]], text=True
    )

def evidence(key: str, s: str, anchor: str) -> dict:
    occurrences = [n + 1 for n, line in enumerate(s.splitlines()) if anchor in line]
    if not occurrences:
        raise ValueError(f"{key} lost required anchor: {anchor!r}")
    return {"file": FILES[key], "line": occurrences[0],
            "pattern": anchor, "source_hits": len(occurrences)}

def order(s: str, *anchors: str) -> None:
    offsets = [s.find(anchor) for anchor in anchors]
    if any(n < 0 for n in offsets) or offsets != sorted(offsets):
        raise ValueError(f"Source lifecycle/order changed: {anchors}")

def validate(src: dict[str, str]) -> dict:
    anchors = {key: [evidence(key, src[key], a) for a in required]
               for key, required in ANCHORS.items()}
    controller = src["controller"]
    sender = src["sender"]
    policy = src["policy"]
    build = src["telemetry_build"]
    # Bound startup and shutdown to the actual methods, not a coincidental
    # occurrence elsewhere in these large files.
    setup = controller[
        controller.index("  setupTelemetry: function setupTelemetry(testing) {"):
        controller.index("  // Do proper shutdown waiting and cleanup.")]
    shutdown = controller[
        controller.index("  async _cleanupOnShutdown() {"):
        controller.index("  shutdown() {", controller.index("  async _cleanupOnShutdown() {"))]
    order(setup, "lazy.TelemetryReportingPolicy.setup();",
          "lazy.TelemetrySend.earlyInit();",
          "await lazy.TelemetrySend.setup(this._testMode);")
    order(shutdown, "lazy.TelemetryReportingPolicy.shutdown();",
          "await lazy.TelemetrySend.shutdown();",
          "await Services.telemetry.shutdown();",
          "lazy.TelemetrySend.flushPingSenderBatch();")
    # Separate telemetry policy and runtime preference checks: deletion
    # requests can still be transmitted after normal upload is disabled.
    send_method = sender[
        sender.index("  submitPing(ping, options) {", sender.index("export var TelemetrySendImpl = {")):
        sender.index("  sendPings(currentPings, persistedPingIds) {")]
    assert "if (!this.sendingEnabled(ping)) {" in send_method
    assert "lazy.TelemetryReportingPolicy.canUpload() &&" in send_method
    assert "if (!this.canSendNow) {" in send_method
    check_sending = sender[
        sender.index("  sendingEnabled(ping = null) {"):
        sender.index("  runPingSender(", sender.index("  sendingEnabled(ping = null) {"))
    ] if "  runPingSender(" in sender[sender.index("  sendingEnabled(ping = null) {"):] else sender[sender.index("  sendingEnabled(ping = null) {"):]
    assert "if (ping && isDeletionRequestPing(ping)) {" in check_sending
    assert "TelemetryUtils.Preferences.FhrUploadEnabled" in check_sending
    assert "Services.telemetry.isOfficialTelemetry" in check_sending
    guard = policy[policy.index("  canUpload() {", policy.index("var TelemetryReportingPolicyImpl = {")):]
    assert "if (!this.dataSubmissionEnabled) {" in guard
    assert "if (this._notificationInProgress) {" in guard
    assert "return !this._shouldNotifyDataReportingPolicy() && !this._shouldShowTOU();" in guard
    order(build, 'FINAL_LIBRARY = "xul"', '"pingsender",',
          '"app/TelemetryControllerParent.sys.mjs",',
          '"app/TelemetryReportingPolicy.sys.mjs",',
          '"app/TelemetrySend.sys.mjs",')
    assert "Glean" not in src["crash_build"] or 'MOZ_CRASHREPORTER' in src["crash_build"]

    def group(title: str, keys: tuple[str, ...], why: str) -> dict:
        return {"name": title, "classification": "retain_protected",
                "why": why, "evidence": [anchors[k][0] for k in keys]}

    return {
        "schema_version": 1,
        "phase": "M3",
        "test": "source_pinned_desktop_telemetry_policy_send_lifecycle",
        "removal_authorized": False,
        "source_boundaries": [
            group("telemetry_controller_startup_shutdown", ("controller",),
                  "Policy setup precedes sender startup; shutdown awaits sender then native telemetry and flushes PingSender."),
            group("sender_policy_deletion_request", ("sender", "policy"),
                  "Transport checks official build and upload preferences; deletion requests are explicitly exempted; notification and terms-of-use policy gates must be preserved."),
            group("native_telemetry_and_pingsender", ("telemetry_build",),
                  "Telemetry compiled into xul, sender/controller JS and pingsender all bundled."),
            group("glean_separate_bindings", ("glean_build",),
                  "Glean has independent native bindings and metrics; no broad telemetry removal supported."),
            group("crashreporter_separate_config", ("crash_build",),
                  "Crash reporter has its own MOZ_CRASHREPORTER build gate."),
            group("browser_preferences_and_privacy_ui", ("browser_prefs", "privacy"),
                  "Desktop shutdown sender/archive prefs and data reporting UI remain; preferences do not prove actual uploads."),
        ],
        "all_source_anchors": anchors,
        "potential_next_candidate": "Guarded Linux-only transport submission experiment, ONLY after native no-upload network proof including deletion-request handling and sender startup/shutdown equivalence; do not cut Glean/local metrics or crashreporter.",
        "limitations": [
            "Exact source strings do not prove runtime reachability or current network traffic.",
            "This checks named high-impact files, not a complete consumer call graph.",
            "Disabling data upload may require preserving privacy deletion requests; a pure module deletion can be incorrect.",
            "Native build, actual captured HTTP transmission and opt-out preference tests not performed.",
            "No supported source deletion, observed package reduction or M3 gate credit.",
        ],
    }

def self_test(src: dict[str, str]) -> None:
    mutations = (
        ("controller", "lazy.TelemetryReportingPolicy.setup();"),
        ("controller", "await lazy.TelemetrySend.setup(this._testMode);"),
        ("controller", "await lazy.TelemetrySend.shutdown();"),
        ("sender", "if (ping && isDeletionRequestPing(ping)) {"),
        ("sender", "if (!this.sendingEnabled(ping)) {"),
        ("policy", "if (!this.dataSubmissionEnabled) {"),
        ("telemetry_build", '"app/TelemetrySend.sys.mjs",'),
        ("glean_build", '"bindings/GleanPings.cpp",'),
        ("crash_build", 'if CONFIG["MOZ_CRASHREPORTER"]:'),
        ("browser_prefs", 'pref("toolkit.telemetry.shutdownPingSender.enabled", true);'),
        ("privacy", "!AppConstants.MOZ_DATA_REPORTING &&"),
    )
    for key, needle in mutations:
        assert needle in src[key]
        changed = deepcopy(src)
        changed[key] = changed[key].replace(needle, "BROKEN_AUDIT_FIXTURE", 1)
        try:
            validate(changed)
        except (ValueError, AssertionError):
            continue
        raise AssertionError(f"Source mutation not caught: {key}: {needle}")
    print(f"PASS: {len(mutations)} broken telemetry policy/transport assertions rejected")

def main() -> None:
    cli = argparse.ArgumentParser()
    cli.add_argument("--output", type=Path)
    cli.add_argument("--self-test", action="store_true")
    args = cli.parse_args()
    sha = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                  text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Unpinned source commit")
    data = {key: source(key) for key in FILES}
    report = validate(data)
    report["source_commit"] = sha
    if args.self_test:
        self_test(data)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS: {len(report['source_boundaries'])} protected telemetry-policy/native boundaries at {sha}")
    print("SOURCE ONLY: no telem submission removal or native/package credit")

if __name__ == "__main__":
    try:
        main()
    except (AssertionError, ValueError, OSError, subprocess.CalledProcessError) as ex:
        print("FAIL: telemetry lifecycle contract:", ex, file=sys.stderr)
        raise SystemExit(1)
