-- Presence frames, each as small as it can be, all riding in one presence value. The protocol version rides on the meta alone, and the
-- other frames are read only beside a meta that was accepted. Account identity comes from the game's presence entry.
-- BEAT: the longest a live sender goes without sending. STALE and LIVE: how old a beat may be by the sender's clock, and how
-- long ago it may have last moved on by the reader's. The game sends a presence change on its next 30-second update, so a live
-- sender's beats can reach a reader about 60 seconds apart; a silent sender reads as stale within about 100 seconds.
-- The reasoning is in docs/HAVOC-BOARD-API.md.
local P = {MAX_BYTES = 250, VERSION = "4", BEAT = 24, STALE = 96, LIVE = 90, EPOCH = 1577836800}
-- The fields of the value, each one frame below; peers and replies are named by slot.
P.fields = {meta = "m", votes = "v", beat = "b", assignment = "a", request = "q", attempt = "t"}
for i = 1, 4 do
    P.fields["peer" .. i] = tostring(i)
    P.fields["reply" .. i] = tostring(i + 4)
end
-- The presence keys: the value, and the rest of a value longer than one key holds.
P.keys = {"hv", "hw"}
local F = P.fields
local TAGS = {"1", "2", "3", "4", "5", "6", "7", "8", "q", "t"}
local TAGGED = {}
for _, tag in ipairs(TAGS) do TAGGED[tag] = true end

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
local B64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

function P.base36(n, width)
    local out = ""
    repeat
        local d = n % 36
        out = B36:sub(d + 1, d + 1) .. out
        n = math.floor(n / 36)
    until n == 0
    return width and string.rep("0", width - #out) .. out or out
end

-- Fingerprints bind values across clients; they are not authentication. A polynomial hash modulo the largest prime below 2^36
-- spreads over all 36 bits, and two values differing in one character never share one. Every step stays exact in a double.
local PRIME = 68719476731
function P.digest(raw)
    local h = 5381
    for i = 1, #raw do h = (h * 65599 + raw:byte(i)) % PRIME end
    local out = {}
    for i = 6, 1, -1 do
        local d = h % 64
        out[i] = B64:sub(d + 1, d + 1)
        h = math.floor(h / 64)
    end
    return table.concat(out)
end

-- Read here rather than by tonumber, whose base-36 reading stops at 32 bits on some builds.
local function from36(text)
    if type(text) ~= "string" or not text:match("^[0-9a-z]+$") then return end
    local n = 0
    for i = 1, #text do n = n * 36 + B36:find(text:sub(i, i), 1, true) - 1 end
    return n
end

-- A session is the second it began, counted from EPOCH, so it also dates the beats and expiries sent under it.
function P.base(session) return P.EPOCH + from36(session) end

local codes = {
    status = {unknown = "u", loading = "l", available = "a", none = "n", failed = "f"},
    reply = {accepted = "a", busy = "b", denied = "d", changed = "c", failed = "f", voting = "v", expired = "e", approved = "p", rejected = "r"},
}
local words = {}
for kind, map in pairs(codes) do
    words[kind] = {}
    for word, code in pairs(map) do words[kind][code] = word end
end
local widths = {session = 6, digest = 6, slot = 1, bit = 1, hex = 1, tick = 1, status = 1, reply = 1}
local tops = {slot = 4, bit = 1, hex = 15, tick = 35, count = 78364164095}
-- Fixed-width fields first, then any counts, separated by dots. Times are seconds after the sender's session began.
-- The meta changes only with the session, status or permission; the votes on your map and the refresh signal change apart from it.
-- A peer frame names the assignment it votes for only when it holds a vote: no vote is no vote on whatever the owner now has.
local schemas = {
    M = {{"scope", "digest"}, {"session", "session"}, {"status", "status"}, {"remote", "bit"}},
    V = {{"votes", "hex"}, {"refresh", "tick"}},
    B = {{"beat", "count"}},
    P = {{"ack", "session"}, {"vote", "bit"}, {"target", "digest", "vote"}},
    Q = {{"owner", "slot"}, {"ack", "session"}, {"assignment", "digest"}, {"id", "count"}, {"expires", "count"}},
    R = {{"ack", "session"}, {"status", "reply"}, {"id", "count"}},
    A = {{"requester", "slot"}, {"ack", "session"}, {"assignment", "digest"}, {"mission", "digest"}, {"id", "count"}, {"expires", "count"}},
}

local function field(kind, value)
    if kind == "session" then return type(value) == "string" and #value == 6 and value:match("^[0-9a-z]+$") and value end
    if kind == "digest" then return type(value) == "string" and #value == 6 and value:match("^[%w%-_]+$") and value end
    if codes[kind] then return codes[kind][value] end
    if type(value) ~= "number" or value ~= math.floor(value) or value < (kind == "slot" and 1 or 0) or value > tops[kind] then return end
    return P.base36(value)
end

function P.encode(kind, frame)
    local schema = schemas[kind]
    if type(frame) ~= "table" or not schema then return nil, "invalid " .. tostring(kind) .. " frame" end
    local head, counts = {kind == "M" and P.VERSION or ""}, {}
    for _, spec in ipairs(schema) do
        if not spec[3] or frame[spec[3]] == 1 then
            local text = field(spec[2], frame[spec[1]])
            if not text then return nil, "invalid " .. kind .. " frame" end
            if spec[2] == "count" then counts[#counts + 1] = text else head[#head + 1] = text end
        end
    end
    local raw = table.concat(head) .. table.concat(counts, ".")
    if #raw > P.MAX_BYTES then return nil, "presence value exceeds 250 bytes" end
    return raw
end

function P.decode(kind, raw)
    if type(raw) ~= "string" or #raw == 0 or #raw > P.MAX_BYTES then return nil, "invalid presence value size" end
    local schema = schemas[kind]
    if not schema then return nil, "unknown frame" end
    local at = 1
    if kind == "M" then
        if raw:sub(1, 1) ~= P.VERSION then return nil, "incompatible presence protocol" end
        at = 2
    end
    local frame, counts = {}, {}
    for _, spec in ipairs(schema) do
        local name, kind_of = spec[1], spec[2]
        if kind_of == "count" then counts[#counts + 1] = name
        elseif not spec[3] or frame[spec[3]] == 1 then
            local text = raw:sub(at, at + widths[kind_of] - 1)
            at = at + widths[kind_of]
            if kind_of == "session" or kind_of == "digest" then frame[name] = text
            elseif words[kind_of] then frame[name] = words[kind_of][text]
            else frame[name] = from36(text) end
        end
    end
    if #counts > 0 then
        local rest, i = raw:sub(at) .. ".", 0
        for text in rest:gmatch("([^.]*)%.") do
            i = i + 1
            if counts[i] then frame[counts[i]] = from36(text) end
        end
        if i ~= #counts then return nil, "invalid presence frame" end
    end
    -- Only the canonical spelling is accepted, so one value has one meaning.
    local encoded, err = P.encode(kind, frame)
    if encoded ~= raw then return nil, err or "noncanonical presence value" end
    return frame
end

-- An assignment whose ID is a UUID rides with its 128 bits in 22 characters after a "!", in place of the codec's "1|" and the 36 it
-- is spelled with; the reader spells it out again, so fingerprints and the codec see the assignment as the codec wrote it.
local UUID = "^1|(" .. ("%x"):rep(8) .. "%-" .. ("%x"):rep(4) .. "%-" .. ("%x"):rep(4) .. "%-" .. ("%x"):rep(4) .. "%-" .. ("%x"):rep(12) .. ")(|.*)$"
local function shrink(assignment)
    local id, rest = assignment:match(UUID)
    if not id or id:find("%u") then return assignment end
    local hex, out = id:gsub("%-", ""), {"!"}
    for i = 1, 31, 3 do
        local n = tonumber(hex:sub(i, i + 2), 16)
        out[#out + 1] = B64:sub(math.floor(n / 64) + 1, math.floor(n / 64) + 1) .. B64:sub(n % 64 + 1, n % 64 + 1)
    end
    return table.concat(out) .. rest
end
local function grow(assignment)
    if assignment:sub(1, 1) ~= "!" then return assignment end
    local hex = {}
    for i = 2, 22, 2 do
        local high, low = B64:find(assignment:sub(i, i), 1, true), B64:find(assignment:sub(i + 1, i + 1), 1, true)
        if not high or not low then return end
        local n = (high - 1) * 64 + low - 1
        if i == 22 and n > 255 then return end
        hex[#hex + 1] = string.format(i == 22 and "%02x" or "%03x", n)
    end
    hex = table.concat(hex)
    return "1|" .. hex:sub(1, 8) .. "-" .. hex:sub(9, 12) .. "-" .. hex:sub(13, 16) .. "-" .. hex:sub(17, 20) .. "-" .. hex:sub(21) .. assignment:sub(24)
end

-- The value: the meta, the votes and the beat, then the assignment (empty when there is none) and each further frame that is there,
-- led by its field's tag, all after slashes; "" when every field is empty. No frame holds a slash, a plus or a "!".
function P.pack(fields)
    local any = false
    for _, tag in pairs(F) do
        local value = fields[tag]
        if value ~= nil and (type(value) ~= "string" or value:find("[/+!]")) then return nil, "invalid presence field" end
        any = any or value ~= nil and value ~= ""
    end
    if not any then return "" end
    local meta, votes, beat = fields[F.meta] or "", fields[F.votes] or "", fields[F.beat] or ""
    if #meta ~= 15 or #votes ~= 2 or beat == "" then return nil, "incomplete presence value" end
    local out = {meta .. votes .. beat, shrink(fields[F.assignment] or "")}
    for _, tag in ipairs(TAGS) do
        local value = fields[tag]
        if value and value ~= "" then out[#out + 1] = tag .. value end
    end
    local raw = table.concat(out, "/")
    if #raw > 2 * P.MAX_BYTES - 1 then return nil, "presence value exceeds two keys" end
    return raw
end

function P.unpack(raw)
    if type(raw) ~= "string" or raw == "" then return end
    local parts = {}
    for part in (raw .. "/"):gmatch("([^/]*)/") do parts[#parts + 1] = part end
    if #parts < 2 then return end
    local head = parts[1]
    local fields = {[F.meta] = head:sub(1, 15), [F.votes] = head:sub(16, 17), [F.beat] = head:sub(18)}
    if parts[2] ~= "" then fields[F.assignment] = grow(parts[2]) end
    if parts[2] ~= "" and not fields[F.assignment] then return end
    for i = 3, #parts do
        local tag = parts[i]:sub(1, 1)
        if not TAGGED[tag] or fields[tag] then return end
        fields[tag] = parts[i]:sub(2)
    end
    if P.pack(fields) ~= raw then return end
    return fields
end

-- A value over one key's 250 bytes keeps its first 249 in the first key, marked by a plus, and the rest in the second.
function P.split(raw)
    if #raw <= P.MAX_BYTES then return raw end
    return raw:sub(1, P.MAX_BYTES - 1) .. "+", raw:sub(P.MAX_BYTES)
end

function P.join(first, rest)
    if type(first) ~= "string" or first == "" or #first > P.MAX_BYTES then return end
    if first:sub(-1) ~= "+" then return first end
    if #first ~= P.MAX_BYTES or type(rest) ~= "string" or rest == "" or #rest > P.MAX_BYTES then return end
    return first:sub(1, -2) .. rest
end

return P
