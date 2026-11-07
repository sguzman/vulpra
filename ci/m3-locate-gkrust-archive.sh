#!/usr/bin/env bash
# Fail-closed discovery of the actual current Mozilla-built gkrust archive.
# An earlier native CI failed to locate its assumed hardcoded archive path.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: m3-locate-gkrust-archive.sh BUILT_OBJDIR" >&2
  exit 2
fi

obj="$(realpath -e -- "$1")" || {
  echo "FAIL: missing compiled Firefox object directory" >&2
  exit 1
}
if [ "$obj" = "/" ] || [ ! -d "$obj" ]; then
  echo "FAIL: invalid compiled Firefox object directory" >&2
  exit 1
fi

# Separate assertions: 'test A && test B' is not an adequate guard under
# bash -e, because failure of the first AND-list element can be ignored.
libxul="$obj/dist/bin/libxul.so"
if [ ! -f "$libxul" ] || [ ! -s "$libxul" ] || [ -L "$libxul" ]; then
  echo "FAIL: unstripped libxul.so absent from native build dist/bin" >&2
  exit 1
fi

direct="$obj/toolkit/library/rust/libgkrust.a"
if [ -f "$direct" ] && [ -s "$direct" ] && [ ! -L "$direct" ]; then
  archive="$direct"
  mode=expected
else
  tmp="$(mktemp)"
  trap "rm -f -- '$tmp'" EXIT
  # Follow no symlinks; retain only actual named regular Rust archives.
  find "$obj" -type f -name libgkrust.a -print > "$tmp" || {
    echo "FAIL: native Rust archive enumeration failed" >&2
    exit 1
  }
  mapfile -t candidates < "$tmp"
  if [ "${#candidates[@]}" -ne 1 ]; then
    echo "FAIL: expected one unique current gkrust archive; found ${#candidates[@]} candidates" >&2
    exit 1
  fi
  archive="${candidates[0]}"
  mode=unique-fallback
fi

if [ ! -f "$archive" ] || [ ! -s "$archive" ] || [ -L "$archive" ]; then
  echo "FAIL: selected native Rust archive missing, empty or symlink" >&2
  exit 1
fi
canonical="$(realpath -e -- "$archive")"
case "$canonical" in
  "$obj"/*) ;;
  *) echo "FAIL: selected native Rust archive escapes compiled object directory" >&2; exit 1 ;;
esac

echo "PASS: selected a bounded normal-build Rust staticlib by $mode path" >&2
echo "$canonical"
