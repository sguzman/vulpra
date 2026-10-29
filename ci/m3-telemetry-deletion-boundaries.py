#!/usr/bin/env python3
"""Read-only, source-pinned FHR upload opt-out vs data-submission shutdown audit.

This deliberately distinguishes user upload opt-out, deletion-request cleanup,
uncontrollable Nimbus pings, transport policy, and the independent master switch.
It cannot establish live delivery, network privacy, deletion success or safe
sender removal. It never changes the browser.
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
    "utils": "toolkit/components/telemetry/app/TelemetryUtils.sys.mjs",
}


def span(s: str, begin: str, end: str) -> str:
    start = s.index(begin)
    stop = s.index(end, start + len(begin))
    return s[start:stop]


def ordered(s: str, *anchors: str) -> None:
    indices = [s.find(a) for a in anchors]
    if min(indices) < 0 or indices != sorted(indices) or len(set(indices)) != len(indices):
        raise ValueError("Missing/out-of-order protected source path: " + repr(anchors))


def require(s: str, *anchors: str) -> None:
    for anchor in anchors:
        if anchor not in s:
            raise ValueError("Missing protected source relationship: " + anchor)


def evidence(key: str, s: str, anchor: str) -> dict:
    match = next((i for i, line in enumerate(s.splitlines(), 1) if anchor in line), None)
    if match is None:
        raise ValueError("Missing evidence location: " + anchor)
    return {"path": FILES[key], "line": match, "anchor": anchor}


def validate(src: dict[str, str]) -> dict:
    controller, sender, policy, utils = (src[k] for k in
        ("controller", "sender", "policy", "utils"))

    # Master policy and user upload preference are DIFFERENT knobs.
    require(utils,
        'DataSubmissionEnabled: "datareporting.policy.dataSubmissionEnabled"',
        'FhrUploadEnabled: "datareporting.healthreport.uploadEnabled"')
    require(policy, "get dataSubmissionEnabled() {",
            "TelemetryUtils.Preferences.DataSubmissionEnabled,")
    policy_guard = span(policy,
        '  canUpload() {',
        '  isFirstRun() {')
    # First canUpload() wrapper is an earlier export; use the implementation
    # after the actual Impl method instead of matching its public facade.
    policy_guard = span(policy[policy.index("var TelemetryReportingPolicyImpl = {"):],
        '  canUpload() {', '  isFirstRun() {')
    ordered(policy_guard,
        'if (!this.dataSubmissionEnabled) {', 'if (this._notificationInProgress) {',
        'return !this._shouldNotifyDataReportingPolicy() && !this._shouldShowTOU();')

    # Preference observer and data cleanup: a deletion request is deliberately
    # formed AFTER old queues are cleared and identifiers replaced.
    observation = span(controller, '  observe(aSubject, aTopic, aData) {',
                       '  registerSyncPingShutdown(fnShutdown) {')
    ordered(observation,
        'case "nsPref:changed":',
        'if (aData == TelemetryUtils.Preferences.FhrUploadEnabled) {',
        'return this._onUploadPrefChange();')

    observers = span(controller, '  _attachObservers() {',
                     '  _detachObservers() {')
    require(observers, 'if (TelemetryControllerBase.IS_UNIFIED_TELEMETRY) {',
            'Services.prefs.addObserver(',
            'TelemetryUtils.Preferences.FhrUploadEnabled,')
    optout = span(controller, '  _onUploadPrefChange() {',
                  '  QueryInterface: ChromeUtils.generateQI(')
    require(optout, 'if (uploadEnabled) {', 'return;', 'Glean.telemetry.dataUploadOptin.set(true);')
    ordered(optout,
        'await lazy.TelemetrySend.clearCurrentPings();',
        'await lazy.TelemetryStorage.removeAppDataPings();',
        'await lazy.TelemetryStorage.runRemovePendingPingsTask();',
        'await lazy.TelemetryStorage.removeUninstallPings();',
        'lazy.TelemetrySession.resetSubsessionCounter();',
        'Services.telemetry.getSnapshotForScalars(',
        'await lazy.ClientID.setCanaryIdentifiers();',
        'this.submitExternalPing(',
        'PING_TYPE_DELETION_REQUEST,',
        'this._shutdownBarrier.client.addBlocker(')
    require(optout, 'overrideClientId: oldClientId',
            'overrideProfileGroupId: oldProfileGroupId',
            'TelemetryUtils.TELEMETRY_UPLOAD_DISABLED_TOPIC')

    # Nimbus suppression cannot override a deletion-request ping.
    submission = span(controller, '  submitExternalPing: function send(',
                      '  /**\n   * Save a ping to disk.')
    require(controller, 'const PING_TYPE_DELETION_REQUEST = "deletion-request";')
    require(submission, 'const UNCONTROLLABLE_PINGS = [',
            '"deletion-request",', 'if (UNCONTROLLABLE_PINGS.includes(aType)) {',
            'this._submitPingLogic(aType, aPayload, aOptions);')
    logic = span(controller, '  async _submitPingLogic(',
                 '  submitExternalPing: function send(')
    require(logic, 'lazy.TelemetrySend.submitPing(pingData, {')

    # A deletion ping passes a type-specific guard AFTER the official-build
    # gate; no claim that its transport is guaranteed to reach a server.
    classification = span(sender, 'function isDeletionRequestPing(aPing) {', '\n}')
    require(sender, 'const PING_TYPE_DELETION_REQUEST = "deletion-request";')
    require(classification,
        'isV4PingFormat(aPing) && aPing.type == PING_TYPE_DELETION_REQUEST')
    sender_impl = sender[sender.index('export var TelemetrySendImpl = {'):]
    enabled = span(sender_impl, '  sendingEnabled(ping = null) {',
                   '  /**\n   * Track any pending ping send')
    ordered(enabled,
        '!Services.telemetry.isOfficialTelemetry',
        'if (IS_UNIFIED_TELEMETRY) {',
        'if (ping && isDeletionRequestPing(ping)) {',
        'return true;',
        'TelemetryUtils.Preferences.FhrUploadEnabled,')
    submit = span(sender_impl, '  submitPing(ping, options) {',
                  '  /**\n   * Only used in tests.')
    ordered(submit,
        'if (!this.sendingEnabled(ping)) {',
        'lazy.TelemetryReportingPolicy.canUpload() &&',
        'if (!this.canSendNow) {',
        'return savePing(ping);',
        'SendScheduler.triggerSendingPings(true);')
    can_send = span(sender_impl, '  get canSendNow() {',
                    '  /**\n   * Check if sending is disabled.')
    require(can_send, 'if (!lazy.TelemetryReportingPolicy.canUpload()) {',
            'return this._sendingEnabled;')
    scheduler = span(sender, '  async _doSendTask() {',
                     '      // Bail out if there is nothing to send.')
    ordered(scheduler,
        'if (!TelemetrySendImpl.sendingEnabled()) {',
        'pending = [];',
        'current = current.filter(p => isDeletionRequestPing(p));')
    ping = span(sender_impl, '  _doPing(ping, id, isPersisted) {',
                '  get canSendNow() {') if '  get canSendNow() {' in sender_impl[
                    sender_impl.index('  _doPing(ping, id, isPersisted) {'):] else sender_impl[
                    sender_impl.index('  _doPing(ping, id, isPersisted) {'):]
    require(ping, 'if (!this.sendingEnabled(ping)) {')

    return {
        "schema_version": 1,
        "phase": "M3",
        "audit": "fhr_user_optout_vs_master_data_submission_and_deletion_path",
        "removal_authorized": False,
        "source_boundaries": [
            {"name": "distinct_master_policy_and_upload_preferences",
             "evidence": [evidence("utils", utils, 'DataSubmissionEnabled:'),
                          evidence("utils", utils, 'FhrUploadEnabled:'),
                          evidence("policy", policy, 'if (!this.dataSubmissionEnabled) {')]},
            {"name": "upload_pref_observer_and_old_queue_purge",
             "evidence": [evidence("controller", controller, '_onUploadPrefChange() {'),
                          evidence("controller", controller, 'await lazy.TelemetrySend.clearCurrentPings();'),
                          evidence("controller", controller, 'await lazy.TelemetryStorage.removeAppDataPings();')]},
            {"name": "identifier_rotation_and_deletion_request",
             "evidence": [evidence("controller", controller, 'await lazy.ClientID.setCanaryIdentifiers();'),
                          evidence("controller", controller, 'PING_TYPE_DELETION_REQUEST,'),
                          evidence("controller", controller, 'overrideClientId: oldClientId')]},
            {"name": "uncontrollable_deletion_type_in_nimbus",
             "evidence": [evidence("controller", controller, 'const UNCONTROLLABLE_PINGS = ['),
                          evidence("controller", controller, 'this._submitPingLogic(aType, aPayload, aOptions);')]},
            {"name": "official_build_gate_and_type_specific_upload_optout",
             "evidence": [evidence("sender", sender, 'isV4PingFormat(aPing) && aPing.type == PING_TYPE_DELETION_REQUEST'),
                          evidence("sender", sender, '!Services.telemetry.isOfficialTelemetry'),
                          evidence("sender", sender, 'if (ping && isDeletionRequestPing(ping)) {')]},
            {"name": "sender_policy_scheduler_and_pending_queues",
             "evidence": [evidence("sender", sender, 'if (!this.canSendNow) {'),
                          evidence("sender", sender, 'pending = [];'),
                          evidence("sender", sender, 'current = current.filter(p => isDeletionRequestPing(p));')]},
        ],
        "engineering_decision": (
            "Protect the FHR opt-out deletion-request lifecycle and independent "
            "policy gate. Do not indiscriminately force DataSubmissionEnabled=false, "
            "delete TelemetrySend or drop client-ID/storage modules as a debloat. "
            "Before any network-suppression candidate, validate actual opt-out/"
            "deletion behavior and ensure local metrics, Glean and crash work."
        ),
        "limits": [
            "Source-pinned control-flow anchors are not a dynamic execution trace.",
            "Deletion request submission, queue persistence and server delivery are different outcomes.",
            "Policy gating of canSendNow may persist pings; this audit does not prove later delivery.",
            "No network packet inspection, browser runtime test, new native build, or package-byte saving.",
            "Does not assert which account/usage reporting features apply to Vulpra's app ID.",
        ],
    }


def self_test(src: dict[str, str]) -> None:
    mutations = (
        ("utils", 'FhrUploadEnabled: "datareporting.healthreport.uploadEnabled"'),
        ("policy", 'return !this._shouldNotifyDataReportingPolicy() && !this._shouldShowTOU();'),
        ("controller", 'return this._onUploadPrefChange();'),
        ("controller", 'await lazy.TelemetrySend.clearCurrentPings();'),
        ("controller", 'await lazy.TelemetryStorage.removeAppDataPings();'),
        ("controller", 'await lazy.ClientID.setCanaryIdentifiers();'),
        ("controller", 'overrideClientId: oldClientId'),
        ("controller", 'const UNCONTROLLABLE_PINGS = ['),
        ("sender", 'isV4PingFormat(aPing) && aPing.type == PING_TYPE_DELETION_REQUEST'),
        ("sender", 'if (ping && isDeletionRequestPing(ping)) {'),
        ("sender", 'if (!this.canSendNow) {'),
        ("sender", 'current = current.filter(p => isDeletionRequestPing(p));'),
    )
    for key, anchor in mutations:
        changed = deepcopy(src)
        assert anchor in changed[key], (key, anchor)
        changed[key] = changed[key].replace(anchor, "INVALID_AUDIT_MUTATION", 1)
        try:
            validate(changed)
        except (AssertionError, ValueError):
            continue
        raise AssertionError(f"Broken deletion/policy relationship accepted: {key}: {anchor}")
    print(f"PASS: {len(mutations)} broken privacy opt-out relationships rejected")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    sha = subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    if not re.fullmatch(r"[a-f0-9]{40}", sha):
        raise ValueError("Expected canonical source SHA")
    src = {name: subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "HEAD:" + path], text=True)
        for name, path in FILES.items()}
    report = validate(src)
    report["source_commit"] = sha
    if args.self_test:
        self_test(src)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS: {len(report['source_boundaries'])} pinned deletion/policy boundaries at {sha}")
    print("AUDIT ONLY: no transport disable, network proof or native package credit")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, AssertionError, OSError, subprocess.CalledProcessError) as exc:
        print("FAIL: privacy deletion source contract:", exc, file=sys.stderr)
        raise SystemExit(1)
