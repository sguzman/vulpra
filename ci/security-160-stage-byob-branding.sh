#!/usr/bin/env bash
# Derive a NEW Firefox160 BYOB source-overlay variant from the preserved
# 28-file verified candidate. Never modify or re-label the original build.
set -euo pipefail
umask 077
fail() { printf 'FAIL: Firefox160 BYOB overlay: %s\n' "$1" >&2; exit 1; }

if [[ $# -ne 4 || "$1" != --derive ]]; then
  echo 'Usage: security-160-stage-byob-branding.sh --derive <original-28-stage> <pinned-main-branding-file> <empty-destination>' >&2
  exit 2
fi
script_root="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
source_stage="$(realpath -e -- "$2")" || fail 'missing original source stage'
brand_file="$(realpath -e -- "$3")" || fail 'missing pinned BYOB branding source'
destination="$(realpath -m -- "$4")" || fail 'cannot canonicalize output'
brand_path='browser/branding/unofficial/pref/firefox-branding.js'
old_brand_git_blob='9308a1b26f339e0e89d959f0c4559eb7596a0fe6'
new_brand_git_blob='ae3fd50a6aee0ad58933dca09db39b7b87c0eb5e'
[[ -f "$source_stage/$brand_path" && ! -L "$source_stage/$brand_path" ]] ||
  fail 'original staged branding is missing or symlinked'
[[ -f "$brand_file" && ! -L "$3" ]] || fail 'new branding source is not a regular file'
[[ "$source_stage" != "$script_root" && "$source_stage" != "$destination" ]] ||
  fail 'stage/output overlap'
for root in "$source_stage" "$script_root"; do
  [[ "$destination" != "$root" && "$destination/" != "$root/"* ]] ||
    fail 'destination overlaps original source or Git checkout'
done
[[ ! -e "$destination" && ! -L "$destination" ]] || fail 'destination already exists'
[[ -z "$(find "$source_stage" -type l -print -quit)" ]] ||
  fail 'unverified source-stage symlink'
[[ "$(find "$source_stage" -type f | wc -l)" == 28 ]] ||
  fail 'expected exactly 28 original verified overlay files'

[[ "$(git hash-object -- "$source_stage/$brand_path")" == "$old_brand_git_blob" ]] ||
  fail 'original Firefox160 branding does not match preserved source contract'
[[ "$(git hash-object -- "$brand_file")" == "$new_brand_git_blob" ]] ||
  fail 'new BYOB branding source is not the pinned tested main source'
# Independent source-level checks, not native Firefox runtime evidence.
for key in identity.fxaccounts.enabled signon.rememberSignons \
           signon.autofillForms signon.generation.enabled; do
  [[ "$(grep -Fxc "pref(\"$key\", false);" "$brand_file" || true)" == 1 ]] ||
    fail 'missing or duplicate BYOB false default'
done
! grep -Eq '^[[:space:]]*(lockPref|user_pref)\(' "$brand_file" ||
  fail 'BYOB policy must not lock or write profile preferences'
! grep -Eq '^pref\("(security\.|browser\.safebrowsing\.)' "$brand_file" ||
  fail 'BYOB branding must not weaken security service defaults'
# The preserved 28-file source manifest must remain identical except for
# one reviewed brand-file replacement. Source-stage provenance itself is
# proved by the caller's original exact-source pinned staging operation.
mkdir -m 700 -- "$destination"
cp -a -- "$source_stage/." "$destination/"
cp -- "$brand_file" "$destination/$brand_path"
[[ "$(git hash-object -- "$destination/$brand_path")" == "$new_brand_git_blob" ]] ||
  fail 'BYOB branding postimage drift'
[[ -z "$(find "$destination" -type l -print -quit)" ]] ||
  fail 'unexpected symlink in derived stage'
[[ "$(find "$destination" -type f | wc -l)" == 28 ]] ||
  fail 'changed staged file count'
original_list="$(mktemp)"
derived_list="$(mktemp)"
trap 'rm -f -- "$original_list" "$derived_list"' EXIT
(cd "$source_stage" && find . -type f -printf '%P\n' | LC_ALL=C sort) > "$original_list"
(cd "$destination" && find . -type f -printf '%P\n' | LC_ALL=C sort) > "$derived_list"
cmp -s "$original_list" "$derived_list" || fail 'BYOB overlay added/deleted paths'
changed=0
while IFS= read -r path; do
  old="$(git hash-object -- "$source_stage/$path")" || fail 'source hashing error'
  new="$(git hash-object -- "$destination/$path")" || fail 'new hashing error'
  if [[ "$old" != "$new" ]]; then
    [[ "$path" == "$brand_path" ]] || fail 'BYOB patch modified an unrelated source file'
    ((changed+=1))
  fi
done < "$original_list"
[[ "$changed" == 1 ]] || fail 'BYOB variant did not modify precisely one branding file'
echo 'PASS: BYOB variant retained 28 source paths; exactly one pinned branding file differs'
echo 'LIMIT: source-only variant; original Firefox160 build untouched, native compile and effective runtime prefs not tested'
