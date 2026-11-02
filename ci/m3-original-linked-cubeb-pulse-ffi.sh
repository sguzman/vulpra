#!/usr/bin/env bash
# Exact-source ORIGINAL unstripped libxul native C-to-Rust cubeb FFI probe.
# This tests address-taken Rust entrypoint + cubeb indirect dispatch.
# Neither a direct call instruction nor proof of the executed indirect target.
set -euo pipefail
fail(){ printf 'cubeb-pulse-native: %s\n' "$*" >&2; exit 1; }
[[ $# -eq 3 ]] || fail 'usage: PINNED_SOURCE_SHA UNSTRIPPED_LIBXUL OUT_JSON'
[[ "$1" == b1482404dfb8b01342990ee99ea3df0f9756b5f7 ]] || fail 'source SHA mismatch'
elf="$2"; report="$3"
[[ -f "$elf" && ! -L "$elf" ]] || fail 'not a regular original ELF'
bytes="$(stat -c %s "$elf")"
[[ "$bytes" =~ ^[0-9]+$ && "$bytes" -ge 64 && "$bytes" -le 17179869184 ]] || fail 'unbounded original ELF'
[[ "$(od -An -tx1 -N4 "$elf" | tr -d ' \n')" == 7f454c46 ]] || fail 'not ELF'
readelf -hW "$elf" | grep -Fq 'Advanced Micro Devices X86-64' || fail 'not x86_64 ELF'
readelf -SW "$elf" | grep -Eq '[[:space:]]\.symtab[[:space:]]' || fail 'missing unstripped symtab'
for symbol in cubeb_init pulse_rust_init; do
  count="$(nm --defined-only --no-demangle --format=posix "$elf" |
    awk -v sym="$symbol" '$1==sym && $2 ~ /^[tTwW]$/ { n++ } END { print n+0 }')"
  [[ "$count" == 1 ]] || fail "expected exactly one compiled $symbol definition (found $count)"
done
# Inspect one original compiled function only. GNU objdump resolves the
# native RIP-relative target to the linked Rust symbol, not a source grep.
disassembly="$(objdump -d --no-show-raw-insn --disassemble=cubeb_init "$elf")"
[[ "$(printf %s "$disassembly" | wc -c)" -le 2000000 ]] || fail 'cubeb_init disassembly unbounded'
[[ "$disassembly" == *"<cubeb_init>:"* ]] || fail 'compiled cubeb_init body missing'
native="$(awk '
  /^[[:space:]]*[0-9a-f]+:/ {
    if ($0 ~ /<pulse_rust_init>/ &&
        $0 ~ /[[:space:]](lea|leaq|mov|movq|movabs|push)[[:space:]]/) addr++
    if ($0 ~ /[[:space:]]call(q)?[[:space:]]+\*/) indirect++
  }
  END {printf "%d %d", addr+0, indirect+0}
' <<<"$disassembly")"
read -r refs calls <<<"$native"
[[ "$refs" =~ ^[0-9]+$ && "$calls" =~ ^[0-9]+$ ]] || fail 'invalid instruction counts'
[[ "$refs" -ge 1 && "$refs" -le 64 ]] || fail "expected compiled cubeb_init address-taken pulse_rust_init, got $refs"
[[ "$calls" -ge 1 && "$calls" -le 128 ]] || fail "expected compiled cubeb_init indirect function-pointer call, got $calls"
# Preserve only bounded counts, not disassembly, source paths, native PCs or PIDs.
jq -n --arg source "$1" --argjson refs "$refs" --argjson calls "$calls" '{
  schema_version:1,
  status:"exact_original_compiled_cubeb_pulse_rust_address_and_dispatch_verified",
  source_commit:$source,
  compiled_input:"original unstripped libxul.so",
  cubeb_init_text_definition_count:1,
  pulse_rust_init_text_definition_count:1,
  cubeb_init_address_takes_pulse_rust_init:$refs,
  cubeb_init_indirect_call_instructions:$calls,
  actual_indirect_call_target_executed_proven:false,
  source_to_native_ffi_address_reference_proven:true,
  direct_cubeb_to_pulse_rust_call_instruction_proven:false,
  uninstrumented_original_browser_stack_proven:false,
  full_ffi_dependency_graph_proven:false,
  source_pruning_authorized:false,
  m3_sixth_gate_closed:false
}' >"$report"
echo 'PASS: original compiled cubeb_init takes Rust pulse_rust_init address and has indirect dispatch; runtime callee unproved'
