#!/usr/bin/env bash
# Regression for the native NSPR os_Linux_x86_64.s compiler-driver options.
set -euo pipefail
[[ "${VULPRA_NIX_DEV:-}" == 1 ]] || { echo 'ERROR: Nix devShell required' >&2; exit 1; }
[[ -n "${AS:-}" && -x "$AS" ]] || { echo 'ERROR: AS must be an executable compiler driver' >&2; exit 1; }
case "${AS##*/}" in
  as) echo 'ERROR: AS points to a raw assembler, not a compiler driver' >&2; exit 1 ;;
esac
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
cat > "$scratch/os_Linux_x86_64.s" <<'SRC'
.text
.globl vulpra_nspr_assembler_smoke
.type vulpra_nspr_assembler_smoke, @function
vulpra_nspr_assembler_smoke:
  ret
.size vulpra_nspr_assembler_smoke, .-vulpra_nspr_assembler_smoke
SRC
printf '/* assembly smoke header */\n' > "$scratch/mozilla-config.h"
"$AS" -o "$scratch/os_Linux_x86_64.o" \
  -Wa,--noexecstack -fPIC -DMOZILLA_CLIENT \
  -include "$scratch/mozilla-config.h" -gdwarf-4 \
  -c "$scratch/os_Linux_x86_64.s"
[[ -s "$scratch/os_Linux_x86_64.o" ]] || { echo 'ERROR: assembly object not created' >&2; exit 1; }
printf 'PASS: Nix native compiler driver builds NSPR-style x86_64 assembly\n'
