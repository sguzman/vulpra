# Sanitize GDB SIGSEGV output. Fields are positional: <4096, ==0, sigcode.
# Never print raw pointers, PID values, function arguments or filesystem paths.
# GDB may render boolean expressions as 0/1 rather than
# true/false. Parse the three successive print results in order,
# not as independent regex branches (which mislabels 1 as MAPERR).
/^[$][0-9]+ = / {
  ++fault_field
  value=$3
  if (fault_field == 1) {
    if (value=="true" || value=="1") print "DIAGNOSTIC fault address under 4096 bytes: yes"
    else if (value=="false" || value=="0") print "DIAGNOSTIC fault address under 4096 bytes: no"
    else print "DIAGNOSTIC fault address under 4096 bytes: unavailable"
  } else if (fault_field == 2) {
    if (value=="true" || value=="1") print "DIAGNOSTIC fault address exactly null: yes"
    else if (value=="false" || value=="0") print "DIAGNOSTIC fault address exactly null: no"
    else print "DIAGNOSTIC fault address exactly null: unavailable"
  } else if (fault_field == 3) {
    if (value=="1") print "DIAGNOSTIC fault class: SEGV_MAPERR"
    else if (value=="2") print "DIAGNOSTIC fault class: SEGV_ACCERR"
    else print "DIAGNOSTIC fault class: other-or-unavailable"
  }
}
/received signal/ {
  if (/SIGSEGV/) print "DIAGNOSTIC signal: SIGSEGV";
  else print "DIAGNOSTIC signal: other";
}
/^#[0-9]+[[:space:]]/ {
  module="unknown"
  if (match($0, / from [^[:space:]]+/)) {
    path=substr($0, RSTART+6, RLENGTH-6)
    parts_count=split(path, parts, "/")
    module=parts[parts_count]
  }
  frame=$0
  sub(/^#[0-9]+[[:space:]]+/, "", frame)
  sub(/^0x[0-9a-fA-F]+[[:space:]]+in[[:space:]]+/, "", frame)
  sub(/^in[[:space:]]+/, "", frame)
  sub(/[(].*/, "", frame)
  sub(/[[:space:]]+(at|from)[[:space:]].*/, "", frame)
  gsub(/[^A-Za-z0-9_:~<>., +*-]/, "?", frame)
  print "DIAGNOSTIC symbolic frame " ++n ": " substr(frame,1,120) " [module=" module "]"
  if (n >= 15) exit
}

END {
  if (!fault_field || fault_field < 3) print "DIAGNOSTIC fault classification: incomplete"
  if (!n) print "DIAGNOSTIC frames: none"
}
