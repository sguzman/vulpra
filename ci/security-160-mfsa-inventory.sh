#!/usr/bin/env bash
# Read-only inventory of CVE text identifiers in Mozilla's public MFSA 2026-125.
# This is NOT a source patch, exploit or security readiness check.
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if test "$#" -ne 4 || test "$1" != --extract; then
  echo 'Usage: security-160-mfsa-inventory.sh --extract <official-mfsa-html> <bounded-four-cve-manifest.json> <new-report.json>' >&2
  exit 2
fi
source_html="$2"
manifest="$3"
report="$4"
for command in jq sha256sum grep sort comm wc cut; do
  command -v "$command" >/dev/null || fail "required utility absent: $command"
done
test -f "$source_html" && test ! -L "$source_html" && test -s "$source_html" || fail 'missing advisory HTML'
test -f "$manifest" && test ! -L "$manifest" && test -s "$manifest" || fail 'missing prior CVE manifest'
test ! -e "$report" && test ! -L "$report" || fail 'report must not already exist'
bytes="$(wc -c < "$source_html")"
(( bytes > 100 && bytes < 5000000 )) || fail 'advisory HTML size out of accepted bounds'
grep -Fq 'Mozilla Foundation Security Advisory 2026-125' "$source_html" || fail 'Mozilla advisory heading absent'
grep -Fq 'Security Vulnerabilities fixed in Firefox 160' "$source_html" || fail 'Firefox 160 advisory title absent'
jq -e '
  .schema_version == 1 and
  .kind == "vulpra_firefox_160_security_patch_presence_bounded_spotcheck" and
  .advisory == "MFSA 2026-125" and
  .scope.cves_checked == 4 and .scope.paths_checked == 6 and
  .scope.all_mfsa2026_125_audited == false and
  .scope.security_current == false and .scope.release_ready == false and
  (.patch_files | type == "array" and length == 6) and
  ([.patch_files[].cve] | unique | sort) ==
    ["CVE-2026-124853","CVE-2026-124854","CVE-2026-124856","CVE-2026-124902"]
' "$manifest" >/dev/null || fail 'prior four-CVE manifest contract changed'

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
# Extract text tokens, not DOM or executable HTML. These values alone cannot
# establish advisory completeness, applicability, or source patch presence.
LC_ALL=C grep -oE 'CVE-[0-9]{4}-[0-9]{4,}' "$source_html" |
  LC_ALL=C sort -u > "$work/all-cves" || fail 'no CVEs in advisory HTML'
jq -r '.patch_files[].cve' "$manifest" | LC_ALL=C sort -u > "$work/checked-cves"
all="$(wc -l < "$work/all-cves")"
selected="$(wc -l < "$work/checked-cves")"
test "$selected" -eq 4 || fail 'unexpected prior spotcheck size'
(( all > selected )) || fail 'inventory no broader than four-CVE spotcheck'
test "$(LC_ALL=C comm -23 "$work/checked-cves" "$work/all-cves" | wc -l)" -eq 0 ||
  fail 'previously checked CVE not present in official advisory'
LC_ALL=C comm -23 "$work/all-cves" "$work/checked-cves" > "$work/outside-spotcheck"
other="$(wc -l < "$work/outside-spotcheck")"
test "$((other + selected))" -eq "$all" || fail 'inconsistent CVE partition'
digest="$(sha256sum "$source_html" | cut -d ' ' -f1)"
jq -n \
  --arg url 'https://www.mozilla.org/en-US/security/advisories/mfsa2026-125/' \
  --arg sha "$digest" \
  --argjson count "$all" --argjson selected "$selected" --argjson outside "$other" \
  --slurpfile all <(jq -R . "$work/all-cves" | jq -s .) \
  --slurpfile audited <(jq -R . "$work/checked-cves" | jq -s .) \
  --slurpfile remaining <(jq -R . "$work/outside-spotcheck" | jq -s .) \
  '{
    schema_version:1,
    kind:"firefox160_official_advisory_cve_text_inventory",
    official_advisory_url:$url,
    official_html_sha256:$sha,
    unique_cve_identifiers_in_html:$count,
    previously_checked_source_cve_identifiers:$selected,
    other_advisory_cve_identifiers_without_individual_source_spotchecks:$outside,
    identifiers:$all[0],
    previously_source_spotchecked_identifiers:$audited[0],
    remaining_unreviewed_identifiers:$remaining[0],
    applicability_independently_verified:false,
    every_security_fix_independently_verified:false,
    native_binary_compiled_in_this_audit:false,
    security_current:false,
    release_ready:false
  }' > "$report"
jq -e '
  .unique_cve_identifiers_in_html == (.identifiers|length) and
  .other_advisory_cve_identifiers_without_individual_source_spotchecks ==
    (.remaining_unreviewed_identifiers|length) and
  .previously_checked_source_cve_identifiers ==
    (.previously_source_spotchecked_identifiers|length) and
  .security_current == false and .release_ready == false
' "$report" >/dev/null || fail 'report self-consistency check failed'
printf 'PASS: %s unique advisory CVE tokens; prior source spotcheck=%s; outside prior spotcheck=%s\n' "$all" "$selected" "$other"
echo 'LIMIT: no per-CVE applicability, patch, runtime, exploit or release acceptance'
