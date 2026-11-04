#!/usr/bin/env python3
"""Fail-closed independent cross-report audit of bounded native M3 Actions evidence.

Read only the seven *sanitized reports* from a downloaded Actions artifact ZIP.
The trusted source commit and run ID must be supplied from GitHub run metadata.
This is NOT a native compiler run, tarball content check, full linker/FFI/dlopen
closure, security proof, Arch parity test, or permission to remove code.
"""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
from pathlib import Path
import re
import stat
import sys
import tempfile
import warnings
from urllib.parse import urlsplit
from zipfile import ZipFile, ZIP_DEFLATED, ZipInfo

PACKAGE = "vulpra-local-m3-native-link-ci.tar.xz"
REPORTS = {
    "config": "m3-native-link-config.json",
    "replay": "m3-native-packager-replay.json",
    "link": "m3-native-link-inputs.json",
    "elf": "m3-native-link-elf-package-graph.json",
    "local": "m3-localhost-acceptance.json",
    "webext": "webextension-smoke-",  # stamped basename
    "sidecar": PACKAGE + ".sha256",
}
HEX64 = re.compile(r"[a-f0-9]{64}\Z")
SHA40 = re.compile(r"[a-f0-9]{40}\Z")
MAX_ZIP_BYTES = 2 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 512 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(value):
    require(isinstance(value, str) and HEX64.fullmatch(value), "Missing/malformed SHA-256")
    return value


def reports_from_zip(path):
    require(path.is_file() and 100 < path.stat().st_size <= MAX_ZIP_BYTES,
            "Evidence ZIP missing or too large")
    found = {}
    with ZipFile(path) as z:
        items = z.infolist()
        require(len(items) == 7, "Unexpected evidence ZIP member count")
        require(sum(i.file_size for i in items) <= MAX_UNCOMPRESSED_BYTES,
                "Unbounded evidence ZIP expanded bytes")
        for info in items:
            require(not info.is_dir(), "Directory rather than evidence file")
            require(info.file_size <= MAX_UNCOMPRESSED_BYTES, "Unbounded evidence entry")
            require(not (info.external_attr >> 16 and
                         stat.S_ISLNK(info.external_attr >> 16)), "Symlink evidence member")
            parts = info.filename.split("/")
            require(len(parts) > 1 and all(x not in ("", ".", "..") for x in parts),
                    "Unsafe evidence archive path")
            name = parts[-1]
            if name.startswith(REPORTS["webext"]) and name.endswith(".json"):
                key = "webext"
            else:
                matches = [k for k, v in REPORTS.items()
                           if k != "webext" and v == name]
                require(len(matches) == 1, "Unexpected evidence archive member")
                key = matches[0]
            require(key not in found, "Duplicate evidence type")
            data = z.read(info)
            found[key] = data if key == "sidecar" else json.loads(data)
    require(set(found) == set(REPORTS), "Missing evidence report")
    return found


def check_flags(config):
    require(config.get("configure_executed_in_this_run") is True,
            "Not a real generated configuration")
    require(config.get("native_browser_compiled") is False,
            "Configure-only report overclaims a build")
    flags = config["observed_generated_substs"]
    expected = {
        "MOZ_BUILD_APP": "browser", "MOZ_WIDGET_TOOLKIT": "gtk",
        "OS_TARGET": "Linux", "MOZ_APP_BASENAME": "Vulpra",
        "MOZ_APP_NAME": "vulpra", "MOZ_SERVICES_SYNC": "1",
        "MOZ_NORMANDY": "1", "MOZ_DEVTOOLS": "all",
        "MOZ_CRASHREPORTER": "1", "MOZ_UPDATER": "1",
        "MOZ_SANDBOX": "1", "MOZ_WAYLAND": "1", "MOZ_X11": "1",
        "ENABLE_WEBDRIVER": "1",
    }
    for key, expected_value in expected.items():
        actual = flags.get(key, {})
        require(actual.get("state") == "recorded" and actual.get("value") == expected_value,
                "Protected generated config missing: " + key)
    require(flags.get("VULPRA_NO_ASROUTER_PROMOS", {}).get("value") in (None, ""),
            "Normal browser was compiled with promotional omission")
    for key in ("VULPRA_NO_NEWTAB_ADSFEED", "VULPRA_NO_NEWTAB_PROMOCARD"):
        # They must not be present or enabled in the unomitted normal build.
        require(key not in flags or flags[key].get("value") in (None, ""),
                "Normal browser changed optional source omission: " + key)
    return len(expected)


def check_elf_graph(graph):
    members = graph["elf_members"]
    edges = graph["direct_edges"]
    require(len(members) == 28 and len(edges) == 268,
            "Historical full-normal ELF/edge counts changed")
    require(graph["archive_regular_members"] == 47 and
            graph["archive_link_members"] == 0,
            "Package physical member census changed")
    paths = [m["path"] for m in members]
    require(len(set(paths)) == len(paths), "Duplicate native ELF member")
    require(graph["archive_regular_logical_bytes"] >= sum(m["logical_bytes"] for m in members),
            "ELF regular bytes exceed archive logical bytes")
    provider = {}
    expected_edges = []
    for m in members:
        require(m["name"] == Path(m["path"]).name and m["logical_bytes"] > 0,
                "Inconsistent packaged ELF name/size")
        sha(m["sha256"])
        keys = {m["name"]}
        if m.get("soname"):
            keys.add(m["soname"])
        for key in keys:
            provider.setdefault(key, set()).add(m["path"])
        require(len(m["needed"]) == len(set(m["needed"])),
                "Repeated direct DT_NEEDED declaration")
        expected_edges.extend((m["path"], lib) for lib in m["needed"])
    reported_edges = [(e["requester"], e["needed"]) for e in edges]
    require(reported_edges == expected_edges, "Direct ELF edge sequence does not match members")
    packaged = set()
    absent = set()
    for e in edges:
        matches = sorted(provider.get(e["needed"], []))
        require(e["possible_members"] == matches,
                "Contradictory ELF provider list")
        expected_scope = ("packaged_elf_declared_name" if matches else
                          "absent_from_archive_loader_resolution_unverified")
        require(e["scope"] == expected_scope, "Incorrect ELF edge classification")
        (packaged if matches else absent).add(e["needed"])
    require(graph["direct_needed_edges"] == len(edges) and
            graph["unique_needed_names"] == len(packaged | absent),
            "Invalid aggregate native dependency counts")
    require(graph["packaged_elf_needed_names"] == sorted(packaged) and
            graph["not_packaged_needed_names"] == sorted(absent) and
            graph["archive_link_only_needed_names"] == [],
            "Native loader classification sets disagree")
    require(graph["host_dependency_resolution_verified"] is False and
            graph["dlopen_and_indirect_runtime_dependencies_complete"] is False and
            graph["current_main_compiled_source_matched"] is False and
            graph["source_removal_authorized"] is False and
            graph["marginal_compressed_saving_bytes"] is None,
            "Static graph overclaims unverified dependency closure")
    return {"elf_members": len(members), "direct_needed_edges": len(edges),
            "distinct_needed_names": len(packaged | absent),
            "absent_from_package": len(absent)}


def reconcile(data, expected_source, expected_run):
    require(bool(SHA40.fullmatch(expected_source)), "Expected source not a SHA-1 commit")
    require(isinstance(expected_run, int) and expected_run > 0,
            "Missing trusted workflow run ID")
    conf, link, elf, replay, local, ext = [data[k] for k in
                                          ("config", "link", "elf", "replay", "local", "webext")]
    for k in ("config", "link", "elf", "replay", "local", "webext"):
        require(data[k].get("schema_version") == 1,
                "Unsupported report schema: " + k)
    for k in ("config", "link", "elf", "replay"):
        require(data[k].get("source_commit") == expected_source,
                "Source revision differs: " + k)
    require(link.get("workflow_run_id") == expected_run,
            "Workflow run ID differs from trusted metadata")
    flags_count = check_flags(conf)
    counts = check_elf_graph(elf)

    archive_sha = sha(link["package"]["package_sha256"])
    require(archive_sha == elf["archive_sha256"] == local["sha256"],
            "Package hash differs between link/ELF/runtime records")
    side = data["sidecar"].decode("ascii").strip().split()
    require(len(side) == 2 and side[0] == archive_sha and side[1].lstrip("*") == PACKAGE,
            "Packaged archive SHA sidecar mismatch")
    require(link["package"]["package_compressed_bytes"] == elf["archive_compressed_bytes"]
            and link["package"]["regular_member_count"] == elf["archive_regular_members"],
            "Package length/member count differs across reports")
    lib = link["package"]["libxul_member"]
    packaged = [m for m in elf["elf_members"] if m["name"] == "libxul.so"]
    require(len(packaged) == 1 and lib["path"] == packaged[0]["path"] and
            lib["bytes"] == packaged[0]["logical_bytes"] and
            sha(lib["sha256"]) == packaged[0]["sha256"],
            "Packaged libxul hash/bytes not independently reconciled")
    require(replay["method"] == "mozpack.files.ExecutableFile.copy" and
            replay["buildconfig_origin"] ==
            "real_mach_python_buildconfig_verified_against_generated_substs",
            "Not the real Gecko generated packager")
    for key in ("mozpack_copy_ran_on_temporary_file", "reproduced_matches_staged",
                "source_binary_intact_after_replay", "staged_binary_intact_after_replay"):
        require(replay[key] is True, "Packager transform safety/identity missing: " + key)
    require(replay["packaged_archive_member_verified_by_other_report"] is False,
            "Replay script claimed independent tar-member verification")
    require(sha(replay["source_libxul_sha256"]) == link["built_libxul_sha256"] and
            replay["staged_libxul_sha256"] == replay["reproduced_libxul_sha256"] == lib["sha256"],
            "Linked/staged/reproduced libxul identities disagree")
    require(link["built_libxul_matches_packaged_libxul"] is
            (link["built_libxul_sha256"] == lib["sha256"]),
            "Incorrect raw-vs-stripped identity classification")
    transform = link["packaging_transform_replay"]
    require(transform["deterministic_reproduction_verified"] is True and
            transform["source_commit"] == expected_source and
            transform["original_libxul_sha256"] == link["built_libxul_sha256"] and
            transform["staged_and_reproduced_libxul_sha256"] == lib["sha256"] and
            transform["original_and_packaged_hash_equal"] is link["built_libxul_matches_packaged_libxul"],
            "Link report contradicts real Gecko packager replay")
    response = link["libxul_link_input_response"]
    require(100 <= response["entry_count"] <= 100000 and
            sum(response["entry_extension_counts"].values()) == response["entry_count"] and
            response["raw_input_paths_retained_in_report"] is False and
            sha(response["sha256"]), "Unverified linker input response census")
    order = link["dist_native_loader_order"]
    require(order == link["package"]["packaged_native_loader_order"] and
            order["count"] == len(order["ordered_names"]) and
            order["mozgtk_before_mozwayland"] is True and
            order["ordered_names"].index("libmozgtk.so") <
            order["ordered_names"].index("libmozwayland.so"),
            "Native preload order is inconsistent")
    require(link["runtime_passed_after_link_audit"] is True and
            link["runtime_gates"] == ["Wayland private Weston", "localhost JS navigation",
                                       "isolated profile and WebExtension", "Nimbus check"],
            "Linked source runtime gates are missing")
    require(link["source_removal_authorized"] is False and
            link["compressed_package_savings_claimed"] is None and
            link["linker_full_map_recorded"] is False and
            link["per_feature_native_bytes_attributed"] is False,
            "Link report overclaims feature/size closure")

    for item in (local, ext):
        require(item["package"] == PACKAGE, "Runtime tested another packaged browser")
    require(local["result"] == "pass" and local["profile_isolation"] is True and
            local["screenshot_png_signature"] is True and
            local["screenshot_png_complete_and_crc_valid"] is True and
            all(isinstance(x, int) and x > 0 for x in local["screenshot_dimensions"]) and
            local["local_request_sequence"] == ["/page"],
            "Local graphical screenshot gate missing")
    require(ext["status"] == "pass" and
            ext["javascript_navigation"]["verified"] is True and
            ext["javascript_navigation"]["local_request_sequence"] ==
            ["/start", "/js-run", "/page"],
            "Real browser JavaScript redirect gate missing")
    uri = urlsplit(ext["javascript_navigation"]["final_url"])
    require(uri.scheme == "http" and uri.hostname == "127.0.0.1" and
            uri.port is not None and uri.path == "/page" and
            ext["javascript_navigation"]["final_document_title"] == "M3 destination" and
            ext["javascript_navigation"]["final_document_text"] ==
            "JavaScript navigation succeeded", "WebDriver final URL/DOM not verified")
    for key in ("temporary_unsigned_install", "content_scripts",
                "background_messaging", "storage_local", "uninstall"):
        require(ext["webextension"][key] is True,
                "Native packaged WebExtension missing: " + key)
    require(ext["webextension"]["post_uninstall_samples"] >= 2 and
            ext["security"]["original_firefox_profile_preserved"] is True and
            ext["security"]["temporary_home"] is True,
            "Disposable profile and extension uninstall not verified")
    require(ext["nimbus"] is not None and
            ext["nimbus"]["store_ready"] is True and
            ext["nimbus"]["api_ready"] is True,
            "Actual Nimbus initialization not verified")
    require(ext["asrouter_promotion_optout"] is None and
            ext["newtab_adsfeed_optout"] is None,
            "Normal build's non-applicable opt-out checks misclassified")
    return {
        "schema_version": 1, "status": "reconciled",
        "source_commit": expected_source, "workflow_run_id": expected_run,
        "package_sha256": archive_sha,
        "package_compressed_bytes": elf["archive_compressed_bytes"],
        "normal_protected_config_flags_checked": flags_count,
        "libxul_link_input_records": response["entry_count"], **counts,
        "real_packaged_js_wayland_webextension_nimbus_reports_crosschecked": True,
        "fully_resolved_native_ffi_or_dlopen": False,
        "arch_hyprland_workstation_tested": False,
        "native_feature_bytes_saved_claimed": None,
        "source_removal_authorized": False,
    }


def mutation_tests(data, source, run):
    """The report must reject every distinct forged cross-document claim."""
    import copy
    cases = [
        ("run", lambda d: d["link"].__setitem__("workflow_run_id", run + 1)),
        ("source", lambda d: d["elf"].__setitem__("source_commit", "0" * 40)),
        ("package-sha", lambda d: d["local"].__setitem__("sha256", "0" * 64)),
        ("sidecar", lambda d: d.__setitem__("sidecar", b"0" * 64)),
        ("elf-edge", lambda d: d["elf"]["direct_edges"][0].__setitem__("needed", "libfaked.so")),
        ("elf-aggregate", lambda d: d["elf"].__setitem__("direct_needed_edges", 267)),
        ("untrusted-host", lambda d: d["elf"].__setitem__("host_dependency_resolution_verified", True)),
        ("libxul-sha", lambda d: d["link"]["package"]["libxul_member"].__setitem__("sha256", "0" * 64)),
        ("packager", lambda d: d["replay"].__setitem__("reproduced_matches_staged", False)),
        ("gtk", lambda d: d["config"]["observed_generated_substs"]["MOZ_WAYLAND"].__setitem__("value", "")),
        ("webextension", lambda d: d["webext"]["webextension"].__setitem__("uninstall", False)),
        ("dom", lambda d: d["webext"]["javascript_navigation"].__setitem__("final_document_text", "wrong")),
        ("nimbus", lambda d: d["webext"]["nimbus"].__setitem__("store_ready", False)),
        ("screenshot", lambda d: d["local"].__setitem__("screenshot_png_complete_and_crc_valid", False)),
        ("overclaim", lambda d: d["link"].__setitem__("source_removal_authorized", True)),
    ]
    for label, corrupt in cases:
        fake = copy.deepcopy(data)
        corrupt(fake)
        try:
            reconcile(fake, source, run)
        except ValueError:
            continue
        raise AssertionError("Forged native evidence was accepted: " + label)
    return len(cases)


def zip_mutation_tests(path):
    """Ensure hostile ZIP members cannot masquerade as bounded CI reports."""
    with ZipFile(path) as z:
        originals = [(x.filename, z.read(x.filename)) for x in z.infolist()]
    def altered(case):
        with tempfile.TemporaryDirectory(prefix="vulpra-artifact-adversarial-") as d:
            out = Path(d) / "fake.zip"
            with ZipFile(out, "w", compression=ZIP_DEFLATED) as z:
                for i, (name, raw) in enumerate(originals):
                    if case == "traversal" and i == 0:
                        name = "../" + name
                    elif case == "duplicate" and i == 1:
                        name = originals[0][0]
                    elif case == "unknown" and i == 0:
                        name = "_temp/unknown-report.json"
                    if case == "symlink" and i == 0:
                        info = ZipInfo(name)
                        info.create_system = 3
                        info.external_attr = (stat.S_IFLNK | 0o777) << 16
                        z.writestr(info, raw)
                    else:
                        with warnings.catch_warnings():
                            warnings.simplefilter("ignore", UserWarning)
                            z.writestr(name, b"0" * (MAX_UNCOMPRESSED_BYTES + 1)
                                       if case == "unbounded" and i == 0 else raw)
            try:
                reports_from_zip(out)
            except (ValueError, UnicodeError):
                return
            raise AssertionError("Accepted untrusted ZIP structure: " + case)
    cases = ("traversal", "duplicate", "unknown", "symlink", "unbounded")
    for case in cases:
        altered(case)
    return len(cases)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("zip", type=Path, help="Downloaded bounded GitHub Actions artifact ZIP")
    p.add_argument("--source-sha", required=True, help="Trusted workflow run head SHA")
    p.add_argument("--run-id", required=True, type=int, help="Trusted GitHub Actions run ID")
    p.add_argument("--expected-zip-sha256", help="Optional externally recorded artifact ZIP digest")
    p.add_argument("--self-test", action="store_true", help="Reject 20 forged metadata and ZIP cases")
    p.add_argument("--output", type=Path, help="Write bounded sanitized reconciliation result")
    args = p.parse_args()
    if args.expected_zip_sha256:
        require(sha(args.expected_zip_sha256) == sha256(args.zip.read_bytes()).hexdigest(),
                "Downloaded evidence ZIP digest mismatch")
    data = reports_from_zip(args.zip)
    result = reconcile(data, args.source_sha, args.run_id)
    if args.self_test:
        n = mutation_tests(data, args.source_sha, args.run_id) + zip_mutation_tests(args.zip)
        print(f"PASS: {n} forged cross-report and ZIP metadata cases rejected")
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    print("No full linker/FFI/dlopen closure, target Arch parity, or source-removal permission")


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, IndexError, UnicodeError, ValueError, AssertionError, TypeError) as exc:
        print("FAIL M3 independent native artifact reconciliation:", exc, file=sys.stderr)
        raise SystemExit(1)
