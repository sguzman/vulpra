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
# Parse the full actual native text-definition inventory once. Linker
# optimization may encode the function pointer as a local PC-relative LEA,
# a GLOB_DAT slot, or an R_X86_64_RELATIVE address in a read-only table.
symbols="$(nm --defined-only --no-demangle --format=posix "$elf" |
  awk '($1=="cubeb_init" || $1=="pulse_rust_init") && $2 ~ /^[tTwW]$/ {
    print $1, $2, $3
  }')"
for symbol in cubeb_init pulse_rust_init; do
  count="$(awk -v sym="$symbol" '$1==sym {n++} END {print n+0}' <<<"$symbols")"
  [[ "$count" == 1 ]] || fail "expected exactly one compiled $symbol definition (found $count)"
done
pulse_address="$(awk '$1=="pulse_rust_init" {print tolower($3)}' <<<"$symbols")"
[[ "$pulse_address" =~ ^[0-9a-f]{1,16}$ ]] || fail 'missing original Rust symbol address'
pulse_address="$(sed -E 's/^0+//' <<<"$pulse_address")"
[[ -n "$pulse_address" ]] || pulse_address=0
# Inspect only the original cubeb function; no global instruction grep.
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
read -r direct_refs calls <<<"$native"
[[ "$direct_refs" =~ ^[0-9]+$ && "$calls" =~ ^[0-9]+$ ]] || fail 'invalid instruction counts'
[[ "$calls" -ge 1 && "$calls" -le 128 ]] || fail "expected compiled cubeb_init indirect function-pointer call, got $calls"
# Trace optimized function-pointer table loads: source-level cubeb's local
# default_init array can be materialized as PIC GOT entries. Only count
# a slot if a REAL ELF relocation makes it point at pulse_rust_init AND
# a native cubeb_init instruction reads that very slot.
slots="$(readelf -Wr "$elf" | awk -v target="$pulse_address" '
  $3=="R_X86_64_RELATIVE" {
    add=tolower($4); sub(/^0+/,"",add);
    if (add==target) {
      off=tolower($1); sub(/^0+/,"",off); if(off=="")off="0";
      print off;
    }
  }
  ($3=="R_X86_64_GLOB_DAT" || $3=="R_X86_64_64") && $5=="pulse_rust_init" {
    off=tolower($1); sub(/^0+/,"",off); if(off=="")off="0";
    print off;
  }
')"
relocated_refs=0
while IFS= read -r slot; do
  [[ -n "$slot" ]] || continue
  [[ "$slot" =~ ^[0-9a-f]{1,16}$ ]] || fail 'invalid native relocation slot'
  # GNU objdump annotates RIP-relative loads with "# slot <...>".
  # Require an actual MOV-family instruction, not a symbol in a comment alone.
  if awk -v slot="$slot" '
    /^[[:space:]]*[0-9a-f]+:/ &&
    /[[:space:]](mov|movq|movhps|movaps|lea)[[:space:]]/ &&
    index($0,"# " slot " ")>0 {seen=1}
    END {exit !seen}
  ' <<<"$disassembly"; then
    relocated_refs=$((relocated_refs+1))
  fi
  [[ "$relocated_refs" -le 64 ]] || fail 'unbounded relocatable Rust address refs'
done <<<"$slots"
refs=$((direct_refs+relocated_refs))
[[ "$refs" -ge 1 && "$refs" -le 64 ]] || fail \
  "no machine-level Rust address reference: direct=$direct_refs, relocated=$relocated_refs"
# Preserve only bounded counts, not disassembly, source paths, native PCs or PIDs.
jq -n --arg source "$1" --argjson refs "$refs" --argjson calls "$calls" --argjson direct_refs "$direct_refs" --argjson relocated_refs "$relocated_refs" '{
  schema_version:1,
  status:"exact_original_compiled_cubeb_pulse_rust_address_and_dispatch_verified",
  source_commit:$source,
  compiled_input:"original unstripped libxul.so",
  cubeb_init_text_definition_count:1,
  pulse_rust_init_text_definition_count:1,
  cubeb_init_address_takes_pulse_rust_init:$refs,
  cubeb_init_direct_address_instructions:$direct_refs,
  cubeb_init_relocated_symbol_slot_references:$relocated_refs,
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
