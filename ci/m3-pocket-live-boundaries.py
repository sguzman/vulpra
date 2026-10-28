#!/usr/bin/env python3
"""Source-pinned Pocket/New Tab runtime boundaries, without compiling or pruning.

Only verifies tracked source anchors at Git HEAD and emits a documented
source-level dependency map. No JS executes; a grep/regex match is NOT a proof
of live runtime reachability or authorization to omit resources.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "registry": "browser/extensions/newtab/lib/ActivityStream.sys.mjs",
    "modern": "browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs",
    "legacy": "browser/extensions/newtab/lib/TopStoriesFeed.sys.mjs",
    "bundles": "browser/extensions/newtab/moz.build",
    "jar": "browser/extensions/newtab/addon-jar.mn",
}


def tracked_text(name: str) -> str:
    path = FILES[name]
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "HEAD:" + path], text=True
    )


def evidence(text: str, anchor: str, source: str, *, count: int = 1) -> dict:
    occurrences = [i + 1 for i, line in enumerate(text.splitlines())
                   if anchor in line]
    if len(occurrences) != count:
        raise ValueError(
            f"Required source anchor changed in {source}: {anchor!r}; "
            f"wanted {count}, found {occurrences}"
        )
    return {"path": FILES[source], "line": occurrences[0],
            "anchor": anchor, "hits": len(occurrences)}


def section(text: str, start: str, end: str, source: str) -> str:
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError(f"Could not isolate {source} section: {start} .. {end}")
    a = text.index(start)
    b = text.index(end, a + len(start))
    if b <= a:
        raise ValueError(f"Out-of-order source section in {source}")
    return text[a:b]


def registration(registry: str, key: str, constructor: str) -> dict:
    # Use a bounded FEEDS_DATA registration, rather than an unrelated text hit.
    start = f'name: "{key}"'
    if registry.count(start) != 1:
        raise ValueError(f"Expected one {key} feed registration")
    chunk = registry[registry.index(start):]
    cut = chunk.find("\n  },")
    if cut < 0:
        raise ValueError(f"Unterminated feed registration {key}")
    body = chunk[:cut]
    if not re.search(r"factory:\s*\(\)\s*=>\s*new lazy\." +
                     re.escape(constructor) + r"\s*\(", body):
        raise ValueError(f"{key} no longer constructs {constructor}")
    return evidence(registry, start, "registry")


def validate_source(texts: dict[str, str]) -> dict:
    registry, modern, legacy, bundles, jar = (texts[name] for name in FILES)
    feeds = section(registry, "const FEEDS_DATA = [", "\n];",
                    "ActivityStream FEEDS_DATA")
    legacy_entry = registration(feeds, "system.topstories", "TopStoriesFeed")
    modern_entry = registration(feeds, "discoverystreamfeed", "DiscoveryStreamFeed")
    # Resolve line numbers in the whole file, not the sliced FEEDS_DATA block.
    legacy_entry = evidence(registry, 'name: "system.topstories"', "registry")
    modern_entry = evidence(registry, 'name: "discoverystreamfeed"', "registry")
    top_sites = registration(feeds, "system.topsites", "TopSitesFeed")
    top_sites = evidence(registry, 'name: "system.topsites"', "registry")
    prefs_feed = registration(feeds, "prefs", "PrefsFeed")
    prefs_feed = evidence(registry, 'name: "prefs"', "registry")

    # TopStoriesFeed retains an independently initialized legacy fallback when
    # Discovery Stream is disabled or its preference cannot be parsed.
    legacy_gate = section(legacy, "  lazyLoadTopStories(options = {}) {",
                          "\n  handleDisabled(action) {", "TopStoriesFeed")
    for token in (
        "JSON.parse(dsPref).enabled",
        "this.discoveryStreamEnabled = false",
        "if (this.storiesLoaded || !userPref)",
        "if (!this.discoveryStreamEnabled && !this.propertiesInitialized)",
        "this.initializeProperties();",
        "this.init();",
    ):
        if token not in legacy_gate:
            raise ValueError(f"Legacy New Tab fallback changed: {token}")
    for token in ("fetchStories()", "fetchTopics()", "this.clearCache()",
                  'this._prefs.get("pocketCta")'):
        if token not in legacy:
            raise ValueError(f"Legacy recommendation data/CTA user changed: {token}")

    # DiscoveryStream feeds own both recommendation and sponsored branches.
    refresh = section(modern, "  async refreshAll(options = {}) {",
                      "\n  // We have to rotate stories", "DiscoveryStream")
    if "if (this.showStories)" not in refresh:
        raise ValueError("Modern story-gating changed")
    if "this.loadSpocs(" not in refresh or "this.loadComponentFeeds(" not in refresh:
        raise ValueError("Sponsored and organic modern feed paths changed")
    for token in ("get showStories() {", "get showSponsoredStories() {",
                  "this.adsClient = lazy.AdsClient.getClient();",
                  "lazy.NimbusFeatures.pocketNewtab.onUpdate(",
                  'if (action.data.name === "pocketConfig")'):
        if token not in modern:
            raise ValueError(f"Modern recommendation coupling changed: {token}")

    # Both feed implementations remain bundled into New Tab. User UI/places,
    # prefs, generated content bundles and alternate JAR/XPI are preserved.
    for token in ('JAR_MANIFESTS += ["addon-jar.mn"]',
                  'script="build-newtab-bundles.py"',
                  'DIRS += ["webext-glue"]'):
        if token not in bundles:
            raise ValueError(f"New Tab package dependency changed: {token}")
    if "builtin-addons/newtab/lib/ (./lib/*)" not in jar:
        raise ValueError("Default New Tab module wildcard changed")
    if "builtin-addons/newtab/lib/DiscoveryStreamFeed.sys.mjs" not in jar:
        raise ValueError("Alternate New Tab manifest lost modern feed")

    promoted = [
        evidence(registry, '"discoverystream.promoCard.enabled"', "registry"),
        evidence(registry, '"pocketCta"', "registry"),
    ]

    return {
        "schema_version": 1,
        "mode": "pinned_head_source_boundary_audit_only",
        "newtab_registration": {
            "modern_recommendations": modern_entry,
            "legacy_recommendations": legacy_entry,
            "protected_top_sites": top_sites,
            "protected_preferences": prefs_feed,
        },
        "live_source_boundaries": [
            {
                "id": "legacy_topstories_fallback",
                "classification": "retain",
                "why": "TopStoriesFeed has its own discovery-disabled fallback, cache, "
                       "stories/topics fetch and pocket CTA dispatch.",
                "evidence": [
                    evidence(legacy, "  lazyLoadTopStories(options = {}) {", "legacy"),
                    evidence(legacy, "this.discoveryStreamEnabled = false", "legacy"),
                    evidence(legacy, "this.initializeProperties();", "legacy"),
                ],
            },
            {
                "id": "modern_discovery_recommendations",
                "classification": "retain",
                "why": "DiscoveryStreamFeed connects story visibility, content fetching, "
                       "Nimbus pref updates and recommendation state.",
                "evidence": [
                    evidence(modern, "get showStories() {", "modern"),
                    evidence(modern, "this.loadComponentFeeds(", "modern", count=2),
                    evidence(modern, "lazy.NimbusFeatures.pocketNewtab.onUpdate(", "modern"),
                ],
            },
            {
                "id": "sponsored_discovery_path",
                "classification": "retain_pending_guard_audit",
                "why": "Sponsored content still uses SPoCs and shared AdsClient independently "
                       "of optional AdsFeed.sys.mjs.",
                "evidence": [
                    evidence(modern, "get showSponsoredStories() {", "modern"),
                    evidence(modern, "this.adsClient = lazy.AdsClient.getClient();", "modern"),
                    evidence(modern, "this.loadSpocs(", "modern", count=4),
                ],
            },
            {
                "id": "pocket_promo_preferences",
                "classification": "narrow_optional_pref_only_no_removal",
                "why": "Promotional-card and Pocket CTA preference strings exist, "
                       "but renderer imports, remote overrides and page consumers "
                       "have not been proven safe for packaging omission.",
                "evidence": promoted,
            },
        ],
        "protected_bundles": [
            FILES["registry"], FILES["modern"], FILES["legacy"],
            FILES["bundles"], FILES["jar"],
        ],
        "removal_authorized": False,
        "candidate_recommendation": "Keep both independent story feeds, generated "
                                    "New Tab bundles, Top Sites, prefs and Nimbus. "
                                    "Next audit actual promo-card/CTA callers and "
                                    "renderer fallback before opt-in experiments.",
        "limitations": [
            "Source anchor presence is not dynamic runtime reachability.",
            "Only the named, tracked source files were inspected.",
            "No compiler, browser runtime, network trace or package measurement.",
            "A preference name alone cannot authorize deletion of a resource.",
        ],
    }


def self_test(texts: dict[str, str]) -> None:
    report = validate_source(texts)
    assert report["removal_authorized"] is False
    mutations = (
        ("registry", 'name: "system.topstories"'),
        ("registry", 'name: "discoverystreamfeed"'),
        ("legacy", "if (!this.discoveryStreamEnabled && !this.propertiesInitialized)"),
        ("modern", "this.loadComponentFeeds("),
        ("modern", "this.adsClient = lazy.AdsClient.getClient();"),
        ("bundles", 'JAR_MANIFESTS += ["addon-jar.mn"]'),
        ("jar", "builtin-addons/newtab/lib/ (./lib/*)"),
    )
    for name, token in mutations:
        changed = dict(texts)
        if token not in texts[name]:
            raise AssertionError(f"Bad self-test fixture: {name}, {token}")
        changed[name] = texts[name].replace(token, "DISABLED_IN_TEST", 1)
        try:
            validate_source(changed)
        except (ValueError, AssertionError):
            continue
        raise AssertionError(f"Failed to detect missing source dependency: {name}, {token}")
    print("PASS: seven deliberately broken source dependencies rejected")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, help="write a bounded JSON audit")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    sha = subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True
    ).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Noncanonical pinned Git commit SHA")
    texts = {key: tracked_text(key) for key in FILES}
    result = validate_source(texts)
    result["source_commit"] = sha
    if args.self_test:
        self_test(texts)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: bounded Pocket/DiscoveryStream source boundary audit at {sha}")
    print("PASS: both recommendation feeds + fallback + shared sponsored and New Tab UI preserved")
    print("AUDIT ONLY: no source removal, runtime claim, native package bytes or M3 gate credit")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.CalledProcessError, AssertionError) as exc:
        print("FAIL: Pocket boundary source changed:", exc, file=sys.stderr)
        raise SystemExit(1)
