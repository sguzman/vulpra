#!/usr/bin/env bash
# Verify the isolated M3 Normandy-free resource contract against Git HEAD.
# Uses Git blobs so sparse CI checkouts still audit the complete pinned source.
set -Eeuo pipefail
repo="${1:-$PWD}"
python3 - "$repo" <<'PY'
from pathlib import Path
import subprocess
import sys

repo = Path(sys.argv[1])
def source(path):
    return subprocess.run(
        ["git", "-C", str(repo), "show", "HEAD:" + path],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    ).stdout.decode()

normal = source("ci/mozconfig-linux")
lean = source("ci/mozconfig-linux-normandy-experiment")
assert "VULPRA_EXPERIMENT_NO_NORMANDY" not in normal
assert "obj-vulpra-linux-normandy-experiment" not in normal
assert "export VULPRA_EXPERIMENT_NO_NORMANDY=1" in lean
assert "obj-vulpra-linux-normandy-experiment" in lean
assert "mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-vulpra-linux" in normal
assert "ac_add_options --with-app-basename=Vulpra" in normal
assert "ac_add_options --with-app-basename=Vulpra" in lean

configure = source("browser/moz.configure")
assert 'env="VULPRA_EXPERIMENT_NO_NORMANDY"' in configure
assert 'def vulpra_include_normandy(experimental_disable):' in configure
assert 'return not experimental_disable' in configure
assert 'imply_option("MOZ_NORMANDY", True, when=vulpra_include_normandy)' in configure
assert 'imply_option("MOZ_SERVICES_SYNC", True)' in configure

build = source("toolkit/components/moz.build")
assert 'DIRS += ["messaging-system"]' in build
assert 'DIRS += ["normandy"]' in build
assert 'if CONFIG["MOZ_NORMANDY"]:\n        DIRS += ["normandy"]' not in build

# Mozilla's frontend requires the original jar.mn file to remain declared.
jarbuild = source("toolkit/components/normandy/moz.build")
assert 'JAR_MANIFESTS += ["jar.mn"]' in jarbuild
assert "vulpra-shared.jar.mn" not in jarbuild
jar = source("toolkit/components/normandy/jar.mn")
assert jar.count("#ifdef MOZ_NORMANDY") == 1, "Expected one conditional jar section"
assert jar.count("#else") == 1 and jar.count("#endif") == 1
header, body = jar.split("#ifdef MOZ_NORMANDY", 1)
full, tail = body.split("#else", 1)
shared, footer = tail.split("#endif", 1)
assert "% resource normandy %res/normandy/" in header
for name in ("res/normandy/Normandy.sys.mjs", "res/normandy/content/",
             "res/normandy/actions/", "res/normandy/vendor/"):
    assert name in full, f"Missing standard resource anchor: {name}"
    assert name not in shared, f"Lean variant retains recipe/studies resource: {name}"
for name in ("ClientEnvironment.sys.mjs", "NormandyApi.sys.mjs",
             "NormandyUtils.sys.mjs", "LegacyHeartbeat.schema.json"):
    assert name in shared, f"Missing retained Nimbus dependency: {name}"
assert not footer.strip()

manifest = source("browser/components/BrowserComponents.manifest").splitlines()
init = "category browser-before-ui-startup resource://normandy/Normandy.sys.mjs Normandy.init"
uninit = "category browser-quit-application-granted resource://normandy/Normandy.sys.mjs Normandy.uninit"
for item in (init, uninit):
    assert manifest.count(item) == 1
    index = manifest.index(item)
    assert manifest[index - 1] == "#ifdef MOZ_NORMANDY"
    assert manifest[index + 1] == "#endif"

lean_boot = "category browser-before-ui-startup moz-src:///toolkit/components/nimbus/NimbusBootstrap.sys.mjs NimbusBootstrap.init"
assert manifest.count(lean_boot) == 1
index = manifest.index(lean_boot)
assert "#ifndef MOZ_NORMANDY" in manifest[index - 5:index]
assert "#ifdef XP_LINUX" in manifest[index - 6:index]
assert manifest[index + 1:index + 3] == ["#endif", "#endif"]
nimbus_build = source("toolkit/components/nimbus/moz.build")
assert 'and not CONFIG["MOZ_NORMANDY"]' in nimbus_build
assert 'MOZ_SRC_FILES += ["NimbusBootstrap.sys.mjs"]' in nimbus_build
bootstrap = source("toolkit/components/nimbus/NimbusBootstrap.sys.mjs")
assert 'UI_READY = "sessionstore-windows-restored"' in bootstrap
assert "await ExperimentAPI.init();" in bootstrap
registry = source("browser/components/DesktopActorRegistry.sys.mjs")
assert "if (!AppConstants.MOZ_NORMANDY)" in registry
assert "delete JSWINDOWACTORS.ShieldFrame;" in registry

# Graphical acceptance must observe a real committed buffer, not just
# a process that remains alive while Weston is running.
wayland = source("packaging/test-wayland.sh")
assert "WAYLAND_DEBUG=client" in wayland
assert "'xdg_wm_base'" in wayland
assert 'wl_surface([#@][0-9]+)' in wayland
assert '.attach' in wayland and '.commit' in wayland
assert 'wl_buffer[#@][0-9]+' in wayland
assert 'found_commit.group(1) in attached' in wayland
assert 'attached.add(found_attach.group(1))' in wayland
print("PASS: Wayland frame evidence pairs real buffer attachment with a later commit on the same surface")

# Do not claim matched source/toolchain without matched native resource policy.
native_ci = source(".github/workflows/build-m3-normandy.yml")
paired_ci = source(".github/workflows/compare-m3-normandy-size.yml")
for name, workflow in (("native", native_ci), ("matched", paired_ci)):
    assert 'CARGO_BUILD_JOBS: "1"' in workflow, name
    assert "sudo fallocate -l 24G" in workflow, name
    assert "sudo swapon \"$swap\"" in workflow, name
    assert "SwapTotal:" in workflow, name
assert "github.event.workflow_run.conclusion == 'success'" in paired_ci
assert "git\",\"checkout\",\"--detach\",sha" in paired_ci
print("PASS: native and matched full-Normandy builds use equal constrained Rust/swap environment")

print("PASS: standard Vulpra build default untouched; opt-in isolated object directory")
print("PASS: original jar.mn retains shared Nimbus helper/schema resources only")
print("PASS: Normandy startup/shutdown conditional; lean Nimbus bootstrap guarded")
print("PASS: disabled ShieldFrame actor absent; no source deletion performed")
print("SOURCE TEST ONLY: native runtime and package-size savings remain unverified")
PY
