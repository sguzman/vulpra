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
from urllib.parse import quote

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


def portable_member(value):
    """Reversibly percent-encode unusual upstream filenames, not discard them."""
    if not isinstance(value, str):
        raise ValueError("Expected source or installation member")
    value = value.replace("\\", "/").strip("/")
    if ".." in value.split("/"):
        raise ValueError("Unsafe parent traversal in ownership member")
    if "\x00" in value:
        raise ValueError("NUL in ownership member")
    return quote(value, safe="/._-+@")


def source_identity(item, root, object_root):
    """Label a frontend file by its *actual* source/obj origin, never host paths."""
    raw = str(getattr(item, "full_path", item)).replace("\\", "/")
    if not os.path.isabs(raw):
        raise ValueError("Frontend ownership input lacks an absolute full_path")
    physical = os.path.realpath(raw).replace("\\", "/")
    for label, directory in (("obj", object_root), ("src", root)):
        prefix = str(directory).replace("\\", "/").rstrip("/") + "/"
        if physical.startswith(prefix):
            return (label, portable_member(physical[len(prefix):]))
    return ("other", portable_member(os.path.basename(physical)))


def install_component(value):
    """Do not silently mistake absolute or noncanonical targets for dist paths."""
    raw = str(value) if value is not None else ""
    if raw.startswith("/") or raw.startswith("\\"):
        return "@noncanonical-install-component"
    try:
        return portable_member(raw)
    except ValueError:
        return "@noncanonical-install-component"


def declared_link_source(item, root, object_root):
    """Classify each linkable compile unit without guessing relative ownership."""
    raw = str(getattr(item, "full_path", item)).replace("\\", "/")
    if os.path.isabs(raw):
        return source_identity(item, root, object_root)
    return ("unresolved_relative", portable_member(raw))


def linkable_identity(obj):
    """Stable declared link-target identity independent of source/obj directory."""
    owner = normalized(getattr(obj, "relsrcdir", "") or "")
    kind = type(obj).__name__
    build_kind = portable_member(str(getattr(obj, "KIND", "unspecified")))
    name = getattr(obj, "name", None)
    if name is None:
        name = getattr(obj, "program", None)
    return (owner, kind, build_kind, portable_member(str(name or kind)))


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("normal", "combined_four"):
        raise ValueError("usage: EVALUATED_VARIANT CONFIG_STATUS_PATH OUTPUT_JSON")
    variant, status_path, outfile = sys.argv[1:]
    from mozbuild.backend.configenvironment import BuildConfig, ConfigEnvironment
    from mozbuild.frontend.reader import BuildReader
    from mozbuild.frontend.emitter import TreeMetadataEmitter
    from mozbuild.frontend.data import DirectoryTraversal, MozSrcFiles, JARManifest, BaseSources, UnifiedSources, WebIDLCollection, Linkable, BaseLibrary, BaseRustLibrary, BaseRustProgram

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
    evaluated_compile_source_inputs = set()
    evaluated_unified_source_members = set()
    evaluated_webidl_binding_units = set()
    evaluated_webidl_unified_members = set()
    emitted_linkables = []
    jar_manifest_inputs = set()
    installed_resource_inputs = set()
    noncanonical_install_base_members = 0
    noncanonical_install_resource_members = 0
    unexpanded_glob_install_inputs = 0
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
        if isinstance(obj, Linkable):
            emitted_linkables.append(obj)
            if len(emitted_linkables) > 10000:
                raise ValueError("Unexpectedly many emitted native linkables")
        if isinstance(obj, WebIDLCollection):
            # Exact upstream WebIDLCollection.all_source_files() list:
            # generated binding units, including global bindings and
            # generated UnifiedBindings cpp groups.
            for generated_name in obj.all_source_files():
                evaluated_webidl_binding_units.add(
                    (rel, portable_member(str(generated_name))))
            for generated_unit, member_names in obj.unified_source_mapping:
                generated = portable_member(str(generated_unit))
                for member in member_names:
                    evaluated_webidl_unified_members.add(
                        (rel, generated, portable_member(str(member))))
            if len(evaluated_webidl_unified_members) > 100000:
                raise ValueError("Unexpectedly many WebIDL binding members")
        if isinstance(obj, UnifiedSources) and obj.have_unified_mapping:
            # Actual Mozilla group_unified_files membership, not a
            # name-based guess about generated Unified_* translation units.
            for generated_unit, members in obj.unified_source_mapping:
                unit = portable_member(str(generated_unit))
                for member_item in members:
                    origin, member = source_identity(member_item, root, object_root)
                    evaluated_unified_source_members.add(
                        (rel, unit, origin, member))
                    if len(evaluated_unified_source_members) > 100000:
                        raise ValueError("Unexpected unified source expansion")
        if isinstance(obj, BaseSources):
            # Source-file members produced by the real frontend. This is
            # not the compiled linker command or final object-file census.
            for phase, members in (
                    ("static", obj.static_files),
                    ("generated", obj.generated_files)):
                for item in members:
                    origin, member = source_identity(item, root, object_root)
                    evaluated_compile_source_inputs.add(
                        (rel, kind, phase, origin, member))
                    if len(evaluated_compile_source_inputs) > 100000:
                        raise ValueError("Unexpectedly large compile source map")
        if isinstance(obj, JARManifest):
            # This is an evaluated jar.mn *input*, not a parsed entry or
            # proof of final omni.ja ownership.
            origin, member = source_identity(obj.path, root, object_root)
            jar_manifest_inputs.add((rel, origin, member))
            if len(jar_manifest_inputs) > 5000:
                raise ValueError("Unexpectedly many evaluated JAR manifests")
        if kind in ("FinalTargetFiles", "FinalTargetPreprocessedFiles",
                    "LocalizedFiles", "LocalizedPreprocessedFiles"):
            # Real frontend installer inputs. Destination roots and hierarchy
            # are metadata, not a claim that the resource reached the archive.
            target = install_component(getattr(obj, "install_target", None))
            for base, files in obj.files.walk():
                subdir = install_component(base)
                for item in files:
                    origin, member = source_identity(item, root, object_root)
                    # Glob declarations are inputs, not enumerated installed
                    # files; do not infer one declared pattern == one payload.
                    raw_item = str(getattr(item, "full_path", item))
                    declaration = (
                        "unexpanded_glob" if any(c in raw_item for c in "*?[")
                        else "path")
                    if declaration == "unexpanded_glob":
                        unexpanded_glob_install_inputs += 1
                    name = getattr(item, "target_basename", None)
                    if kind in ("FinalTargetPreprocessedFiles",
                                "LocalizedPreprocessedFiles"):
                        name = obj.get_obj_basename(item)
                    if name is None:
                        name = os.path.basename(member)
                    basename = install_component(name)
                    installed_resource_inputs.add(
                        (rel, kind, origin, member, target, subdir, basename, declaration))
                    if "@noncanonical-install-component" in (
                            target, subdir, basename):
                        noncanonical_install_resource_members += 1
                    if len(installed_resource_inputs) > 100000:
                        raise ValueError("Unexpectedly many installer inputs")
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
                    try:
                        install_base = normalized(str(base) if base else "")
                    except ValueError:
                        # Some installation paths are not source-root-relative.
                        # Label their limits rather than inventing ownership.
                        install_base = "@noncanonical-install-base"
                        noncanonical_install_base_members += 1
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

    # Link edges can be populated by the emitter after individual target
    # objects appear, so inspect them only after the complete emission.
    declared_link_target_nodes = set()
    declared_library_link_edges = set()
    declared_system_library_links = set()
    declared_static_link_into = set()
    declared_linkable_compile_units = set()
    evaluated_rust_program_targets = set()
    evaluated_rust_program_features = set()
    evaluated_rust_library_targets = set()
    evaluated_rust_library_features = set()
    evaluated_rust_library_dependencies = set()
    unresolved_relative_compile_units = 0
    for obj in emitted_linkables:
        consumer = linkable_identity(obj)
        if isinstance(obj, BaseRustProgram):
            cargo_origin, cargo_member = source_identity(
                obj.cargo_file, root, object_root)
            evaluated_rust_program_targets.add(
                consumer + (
                    cargo_origin, cargo_member,
                    portable_member(str(obj.output_category or ""))))
            for feature in getattr(obj, "features", ()):
                evaluated_rust_program_features.add(
                    consumer + (portable_member(str(feature)),))
            if len(evaluated_rust_program_targets) > 5000:
                raise ValueError("Unexpectedly many declared Rust programs")
        if isinstance(obj, BaseRustLibrary):
            cargo_origin, cargo_member = source_identity(
                obj.cargo_file, root, object_root)
            # This covers the actual Mozilla-emitted staticlib frontend
            # declarations, not Cargo's resolved transitive dependency graph
            # or a generated rustc invocation.
            evaluated_rust_library_targets.add(
                consumer + (
                    cargo_origin, cargo_member,
                    portable_member(str(obj.crate_type or "")),
                    portable_member(str(obj.cargo_crate_type or "")),
                    portable_member(str(obj.cargo_profile_suffix or "")),
                    portable_member(str(obj.output_category or "")),
                    bool(obj.is_gkrust), bool(obj.no_lto)))
            for feature in obj.features:
                evaluated_rust_library_features.add(
                    consumer + (portable_member(str(feature)),))
            for dependency in obj.dependencies:
                evaluated_rust_library_dependencies.add(
                    consumer + (portable_member(str(dependency)),))
            if len(evaluated_rust_library_dependencies) > 15000:
                raise ValueError("Unexpectedly many declared Rust dependencies")
        declared_link_target_nodes.add(consumer)
        for suffix, members in obj.sources.items():
            for item in members:
                origin, member = declared_link_source(item, root, object_root)
                declared_linkable_compile_units.add(
                    consumer + (portable_member(str(suffix)), origin, member))
                if origin == "unresolved_relative":
                    unresolved_relative_compile_units += 1
                if len(declared_linkable_compile_units) > 100000:
                    raise ValueError("Unexpectedly many linkable compile units")
        for lib in obj.linked_libraries:
            if not isinstance(lib, BaseLibrary):
                raise ValueError("Non-library in emitted linked_libraries")
            declared_library_link_edges.add(consumer + linkable_identity(lib))
        for system_lib in obj.linked_system_libs:
            if not isinstance(system_lib, str):
                raise ValueError("Unexpected system library link token")
            declared_system_library_links.add(
                consumer + (portable_member(system_lib),))
        into = getattr(obj, "link_into", None)
        if into:
            declared_static_link_into.add(consumer + (portable_member(str(into)),))
        if (len(declared_library_link_edges) > 100000 or
                len(declared_system_library_links) > 100000):
            raise ValueError("Unexpectedly large declared native link map")

    unified_generated_unit_keys = {
        (owner, unit) for owner, unit, _, _ in evaluated_unified_source_members
    }
    unresolved_unified_linkable_units = {
        (record[0], record[-1])
        for record in declared_linkable_compile_units
        if record[-2] == "unresolved_relative" and
        record[-1].startswith("Unified_")
    }
    unmatched_unified_linkable_units = (
        unresolved_unified_linkable_units - unified_generated_unit_keys
    )

    unresolved_nonunified_linkable_units = {
        (record[0], record[-1])
        for record in declared_linkable_compile_units
        if record[-2] == "unresolved_relative" and
        not record[-1].startswith("Unified_")
    }
    unmatched_webidl_linkable_units = (
        unresolved_nonunified_linkable_units - evaluated_webidl_binding_units
    )

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
        "actual_evaluated_rust_program_targets": sorted(
            [list(x) for x in evaluated_rust_program_targets]),
        "actual_evaluated_rust_program_target_count": len(evaluated_rust_program_targets),
        "actual_evaluated_rust_program_features": sorted(
            [list(x) for x in evaluated_rust_program_features]),
        "actual_evaluated_rust_program_feature_count": len(evaluated_rust_program_features),
        "actual_evaluated_rust_library_targets": sorted(
            [list(x) for x in evaluated_rust_library_targets]),
        "actual_evaluated_rust_library_target_count": len(evaluated_rust_library_targets),
        "actual_evaluated_rust_library_features": sorted(
            [list(x) for x in evaluated_rust_library_features]),
        "actual_evaluated_rust_library_feature_count": len(evaluated_rust_library_features),
        "actual_evaluated_rust_library_dependencies": sorted(
            [list(x) for x in evaluated_rust_library_dependencies]),
        "actual_evaluated_rust_library_dependency_count": len(evaluated_rust_library_dependencies),
        "cargo_resolved_dependency_graph_proven": False,
        "rustc_invocation_or_rust_linker_executed": False,
        "actual_evaluated_linkable_nodes": sorted(
            [list(x) for x in declared_link_target_nodes]),
        "actual_evaluated_linkable_node_count": len(declared_link_target_nodes),
        "actual_evaluated_library_link_edges": sorted(
            [list(x) for x in declared_library_link_edges]),
        "actual_evaluated_library_link_edge_count": len(declared_library_link_edges),
        "actual_evaluated_system_library_links": sorted(
            [list(x) for x in declared_system_library_links]),
        "actual_evaluated_system_library_link_count": len(declared_system_library_links),
        "actual_evaluated_webidl_binding_units": sorted(
            [list(x) for x in evaluated_webidl_binding_units]),
        "actual_evaluated_webidl_binding_unit_count": len(evaluated_webidl_binding_units),
        "actual_evaluated_webidl_unified_members": sorted(
            [list(x) for x in evaluated_webidl_unified_members]),
        "actual_evaluated_webidl_unified_member_count": len(evaluated_webidl_unified_members),
        "unresolved_nonunified_linkable_unit_count": len(unresolved_nonunified_linkable_units),
        "unmatched_webidl_linkable_units": sorted(
            [list(x) for x in unmatched_webidl_linkable_units]),
        "webidl_codegen_executed": False,
        "actual_evaluated_unified_source_members": sorted(
            [list(x) for x in evaluated_unified_source_members]),
        "actual_evaluated_unified_source_member_count": len(evaluated_unified_source_members),
        "actual_evaluated_unified_generated_unit_count": len(unified_generated_unit_keys),
        "unresolved_unified_linkable_unit_count": len(unresolved_unified_linkable_units),
        "unmatched_unified_linkable_units": sorted(
            [list(x) for x in unmatched_unified_linkable_units]),
        "actual_evaluated_linkable_compile_units": sorted(
            [list(x) for x in declared_linkable_compile_units]),
        "actual_evaluated_linkable_compile_unit_count": len(declared_linkable_compile_units),
        "unresolved_relative_linkable_compile_unit_count": unresolved_relative_compile_units,
        "declared_compile_owner_is_linker_object_proof": False,
        "actual_evaluated_static_link_into": sorted(
            [list(x) for x in declared_static_link_into]),
        "actual_evaluated_static_link_into_count": len(declared_static_link_into),
        "actual_linker_commands_executed": False,
        "actual_linker_flag_and_object_equivalence_proven": False,
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
        "noncanonical_moz_src_install_base_members": noncanonical_install_base_members,
        "actual_evaluated_compile_source_inputs": sorted(
            [list(x) for x in evaluated_compile_source_inputs]),
        "actual_evaluated_compile_source_input_count": len(evaluated_compile_source_inputs),
        "compiled_linker_input_closure_proven": False,
        "actual_evaluated_jar_manifest_inputs": sorted(
            [list(x) for x in jar_manifest_inputs]),
        "actual_evaluated_jar_manifest_count": len(jar_manifest_inputs),
        "actual_evaluated_install_resource_inputs": sorted(
            [list(x) for x in installed_resource_inputs]),
        "actual_evaluated_install_resource_input_count": len(installed_resource_inputs),
        "noncanonical_install_resource_members": noncanonical_install_resource_members,
        "unexpanded_glob_install_input_count": unexpanded_glob_install_inputs,
        "source_objdir_subtree_matched_before_topsrcdir": True,
        "jar_manifest_entries_parsed": False,
        "compiled_resource_installation_proven": False,
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
