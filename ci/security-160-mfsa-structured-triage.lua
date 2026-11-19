-- Deterministic, stdlib-only Lua 5.4 inventory of Mozilla MFSA 2026-125
-- headings and explicitly reported impact/bug IDs. No exploit/patch verdicts.
-- Advisory URL fetched separately by bounded, authenticated CI.
local function fail(msg) error("FAIL: " .. msg, 0) end
if #arg ~= 4 or arg[1] ~= "--extract" then
  fail("Usage: lua script --extract OFFICIAL_HTML CHECKED_CVE_LINES OUTPUT_JSON")
end
local function read(path)
  local f, err = io.open(path, "rb")
  if not f then fail("Unable to read input: " .. tostring(err)) end
  local value = f:read("*a")
  f:close()
  return value
end
local original = read(arg[2])
if #original < 100 or #original > 5000000 then fail("Advisory HTML size out of bounds") end
if not original:find("Mozilla Foundation Security Advisory 2026-125", 1, true) or
   not original:find("Security Vulnerabilities fixed in Firefox 160", 1, true) then
  fail("Wrong advisory or missing official release title")
end
local checked = {}
local checked_count = 0
for line in read(arg[3]):gmatch("[^\r\n]+") do
  if not line:match("^CVE%-%d%d%d%d%-%d%d%d%d+$") or checked[line] then
    fail("Invalid or repeated source-spotchecked CVE identifier")
  end
  checked[line] = true
  checked_count = checked_count + 1
end
if checked_count ~= 4 or
   not checked["CVE-2026-124853"] or
   not checked["CVE-2026-124854"] or
   not checked["CVE-2026-124856"] or
   not checked["CVE-2026-124902"] then
  fail("Existing source-audited four-CVE set changed")
end

-- Extract visible prose only. The advisory is untrusted and never executed.
-- This is a bounded heading inventory, not an HTML security sanitizer.
local visible = original
  :gsub("<[sS][cC][rR][iI][pP][tT][^>]*>.-</[sS][cC][rR][iI][pP][tT]%s*>", " ")
  :gsub("<[sS][tT][yY][lL][eE][^>]*>.-</[sS][tT][yY][lL][eE]%s*>", " ")
  :gsub("<[^>]*>", " ")
  :gsub("&nbsp;", " ")
  :gsub("&amp;", "&")
  :gsub("&#39;", "'")
  :gsub("&quot;", '"')
  :gsub("%s+", " ")
local positions, at = {}, 1
while true do
  local first, last, id = visible:find("(CVE%-%d%d%d%d%-%d+):", at)
  if not first then break end
  positions[#positions + 1] = {first = first, last = last, id = id}
  at = last + 1
  if #positions > 300 then fail("Too many advisory heading-like CVEs") end
end
if #positions < 20 then fail("Too few structured CVE headings found") end

local function jsonstring(s)
  local replacements = {['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n',
                        ['\r'] = '\\r', ['\t'] = '\\t'}
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    return replacements[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end
local allowed = {critical = true, high = true, moderate = true, low = true}
local entries, seen, counts = {}, {}, {critical = 0, high = 0, moderate = 0, low = 0}
local priority_count, source_spotchecked = 0, 0
for i, found in ipairs(positions) do
  local boundary = positions[i + 1] and (positions[i + 1].first - 1) or #visible
  local section = visible:sub(found.first, boundary)
  local title = section:match("^CVE%-%d%d%d%d%-%d+:%s*(.-)%s+Reporter%s+")
  local reporter = section:match("%sReporter%s+(.-)%s+Impact%s+")
  local impact = section:match("%sImpact%s+(%a+)%s+")
  local bug = section:match("%sReferences%s+Bug%s+(%d+)")
  if seen[found.id] or not title or #title < 5 or #title > 250 or
     not reporter or #reporter < 1 or #reporter > 150 or not allowed[impact] then
    fail("Duplicate or unparsable structured advisory entry " .. found.id)
  end
  seen[found.id] = true
  counts[impact] = counts[impact] + 1
  if checked[found.id] then source_spotchecked = source_spotchecked + 1 end
  local lower = title:lower()
  local boundary_priority =
    lower:find("sandbox escape", 1, true) or
    lower:find("privilege escalation", 1, true) or
    lower:find("same-origin policy bypass", 1, true) or
    lower:find("site isolation", 1, true) or
    lower:find("mitigation bypass", 1, true)
  local tier = impact == "high" and
    (boundary_priority and "high_boundary_review" or "other_high_review") or
    (impact .. "_review")
  if tier == "high_boundary_review" then priority_count = priority_count + 1 end
  local android = lower:find("android", 1, true) ~= nil
  entries[#entries + 1] = table.concat({
    '{"cve":', jsonstring(found.id),
    ',"title":', jsonstring(title),
    ',"impact":', jsonstring(impact),
    ',"bug_id":', bug and tonumber(bug) or 'null',
    ',"reporter":', jsonstring(reporter),
    ',"triage_tier":', jsonstring(tier),
    ',"explicit_android_title":', tostring(android),
    ',"previously_source_spotchecked":', tostring(checked[found.id] or false),
    ',"independently_verified_fix":false',
    ',"applicability_reviewed":false',
    '}'
  })
end
if source_spotchecked ~= 4 then fail("Known four CVEs missing from structured headings") end
local checked_json = jsonstring(arg[3])
local report = table.concat({
  '{\n"schema_version":1,\n',
  '"kind":"firefox160_mfsa2026_125_structured_triage_not_patch_audit",\n',
  '"advisory":"MFSA 2026-125",\n',
  '"official_url":"https://www.mozilla.org/en-US/security/advisories/mfsa2026-125/",\n',
  '"unique_structured_cve_headings":', tostring(#entries), ',\n',
  '"previously_source_spotchecked_cves":', tostring(source_spotchecked), ',\n',
  '"other_cves_without_individual_source_review":', tostring(#entries - source_spotchecked), ',\n',
  '"high_priority_boundary_review_count":', tostring(priority_count), ',\n',
  '"by_impact":{"critical":', tostring(counts.critical), ',"high":',
  tostring(counts.high), ',"moderate":', tostring(counts.moderate),
  ',"low":', tostring(counts.low), '},\n',
  '"ranking_is_a_review_queue_not_exploitability_or_fix_verdict":true,\n',
  '"all_advisory_fixes_independently_verified":false,\n',
  '"security_current":false,\n"release_ready":false,\n',
  '"entries":[\n', table.concat(entries, ',\n'), '\n]\n}\n'
})
local check = io.open(arg[4], "rb")
if check then check:close(); fail("Refusing to overwrite existing structured advisory proof") end
local out, err = io.open(arg[4], "wb")
if not out then fail("Cannot write new output: " .. tostring(err)) end
out:write(report)
out:close()
print(string.format(
  "PASS: structured official advisory triage of %d CVEs (%d high, %d high boundary review, 4 prior source spotchecks)",
  #entries, counts.high, priority_count
))
print("LIMIT: metadata-only risk queue; no per-CVE fix/applicability/exploit/security-current approval")
