#!/usr/bin/env bash
# Offline end-to-end fixture. The fake WebDriver never starts a browser.
set -Eeuo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
repo="$work/repo"
bin="$work/bin"
mkdir -p "$repo/ci/fixtures" "$bin" "$work/pkg/vulpra"
git -C "$repo" init -q
printf 'mock mach\n' > "$repo/mach"
cp "$here/fixtures/input-to-raf.html" "$repo/ci/fixtures/input-to-raf.html"
printf 'Name=Vulpra\n' > "$work/pkg/vulpra/application.ini"
printf '\177ELFfake-binary-not-executed\n' > "$work/pkg/vulpra/vulpra"
chmod +x "$work/pkg/vulpra/vulpra"
git -C "$repo" add mach ci
git -C "$repo" -c user.name=QA -c user.email=qa@example.invalid commit -qm 'isolated mock'
packdir="$repo/.git/vulpra-native-build/packages"
mkdir -p "$packdir"
archive="$packdir/vulpra-local-fixture.tar.xz"
tar -cJf "$archive" -C "$work/pkg" vulpra
(cd "$packdir" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")

cat > "$bin/geckodriver" <<'DRIVER'
#!/usr/bin/env bash
# No actual port bound: the curl fixture returns synthetic WebDriver JSON.
exec sleep 60
DRIVER

cat > "$bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
url="${*: -1}"
[[ "$url" == http://127.0.0.1:* ]] || { echo "Non-loopback WebDriver URL" >&2; exit 3; }
printf '%s\n' "$url" >> "$MOCK_CALLS"
if [[ "$url" == */status ]]; then
  echo '{"value":{"ready":true}}'
elif [[ "$url" == */session ]]; then
  echo '{"value":{"sessionId":"fixture-session","capabilities":{"browserName":"firefox","acceptInsecureCerts":false}}}'
elif [[ "$url" == */element ]]; then
  echo '{"value":{"element-6066-11e4-a52e-4f735466cecf":"fixture-element"}}'
elif [[ "$url" == */execute/sync ]]; then
  if [[ "$*" == *'vulpraProbe.report().ready'* ]]; then
    echo '{"value":true}'
  else
    echo '{"value":{"ready":true,"inputEvents":48,"trustedEvents":48,"inputToNextRafMs":{"count":48,"p50":3,"p95":8,"max":11},"rafIntervalMs":{"count":120,"p50":16.7,"p95":20.1,"max":40},"visibility":"visible","note":"mock fixture"}}'
  fi
else
  echo '{"value":null}'
fi
CURL
chmod +x "$bin/geckodriver" "$bin/curl"
export MOCK_CALLS="$work/calls.txt"
PATH="$bin:$PATH" bash "$here/measure-input-frame-local.sh" "$repo" > "$work/out" 2>&1 || {
  cat "$work/out" >&2
  echo 'FAIL: mock WebDriver integration' >&2; exit 1;
}
grep -Fq 'PASS: 48 trusted input events.' "$work/out"
[[ "$(grep -c '/element/fixture-element/value$' "$MOCK_CALLS")" == 48 ]] || {
  echo 'FAIL: wrong synthetic keystroke count' >&2; exit 1;
}
mapfile -t reports < <(find "$repo/.git/vulpra-native-build" -maxdepth 1 -name 'input-frame-*.json' -type f)
(("${#reports[@]}" == 1)) || { echo 'FAIL: no bounded report' >&2; exit 1; }
jq -e '.status=="pass" and .mode=="headless" and .isolated_profile==true
  and .metrics.inputEvents==48 and .metrics.trustedEvents==48
  and .metrics.rafIntervalMs.p95==20.1
  and (.limits | length >= 3)' "${reports[0]}" >/dev/null
grep -Fq '/session/fixture-session' "$MOCK_CALLS"
if grep -q 'https://' "$MOCK_CALLS"; then
  echo 'FAIL: non-local WebDriver request' >&2; exit 1;
fi
# An integrity failure is a hard denial, not a fallback to an unchecked tarball.
printf 'bad sha256\n' > "$archive.sha256"
if PATH="$bin:$PATH" bash "$here/measure-input-frame-local.sh" "$repo" > "$work/reject" 2>&1; then
  echo 'FAIL: unchecked package accepted' >&2; exit 1;
fi
if PATH="$bin:$PATH" VULPRA_INPUT_SAMPLES=81 bash "$here/measure-input-frame-local.sh" "$repo" > "$work/reject" 2>&1; then
  echo 'FAIL: unbounded sample count accepted' >&2; exit 1;
fi
echo 'PASS: mocked isolated WebDriver input/rAF report, loopback-only calls, checksum denial and bounded samples.'
