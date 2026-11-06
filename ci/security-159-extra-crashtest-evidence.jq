# Independent source/package/runtime evidence crosscheck for three original
# Mozilla 159 regression HTML fixtures. The native browser build/driver belongs
# to an isolated security branch; the verifier lives on protected main.
# Inputs: --slurpfile replay <JSON> --slurpfile native <JSON>
#         --arg source <trusted SHA> --argjson run <trusted Actions run ID>
def sha40: type == "string" and test("^[0-9a-f]{40}$");
def sha64: type == "string" and test("^[0-9a-f]{64}$");
def valid_case:
  (.iterations | type == "array" and length == 2) and
  ([.iterations[].iteration] == [0,1]) and
  all(.iterations[]; (.height | type == "number" and . > 0 and . == floor)) and
  (if .name == "svg" then
    .fixture == "layout/svg/crashtests/2079252.html" and
    .git_blob_sha1 == "a8d78aae061029dcc7cb72e86a18647b2d483625"
  elif .name == "table" then
    .fixture == "testing/web-platform/tests/css/css-tables/crashtests/border-collapse-dynamic-crash.html" and
    .git_blob_sha1 == "6d716acb679c1f174e75a4d3d6ddfc85dcba7852"
  elif .name == "multicol" then
    .fixture == "testing/web-platform/tests/css/css-multicol/crashtests/block-break-before.html" and
    .git_blob_sha1 == "bfb5f0894b80bf39633afcf37be9fdcbb68ab96c"
  else false end);
if (($replay | length) != 1 or ($native | length) != 1) then
  error("expected one extra-crashtest replay and one native-build report")
else
  $replay[0] as $r | $native[0] as $n |
  if (
    ($source | sha40) and
    ($run | type == "number" and . > 0 and floor == .) and
    $n.source_commit == $source and
    $n.workflow_run_id == $run and
    $n.runtime_passed_after_link_audit == true and
    ($n.package.package_sha256 | sha64) and
    $r.schema_version == 1 and
    $r.status == "passed_bounded_original_extra_crashtests" and
    $r.source_commit == $source and
    $r.real_packaged_browser == true and
    $r.accept_insecure_certs == false and
    $r.temporary_profile_preserved == true and
    $r.original_mozilla_fixture_hashes_verified == true and
    $r.official_wpt_harness_used == false and
    $r.memory_safety_exploit_rejection_proven == false and
    $r.security_current == false and
    $r.release_ready == false and
    ($r.cases | type == "array" and length == 3) and
    ([$r.cases[].name] | sort) == ["multicol","svg","table"] and
    all($r.cases[]; valid_case)
  ) then {
    schema_version: 1,
    status: "bounded_extra_crashtests_source_linked_reconciliation",
    source_commit: $source,
    native_run_id: $run,
    compiled_package_sha256: $n.package.package_sha256,
    original_mozilla_fixture_blobs: [ $r.cases[] |
      {name, fixture, git_blob_sha1} ],
    real_packaged_fixture_replays: 6,
    full_wpt_harness_executed: false,
    exploit_rejection_proven: false,
    full_advisory_audited: false,
    release_ready: false,
    m3_sixth_gate_closed: false
  } else error("extra crashtest provenance, fixture hashes or browser results rejected")
  end
end
