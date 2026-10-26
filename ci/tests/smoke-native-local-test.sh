#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT="${1:?Pass absolute path to smoke-native-local.sh}"
R=$(mktemp -d)
trap 'rm -rf -- "$R"' EXIT
mkdir -p "$R/repo/obj-vulpra-linux/dist/bin"
cd "$R/repo"
git init -q
git config user.name Test
git config user.email test@example.invalid
printf 'probe fixture\n' > README
git add README
git commit -qm 'Local smoke mock fixture'
cat > obj-vulpra-linux/mozinfo.json <<'JSON'
{"appname": "vulpra", "bin_suffix": "", "buildapp": "browser"}
JSON
cat > obj-vulpra-linux/dist/bin/application.ini <<'INI'
[App]
Name=Vulpra
Vendor=Vulpra
INI
cat > obj-vulpra-linux/dist/bin/vulpra <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$*" == *"--no-remote"* && "$*" == *"--headless"* && "$*" == *"--profile"* ]] || exit 80
[[ "$HOME" == *"/home" ]] || exit 81
[[ ! -e "$HOME/.mozilla" ]] || exit 82
screenshot=""
while (($#)); do
  if [[ "$1" == --screenshot ]]; then
    screenshot="$2"
    break
  fi
  shift
done
[[ -n "$screenshot" ]] || exit 83
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WlV3y8AAAAASUVORK5CYII=' | base64 -d > "$screenshot"
MOCK
chmod +x obj-vulpra-linux/dist/bin/vulpra
HOME="$R/home-real" bash "$SCRIPT" "$R/repo" > "$R/run.log" 2>&1 || {
  cat "$R/run.log"; exit 1;
}
grep -Fq 'PASS: Compiled Vulpra started headlessly' "$R/run.log"
test "$(find "$R/repo/.git/vulpra-native-build" -name 'native-smoke-*.png' | wc -l)" -eq 1
echo 'PASS: chooses configured vulpra binary, renders PNG, isolates HOME'
sed -i 's/^Name=Vulpra$/Name=Firefox/' obj-vulpra-linux/dist/bin/application.ini
set +e
HOME="$R/home-real" bash "$SCRIPT" "$R/repo" > "$R/badname.log" 2>&1
result=$?
set -e
[[ "$result" == 5 ]] || { cat "$R/badname.log"; echo "FAIL: unexpected invalid identity exit $result"; exit 2; }
echo 'PASS: refuses non-Vulpra application identity'
sed -i 's/^Name=Firefox$/Name=Vulpra/' obj-vulpra-linux/dist/bin/application.ini
rm obj-vulpra-linux/dist/bin/vulpra
set +e
HOME="$R/home-real" bash "$SCRIPT" "$R/repo" > "$R/nobinary.log" 2>&1
result=$?
set -e
[[ "$result" == 4 ]] || { cat "$R/nobinary.log"; echo "FAIL: unexpected absent executable exit $result"; exit 3; }
echo 'PASS: reports absent browser with diagnostics'
echo 'PASS: native startup probe regression tests'
