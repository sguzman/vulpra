#!/usr/bin/env bash
# Real GNU cc/ELF/binutils fixtures for original compiled cubeb/Rust seam auditor.
set -euo pipefail
[[ $# -eq 1 ]] || exit 2
auditor="$(realpath -e "$1")"
work="$(mktemp -d /tmp/vulpra-cubeb-ffi-fixture.XXXXXX)"
trap 'rm -rf -- "$work"' EXIT
source_sha=b1482404dfb8b01342990ee99ea3df0f9756b5f7
cat >"$work/positive.c" <<'EOF'
__attribute__((noinline)) int pulse_rust_init(int n){ return n+1; }
__attribute__((noinline)) int alsa_init(int n){ return n-1; }
__attribute__((noinline)) int cubeb_init(int n) {
  int (*volatile choices[2])(int)={pulse_rust_init,alsa_init};
  for(int i=0;i<2;i++) if(choices[i](n)==0) return 0;
  return -1;
}
EOF
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -O2 -Wl,-Bsymbolic \
  "$work/positive.c" -o "$work/libxul.so"
echo 'Synthetic compiled cubeb_init instructions (fixture only):'
objdump -d --no-show-raw-insn --disassemble=cubeb_init "$work/libxul.so" | tail -n 28
echo 'Synthetic linked cubeb and pulse symbols (fixture only):'
nm --defined-only --no-demangle --format=posix "$work/libxul.so" |
  grep -E '^(cubeb_init|pulse_rust_init) '
bash "$auditor" "$source_sha" "$work/libxul.so" "$work/positive.json"
jq -e '.source_to_native_ffi_address_reference_proven==true and
        .cubeb_init_address_takes_pulse_rust_init>=1 and
        .cubeb_init_indirect_call_instructions>=1 and
        .direct_cubeb_to_pulse_rust_call_instruction_proven==false and
        .actual_indirect_call_target_executed_proven==false and
        .m3_sixth_gate_closed==false' "$work/positive.json" >/dev/null
cat >"$work/direct.c" <<'EOF'
__attribute__((noinline)) int pulse_rust_init(int n){ return n+1; }
__attribute__((noinline)) int cubeb_init(int n){ return pulse_rust_init(n); }
EOF
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -O2 -Wl,-Bsymbolic \
  "$work/direct.c" -o "$work/direct.so"
if bash "$auditor" "$source_sha" "$work/direct.so" "$work/no-direct.json" >/dev/null 2>&1; then
  echo 'ERROR: rejected direct call wrongly accepted as indirect cubeb FFI address-taking' >&2; exit 1
fi
cat >"$work/unrelated.c" <<'EOF'
__attribute__((noinline)) int pulse_rust_init(int n){ return n+1; }
__attribute__((noinline)) int alsa_init(int n){ return n-1; }
__attribute__((noinline)) int cubeb_init(int n) {
  int (*volatile choices[2])(int)={alsa_init,alsa_init};
  return choices[n&1](n);
}
EOF
cc -std=c11 -Wall -Wextra -Werror -fPIC -shared -O2 -Wl,-Bsymbolic \
  "$work/unrelated.c" -o "$work/unrelated.so"
if bash "$auditor" "$source_sha" "$work/unrelated.so" "$work/no-reference.json" >/dev/null 2>&1; then
  echo 'ERROR: Rust entrypoint presence without cubeb machine reference accepted' >&2; exit 1
fi
if bash "$auditor" not-original "$work/libxul.so" "$work/no-pin.json" >/dev/null 2>&1; then
  echo 'ERROR: source revision check ignored' >&2; exit 1
fi
printf 'not-an-ELF\n' > "$work/fake.so"
if bash "$auditor" "$source_sha" "$work/fake.so" "$work/no-elf.json" >/dev/null 2>&1; then
  echo 'ERROR: non-ELF input accepted' >&2; exit 1
fi
echo 'PASS: real native indirect positive, direct-call, unrelated-reference, wrong-source and fake-ELF negative fixtures'
