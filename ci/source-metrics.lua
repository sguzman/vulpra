-- Vulpra source inventory: deterministic byte/file counts from NUL-delimited find.
-- Reads: find ... -printf '%s\t%P\0' | lua5.4 tools/source-metrics.lua
local input = io.read("*a")
local by_top, by_extension = {}, {}
local files, bytes = 0, 0

local function increment(tbl, name, size)
    local item = tbl[name]
    if not item then
        item = { files = 0, bytes = 0 }
        tbl[name] = item
    end
    item.files = item.files + 1
    item.bytes = item.bytes + size
end

local start = 1
while start <= #input do
    local zero = input:find("\0", start, true)
    if not zero then
        error("source inventory stream was not NUL terminated")
    end
    local record = input:sub(start, zero - 1)
    local size_text, path = record:match("^(%d+)\t(.+)$")
    if not size_text or not path or path:find("\0", 1, true) then
        error("malformed inventory record at byte " .. start)
    end
    local size = tonumber(size_text)
    if not size then error("invalid source file length") end
    files = files + 1
    bytes = bytes + size
    local top = path:match("^([^/]+)/") or path
    local base = path:match("([^/]+)$") or path
    local extension = (base:sub(1, 1) == "." and "(dotfile)") or base:match("%.([^%.]+)$") or "(none)"
    increment(by_top, top, size)
    increment(by_extension, extension:lower(), size)
    start = zero + 1
end

local function esc(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
end
local function sorted_items(tbl)
    local items = {}
    for name, item in pairs(tbl) do
        items[#items+1] = {name = name, files = item.files, bytes = item.bytes}
    end
    table.sort(items, function(a, b)
        if a.bytes == b.bytes then return a.name < b.name end
        return a.bytes > b.bytes
    end)
    return items
end
local function print_items(items)
    io.write("[\n")
    for i, item in ipairs(items) do
        io.write("    {\"name\":", esc(item.name), ",\"files\":", item.files, ",\"bytes\":", item.bytes, "}")
        if i < #items then io.write(",") end
        io.write("\n")
    end
    io.write("  ]")
end

io.write("{\n")
io.write('  "schema_version": 1,\n')
io.write('  "ref": ', esc(os.getenv("VULPRA_SOURCE_REF") or "unknown"), ',\n')
io.write('  "files": ', files, ',\n')
io.write('  "bytes": ', bytes, ',\n')
io.write('  "top_level": ')
print_items(sorted_items(by_top))
io.write(',\n  "extensions": ')
print_items(sorted_items(by_extension))
io.write('\n}\n')
