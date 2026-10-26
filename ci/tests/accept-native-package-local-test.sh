#!/usr/bin/env bash
# Offline synthetic acceptance-runner tests: real browser runtime is a separate gate.
set -Eeuo pipefail
RUNNER="${1:?Pass absolute acceptance Python probe path}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
mkdir -p "$R/repo" "$R/package/vulpra" "$R/repo/.git/vulpra-native-build/packages"
cd "$R/repo"
git init -q
git config user.name CI
git config user.email test@example.invalid
printf 'fixture\n' > README
git add README
git commit -qm 'Acceptance fixture'
cat > "$R/package/vulpra/application.ini" <<'INI'
[App]
Name=Vulpra
INI
cat > "$R/package/vulpra/vulpra-launch" <<'LAUNCH'
#!/usr/bin/env bash
set -Eeuo pipefail
for argument in "$@"; do
  case "$argument" in
    --profile|-profile|-P|--profile=*|-profile=*) 
      if [[ "${MOCK_ACCEPT_OVERRIDE:-0}" != 1 ]]; then exit 2; fi ;;
  esac
done
mkdir -p "$XDG_DATA_HOME/vulpra/default"
exec "$(dirname "$0")/vulpra" "$@"
LAUNCH
cat > "$R/package/vulpra/vulpra" <<'BROWSER'
#!/usr/bin/env python3
import base64, os, pathlib, sys, urllib.request
args = sys.argv
if "--screenshot" not in args:
    raise SystemExit(2)
url = args[-1]
if url.startswith("http://127.0.0.1:"):
    with urllib.request.urlopen(url, timeout=10) as r:
        start = r.read()
    assert b'location.replace("/page")' in start
    root = url.rsplit("/", 1)[0]
    with urllib.request.urlopen(root + "/page", timeout=10) as r:
        page = r.read()
    assert b"XMLHttpRequest()" in page
    if os.environ.get("MOCK_SKIP_JS", "0") != "1":
        with urllib.request.urlopen(root + "/js-run", timeout=10) as r:
            assert b"JavaScript network check successful" in r.read()
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlV3y8AAAAASUVORK5CYII=")
pathlib.Path(args[args.index("--screenshot") + 1]).write_bytes(png)
BROWSER
chmod +x "$R/package/vulpra/vulpra" "$R/package/vulpra/vulpra-launch"
ARCHIVE="$R/repo/.git/vulpra-native-build/packages/vulpra-local-fixture.tar.xz"
tar -cJf "$ARCHIVE" -C "$R/package" .
(cd "$(dirname "$ARCHIVE")" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
echo 'Vulpra build exit code: 0 (elapsed 42s)' > "$R/repo/.git/vulpra-native-build/build-fixture.log"
HOME="$R/home" python3 "$RUNNER" "$R/repo" > "$R/ok.log" 2>&1 || { cat "$R/ok.log"; exit 1; }
grep -Fq 'PASS: Browser navigated local HTTP pages and executed JavaScript' "$R/ok.log"
JSON=$(find "$R/repo/.git/vulpra-native-build" -maxdepth 1 -type f -name 'acceptance-*.json' | head -1)
python3 - "$JSON" <<'PY'
import json, sys
j = json.load(open(sys.argv[1]))
assert j["status"] == "pass"
assert j["native_executable_name"] == "vulpra"
assert j["successful_incremental_build_seconds"] == 42
assert j["assertions"]["profile_override_refused"]
assert set(("/start", "/page", "/js-run")).issubset(j["navigation_requests"])
assert j["browser_startup_navigation_screenshot_seconds"] > 0
assert j["package_size_bytes"] > 0
PY
echo 'PASS: fixture package navigation, JS, private profile and metrics written'
set +e
HOME="$R/home" MOCK_SKIP_JS=1 python3 "$RUNNER" "$R/repo" > "$R/nojs.log" 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || { cat "$R/nojs.log"; echo "FAIL: no-JS case expected error, got $status"; exit 2; }
grep -Fq 'Navigation or JavaScript failed' "$R/nojs.log"
echo 'PASS: missing JavaScript network request correctly rejected'
set +e
HOME="$R/home" MOCK_ACCEPT_OVERRIDE=1 python3 "$RUNNER" "$R/repo" > "$R/override.log" 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || { cat "$R/override.log"; echo "FAIL: accepted external profile escape"; exit 3; }
grep -Fq 'profile selection escape' "$R/override.log"
echo 'PASS: external profile escape correctly rejected'
printf '%064d  wrong-archive.tar.xz\n' 0 > "$ARCHIVE.sha256"
set +e
HOME="$R/home" python3 "$RUNNER" "$R/repo" > "$R/hash.log" 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || { cat "$R/hash.log"; echo "FAIL: corrupt package checksum accepted"; exit 4; }
grep -Fq 'SHA-256 mismatch' "$R/hash.log"
echo 'PASS: package checksum corruption correctly rejected'
echo 'PASS: offline native acceptance probe regressions'
