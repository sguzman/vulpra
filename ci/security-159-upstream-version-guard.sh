#!/usr/bin/env bash
# Fail-closed Mozilla desktop stable-release drift check.
# A matching upstream version does NOT make Vulpra security-current.
set -euo pipefail

EXPECTED_STABLE="159.0.1"
MOZILLA_RELEASE_JSON="https://product-details.mozilla.org/1.0/firefox_versions.json"
SECURITY_TRACKER="https://github.com/sguzman/vulpra/issues/3"

validate_release_feed() {
  local file="$1" actual
  actual="$(jq -er '
    .LATEST_FIREFOX_VERSION |
    select(type == "string" and test("^[0-9]+[.][0-9]+([.][0-9]+)?$"))
  ' "$file")" || {
    echo "::error::Mozilla stable-release feed missing a valid version" >&2
    return 1
  }
  if [[ "$actual" != "$EXPECTED_STABLE" ]]; then
    echo "::error::Firefox stable release changed: pinned=$EXPECTED_STABLE, upstream=$actual. Review every new Mozilla advisory and port required updates before shipping Vulpra. $SECURITY_TRACKER" >&2
    return 1
  fi
  echo "PASS: Mozilla still publishes Firefox stable $EXPECTED_STABLE"
  echo "LIMIT: Vulpra's unaudited high-impact Firefox 159 issues and target workstation QA remain open; this is not release acceptance"
}

self_test() {
  local temp
  temp="$(mktemp -d)"
  trap 'rm -rf -- "$temp"' RETURN
  printf '{"LATEST_FIREFOX_VERSION":"159.0.1"}\n' > "$temp/good.json"
  validate_release_feed "$temp/good.json" >/dev/null
  local failures=0
  for payload in \
    '{"LATEST_FIREFOX_VERSION":"159.0.2"}' \
    '{"LATEST_FIREFOX_VERSION":"160.0"}' \
    '{"LATEST_FIREFOX_VERSION":"159.0"}' \
    '{"LATEST_FIREFOX_VERSION":null}' \
    '{"LATEST_FIREFOX_VERSION":159.01}' \
    '{"LATEST_FIREFOX_VERSION":"159.0.1-extra"}' \
    '{}' \
    'not-json'; do
    printf '%s\n' "$payload" > "$temp/forged.json"
    if validate_release_feed "$temp/forged.json" >/dev/null 2>&1; then
      echo "FAIL: accepted altered, stale or malformed upstream release feed: $payload" >&2
      return 1
    fi
    failures=$((failures + 1))
  done
  [[ "$failures" -eq 8 ]] || return 1
  echo "PASS: 8/8 altered, missing, stale and malformed upstream release states rejected"
}

check_live() {
  local temp
  temp="$(mktemp)"
  trap 'rm -f -- "$temp"' RETURN
  curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 60 \
    --proto '=https' --tlsv1.2 "$MOZILLA_RELEASE_JSON" -o "$temp"
  validate_release_feed "$temp"
}

case "$*" in
  --self-test) self_test ;;
  --check-live) check_live ;;
  *)
    echo "Usage: $0 --self-test | --check-live" >&2
    exit 2
    ;;
esac
