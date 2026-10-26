#!/usr/bin/env bash
# Record repeatable native-build measurements for future debloat comparisons.
set -euo pipefail
if [[ $# -ne 4 ]]; then
  printf 'usage: measure-build.sh dist-dir packaged-archive native-build-seconds output.json\n' >&2
  exit 2
fi
dist="$(realpath -e -- "$1")"
archive="$(realpath -e -- "$2")"
seconds="$3"
output="$4"
[[ "$seconds" =~ ^[0-9]+$ ]] || { echo 'Native duration must be an integer' >&2; exit 2; }
[[ -f "$dist/bin/application.ini" ]] || {
  echo 'Missing compiled application.ini' >&2
  exit 1
}
binary=''
for candidate in vulpra firefox; do
  if [[ -x "$dist/bin/$candidate" ]]; then
    binary="$dist/bin/$candidate"
    break
  fi
done
[[ -n "$binary" ]] || {
  echo 'Missing compiled browser executable (vulpra or firefox)' >&2
  exit 1
}
grep -Fxq 'Name=Vulpra' "$dist/bin/application.ini" || {
  echo 'Compiled browser does not identify as Vulpra' >&2
  exit 1
}
command -v jq >/dev/null || { echo 'jq is required to generate valid JSON' >&2; exit 1; }
source_commit="$(git rev-parse HEAD)"
archive_bytes="$(stat -c '%s' "$archive")"
binary_bytes="$(stat -c '%s' "$binary")"
source_lib="$dist/bin/libxul.so"
library_bytes=0
if [[ -f "$source_lib" ]]; then
  library_bytes="$(stat -c '%s' "$source_lib")"
fi
archive_hash="$(sha256sum "$archive" | cut -d' ' -f1)"
jq -n \
  --arg source_commit "$source_commit" \
  --arg native_executable_name "$(basename "$binary")" \
  --arg platform "$(uname -s)" \
  --arg archive_name "$(basename -- "$archive")" \
  --arg archive_sha256 "$archive_hash" \
  --argjson native_build_seconds "$seconds" \
  --argjson archive_bytes "$archive_bytes" \
  --argjson native_executable_bytes "$binary_bytes" \
  --argjson libxul_bytes "$library_bytes" \
  '{
     schema_version: 1,
     source_commit: $source_commit,
     platform: $platform,
     application: "Vulpra",
     native_build_seconds: $native_build_seconds,
     archive_name: $archive_name,
     archive_sha256: $archive_sha256,
     archive_bytes: $archive_bytes,
     native_executable_name: $native_executable_name,
     native_executable_bytes: $native_executable_bytes,
     libxul_bytes: $libxul_bytes,
     measurement_scope: "native mach build only; bootstrap, packaging and smoke excluded"
   }' > "$output"
jq -e '.schema_version == 1 and .native_build_seconds >= 0 and .archive_bytes > 0 and .native_executable_bytes > 0' "$output" >/dev/null
echo "PASS: recorded native build evidence in $output"
