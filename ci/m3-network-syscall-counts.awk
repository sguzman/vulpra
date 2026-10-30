# Aggregate network syscall class counts from strace -ff network-only logs.
# Does not print addresses, paths, process identifiers, trace lines, arguments,
# individual endpoints or other raw data.
{
  # The trace includes browser, Weston, harness and child processes, so all
  # counts are aggregate, not browser-only attribution.
  n++;
  if ($0 ~ /socket[(]/) socket_calls++;
  if ($0 ~ /connect[(]/) connect_calls++;
  if ($0 ~ /recvmsg[(]/) recvmsg_calls++;
  if ($0 ~ /sendmsg[(]/) sendmsg_calls++;
  if ($0 ~ /getsockopt[(]/) getsockopt_calls++;
  if ($0 ~ /AF_NETLINK/) netlink++;
  if ($0 ~ /AF_INET6/) ipv6++;
  if ($0 ~ /AF_INET[,}]/) ipv4++;
  if ($0 ~ /AF_UNIX/) unix++;
  if ($0 ~ /ENETUNREACH/) netunreach++;
  if ($0 ~ /EHOSTUNREACH/) hostunreach++;
  if ($0 ~ /ECONNREFUSED/) refused++;
  if ($0 ~ /EACCES|EPERM/) denied++;
}
END {
  if (!n) {
    print "DIAGNOSTIC: no strace events observed"
    exit 2
  }
  print "aggregate network syscall lines:", n
  print "socket() calls:", socket_calls+0
  print "connect() calls:", connect_calls+0
  print "recvmsg() calls:", recvmsg_calls+0
  print "sendmsg() calls:", sendmsg_calls+0
  print "getsockopt() calls:", getsockopt_calls+0
  print "AF_NETLINK occurrences:", netlink+0
  print "AF_INET occurrences:", ipv4+0
  print "AF_INET6 occurrences:", ipv6+0
  print "AF_UNIX occurrences:", unix+0
  print "ENETUNREACH occurrences:", netunreach+0
  print "EHOSTUNREACH occurrences:", hostunreach+0
  print "ECONNREFUSED occurrences:", refused+0
  print "EACCES/EPERM occurrences:", denied+0
}
