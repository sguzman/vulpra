#!/usr/bin/env bash
# Bounded source-identity audit of six Firefox 160 files in the previously
# verified 28-overlay candidate. This is not exploit or release acceptance.
set -euo pipefail

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if test "$#" -ne 5 || test "$1" != "--check"; then
  echo 'Usage: security-160-verify-retained-fixes.sh --check <official-160-checkout> <main-spotcheck-manifest.json> <full-tree-ledger-dir> <output.json>' >&2
  exit 2
fi

upstream="$(cd -- "$2" && pwd -P)" || fail 'upstream checkout missing'
manifest="$3"
ledger="$(cd -- "$4" && pwd -P)" || fail 'source candidate ledger missing'
output="$5"
release=2887d9de1f69c0e9776413da80e7ba0d1225dd9b

test "$(git -C "$upstream" rev-parse HEAD)" = "$release" ||
  fail 'source checkout is not the pinned official Firefox 160 release'
test -f "$manifest" && test -f "$ledger/candidate-tree-report.json" &&
  test -f "$ledger/overlay-paths.txt" &&
  test -f "$ledger/changes-against-exact-firefox160.tsv" ||
  fail 'missing immutable source provenance input'
test ! -e "$output" || fail 'audit output must not already exist'

jq -e --arg release "$release" '
  .schema_version == 1 and
  .kind == "vulpra_firefox_160_security_patch_presence_bounded_spotcheck" and
  .upstream_release_sha == $release and
  .advisory == "MFSA 2026-125" and
  (.patch_files | type == "array" and length == 6) and
  ([.patch_files[].path] | unique | length == 6) and
  ([.patch_files[].cve] | unique | sort) ==
    ["CVE-2026-124853","CVE-2026-124854","CVE-2026-124856","CVE-2026-124902"] and
  all(.patch_files[];
    (.path | type == "string") and
    (.firefox_160_release_git_blob | test("^[0-9a-f]{40}$"))) and
  .scope.cves_checked == 4 and .scope.paths_checked == 6 and
  .scope.all_mfsa2026_125_audited == false and
  .scope.security_current == false and .scope.release_ready == false
' "$manifest" >/dev/null || fail 'main branch security manifest is out of scope or changed'

jq -e --arg release "$release" '
  .schema_version == 1 and
  .firefox160_commit == $release and
  (.assembled_git_tree | test("^[0-9a-f]{40}$")) and
  .source_files_modified == 26 and
  .vulpra_source_files_added == 2 and
  .upstream_files_deleted == 0 and
  .all_other_upstream_files_preserved == true and
  .native_binary_compiled == false and
  .security_current == false
' "$ledger/candidate-tree-report.json" >/dev/null ||
  fail 'verified full-tree candidate ledger is invalid'

list="$ledger/overlay-paths.txt"
changes="$ledger/changes-against-exact-firefox160.tsv"
test "$(wc -l < "$list")" -eq 28 || fail 'overlay list must have exactly 28 paths'
test "$(LC_ALL=C sort -u "$list" | wc -l)" -eq 28 ||
  fail 'overlay list contains duplicate paths'
test "$(awk -F '\t' '$1=="M" {m++} $1=="A" {a++} $1!="A" && $1!="M" {bad++} END {if(m==26&&a==2&&bad==0) print "PASS"; else print "FAIL"}' "$changes")" = PASS ||
  fail 'candidate change-status ledger must be exactly 26 M and 2 A'
cut -f2 "$changes" | LC_ALL=C sort > "$ledger/.candidate-verified-changed-paths.tmp"
trap 'rm -f -- "$ledger/.candidate-verified-changed-paths.tmp"' EXIT
cmp -s "$list" "$ledger/.candidate-verified-changed-paths.tmp" ||
  fail 'overlay path list disagrees with candidate diff'
# The archived ledger is read-only input. Each listed path must be safe and
# must belong to the bounded source overlay, not an upstream security file.
while IFS= read -r path; do
  test -n "$path" || fail 'blank changed path'
  case "$path" in
    /*|../*|*/../*|*/..|./*|*/./*|*/.) fail "unsafe candidate path: $path" ;;
  esac
done < "$list"

checked=0
while IFS=$'\t' read -r path expected; do
  test -n "$path" && test -n "$expected" || fail 'blank security-source record'
  if grep -Fxq -- "$path" "$list"; then
    fail "Vulpra candidate overwrote a security-reviewed Firefox 160 path: $path"
  fi
  file="$upstream/$path"
  test -f "$file" && test ! -L "$file" ||
    fail "missing or symlinked official source: $path"
  actual="$(git -C "$upstream" hash-object -- "$file")" ||
    fail "cannot hash: $path"
  test "$actual" = "$expected" ||
    fail "official Firefox 160 source content differs from audited blob: $path"
  tree_blob="$(git -C "$upstream" ls-tree HEAD -- "$path" | awk '$2=="blob" {print $3}')"
  test "$tree_blob" = "$expected" ||
    fail "authenticated Firefox 160 Git tree differs from audited blob: $path"
  checked=$((checked+1))
done < <(jq -r '.patch_files[] | [.path,.firefox_160_release_git_blob] | @tsv' "$manifest")
test "$checked" -eq 6 || fail 'must independently verify six source files'
candidate_tree="$(jq -r .assembled_git_tree "$ledger/candidate-tree-report.json")"
jq -n --arg release "$release" --arg candidate "$candidate_tree" '{
  schema_version:1,
  kind:"bounded_firefox160_vulpra_security_source_retention",
  firefox160_release_commit:$release,
  independently_assembled_candidate_tree:$candidate,
  exact_upstream_release_blobs_retained:6,
  selected_cves_checked:4,
  source_overlays_checked:28,
  selected_security_paths_overwritten:0,
  native_binary_compiled_in_this_audit:false,
  full_advisory_audited:false,
  security_current:false,
  release_ready:false
}' > "$output"
echo 'PASS: 6/6 selected Firefox 160 security source blobs inherited unchanged by the verified 28-file candidate'
echo 'LIMIT: only four selected CVEs; no native binary, exploit, full advisory, or security-release acceptance'
