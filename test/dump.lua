-- Writes the Super Hi-Res screen (bank $E1, $2000-$9FFF) and the text screen to files
-- every few emulated seconds, and presses keys at given times. Set by run.sh:
--   DUMP_DIR, DUMP_EVERY
--   KEYS   e.g. "60:SU,62:return,70:esc,80:cmd-m"  (seconds:key; key = text to type, or
--          one of return, esc, delete, up, down, left, right, or cmd- and a letter (or ".") for
--          a Command shortcut: the Command key is held while the letter is typed; cmd-. cancels
--          a file dialog)
local dir = os.getenv("DUMP_DIR")
local every = tonumber(os.getenv("DUMP_EVERY") or "15")
local space = manager.machine.devices[":maincpu"].spaces["program"]
local next_dump = every

-- Each entry becomes a timed step.
local steps = {}
for item in string.gmatch(os.getenv("KEYS") or "", "[^,]+") do
    local t, key = item:match("^%s*([%d%.]+):(.+)$")
    t = tonumber(t)
    local text = key
    if key == "return" then text = "\r" end
    local arrow = ({ up = "Up Arrow", down = "Down Arrow", left = "Left Arrow", right = "Right Arrow" })[key]
    local coded = ({ esc = "{ESC}", delete = "{BACKSPACE}" })[key]
    local cmd = key:match("^cmd%-(.)$")
    if cmd then
        -- Both keys pressed as keyboard keys (typed text would drop the Command key).
        local command, letter
        local name = ({ ["."] = ".  >" })[cmd] or (cmd:lower() .. "  " .. cmd:upper())
        for _, port in pairs(manager.machine.ioport.ports) do
            command = command or port.fields["Command"]
            letter = letter or port.fields[name]
        end
        table.insert(steps, { t = t, f = function() command:set_value(1) end })
        table.insert(steps, { t = t + 0.1, f = function() letter:set_value(1) end })
        table.insert(steps, { t = t + 0.3, f = function() letter:clear_value() end })
        table.insert(steps, { t = t + 0.5, f = function() command:clear_value() end })
    elseif arrow then
        -- Typed text has no arrow keys, so press the keyboard key itself for a moment.
        local field
        for _, port in pairs(manager.machine.ioport.ports) do field = field or port.fields[arrow] end
        table.insert(steps, { t = t, f = function() field:set_value(1) end })
        table.insert(steps, { t = t + 0.03, f = function() field:clear_value() end })
    elseif coded then
        table.insert(steps, { t = t, f = function() manager.machine.natkeyboard:post_coded(coded) end })
    else
        table.insert(steps, { t = t, f = function() manager.machine.natkeyboard:post(text) end })
    end
end
table.sort(steps, function(a, b) return a.t < b.t end)
local next_step = 1

local function dump(n)
    local f = io.open(string.format("%s/screen_%03d.shr", dir, n), "wb")
    for a = 0xE12000, 0xE19FFF do f:write(string.char(space:read_u8(a))) end
    f:close()
    -- The 80-column text screen too (a crash shows the Monitor there).
    local tf = io.open(string.format("%s/text_%03d.txt", dir, n), "w")
    for row = 0, 23 do
        local base = 0x400 + (row % 8) * 0x80 + (row // 8) * 0x28
        local line = {}
        for col = 0, 79 do
            local bank = (col % 2 == 0) and 0x010000 or 0x000000
            local c = space:read_u8(bank + base + col // 2) & 0x7F
            if c < 0x20 then c = c + 0x40 end
            line[#line + 1] = string.char(c)
        end
        tf:write(table.concat(line), "\n")
    end
    tf:close()
    manager.machine.video:snapshot()       -- what the display shows (snapshot folder)
    -- And where the processor is, for finding a hang.
    local st = manager.machine.devices[":maincpu"].state
    local pf = io.open(string.format("%s/pc.txt", dir), "a")
    local function reg(n) return st[n] and st[n].value or -1 end
    pf:write(string.format("%d PB=%02X PC=%04X A=%04X X=%04X Y=%04X S=%04X D=%04X DB=%02X\n", n,
        reg("PB"), reg("PC"), reg("A"), reg("X"), reg("Y"), reg("S"), reg("D"), reg("DB")))
    pf:close()
end

-- When the test commands are done, MegaconvertGS writes DONE at the start of the text
-- screen memory ($E0/0400): dump once more and stop instead of running out the time.
local next_check = 1
local function done()
    return space:read_u8(0xE00400) == 0xC4 and space:read_u8(0xE00401) == 0xCF and
        space:read_u8(0xE00402) == 0xCE and space:read_u8(0xE00403) == 0xC5
end

-- PROFILE=file: where the processor is at each call (about 60 a second), counted by
-- bank and address, written with copies of the busy banks when the tests are done.
local profile = os.getenv("PROFILE")
local counts = {}
local function write_profile()
    local f = io.open(profile, "w")
    local banks, total = {}, 0
    for k, n in pairs(counts) do
        f:write(string.format("%06X %d\n", k, n))
        banks[k >> 16] = (banks[k >> 16] or 0) + n
        total = total + n
    end
    f:close()
    -- A copy of each bank that had a good share (not the ROM, the system banks).
    for bank, n in pairs(banks) do
        if n * 20 >= total and bank > 1 and bank < 0xE0 then
            local m = io.open(string.format("%s.%02X", profile, bank), "wb")
            for a = bank << 16, (bank << 16) + 0xFFFF do m:write(string.char(space:read_u8(a))) end
            m:close()
        end
    end
end

emu.register_periodic(function()
    local t = manager.machine.time.seconds
    if profile then
        local st = manager.machine.devices[":maincpu"].state
        local k = (st["PB"].value << 16) | (st["PC"].value & 0xFFFF)
        counts[k] = (counts[k] or 0) + 1
    end
    while next_step <= #steps and t >= steps[next_step].t do
        steps[next_step].f()
        next_step = next_step + 1
    end
    if t >= next_dump then
        dump(next_dump)
        next_dump = next_dump + every
    end
    if t >= next_check then
        next_check = t + 1
        if done() then
            dump(math.floor(t))
            if profile then write_profile() end
            manager.machine:exit()
        end
    end
end)
