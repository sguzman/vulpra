#!/usr/bin/env python3
"""Source-pinned high-impact desktop Sync/FxAccounts dependency graph.

This is a READ-ONLY source contract, not runtime reachability, source deletion,
native compilation, telemetry-policy change, or package-size measurement.
It deliberately includes independent FxAccounts and WebExtension consumers.
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
    "config": "browser/moz.configure",
    "services": "services/moz.build",
    "sync_ui": "browser/base/content/browser-sync.js",
    "accounts_glue": "browser/components/AccountsGlue.sys.mjs",
    "preferences": "browser/components/preferences/config/account-sync.mjs",
    "extension_storage": "toolkit/components/extensions/ExtensionStorageSyncKinto.sys.mjs",
    "firefox_view": "browser/components/firefoxview/SyncedTabsController.sys.mjs",
    "ai_auth": "browser/components/aiwindow/ui/modules/AIWindowAccountAuth.sys.mjs",
}

REQUIRED = {
    "config": ('imply_option("MOZ_SERVICES_SYNC", True)',),
    "services": ('if CONFIG["MOZ_WIDGET_TOOLKIT"] != "android":',
                 '"fxaccounts",', 'if CONFIG["MOZ_SERVICES_SYNC"]:',
                 'DIRS += ["sync"]'),
    "sync_ui": ('"resource://services-sync/UIState.sys.mjs"',
                'SyncedTabs: "resource://services-sync/SyncedTabs.sys.mjs"',
                'Weave: "resource://services-sync/main.sys.mjs"',
                'FxAccounts: "resource://gre/modules/FxAccounts.sys.mjs"',
                'SyncedTabs.getTabClients()', 'UIState.get().syncEnabled'),
    "accounts_glue": ('export const AccountsGlue = {',
                      'FxAccounts: "resource://gre/modules/FxAccounts.sys.mjs"',
                      'UIState: "resource://services-sync/UIState.sys.mjs"',
                      '"fxaccounts:onverified"', '"sync-ui-state:update"',
                      '"fxaccounts:commands:open-uri"'),
    "preferences": ('Weave: "resource://services-sync/main.sys.mjs"',
                    'export var SyncHelpers =', 'window.SyncHelpers = SyncHelpers;',
                    'window.fxAccounts.keys.hasKeysForScope(SCOPE_APP_SYNC)',
                    'let accountsEnabled = Services.prefs.getBoolPref("identity.fxaccounts.enabled");',
                    'let perDeviceSyncEnabled = Services.prefs.getBoolPref('),
    "extension_storage": ('BulkKeyBundle: "resource://services-sync/keys.sys.mjs"',
                          'CollectionKeyManager: "resource://services-sync/record.sys.mjs"',
                          '"resource://gre/modules/FxAccounts.sys.mjs"',
                          'export class ExtensionStorageSyncKinto {',
                          'export const extensionStorageSyncKinto = new ExtensionStorageSyncKinto('),
    "firefox_view": ('export class SyncedTabsController {',
                     'SyncedTabs: "resource://services-sync/SyncedTabs.sys.mjs"',
                     'this.devices = await lazy.SyncedTabs.getTabClients()',
                     'SyncedTabsErrorHandler.getErrorType()'),
    "ai_auth": ('FxAccounts: "resource://gre/modules/FxAccounts.sys.mjs"',
                'lazy.fxAccounts.getSignedInUser()',
                'lazy.FxAccounts.canConnectAccount()'),
}

def tracked_source(key: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "HEAD:" + FILES[key]], text=True
    )

def evidence(source: str, text: str, anchor: str) -> dict:
    lines=[i+1 for i,line in enumerate(text.splitlines()) if anchor in line]
    if not lines:
        raise ValueError(f"{source}: missing tracked source anchor: {anchor}")
    return {"path": FILES[source], "line": lines[0], "anchor": anchor,
            "source_matches": len(lines)}

def validate(docs: dict[str, str]) -> dict:
    entries={}
    for key,tokens in REQUIRED.items():
        entries[key]=[evidence(key, docs[key], token) for token in tokens]

    services=docs["services"]
    a=services.index('if CONFIG["MOZ_WIDGET_TOOLKIT"] != "android":')
    b=services.index('if CONFIG["MOZ_SERVICES_SYNC"]:')
    assert a<b, "FxAccounts is expected to be included independently of Sync"
    assert '"fxaccounts",' in services[a:b], "FxAccounts requires independent desktop inclusion"
    assert 'DIRS += ["sync"]' in services[b:], "Conditional Sync source build changed"

    # These are independent, retained APIs. Disabling source services/sync
    # would remove imports used from the browser and extensions; FxAccounts
    # is independently packaged and serves AI-window authentication.
    boundaries=[
        {"name":"sync_source_vs_fxa_source", "decision":"retain_both",
         "why":"Desktop FxAccounts package registration is not conditional on MOZ_SERVICES_SYNC.",
         "evidence":[entries["services"][1],entries["services"][2],entries["services"][3]]},
        {"name":"browser_sync_tab_ui", "decision":"retain",
         "why":"App menu and synced-tabs UI imports Sync services and FxAccounts; its handlers use UIState and tab clients.",
         "evidence":[entries["sync_ui"][0],entries["sync_ui"][1],entries["sync_ui"][3]]},
        {"name":"accounts_startup_and_commands", "decision":"retain",
         "why":"AccountsGlue startup observes FxA lifecycle, Sync UI state and remote open/close tab commands.",
         "evidence":[entries["accounts_glue"][0],entries["accounts_glue"][2],entries["accounts_glue"][4]]},
        {"name":"account_sync_preferences", "decision":"retain",
         "why":"Preferences expose sync engine setup plus independent account-disabled settings.",
         "evidence":[entries["preferences"][0],entries["preferences"][1],entries["preferences"][4]]},
        {"name":"webextension_sync_storage", "decision":"retain",
         "why":"WebExtension storage.sync imports services-sync cryptographic modules and uses account OAuth; not just a UI decoration.",
         "evidence":[entries["extension_storage"][0],entries["extension_storage"][1],entries["extension_storage"][3]]},
        {"name":"firefox_view_synced_tabs", "decision":"retain",
         "why":"Firefox View controller imports synced-tabs service and handles sync errors and data.",
         "evidence":[entries["firefox_view"][0],entries["firefox_view"][1],entries["firefox_view"][2]]},
        {"name":"ai_window_account_auth", "decision":"retain",
         "why":"AI-window auth uses independently packaged FxAccounts; disabling Sync does not erase account dependencies.",
         "evidence":[entries["ai_auth"][0],entries["ai_auth"][1],entries["ai_auth"][2]]},
    ]
    return {
        "schema_version":1,
        "phase":"M3",
        "test":"pinned_desktop_sync_accounts_high_impact_boundaries",
        "removal_authorized":False,
        "boundaries":boundaries,
        "candidate_decision":"Retain Sync/FxAccounts and browser, FxView and extension callers; no source prune. Future opt-in experiment requires a protected fallback for each live consumer.",
        "limits":[
            "Source anchors and ownership are not a dynamic call graph or runtime reachability proof.",
            "This covers named high-impact callers, not every source consumer or generated JS.",
            "No change to browser code, Sync functionality, account authentication or privacy policy.",
            "No full native build or compressed package evidence, and no M3 gate completion.",
        ]
    }

def self_test(docs: dict[str,str]) -> None:
    probes=(
        ("config",'imply_option("MOZ_SERVICES_SYNC", True)'),
        ("services",'if CONFIG["MOZ_WIDGET_TOOLKIT"] != "android":'),
        ("services",'if CONFIG["MOZ_SERVICES_SYNC"]:'),
        ("sync_ui",'SyncedTabs: "resource://services-sync/SyncedTabs.sys.mjs"'),
        ("accounts_glue",'UIState: "resource://services-sync/UIState.sys.mjs"'),
        ("preferences",'window.fxAccounts.keys.hasKeysForScope(SCOPE_APP_SYNC)'),
        ("extension_storage",'BulkKeyBundle: "resource://services-sync/keys.sys.mjs"'),
        ("firefox_view",'this.devices = await lazy.SyncedTabs.getTabClients()'),
        ("ai_auth",'lazy.FxAccounts.canConnectAccount()'),
    )
    for key,anchor in probes:
        changed=deepcopy(docs)
        assert anchor in changed[key],(key,anchor)
        changed[key]=changed[key].replace(anchor, "REMOVED_IN_TEST", 1)
        try:
            validate(changed)
        except (ValueError, AssertionError):
            continue
        raise AssertionError(f"Source contract did not reject mutation: {key} {anchor}")
    print(f"PASS: {len(probes)} deliberately broken high-impact Sync sources rejected")

def main() -> None:
    args=argparse.ArgumentParser()
    args.add_argument("--self-test", action="store_true")
    args.add_argument("--output", type=Path)
    ns=args.parse_args()
    sha=subprocess.check_output(
        ["git","-C",str(ROOT),"rev-parse","HEAD"],text=True
    ).strip()
    if not re.fullmatch(r"[a-f0-9]{40}",sha):
        raise ValueError("Expected pinned 40-character Git commit")
    docs={key:tracked_source(key) for key in FILES}
    report=validate(docs)
    report["source_commit"]=sha
    if ns.self_test:
        self_test(docs)
    if ns.output:
        ns.output.parent.mkdir(parents=True,exist_ok=True)
        ns.output.write_text(json.dumps(report,indent=2)+"\n")
    print(f"PASS: {len(report['boundaries'])} pinned Sync/FxAccounts high-impact source boundaries at {sha}")
    print("AUDIT ONLY: no Sync/Accounts deletion, no native/browser or package credit")

if __name__=="__main__":
    try:
        main()
    except (OSError, ValueError, AssertionError, subprocess.CalledProcessError) as error:
        print("FAIL: Sync/FxAccounts source audit:",error,file=sys.stderr)
        raise SystemExit(1)
