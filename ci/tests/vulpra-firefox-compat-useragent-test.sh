#!/usr/bin/env bash
# Static Vulpra user-agent source contract; no executable/browser/network tests.
set -euo pipefail
root="$(cd -- "$(dirname -- "$0")/../.." && pwd -P)"
profile="$root/browser/app/profile/firefox.js"
defaults="$root/modules/libpref/init/all.js"
handler="$root/netwerk/protocol/http/nsHttpHandler.cpp"
branding="$root/browser/branding/unofficial/configure.sh"
fail() { printf 'FAIL: %s\n' "$1" >&2; return 1; }

check_contract() {
  local p="$1" d="$2" h="$3" b="$4" count assemble
  for f in "$p" "$d" "$h" "$b"; do
    [[ -s "$f" ]] || { fail "missing source: $f"; return 1; }
  done
  count="$(grep -Fxc 'pref("general.useragent.compatMode.firefox", true);' "$p" || true)"
  [[ "$count" == 1 ]] || { fail "exactly one browser-only Firefox-compatible UA default required"; return 1; }
  count="$(grep -Fc 'general.useragent.compatMode.firefox' "$p" || true)"
  [[ "$count" == 1 ]] || { fail "duplicate Firefox-compatible UA pref"; return 1; }
  grep -Fqx 'pref("general.useragent.compatMode.firefox", false);' "$d" ||
    { fail "generic Gecko default altered"; return 1; }
  if grep -Eq '^[[:space:]]*(pref|sticky_pref|user_pref)[[:space:]]*\("general\.useragent\.override"' "$p"; then
    fail "hardcoded full UA override prohibited"
    return 1
  fi
  assemble="$(sed -n '/^void nsHttpHandler::BuildUserAgent() {/,/^}/p' "$h")"
  [[ -n "$assemble" ]] || { fail "UA assembler missing"; return 1; }
  for token in 'bool isFirefox = mAppName.EqualsLiteral("Firefox");' \
               'if (isFirefox || mCompatFirefoxEnabled)' \
               'mUserAgent += mCompatFirefox;' \
               'if (!isFirefox)' \
               'mUserAgent += mAppName;'; do
    grep -Fq "$token" <<< "$assemble" || { fail "UA assembler lost token: $token"; return 1; }
  done
  grep -Fqx 'MOZ_APP_DISPLAYNAME=Vulpra' "$b" ||
    { fail "Vulpra visible application branding changed"; return 1; }
}
check_contract "$profile" "$defaults" "$handler" "$branding"

if [[ "$#" -eq 1 && "$1" == "--self-test" ]]; then
  fixture="$(mktemp -d)"
  trap 'rm -rf -- "$fixture"' EXIT
  cp -- "$profile" "$fixture/firefox.js"
  cp -- "$defaults" "$fixture/all.js"
  cp -- "$handler" "$fixture/nsHttpHandler.cpp"
  cp -- "$branding" "$fixture/configure.sh"
  p="$fixture/firefox.js"; d="$fixture/all.js"; h="$fixture/nsHttpHandler.cpp"; b="$fixture/configure.sh"
  check_contract "$p" "$d" "$h" "$b"

  sed -i 's/pref("general.useragent.compatMode.firefox", true);/pref("general.useragent.compatMode.firefox", false);/' "$p"
  if check_contract "$p" "$d" "$h" "$b" >/dev/null 2>&1; then fail "disabled app default accepted"; exit 1; fi
  cp -- "$profile" "$p"

  printf '\npref("general.useragent.override", "Firefox/159.0");\n' >> "$p"
  if check_contract "$p" "$d" "$h" "$b" >/dev/null 2>&1; then fail "full UA override accepted"; exit 1; fi
  cp -- "$profile" "$p"

  sed -i 's/pref("general.useragent.compatMode.firefox", false);/pref("general.useragent.compatMode.firefox", true);/' "$d"
  if check_contract "$p" "$d" "$h" "$b" >/dev/null 2>&1; then fail "modified Gecko-wide default accepted"; exit 1; fi
  cp -- "$defaults" "$d"

  sed -i 's/if (isFirefox || mCompatFirefoxEnabled)/if (isFirefox)/' "$h"
  if check_contract "$p" "$d" "$h" "$b" >/dev/null 2>&1; then fail "removed Firefox-compat assembly accepted"; exit 1; fi
  cp -- "$handler" "$h"

  sed -i 's/MOZ_APP_DISPLAYNAME=Vulpra/MOZ_APP_DISPLAYNAME=Firefox/' "$b"
  if check_contract "$p" "$d" "$h" "$b" >/dev/null 2>&1; then fail "lost branded app name accepted"; exit 1; fi

  echo "PASS: Vulpra Firefox compatibility source contract"
  echo "PASS: 5/5 falsified app default, UA override, Gecko default, builder and branding rejected"
elif [[ "$#" -ne 0 ]]; then
  fail 'usage: test.sh [--self-test]'
  exit 2
else
  echo "PASS: Vulpra Firefox-compatible UA default and retained Vulpra token"
fi
