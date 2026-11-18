#!/usr/bin/env bash
# Source-only Vulpra BYOB default-contract test; no browser/profile changes.
set -euo pipefail
LC_ALL=C
source_file="${1:-browser/branding/unofficial/pref/firefox-branding.js}"
[[ -f "$source_file" ]] || { echo 'FAIL: Vulpra branding preference source missing' >&2; exit 1; }

check_defaults() {
  local f="$1" name want count
  for name in identity.fxaccounts.enabled signon.rememberSignons \
              signon.autofillForms signon.generation.enabled; do
    count="$(grep -F -c "\"${name}\"" "$f" || true)"
    [[ "$count" == 1 ]] || return 1
    want="pref(\"${name}\", false);"
    grep -Fxq "$want" "$f" || return 1
  done
  # Normal default preference assignment only. No locked values or profile
  # edits. Keep the browser's extension APIs and protection machinery intact.
  ! grep -Eq '^[[:space:]]*(lockPref|user_pref)\(' "$f" || return 1
  ! grep -Eq '^pref\("browser\.safebrowsing\.|^pref\("extensions\.enabled"|^pref\("security\.' "$f" || return 1
}

check_defaults "$source_file" || {
  echo 'FAIL: Vulpra BYOB defaults are absent, duplicated, locked, or weakened' >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
positive="$work/prefs.js"
negative="$work/negative.js"
cp "$source_file" "$positive"
check_defaults "$positive"

# Deliberately corrupted source files must all be rejected.
count=0
reject() {
  if check_defaults "$negative"; then
    echo 'FAIL: corrupted BYOB defaults incorrectly passed' >&2
    exit 1
  fi
  count=$((count+1))
}
for name in identity.fxaccounts.enabled signon.rememberSignons \
            signon.autofillForms signon.generation.enabled; do
  sed "s/pref(\"${name}\", false);/pref(\"${name}\", true);/" "$positive" > "$negative"
  reject
  sed "/pref(\"${name}\", false);/d" "$positive" > "$negative"
  reject
done
cp "$positive" "$negative"
printf '%s\n' 'lockPref("identity.fxaccounts.enabled", false);' >> "$negative"
reject
cp "$positive" "$negative"
printf '%s\n' 'pref("signon.rememberSignons", false);' >> "$negative"
reject
cp "$positive" "$negative"
printf '%s\n' 'pref("browser.safebrowsing.phishing.enabled", false);' >> "$negative"
reject
[[ "$count" == 11 ]] || { echo 'FAIL: incomplete negative BYOB fixtures' >&2; exit 1; }

echo 'PASS: four BYOB default-only preferences and eleven unsafe regression fixtures rejected'
echo 'LIMIT: source check only; real effective default prefs in next packaged Vulpra require runtime verification.'
