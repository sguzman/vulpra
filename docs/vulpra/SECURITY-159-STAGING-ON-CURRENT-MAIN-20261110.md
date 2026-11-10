# Staged Firefox 159 security hotfixes on current Vulpra main — 2026-11-10

This **separate source-integration candidate** starts from the verified current `main` commit `2006922502b6d27a7d89e56662530726441d8b45`, which is the source of the owner's successful EndeavourOS/Hyprland Vulpra rebuild. It is **not yet merged into main**, compiled from this new branch, installed or run on the owner's PC.

## Source provenance and scope

The previously isolated `security/firefox-159-postbeta-hotfixes` branch held **exact upstream fix-result Git blobs** for two upstream Firefox security defects:

- **CVE-2026-117860**, same-origin policy, Mozilla fix `9a2dc53c369c7ae5172018b35988e1d2ffeff402`, 14 code files.
- **CVE-2026-120572**, layout boundary conditions, Mozilla fix `603a78af8401f8f30c388b3fa330589e35d8b727`, three code files and the original upstream CSS crashtest.

Before staging the patches, all **17 current-main source preimage Git blob IDs were independently inspected** and matched the exact upstream patch-parent preimage IDs in `SECURITY-159-HOTFIX-PORT.json`. All 17 original isolated-branch patched source Git blob IDs matched their exact expected upstream fix-result postimages. The added upstream CSS regression fixture matched its expected Git blob and did not exist on main. All replacements are referenced as **existing Git blobs**, not reconstructed from text or a wholesale merge of the older maintenance branch.

The offline integrity gate `ci/security-159-postbeta-port-check.sh` verifies every resulting Git blob against the immutable manifest. The original `ci/security-159-crashtest-smoke.py --self-test` validates four original Mozilla fixture hashes and rejects 26 forged DOM/runtime outcomes, **without executing a real browser**. Source and runtime evidence must remain distinct.

## Important acceptance boundaries

- The older `security/firefox-159-postbeta-hotfixes` branch's [full native CI build and runtime replay **42224511431 PASS**](https://github.com/sguzman/vulpra/actions/runs/42224511431) and independent [security reconciliation **42231630654 PASS**](https://github.com/sguzman/vulpra/actions/runs/42231630654) are relevant **prior evidence for the old branch only**, not a test of this current-main integration candidate.
- This current-main patch needs its own full native compilation, source/package identity checks and targeted runtime tests **before merging or claiming operational acceptance**. Preserve Wayland, profile isolation, extensions, Nimbus, strict TLS verification and all protected features.
- Mozilla's [Firefox 160 security advisory (MFSA 2026-125, 2026-11-10)](https://www.mozilla.org/en-US/security/advisories/mfsa2026-125/) now exists. Even a verified two-fix 159 source port is **not security-current** and is **not** a substitute for a comprehensive updated source baseline.
- Owner's existing 159.0b5-derived QA binary/profile, the original M3 comparator build, and the immutable `upstream-base` branch remain untouched.
- No release, security-current, M3 completion, or percent increase is claimed. **Overall 61% (Δ+0 pp), M3 5/6 = 83%.**

Next: Validate this staged integration's exact-source CI; determine the safest complete upstream security-update route (including Firefox 160), then require a separate full native build and targeted runtime acceptance for any candidate promoted toward normal use.
