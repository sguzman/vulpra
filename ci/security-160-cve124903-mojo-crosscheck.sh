#!/usr/bin/env bash
# Source-only CVE-2026-124903 Mozilla Bug 2084673 audit.
# No claim of security-current, complete fix, exploit denial or release.
set -euo pipefail
fail() { echo "FAIL: $*" >&2; exit 1; }
if test "$#" -eq 1 && test "$1" = --self-test; then
  echo 'PASS: non-building 13-file Mojo IPC textual audit harness'; exit 0
fi
if test "$#" -ne 4 || test "$1" != --verify; then
  fail 'Usage: SCRIPT --self-test | --verify LEDGER SOURCE_IDENTITY OUT'
fi
ledger="$2"; identity="$3"; output="$4"
test -n "$GH_TOKEN" || fail 'Missing read-only API token'
test ! -e "$output" || fail 'Refusing report overwrite'
for f in "$ledger/candidate-tree-report.json" "$ledger/overlay-paths.txt" "$ledger/changes-against-exact-firefox160.tsv" "$identity"; do
  test -s "$f" && test ! -L "$f" || fail "Missing exact source proof: $f"
done
jq -e '
  .firefox160_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .assembled_git_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .source_files_modified==26 and .vulpra_source_files_added==2 and
  .all_other_upstream_files_preserved==true and .security_current==false
' "$ledger/candidate-tree-report.json" >/dev/null || fail 'Source ledger mismatch'
jq -e '
  .upstream_release_commit=="2887d9de1f69c0e9776413da80e7ba0d1225dd9b" and
  .complete_materialized_source_tree=="42dd7439a27dde92f89ac5eed13f88117a4d7ab5" and
  .verified_overlays==28 and .exact_assembly_tree_match==true and
  .upstream_paths_otherwise_preserved==true
' "$identity" >/dev/null || fail 'Materialized source identity mismatch'
test "$(wc -l < "$ledger/overlay-paths.txt")" -eq 28 ||
  fail 'Expected 28 source overlays'
test "$(cut -f2 "$ledger/changes-against-exact-firefox160.tsv" | sort | sha256sum | cut -d' ' -f1)" = \
  "$(sort "$ledger/overlay-paths.txt" | sha256sum | cut -d' ' -f1)" ||
  fail 'Candidate changed-path records disagree'
commit=f1c9c8b97e0e162b7b78d6c9d2b1aa38c29e3443
release=2887d9de1f69c0e9776413da80e7ba0d1225dd9b
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
gh api "repos/mozilla-firefox/firefox/commits/$commit" > "$work/commit.json" ||
  fail 'Public Mozilla fix unavailable'
jq -e '.commit.message|startswith("Bug 2084673 - Simplify mojo dead proxy handling")' "$work/commit.json" >/dev/null ||
  fail 'Incorrect Mozilla public fix'
jq -r '.files[].filename' "$work/commit.json" | LC_ALL=C sort > "$work/actual"
cat > "$work/expected" <<'PATHS'
ipc/chromium/gtest/ports_unittest.cc
ipc/chromium/src/mojo/core/ports/event.cc
ipc/chromium/src/mojo/core/ports/event.h
ipc/chromium/src/mojo/core/ports/node.cc
ipc/chromium/src/mojo/core/ports/node.h
ipc/chromium/src/mojo/core/ports/node_delegate.h
ipc/glue/NodeChannel.cpp
ipc/glue/NodeChannel.h
ipc/glue/NodeController.cpp
ipc/glue/NodeController.h
ipc/glue/ProtocolUtils.h
ipc/ipdl/ipdl.py
tools/fuzzing/ipc/IPCFuzzController.cpp
PATHS
cmp -s "$work/expected" "$work/actual" ||
  fail 'Wrong public landing changed-path set'
: > "$work/rows.jsonl"
exact=0; diverged=0; retained=0; missing_total=0
while IFS= read -r path; do
  if grep -Fxq -- "$path" "$ledger/overlay-paths.txt"; then
    fail "Vulpra overwrote Mozilla fix path: $path"
  fi
  jq -er --arg p "$path" '.files[]|select(.filename==$p)|.patch' \
    "$work/commit.json" > "$work/patch" || fail "Missing patch for $path"
  test "$(wc -c < "$work/patch")" -gt 40 || fail "Incomplete source diff for $path"
  awk '/^\+[^+]/ {
    s=substr($0,2)
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    if (length(s)>10 && s !~ /^\/\//) print s
  }' "$work/patch" | LC_ALL=C sort -u > "$work/additions"
  curl -fLsS --retry 3 --max-time 90 \
    "https://raw.githubusercontent.com/mozilla-firefox/firefox/$release/$path" \
    -o "$work/release" || fail "Missing official Firefox 160 path: $path"
  release_blob="$(git hash-object -- "$work/release")"
  api_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$release" --jq '.sha')" ||
    fail "Missing release object for $path"
  landed_sha="$(gh api "repos/mozilla-firefox/firefox/contents/$path?ref=$commit" --jq '.sha')" ||
    fail "Missing landed object for $path"
  test "$api_sha" = "$release_blob" || fail "Official source SHA mismatch for $path"
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$work/release" |
    LC_ALL=C sort -u > "$work/release-lines"
  LC_ALL=C comm -23 "$work/additions" "$work/release-lines" > "$work/missing"
  missing="$(wc -l < "$work/missing")"
  present="$(wc -l < "$work/additions")"
  present=$((present-missing))
  retained=$((retained+present))
  missing_total=$((missing_total+missing))
  case "$path" in
    ipc/glue/NodeChannel.cpp)
      test "$missing" -eq 2 || fail 'Unexpected DeadProxy source additions missing'
      grep -Fq 'MakeUnique<IPC::Message>(MSG_ROUTING_CONTROL, DEAD_PROXY_MESSAGE_TYPE)' \
        "$work/release" || fail 'Replacement DeadProxy constructor missing' ;;
    ipc/glue/NodeController.cpp)
      test "$missing" -eq 1 || fail 'Unexpected broker event source additions missing'
      grep -Fq 'MakeUnique<IPC::Message>(MSG_ROUTING_CONTROL, EVENT_MESSAGE_TYPE)' \
        "$work/release" || fail 'Replacement event constructor missing'
      ! grep -Eq 'NodeController::(BroadcastEvent|OnBroadcast)\(' "$work/release" ||
        fail 'Obsolete generic NodeController broadcast API remains'
      grep -Fq 'NodeController::OnDeadProxy(' "$work/release" ||
        fail 'New DeadProxy handler not present'
      grep -Fq 'NodeController::BroadcastDeadProxyInternal(' "$work/release" ||
        fail 'New broker DeadProxy routing not present' ;;
    ipc/chromium/src/mojo/core/ports/event.cc|ipc/chromium/src/mojo/core/ports/event.h)
      test ! -s "$work/additions" || fail 'Expected deletion-only event source patch'
      ! grep -Fq 'CloneForBroadcast' "$work/release" ||
        fail 'Removed event broadcast clone still exists' ;;
    *) test "$missing" -eq 0 || fail "Missing landed code line in $path" ;;
  esac
  if test "$landed_sha" = "$release_blob"; then
    match=exact; exact=$((exact+1))
  else
    match=diverged; diverged=$((diverged+1))
  fi
  jq -cn --arg path "$path" --arg landed "$landed_sha" \
    --arg official "$release_blob" --arg match "$match" \
    --argjson present "$present" --argjson missing "$missing" '{
      path:$path,landed_blob:$landed,firefox160_blob:$official,
      source_blob_comparison:$match,added_lines_present_verbatim:$present,
      added_lines_not_verbatim:$missing,
      semantic_equivalence_of_all_patch_hunks_verified:false,
      overwritten_by_vulpra:false
    }' >> "$work/rows.jsonl"
  printf 'AUDIT: %s — %s; %d significant added lines present, %d not verbatim\n' \
    "$path" "$match" "$present" "$missing"
done < "$work/expected"
test "$exact" -eq 7 && test "$diverged" -eq 6 &&
test "$missing_total" -eq 3 || fail 'Unexpected fix source comparison counts'
jq -n --slurpfile rows "$work/rows.jsonl" --argjson retained "$retained" '{
  schema_version:1,
  kind:"firefox160_cve124903_mojo_source_additions_and_obsolete_apis",
  cve:"CVE-2026-124903",mozilla_bug:2084673,
  landed_commit:"f1c9c8b97e0e162b7b78d6c9d2b1aa38c29e3443",
  official_release_commit:"2887d9de1f69c0e9776413da80e7ba0d1225dd9b",
  candidate_git_tree:"42dd7439a27dde92f89ac5eed13f88117a4d7ab5",
  file_count:($rows|length),exact_file_blobs:7,diverged_file_blobs:6,
  significant_added_lines_present_verbatim:$retained,
  nonverbatim_added_lines_with_known_constructor_reformat:3,
  generic_event_clone_api_removed_in_both_event_files:true,
  generic_controller_broadcast_apis_removed:true,
  new_broker_dead_proxy_handlers_observed:true,
  overlay_collisions:0,files:$rows,
  code_line_presence_is_not_full_semantic_hunk_verification:true,
  all_security_fix_hunks_verified:false,
  runtime_exploit_denial_verified:false,
  complete_cve_fix_verified:false,
  security_current:false,release_ready:false
}' > "$output"
jq -e '
 .file_count==13 and .exact_file_blobs==7 and .diverged_file_blobs==6 and
 .nonverbatim_added_lines_with_known_constructor_reformat==3 and
 .significant_added_lines_present_verbatim>=60 and
 .generic_event_clone_api_removed_in_both_event_files==true and
 .generic_controller_broadcast_apis_removed==true and
 .new_broker_dead_proxy_handlers_observed==true and
 .overlay_collisions==0 and
 .complete_cve_fix_verified==false and
 .security_current==false and .release_ready==false
' "$output" >/dev/null || fail 'Report integrity failed'
echo "PASS: Bug 2084673 all 13 source files; 7 exact, 6 divergent; $retained selected added code lines present; 3 line-format differences; old broadcast APIs removed"
echo 'LIMIT: source text and named obsolete API checks, not complete CVE exploit/security certification'
