# Fail-closed CSS crashtest source/package/browser runtime evidence verifier.
# Inputs: --slurpfile replay <JSON> --slurpfile native <JSON>
#         --arg source <40-character SHA> --argjson run <native run ID>
def sha40: type == "string" and test("^[0-9a-f]{40}$");
def sha64: type == "string" and test("^[0-9a-f]{64}$");
if (($replay | length) != 1 or ($native | length) != 1) then
  error("expected one CSS replay and one native source-linked build report")
else
  $replay[0] as $r | $native[0] as $n |
  if (
    ($source | sha40) and
    ($run | type == "number" and . > 0 and floor == .) and
    $n.source_commit == $source and $n.workflow_run_id == $run and
    $n.runtime_passed_after_link_audit == true and
    ($n.package.package_sha256 | sha64) and
    $r.schema_version == 1 and
    $r.status == "passed_bounded_original_crashtest_replay" and
    $r.source_commit == $source and
    $r.fixture_git_blob_sha1 == "31a14963b356d869475bac62ca44991d9275a285" and
    $r.fixture == "testing/web-platform/tests/css/css-position/crashtests/inline-containing-block-delete-continuations-001.html" and
    $r.real_packaged_browser == true and
    $r.accept_insecure_certs == false and
    $r.temporary_profile_preserved == true and
    $r.official_wpt_harness_used == false and
    $r.memory_safety_exploit_rejection_proven == false and
    $r.security_current == false and $r.release_ready == false and
    ($r.iterations | type == "array" and length == 3) and
    ([$r.iterations[].iteration] == [0,1,2]) and
    all($r.iterations[];
        (.height | type == "number" and . > 0 and . == floor))
  ) then {
    schema_version: 1,
    status: "bounded_css_regression_source_linked_reconciliation",
    source_commit: $source,
    native_run_id: $run,
    compiled_package_sha256: $n.package.package_sha256,
    upstream_fixture_blob_sha1: $r.fixture_git_blob_sha1,
    three_real_packaged_replays_verified: true,
    full_wpt_harness_executed: false,
    exploit_rejection_proven: false,
    full_advisory_audited: false,
    release_ready: false,
    m3_sixth_gate_closed: false
  } else error("original CSS crashtest source, native package or browser result rejected")
  end
end
