#!/usr/bin/env python3
"""Read Mozilla's *evaluated* moz.build frontend from two pinned configured trees.

This narrow Python bridge is required because Mozilla's BuildReader and emitter
are Python APIs; all collected paths are public, repository-relative. No user
profiles or browser executables. This is NOT a complete linker/call/dlopen graph.
"""
import collections
import json
import os
from pathlib import Path
import re
import sys

TARGETS = (
    "browser/components/",
    "browser/extensions/",
    "browser/app",
    "toolkit/components/",
    "toolkit/library/",
    "toolkit/mozapps/",
    "widget/",
    "security/",
    "dom/",
)
FLAGS = (
    "MOZ_NORMANDY", "MOZ_SANDBOX", "MOZ_WAYLAND", "MOZ_X11",
    "MOZ_WIDGET_TOOLKIT", "MOZ_SERVICES_SYNC", "MOZ_DEVTOOLS",
    "MOZ_CRASHREPORTER", "MOZ_UPDATER",
    "VULPRA_NO_ASROUTER_PROMOS", "VULPRA_NO_NEWTAB_ADSFEED",
    "VULPRA_NO_NEWTAB_PROMOCARD",
)


def normalized(s):
    if not isinstance(s, str):
        raise ValueError("Expected native source path")
    value = s.replace("\\", "/").strip("/")
    if value in ("", "."):
        return ""
    if not re.fullmatch(r"[A-Za-z0-9_+./@-]+", value):
        raise ValueError("Unsafe source path characters")
    if ".." in value.split("/"):
        raise ValueError("Source path traversal")
    return value


def edge_target(source, item, root):
    path = getattr(item, "full_path", None)
    if path is None:
        path = str(item)
    path = str(path).replace("\\", "/")
    prefix = str(root).replace("\\", "/").rstrip("/") + "/"
    if path.startswith(prefix):
        return normalized(path[len(prefix):])
    if path.startswith("/"):
        # Absolute-looking paths in DIRS can be Mozilla's /topsrcdir syntax;
        # a genuine different filesystem path must never enter evidence.
        if path.startswith(("/home/", "/tmp/", "/opt/", "/usr/")):
            raise ValueError("Traversal outside the pinned browser source")
        return normalized(path)
    return normalized(f"{source}/{path}" if source else path)


def assert_flags(substs, variant):
    expected = {
        "MOZ_WIDGET_TOOLKIT": "gtk",
        "MOZ_DEVTOOLS": "all",
    }
    for key, value in expected.items():
        if str(substs.get(key)) != value:
            raise ValueError(f"Protected generated flag {key} differs")
    for key in ("MOZ_WAYLAND", "MOZ_SANDBOX", "MOZ_SERVICES_SYNC"):
        if str(substs.get(key)) not in ("1", "True", "true"):
            raise ValueError(f"Protected generated flag {key} not enabled")
    is_lean = variant == "combined_four"
    if (str(substs.get("MOZ_NORMANDY")) in ("1", "True", "true")) == is_lean:
        raise ValueError("Evaluated Normandy setting does not match variant")
    for key in ("VULPRA_NO_ASROUTER_PROMOS",
                "VULPRA_NO_NEWTAB_ADSFEED",
                "VULPRA_NO_NEWTAB_PROMOCARD"):
        value = str(substs.get(key))
        if is_lean and value not in ("1", "True", "true"):
            raise ValueError(f"Combined actual generated opt-in absent: {key}")
        if not is_lean and value in ("1", "True", "true"):
            raise ValueError(f"Normal build unexpectedly omits protected {key}")


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("normal", "combined_four"):
        raise ValueError("usage: EVALUATED_VARIANT CONFIG_STATUS_PATH OUTPUT_JSON")
    variant, status_path, outfile = sys.argv[1:]
    from mozbuild.backend.configenvironment import BuildConfig, ConfigEnvironment
    from mozbuild.frontend.reader import BuildReader
    from mozbuild.frontend.emitter import TreeMetadataEmitter
    from mozbuild.frontend.data import DirectoryTraversal, MozSrcFiles

    status = Path(status_path).resolve(strict=True)
    cfg = BuildConfig.from_config_status(str(status))
    root = Path(cfg.topsrcdir).resolve(strict=True)
    object_root = Path(cfg.topobjdir).resolve(strict=True)
    if status.parent != object_root:
        raise ValueError("Configured original-source objdir mismatch")
    if Path.cwd().resolve(strict=True) != root:
        raise ValueError("Only run against pinned original source checkout")
    if os.environ.get("SOURCE_SHA") != "b1482404dfb8b01342990ee99ea3df0f9756b5f7":
        raise ValueError("Original source commit provenance absent")
    env = ConfigEnvironment(
        cfg.topsrcdir, cfg.topobjdir,
        defines=cfg.defines, substs=cfg.substs,
        source=str(status), mozconfig=cfg.mozconfig,
    )
    assert_flags(cfg.substs, variant)

    types = collections.Counter()
    scope_types = {t: collections.Counter() for t in TARGETS}
    edges = set()
    visited = set()
    visited_traversal = set()
    moz_src_members = set()
    emitted = 0
    reader = BuildReader(env)
    emitter = TreeMetadataEmitter(env)
    for obj in emitter.emit(reader.read_topsrcdir()):
        emitted += 1
        if emitted > 300000:
            raise ValueError("Source frontend unexpectedly exceeded bounded count")
        kind = type(obj).__name__
        types[kind] += 1
        rel = normalized(getattr(obj, "relsrcdir", "") or "")
        visited.add(rel)
        for key in TARGETS:
            if rel.startswith(key):
                scope_types[key][kind] += 1
        if isinstance(obj, MozSrcFiles):
            # Exact evaluated MOZ_SRC_FILES entries, not just object totals.
            # Strip all absolute host paths before emitting the audit artifact.
            for base, files in obj.files.walk():
                for item in files:
                    physical = os.path.realpath(str(getattr(item, "full_path", ""))).replace("\\", "/")
                    source_prefix = str(root).replace("\\", "/").rstrip("/") + "/"
                    object_prefix = str(object_root).replace("\\", "/").rstrip("/") + "/"
                    if physical.startswith(source_prefix):
                        origin, member = "src", normalized(physical[len(source_prefix):])
                    elif physical.startswith(object_prefix):
                        origin, member = "obj", normalized(physical[len(object_prefix):])
                    else:
                        origin, member = "other", normalized(os.path.basename(physical))
                    install_base = normalized(str(base) if base else "")
                    moz_src_members.add((rel, origin, member, install_base))
                    if len(moz_src_members) > 20000:
                        raise ValueError("Unexpectedly large source ownership map")
        if isinstance(obj, DirectoryTraversal):
            visited_traversal.add(rel)
            for item in obj.dirs:
                dest = edge_target(rel, item, root)
                if not dest or dest == rel:
                    raise ValueError("Invalid evaluated directory edge")
                edges.add((rel, dest))
                if len(edges) > 150000:
                    raise ValueError("Unexpectedly large evaluated graph")

    flags = {}
    for flag in FLAGS:
        flags[flag] = {"present": flag in cfg.substs}
        if flag in cfg.substs:
            v = cfg.substs[flag]
            if not isinstance(v, (bool, int, str)):
                raise ValueError("Unexpected non-scalar generated flag")
            flags[flag]["value"] = str(v)
    payload = {
        "schema_version": 1,
        "status": "original_configure_evaluated_mozbuild_frontend",
        "original_source_commit": os.environ["SOURCE_SHA"],
        "variant": variant,
        "evaluated_mozbuild_emission": True,
        "native_linker_or_binary_executed": False,
        "generated_configure_flag_values": flags,
        "emitted_object_count": emitted,
        "source_directories_with_objects": len(visited),
        "evaluated_directory_traversals": len(visited_traversal),
        "evaluated_directory_edges": len(edges),
        "all_emitted_object_type_counts": dict(sorted(types.items())),
        "scoped_emitted_type_counts": {
            k: dict(sorted(v.items())) for k, v in scope_types.items()},
        "directory_edges": sorted([list(x) for x in edges]),
        "actual_emitted_moz_src_file_members": sorted(
            [list(x) for x in moz_src_members]),
        "actual_emitted_moz_src_member_count": len(moz_src_members),
        "complete_compile_or_link_graph": False,
        "ffi_and_runtime_dlopen_graph_proven": False,
        "profile_or_browser_executable_accessed": False,
        "source_pruning_authorized": False,
        "m3_sixth_gate_closed": False,
    }
    if emitted < 500 or len(edges) < 200:
        raise ValueError("Unexpectedly small actual emitted source build graph")
    Path(outfile).write_text(json.dumps(payload, sort_keys=True, indent=2) + "\n")
    print(f"PASS {variant}: evaluated {emitted} Mozilla frontend objects, "
          f"{len(edges)} actual directory edges")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, ImportError) as exc:
        print("FAIL: bounded evaluated Mozilla build graph:", exc, file=sys.stderr)
        raise SystemExit(1)
