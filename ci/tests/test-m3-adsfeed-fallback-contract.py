#!/usr/bin/env python3
"""Check the real source predicates under a synthetic remote AdsFeed override.

This checks only the small boolean branch guard. Actual packaged New Tab and
remote experiment behavior still require full browser runtime validation.
No npm, external services, source mutation, or browser profile is involved.
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "DiscoveryStreamFeed": ("browser/extensions/newtab/lib/DiscoveryStreamFeed.sys.mjs", 2),
    "TopSitesFeed": ("browser/extensions/newtab/lib/TopSitesFeed.sys.mjs", 1),
}
PATTERN = re.compile(
    r"const adsFeedEnabled\s*=\s*"
    r"(!lazy\.AppConstants\.VULPRA_NO_NEWTAB_ADSFEED\s*&&\s*"
    r"(?:this\.store\.getState\(\)\.Prefs\.values|state\.Prefs\.values)"
    r"\[PREF_UNIFIED_ADS_ADSFEED_ENABLED\])\s*;"
)
expressions: list[dict[str, str]] = []
for label, (path, expected_count) in SOURCES.items():
    data = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", "HEAD:" + path], text=True
    )
    found = PATTERN.findall(data)
    assert len(found) == expected_count, (label, len(found), expected_count)
    expressions.extend({"label": label, "expression": item} for item in found)

NODE_TEST = r"""
"use strict";
const expressions = JSON.parse(process.argv[1]);
if (expressions.length !== 3) throw Error("Missing source predicates");
for (const {label, expression} of expressions) {
  // Evaluate the exact predicate extracted from the tracked browser module.
  // The fake store is just the minimum read-only context for its Boolean.
  const evaluate = new Function("lazy", "state",
      "PREF_UNIFIED_ADS_ADSFEED_ENABLED",
      "return function () { return Boolean(" + expression + "); };");
  for (const buildFlag of [false, true]) {
    for (const remotePref of [false, true]) {
      const state = {Prefs: {values: {"unifiedAds.adsFeed.enabled": remotePref}}};
      const lazy = {AppConstants: {VULPRA_NO_NEWTAB_ADSFEED: buildFlag}};
      const fn = evaluate(lazy, state, "unifiedAds.adsFeed.enabled");
      const observed = fn.call({store: {getState() {return state;}}});
      const expected = !buildFlag && remotePref;
      if (observed !== expected) {
        throw Error(label + ": build flag=" + buildFlag +
            ", remote pref=" + remotePref +
            ", got=" + observed + ", expected=" + expected);
      }
    }
  }
  console.log("PASS: " + label + " predicate follows immutable build flag");
}
console.log("PASS: all 3 actual source predicates ignore a remote-on pref in lean");
""";

subprocess.run(
    ["node", "-e", NODE_TEST, json.dumps(expressions)],
    cwd=ROOT,
    check=True,
)
print("SOURCE PREDICATE TEST ONLY: real runtime and package claims require native CI.")
