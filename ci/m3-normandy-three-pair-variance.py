#!/usr/bin/env python3
"""Read-only, source-aware variance of three independently accepted native pairs.

Inputs are signed-off same-source full/opt-in comparison reports. No package
archives downloaded here, no browser compiled, no marginal component-byte claim.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import json
from pathlib import Path
import re
import sys

HEX40=re.compile(r"[0-9a-f]{40}\Z")
HEX64=re.compile(r"[0-9a-f]{64}\Z")
SCHEMA=1

def checked(report, label):
    if not isinstance(report,dict) or report.get("schema_version")!=SCHEMA:
        raise ValueError(label+": malformed comparison schema")
    source=report.get("source_commit")
    if not isinstance(source,str) or HEX40.fullmatch(source) is None:
        raise ValueError(label+": no source-pinned candidate")
    for field in ("full_sha256","lean_sha256"):
        value=report.get(field)
        if not isinstance(value,str) or HEX64.fullmatch(value) is None:
            raise ValueError(label+": missing package SHA256: "+field)
    if report["full_sha256"]==report["lean_sha256"]:
        raise ValueError(label+": same full/lean archive")
    for key in ("full_compressed_bytes","lean_compressed_bytes",
                "full_regular_logical_bytes","lean_regular_logical_bytes",
                "compressed_saved_bytes"):
        val=report.get(key)
        if not isinstance(val,int) or isinstance(val,bool) or val<=0:
            raise ValueError(label+": implausible or missing size: "+key)
    full=report["full_compressed_bytes"]
    lean=report["lean_compressed_bytes"]
    if full-lean!=report["compressed_saved_bytes"]:
        raise ValueError(label+": misreported source-matched archive delta")
    full_regular=report["full_regular_logical_bytes"]
    lean_regular=report["lean_regular_logical_bytes"]
    if not 0<full_regular-lean_regular<full_regular:
        raise ValueError(label+": missing positive regular-file logical delta")
    percent=report.get("compressed_reduction_percent")
    if not isinstance(percent,(int,float)) or isinstance(percent,bool) or (
        abs(percent-round(100*(full-lean)/full,3))>0.00001
    ):
        raise ValueError(label+": reported percentage disagrees with exact measured archive")
    return {"source_commit":source,
            "full_sha256":report["full_sha256"],
            "lean_sha256":report["lean_sha256"],
            "full_compressed_bytes":full,
            "lean_compressed_bytes":lean,
            "compressed_saved_bytes":full-lean,
            "logical_regular_bytes_difference":full_regular-lean_regular}

def reconcile(reports):
    if not isinstance(reports,list) or len(reports)!=3:
        raise ValueError("Require three original independently verified native comparisons")
    trials=[checked(x,"pair "+str(i+1)) for i,x in enumerate(reports)]
    if len(set(x["source_commit"] for x in trials))!=3:
        raise ValueError("Trials must be from three distinct source commits")
    digest_set=[x[k] for x in trials for k in ("full_sha256","lean_sha256")]
    if len(set(digest_set))!=6:
        raise ValueError("Reused or duplicated native package SHA256")
    archived=[x["compressed_saved_bytes"] for x in trials]
    logical=[x["logical_regular_bytes_difference"] for x in trials]
    if any(delta<=0 for delta in archived):
        raise ValueError("One tested omission did not reduce archive size")
    return {
        "schema_version":1,
        "scope":"three original independently verified matched-source opt-in Normandy native archive reports",
        "independent_source_commits":[x["source_commit"] for x in trials],
        "verified_input_archive_hashes_quoted_from_original_reports":True,
        "three_distinct_source_revisions":True,
        "per_pair_reported_archive_sha256_unique":True,
        "trials":trials,
        "compressed_archive_deltas_bytes":archived,
        "compressed_delta_range_bytes":{"minimum":min(archived),"maximum":max(archived)},
        "compressed_delta_invariant":len(set(archived))==1,
        "regular_logical_file_net_size_deltas_bytes":logical,
        "regular_logical_delta_invariant":len(set(logical))==1,
        "native_browser_or_package_executed_by_reconciliation":False,
        "independent_build_archive_reproducibility_proven":False,
        "causal_compiled_or_feature_savings_proven":False,
        "three_trials_additive":False,
        "new_source_removal_authorized":False,
        "whole_m3_gate_passed":False,
        "limitations":[
            "Each original pair was source-matched internally, but the three pairs use different source commits.",
            "Original artifacts' archive byte/hash attestations are authenticated externally by CI.",
            "The same net logical-file difference is not proof of the actual component-owned bytes.",
            "Even logical-file net differences may include unrelated build metadata or code changes.",
            "Different compressed tar.xz deltas cannot be summed or treated as reproducible savings.",
            "No browser, loader, telemetry policy or package runtime was exercised by this script.",
        ],
    }

def tests():
    templates=[
        ("a"*40,86937548,86909928,339564498,339454609,"a"*64,"b"*64,.032),
        ("b"*40,87153852,87138100,339566140,339456251,"c"*64,"d"*64,.018),
        ("c"*40,87151648,87134296,339566140,339456251,"e"*64,"f"*64,.020),
    ]
    raw=[]
    for sha,full,lean,regular_a,regular_b,full_hash,lean_hash,pct in templates:
        raw.append({"schema_version":1,"source_commit":sha,
                    "full_compressed_bytes":full,"lean_compressed_bytes":lean,
                    "full_regular_logical_bytes":regular_a,
                    "lean_regular_logical_bytes":regular_b,
                    "compressed_saved_bytes":full-lean,
                    "full_sha256":full_hash,"lean_sha256":lean_hash,
                    "compressed_reduction_percent":pct})
    result=reconcile(raw)
    assert result["compressed_archive_deltas_bytes"]==[27620,15752,17352]
    assert result["regular_logical_file_net_size_deltas_bytes"]==[109889]*3
    assert result["compressed_delta_invariant"] is False
    assert result["regular_logical_delta_invariant"] is True
    assert result["causal_compiled_or_feature_savings_proven"] is False
    cases=[
        lambda xs:xs[1].update(source_commit=xs[0]["source_commit"]),
        lambda xs:xs[2].update(source_commit="not a SHA"),
        lambda xs:xs[0].update(full_sha256="a"*40),
        lambda xs:xs[0].update(lean_sha256=xs[1]["lean_sha256"]),
        lambda xs:xs[1].update(compressed_saved_bytes=100),
        lambda xs:xs[2].update(compressed_reduction_percent=1.0),
        lambda xs:xs[0].update(full_regular_logical_bytes=300),
        lambda xs:xs[2].update(lean_compressed_bytes=xs[2]["full_compressed_bytes"]),
        lambda xs:xs[1].update(schema_version=4),
        lambda xs:xs[0].update(full_compressed_bytes=True),
    ]
    for i,mutate in enumerate(cases,1):
        wrong=deepcopy(raw)
        mutate(wrong)
        try:reconcile(wrong)
        except (ValueError,KeyError,TypeError):continue
        raise AssertionError("False repeatability/source-safety claim accepted "+str(i))
    return len(cases)

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--first",type=Path)
    p.add_argument("--second",type=Path)
    p.add_argument("--third",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--self-test",action="store_true")
    a=p.parse_args()
    if a.self_test:
        print("PASS:",tests(),"source/hash/arithmetic and non-additive repeatability fixtures")
        if not any((a.first,a.second,a.third,a.output)):return
    if not (a.first and a.second and a.third and a.output):
        p.error("All three authentic reports and --output required")
    reports=[json.loads(pth.read_text()) for pth in (a.first,a.second,a.third)]
    d=reconcile(reports)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(d,indent=2)+"\n")
    print("PASS: three source-distinct native package pairs inspected")
    print("SIGNED ARCHIVE DELTAS:",d["compressed_archive_deltas_bytes"])
    print("NET REGULAR-LOGICAL DELTAS:",d["regular_logical_file_net_size_deltas_bytes"])
    print("NO causal/marginal per-feature byte or M3 gate credit")

if __name__=="__main__":
    try:main()
    except (OSError,ValueError,AssertionError,KeyError,TypeError) as error:
        print("FAIL M3 Normandy variance reconciliation:",error,file=sys.stderr)
        raise SystemExit(1)
