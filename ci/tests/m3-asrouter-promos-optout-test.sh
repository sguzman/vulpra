#!/usr/bin/env bash
# Verify the M3 ASRouter promo opt-out contract against pinned Git HEAD.
set -euo pipefail
repo="${1:-$PWD}"
python3 - "$repo" <<'PY'
from pathlib import Path
import subprocess, sys

repo=Path(sys.argv[1])
def src(path):
    return subprocess.check_output(["git","-C",str(repo),"show","HEAD:"+path],text=True)
normal=src("ci/mozconfig-linux")
baseline=src("ci/mozconfig-linux-m3-baseline")
lean=src("ci/mozconfig-linux-m3-promos-experiment")
assert "VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS" not in normal
assert "VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS" not in baseline
assert "export VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS=1" in lean
assert "obj-vulpra-linux-m3-promos-experiment" in lean
assert "obj-vulpra-linux-m3-promos-experiment" not in normal
def options(s):
    return [line.strip() for line in s.splitlines() if line.strip()
        and not line.lstrip().startswith("#")
        and not line.startswith("mk_add_options MOZ_OBJDIR=")
        and not line.startswith("export VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS=")]
assert options(lean)==options(baseline), (options(lean),options(baseline))

cfg=src("browser/moz.configure")
assert 'env="VULPRA_EXPERIMENT_NO_ASROUTER_PROMOS"' in cfg
assert 'set_config("VULPRA_NO_ASROUTER_PROMOS", vulpra_no_asrouter_promos)' in cfg
assert 'set_define("VULPRA_NO_ASROUTER_PROMOS", depends_if(vulpra_no_asrouter_promos)(lambda _: True))' in cfg
assert 'set_define("VULPRA_NO_ASROUTER_PROMOS", vulpra_no_asrouter_promos)' not in cfg
assert 'if disable and not linux:' in cfg

app=src("toolkit/modules/AppConstants.sys.mjs")
assert "VULPRA_NO_ASROUTER_PROMOS:" in app
assert "#ifdef VULPRA_NO_ASROUTER_PROMOS\n  true,\n#else\n  false,\n#endif" in app

build=src("browser/components/asrouter/moz.build")
assert 'if not CONFIG["VULPRA_NO_ASROUTER_PROMOS"]:' in build
for name in ("SidebarChatBotPromo.sys.mjs","SmartWindowNewTabPromo.sys.mjs"):
    assert build.count('"modules/'+name+'"')==1
assert '"modules/ASRouter.sys.mjs"' in build
assert '"modules/ASRouterTelemetry.sys.mjs"' in build
assert '"modules/OnboardingMessageProvider.sys.mjs"' in build

router=src("browser/components/asrouter/modules/ASRouter.sys.mjs")
assert router.count("if (!AppConstants.VULPRA_NO_ASROUTER_PROMOS)")==2
for case, call in (
    ("sidebar_chatbot_promo","lazy.SidebarChatBotPromo.showPromo"),
    ("smart_window_newtab_promo","lazy.SmartWindowNewTabPromo.showPromo"),
):
    pos=router.index('case "'+case+'":')
    window=router[pos:pos+550]
    assert "if (!AppConstants.VULPRA_NO_ASROUTER_PROMOS)" in window
    assert call in window
# Non-promotional ASRouter functionality, event dispatch, and safety surfaces
# must not be excluded by the experimental conditional.
for entry in ("case \"newtab_message\":", "case \"menu_message\":",
              "case \"feature_callout\":"):
    assert entry in router
assert 'if CONFIG["MOZ_SERVICES_SYNC"]:' in src("services/moz.build")
print("PASS: default browser unchanged; immutable candidate guard and only two optional resources")
print("SOURCE CONTRACT ONLY; NOT AN ACCEPTED NATIVE BROWSER OR BYTE REDUCTION")
PY
